/*
 *  AppDelegateMisc.swift
 *  PreviewMarkdown
 *  Extension for AppDelegate providing functionality used across PreviewApps.
 *
 *  These functions can be used by all PreviewApps
 *
 *  Created by Tony Smith on 18/06/20214.
 *  Copyright © 2025 Tony Smith. All rights reserved.
 */


import AppKit
import WebKit
import UniformTypeIdentifiers


extension AppDelegate {

    // MARK: - Process Handling Functions

    /**
     Generic macOS process creation and run function.

     Make sure we clear the preference flag for this minor version, so that
     the sheet is not displayed next time the app is run (unless the version changes)

     - Parameters:
        - app:  The location of the app.
        - with: Array of arguments to pass to the app.

     - Returns: `true` if the operation was successful, otherwise `false`.
     */
    internal func runProcess(app path: String, with args: [String]) -> Bool {
        
        let task: Process = Process()
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
        
        if !task.isRunning {
            if (task.terminationStatus != 0) {
                // Command failed -- collect the output if there is any
                let outputHandle = outputPipe.fileHandleForReading
                var outString: String = ""
                if let line = String(data: outputHandle.availableData, encoding: String.Encoding.utf8) {
                    outString = line
                }
                
                if outString.count > 0 {
                    print("\(outString)")
                } else {
                    print("Error", "Exit code \(task.terminationStatus)")
                }
                return false
            }
        }
        
        return true
    }


    // MARK: - Finder Database Reset Functions
    
    internal func warnUserAboutReset() {
        
        // Hide panel-opening menus
        self.hidePanelGenerators()
        
        // Warn the user about the risks (minor)
        let alert: NSAlert = showAlert("Are you sure you wish to reset Finder’s UTI database?",
                                       "Resetting Finder’s Uniform Type Identifier (UTI) database may result in unexpected associations between files and apps, but it can also fix situations where previews are not being shown after you have first logged out of your Mac.\n\nLogging out of your Mac fixes most issues and should be tried first.\n\nUSE THIS OPTION AT YOUR OWN RISK — WE ACCEPT NO RESPONSIBILITY WHATSOEVER FOR THIS OPTION’s EFFECTS",
                                        false, true)
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
        let alert: NSAlert = showAlert("Are you really sure you wish to reset Finder’s UTI database?", "", false, true)
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
        let success: Bool = runProcess(app: BUFFOON_CONSTANTS.SYS_LAUNCH_SERVICES,
                                       with: ["-kill", "-f", "-r", "-domain", "user", "-domain", "local"])
        if !success {
            let alert: NSAlert = showAlert("Sorry, the operation failed", "The Finder database could not be reset at this time")
            alert.alertStyle = .critical
            alert.beginSheetModal(for: self.window)
        } else {
            let alert: NSAlert = showAlert("Finder’s database was reset", "")
            alert.beginSheetModal(for: self.window)
        }
    }


    // MARK: - Alert Handler Functions

    /**
     Generic alert generator.

     - Parameters:
        - head:        The alert's title.
        - message:     The alert's message.
        - addOkButton: Should we add an OK button?

     - Returns:     The NSAlert.
     */
    internal func showAlert(_ head: String, _ message: String, _ addOkButton: Bool = true, _ isCritical: Bool = false) -> NSAlert {

        let alert: NSAlert = NSAlert()
        alert.messageText = head
        alert.informativeText = message
        if addOkButton { alert.addButton(withTitle: "OK") }
        if isCritical { alert.alertStyle = .critical }
        return alert
    }


    // MARK: - Data Generator Functions

    /**
     Build a basic 'major-manor' version string for prefs usage.

     - Returns: The version string.
     */
    internal func getVersion() -> String {
        
        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let parts: [String] = (version as NSString).components(separatedBy: ".")
        return parts[0] + "-" + parts[1]
    }


    /**
     Build a date string string for feedback usage.

     - Returns: The date string.
     */
    internal func getDateForFeedback() -> String {

        let date: Date = Date()
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return dateFormatter.string(from: date)
    }


    /**
     Build a user-agent string string for feedback usage.

     - Returns: The user-agent string.
     */
    internal func getUserAgentForFeedback() -> String {

        // Refactor code out into separate function for clarity

        let sysVer: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
        let bundle: Bundle = Bundle.main
        let app: String = bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as! String
        let version: String = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let build: String = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        return "\(app)/\(version)-\(build) (macOS/\(sysVer.majorVersion).\(sysVer.minorVersion).\(sysVer.patchVersion))"
    }


