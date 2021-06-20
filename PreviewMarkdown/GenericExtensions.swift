/*
 *  GenericExtensions.swift
 *  PreviewApps
 *
 *  These functions can be used by all PreviewApps
 *
 *  Created by Tony Smith on 18/06/2021.
 *  Copyright © 2021 Tony Smith. All rights reserved.
 */


import Foundation
import Cocoa
import WebKit


extension AppDelegate {

    // MARK:- Process Handling Functions

    /**
     Generic macOS process creation and run function.

     Make sure we clear the preference flag for this minor version, so that
     the sheet is not displayed next time the app is run (unless the version changes)

     - Parameters:
        - app: The location of the app.
        - with: Array of arguments to pass to the app

     - Returns: `true` if the operation was successful, otherwise `false`
     */
    internal func runProcess(app path: String, with args: [String]) -> Bool {

        let task: Process = Process()
        task.executableURL = URL.init(fileURLWithPath: path)
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


    // MARK: - Misc Functions

    /**
     Present an error message specific to sending feedback.

     This is called from multiple locations: if the initial request can't be created,
     there was a send failure, or a server error
     */
    internal func sendFeedbackError() {

        let alert: NSAlert = showAlert("Feedback Could Not Be Sent",
                                       "Unfortunately, your comments could not be send at this time. Please try again later.")
        alert.beginSheetModal(for: self.reportWindow,
                              completionHandler: nil)

    }


    /**
     Generic alert generator.

     - Parameters:
        - head:    The alert's title.
        - message: The alert's message.

     - Returns: The NSAlert
     */
    internal func showAlert(_ head: String, _ message: String) -> NSAlert {

        let alert: NSAlert = NSAlert()
        alert.messageText = head
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        return alert
    }


    /**
     Build a basic 'major.manor' version string for prefs usage.

     - Returns: The version string
     */
    internal func getVersion() -> String {

        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let parts: [String] = (version as NSString).components(separatedBy: ".")
        return parts[0] + "-" + parts[1]
    }


    /**
     Build a date string string for feedback usage.

     - Returns: The date string
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

     - Returns: The user-agent string
     */
    internal func getUserAgentForFeedback() -> String {

        // Refactor code out into separate function for clarity

        let sysVer: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
        let bundle: Bundle = Bundle.main
        let app: String = bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as! String
        let version: String = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let build: String = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        return "\(app)/\(version)-\(build) (Mac macOS \(sysVer.majorVersion).\(sysVer.minorVersion).\(sysVer.patchVersion))"
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
            alert.beginSheetModal(for: self.reportWindow) { (resp) in
                // Close the feedback window when the modal alert returns
                let _: Timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { timer in
                    self.window.endSheet(self.reportWindow)
                }
            }
        }
    }


    // MARK: - WKWebViewNavigation Delegate Functions

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {

        /*
         * Asynchronously show the sheet once the HTML has loaded
         * (triggered by delegate method)
         */

        if let nav = self.whatsNewNav {
            if nav == navigation {
                // Display the sheet
                self.window.beginSheet(self.whatsNewWindow, completionHandler: nil)
            }
        }
    }

}
