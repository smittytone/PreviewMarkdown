
//  PreviewViewController.swift
//  Previewer
//
//  Created by Tony Smith on 31/10/2019.
//  Copyright © 2021 Tony Smith. All rights reserved.


import Cocoa
import Quartz


class PreviewViewController: NSViewController, QLPreviewingController {

    // MARK:- Class Properties

    @IBOutlet var errorReportField: NSTextField!
    @IBOutlet var renderTextView: NSTextView!

    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }


    // MARK:- QLPreviewingController Required Functions

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {

        // Hide the error message field
        self.errorReportField.isHidden = true

        // FROM 1.1.0
        // Get an error message ready for use
        var reportError: NSError? = nil

        // Load the source file using a co-ordinator as we don't know what thread this function
        // will be executed in when it's called by macOS' QuickLook code
        // NOTE From 1.1.0 we use plain old FileManager for this
        if FileManager.default.isReadableFile(atPath: url.path) {
            // Only proceed if the file is accessible from here
            do {
                // Get the file contents as a string
                let data: Data = try Data.init(contentsOf: url)
                if let markdownString: String = String.init(data: data, encoding: .utf8) {

                    // Update the NSTextView
                    // FROM 1.2.0 -- Use a preference to govern this
                    var doShowLightBackground: Bool = false

                    if let defaults = UserDefaults(suiteName: MNU_SECRETS.PID + ".suite.previewmarkdown") {
                        defaults.synchronize()
                        doShowLightBackground = defaults.bool(forKey: "com-bps-previewmarkdown-do-use-light")
                    }

                    self.renderTextView.backgroundColor = doShowLightBackground ? NSColor.white : NSColor.textBackgroundColor

                    if let renderTextStorage: NSTextStorage = self.renderTextView.textStorage {
                        renderTextStorage.setAttributedString(getAttributedString(markdownString, false))
                    }

                    // Add the subview to the instance's own view and draw
                    self.view.display()

                    // Call the QLPreviewingController indicating no error (nil)
                    handler(nil)
                    return
                } else {
                    // We couldn't get the markdwn string so set an appropriate error to report back
                    reportError = NSError(domain: "com.bps.PreviewMarkdown.Previewer",
                                          code: BUFFOON_CONSTANTS.ERRORS.CODES.BAD_MD_STRING,
                                          userInfo: [NSLocalizedDescriptionKey: BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_MD_STRING])
                }
            } catch {
                // We couldn't read the file so set an appropriate error to report back
                reportError = NSError(domain: "com.bps.PreviewMarkdown.Previewer",
                                      code: BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN,
                                      userInfo: [NSLocalizedDescriptionKey: BUFFOON_CONSTANTS.ERRORS.MESSAGES.FILE_WONT_OPEN])
            }

            handler(reportError)
        }

        // Display the error locally in the window
        showError(reportError!.userInfo[NSLocalizedDescriptionKey] as! String)

        // Call the QLPreviewingController indicating no error (nil)
        handler(nil)
    }


    func preparePreviewOfSearchableItem(identifier: String, queryString: String?, completionHandler handler: @escaping (Error?) -> Void) {

        // Is this ever called?
        NSLog("BUFFOON searchable identifier: \(identifier)")
        NSLog("BUFFOON searchable query:      " + (queryString ?? "nil"))

        // Hand control back to QuickLook
        handler(nil)
    }


    // MARK:- Utility Functions

    func showError(_ errString: String) {

        // Relay an error message to its various outlets

        NSLog("BUFFOON " + errString)
        self.errorReportField.stringValue = errString
        self.errorReportField.isHidden = false
    }

}
