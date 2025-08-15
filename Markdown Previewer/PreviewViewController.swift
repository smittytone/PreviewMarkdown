/*
 *  PreviewViewController.swift
 *  Markdown Previewer
 *
 *  Created by Tony Smith on 31/10/2019.
 *  Copyright © 2025 Tony Smith. All rights reserved.
 */


import Cocoa
import Quartz


class PreviewViewController: NSViewController,
                             QLPreviewingController {

    // MARK: - Class UI Properties

    @IBOutlet weak var errorReportField: NSTextField!
    @IBOutlet weak var renderTextView: NSTextView!
    @IBOutlet weak var renderTextScrollView: NSScrollView!


    // MARK: - Private Properties
    
    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }


    // MARK: - QLPreviewingController Required Functions

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {

        /*
         * This is the main entry point for the macOS QuickLook previewing system
         */

        // Hide the error message field
        self.errorReportField.isHidden = true
        self.renderTextScrollView.isHidden = false
        
        // FROM 1.1.0
        // Get an error message ready for use
        var reportError: NSError? = nil

        do {
            // Get the file contents as a string
            let data: Data = try Data(contentsOf: url, options: [.uncached])

            // FROM 1.4.3
            // Get the string's encoding, or fail back to .utf8
            let encoding: String.Encoding = data.stringEncoding ?? .utf8

            // Convert the data to a string
            if let markdownString: String = String(data: data, encoding: encoding) {
                // Instantiate the common code
                guard let common: Common = Common() else {
                    reportError = setError(BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN)
                    showError(reportError!)
                    handler(reportError)
                    return
                }

                // FROM 2.0.0
                // Pass in the source file's directory
                common.workingDirectory = (url.path as NSString).deletingLastPathComponent

                // FROM 2.0.0
                // Set the view to display in light mode, even if the Mac is set to dark mode,
                // if that's required by the user. This means we can stick to as few fixed colours
                // as possible: AppKit will flip accordingly.
                if common.doShowLightBackground {
                    self.view.appearance = NSAppearance(named: .aqua)
                }

                // Update the NSTextView
                self.renderTextView.backgroundColor = common.doShowLightBackground ? NSColor(white: 0.9, alpha: 1.0) : NSColor.textBackgroundColor
                self.renderTextScrollView.scrollerKnobStyle = common.doShowLightBackground ? .dark : .light

                // FROM 2.1.0
                // Add margin if required
                if common.doShowMargin {
                    self.renderTextView.textContainerInset = BUFFOON_CONSTANTS.PREVIEW_MARGIN_SIZE
                }

                // FROM 2.0.0
                // Correct way to set a text view's link colouring, etc. - and have it stick
                self.renderTextView.linkTextAttributes = [NSAttributedString.Key.foregroundColor: common.linkColor,
                                                          NSAttributedString.Key.cursor: NSCursor.pointingHand ]

                // Access the text view's storage to place the rendered Markdown string
                if let renderTextStorage: NSTextStorage = self.renderTextView.textStorage {
                    if let renderTextContainer: NSTextContainer = self.renderTextView.textContainer {
                        // Add a custom layout manager to trap double-underlines, which
                        // we are using as a proxy for lozenged text - the layouter will
                        // do the replacement work
                        let layouter = PMLayouter()
                        layouter.marginAdd = common.doShowMargin ? BUFFOON_CONSTANTS.PREVIEW_MARGIN_WIDTH : 0.0
                        layouter.fontSize = common.fontSize
                        layouter.lineSpacing = common.lineSpacing
                        renderTextContainer.replaceLayoutManager(layouter)
                    }

                    renderTextStorage.beginEditing()
                    renderTextStorage.setAttributedString(common.getAttributedString(markdownString[...]))
                    renderTextStorage.endEditing()
                    self.view.display()

                    // Call the QLPreviewingController indicating no error (nil)
                    handler(nil)
                    return
                }

                // We couldn't access the preview NSTextView's NSTextStorage
                reportError = setError(BUFFOON_CONSTANTS.ERRORS.CODES.BAD_TS_STRING)
            } else {
                // FROM 1.4.3
                // We couldn't convert to data to a valid encoding
                let errDesc: String = "\(BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_TS_STRING) \(encoding)"
                reportError = NSError(domain: BUFFOON_CONSTANTS.APP_CODE_PREVIEWER,
                                      code: BUFFOON_CONSTANTS.ERRORS.CODES.BAD_MD_STRING,
                                      userInfo: [NSLocalizedDescriptionKey: errDesc])
            }
        } catch {
            // We couldn't read the file so set an appropriate error to report back
            reportError = setError(BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN)
        }

        // Display the error locally in the window
        showError(reportError!)

        // Call the QLPreviewingController indicating an error (!nil)
        handler(reportError)
    }


    func preparePreviewOfSearchableItem(identifier: String, queryString: String?, completionHandler handler: @escaping (Error?) -> Void) {

        // Is this ever called?
        NSLog("BUFFOON searchable identifier: \(identifier)")
        NSLog("BUFFOON searchable query:      " + (queryString ?? "nil"))

        // Hand control back to QuickLook
        handler(nil)
    }


    // MARK: - Utility Functions
    
    /**
     Place an error message in its various outlets.
     
     - parameters:
        - error: The error as an NSError.
     */
    func showError(_ error: NSError) {
        
        let errString: String = error.userInfo[NSLocalizedDescriptionKey] as! String
        self.errorReportField.stringValue = errString
        self.errorReportField.isHidden = false
        self.renderTextScrollView.isHidden = true
        self.view.display()
        NSLog("BUFFOON \(errString)")
    }


    /**
     Generate an NSError for an internal error, specified by its code.

     Codes are listed in `Constants.swift`

     - Parameters:
        - code: The internal error code.

     - Returns: The described error as an NSError.
     */
    func setError(_ code: Int) -> NSError {
        
        // NSError generation function
        
        var errDesc: String
        
        switch(code) {
        case BUFFOON_CONSTANTS.ERRORS.CODES.FILE_INACCESSIBLE:
            errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.FILE_INACCESSIBLE
        case BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN:
            errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.FILE_WONT_OPEN
        case BUFFOON_CONSTANTS.ERRORS.CODES.BAD_TS_STRING:
            errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_TS_STRING
        case BUFFOON_CONSTANTS.ERRORS.CODES.BAD_MD_STRING:
            errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_MD_STRING
        default:
            errDesc = "UNKNOWN ERROR"
        }
        
        return NSError(domain: BUFFOON_CONSTANTS.APP_CODE_PREVIEWER,
                       code: code,
                       userInfo: [NSLocalizedDescriptionKey: errDesc])
    }


    /**
     Execute the supplied block on the main thread.
    */
    private func safeMainSync(_ block: @escaping ()->()) {

        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.sync {
                block()
            }
        }
    }
}
