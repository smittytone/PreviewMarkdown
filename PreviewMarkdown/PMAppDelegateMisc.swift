/*
 *  PMAppDelegateMisc.swift
 *  PreviewMarkdown
 *  Extension for AppDelegate providing functionality used across PreviewApps.
 *
 *  These functions can be used by all PreviewApps
 *
 *  Created by Tony Smith on 18/06/20214.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */

import AppKit


extension AppDelegate {

    // MARK: - Process Handling Functions

    /**
     Generic macOS process creation and run function.

     - Parameters:
     - app:  The location of the app.
     - with: Array of arguments to pass to the app.

     - Returns: `true` if the operation was successful, otherwise `false`.
     */
    internal func runProcess(app path: String, with args: [String]) -> Bool {

        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args

        // Pipe out the output to avoid putting it in the log
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = outputPipe

        do {
            try task.run()
        } catch {
            return false
        }

        // Block until the task has completed (short tasks ONLY)
        task.waitUntilExit()

        if (task.terminationStatus != 0) {
            // Command failed -- collect the output if there is any
            let outputHandle = outputPipe.fileHandleForReading
            var outString = ""
            if let line = String(data: outputHandle.availableData, encoding: .utf8) {
                outString = line
            }
#if DEBUG
            if outString.count > 0 {
                print("\(outString)")
            } else {
                print("Error", "Exit code \(task.terminationStatus)")
            }
#endif
            return false
        }

        return true
    }


    // MARK: - Finder Database Reset Functions

    internal func warnUserAboutReset() {

        // Hide panel-opening menus
        self.hidePanelGenerators()

        // Warn the user about the risks (minor)
        let alert = makeAlert("Are you sure you wish to reset Finder’s UTI database?",
                              "Resetting Finder’s Uniform Type Identifier (UTI) database may result in unexpected associations between files and apps, but it can also fix situations where previews are not being shown after you have first logged out of your Mac.\n\nLogging out of your Mac fixes most issues and should be tried first.\n\nUSE THIS OPTION AT YOUR OWN RISK — WE ACCEPT NO RESPONSIBILITY WHATSOEVER FOR THIS OPTION’s EFFECTS",
                              false,
                              true)
        alert.addButton(withTitle: "Go Back")
        alert.addButton(withTitle: "Continue")

        // Show the alert
        alert.beginSheetModal(for: self.window) { (resp) in
            // Close alert and restore menus
            alert.window.close()

            // If the user wants to continue, perform the reset
            if resp == .alertSecondButtonReturn {
                // Perform the reset
                self.doubleCheck()
            } else {
                self.showPanelGenerators()
            }
        }
    }


    internal func doubleCheck() {

        // Warn the user about the risks (minor)
        let alert = makeAlert("Are you really sure you wish to reset Finder’s UTI database?", "", false, true)
        alert.addButton(withTitle: "No")
        alert.addButton(withTitle: "Yes")

        // Show the alert
        alert.beginSheetModal(for: self.window) { (resp) in
            // Close alert and restore menus
            alert.window.close()
            self.showPanelGenerators()

            // If the user wants to continue, perform the reset
            if resp == .alertSecondButtonReturn {
                // Perform the reset
                self.doResetFinderDatabase()
            }
        }
    }


    /**
     Reset Finder's launch services database using a sub-process.
     */
    internal func doResetFinderDatabase() {

        // Perform the Finder reset
        // NOTE Cannot access the system domain from within the Sandbox
        let success = runProcess(app: BUFFOON_CONSTANTS.SYS_LAUNCH_SERVICES,
                                 with: ["-kill", "-f", "-r", "-domain", "user", "-domain", "local"])
        if !success {
            let alert = makeAlert("Sorry, the operation failed", "The Finder database could not be reset at this time")
            alert.alertStyle = .critical
            alert.beginSheetModal(for: self.window)
        } else {
            let alert = makeAlert("Finder’s database was reset", "")
            alert.beginSheetModal(for: self.window)
        }
    }


    /**
     Disable all panel-opening menu items.
     */
    internal func localHides() {

        self.mainMenuResetFinder.isEnabled = false
    }


    /**
     Enable all panel-opening menu items.
     */
    internal func localShows() {

        self.mainMenuResetFinder.isEnabled = false
    }


    internal func localApplicationDidFinishLaunching() {

        // FROM 1.2.0
        // Get the local UTI for markdown files
        self.localMarkdownUTI = getLocalFileUTI(BUFFOON_CONSTANTS.SAMPLE_UTI_FILE)

        // FROM 2.0.0
        // Register our Markdown to HTML service
        NSApplication.shared.servicesProvider = HTMLServiceProvider()
        NSUpdateDynamicServices()
    }

    
    // MARK: - NSMenuDelegate Functions

    internal func menuWillOpen(_ menu: NSMenu) {

        if menu == self.mainMenu {
            // Check to see if the Option key was down when the menu was clicked
            mainMenuResetFinder.isHidden = !NSEvent.modifierFlags.contains(NSEvent.ModifierFlags.option)
        }
    }
}