    /**
     Read back the host system's registered UTI for the specified file.
     
     This is not PII. It used solely for debugging purposes
     
     - Parameters:
        - filename: The file we'll use to get the UTI.
     
     - Returns: The file's UTI.
     */
    internal func getLocalFileUTI(_ filename: String) -> String {
        
        var localUTI: String = "NONE"
        let samplePath = Bundle.main.resourcePath! + "/" + filename
        
        if FileManager.default.fileExists(atPath: samplePath) {
            // Create a URL reference to the sample file
            let sampleURL = URL(fileURLWithPath: samplePath)
            
            do {
                // Read back the UTI from the URL
                // Use Big Sur's UTType API
                if #available(macOS 11, *) {
                    if let uti: UTType = try sampleURL.resourceValues(forKeys: [.contentTypeKey]).contentType {
                        localUTI = uti.identifier
                    }
                } else {
                    // NOTE '.typeIdentifier' yields an optional
                    if let uti: String = try sampleURL.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier {
                        localUTI = uti
                    }
                }
            } catch {
                // NOP
            }
        }
        
        return localUTI
    }


    /**
     Disable all panel-opening menu items.
     */
    internal func hidePanelGenerators() {
        
        self.helpMenuWhatsNew.isEnabled = false
        self.mainMenuResetFinder.isEnabled = false
    }


    /**
     Enable all panel-opening menu items.
     */
    internal func showPanelGenerators() {
        
        self.helpMenuWhatsNew.isEnabled = true
        self.mainMenuResetFinder.isEnabled = true
    }


    /**
     Determine whether the host Mac is in light mode.
     
     - Returns: `true` if the Mac is in light mode, otherwise `false`.
     */
    internal func isMacInLightMode() -> Bool {
        
        let appearNameString: String = NSApp.effectiveAppearance.name.rawValue
        return (appearNameString == "NSAppearanceNameAqua")
    }


    func applicationSupportsSecureRestorableState() -> Bool {
        
        return true
    }


    // MARK: - URLSession Delegate Functions

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        
        // Some sort of connection error - report it
        self.connectionProgress.stopAnimation(self)
        sendFeedbackError()
    }


    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        // The operation to send the comment completed
        self.connectionProgress.stopAnimation(self)
        if let _ = error {
            // An error took place - report it
            sendFeedbackError()
        } else {
            // The comment was submitted successfully
            let alert: NSAlert = showAlert("Thanks For Your Feedback!",
                                           "Your comments have been received and we’ll take a look at them shortly.")
            alert.beginSheetModal(for: self.window) { (resp) in
                // Close the feedback window when the modal alert returns
                let _: Timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { timer in
                    //self.window.endSheet(self.window)
                    self.showPanelGenerators()
                    self.hasSentFeedback = true
                    self.messageSendButton.isEnabled = false
                }
            }
        }
    }


    // MARK: - WKWebNavigation Delegate Functions

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        // Asynchronously show the sheet once the HTML has loaded
        // (triggered by delegate method)
        
        if let nav = self.whatsNewNav {
            if nav == navigation {
                // Display the sheet
                Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { timer in
                    timer.invalidate()
                    self.window.beginSheet(self.whatsNewWindow, completionHandler: nil)
                }
            }
        }
    }


    // MARK: - NSWindowDelegate Functions

    /**
      Catch when the user clicks on the window's red close button.
     */
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        
        if !checkFeedbackOnQuit() && !checkSettingsOnQuit() {
            // No unsaved settings or unsent feedback, so we're good to close
            return true
        }
        
        // Close mmanually
        // NOTE The above check will fail if there are settings changes and/or
        //      unsent feedback, in which case the following calls will trigger
        //      alerts
        closeBasics()
        closeSettings()
        return false
    }


    // MARK: - NSMenuDelegate Functions

    internal func menuWillOpen(_ menu: NSMenu) {

        if menu == self.mainMenu {
            // Check to see if the Option key was down when the menu was clicked
            mainMenuResetFinder.isHidden = !NSEvent.modifierFlags.contains(NSEvent.ModifierFlags.option)
        }
    }
}
