/*
 *  PreviewViewController.swift
 *  Previewer
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

        // Hide the error message field
        self.errorReportField.stringValue = ""
        self.errorReportField.isHidden = true
        self.renderTextScrollView.isHidden = false
        
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
                let data: Data = try Data.init(contentsOf: url, options: [.uncached])
                
                // FROM 1.4.3
                // Get the string's encoding, or fail back to .utf8
                let encoding: String.Encoding = data.stringEncoding ?? .utf8
                
                // Convert the data to a string
                if let markdownString: String = String.init(data: data, encoding: encoding) {
                    // Instantiate the common code
                    guard let common: Common = Common.init() else {
                        reportError = setError(BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN)
                        showError(reportError!)
                        handler(reportError)
                        return
                    }
                    
                    // FROM 2.0.0
                    // Pass on the initial width of the preview and the source file's directory
                    //common.viewWidth = self.renderTextView.bounds.width
                    common.workingDirectory = (url.path as NSString).deletingLastPathComponent
                    
                    // FROM 2.0.0
                    // Set the view to display in light mode, even if the Mac is set to dakr mode,
                    // if that's required by the user. This means we can stick to as few fixed colours
                    // as possible: AppKit will flip accordingly.
                    if common.doShowLightBackground {
                        self.view.appearance = NSAppearance.init(named: .aqua)
                    }
                    
                    // Update the NSTextView
                    self.renderTextView.backgroundColor = common.doShowLightBackground ? NSColor.init(white: 0.9, alpha: 1.0) : NSColor.textBackgroundColor
                    self.renderTextScrollView.scrollerKnobStyle = common.doShowLightBackground ? .dark : .light

                    // FROM 2.0.0
                    // Correct way to set a text view's link colouring, etc. - and have it stick
                    self.renderTextView.linkTextAttributes = [NSAttributedString.Key.foregroundColor: common.linkColor,
                                                              NSAttributedString.Key.cursor: NSCursor.pointingHand ]

                    if let renderTextStorage: NSTextStorage = self.renderTextView.textStorage {
                        if let renderTextContainer: NSTextContainer = self.renderTextView.textContainer {
                            let layouter = PMLayouter()
                            //layouter.lozengeColour = .red
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
        } else {
            // File passed isn't readable
            reportError = setError(BUFFOON_CONSTANTS.ERRORS.CODES.FILE_INACCESSIBLE)
        }

        // Display the error locally in the window
        showError(reportError!)

        // Call the QLPreviewingController indicating an error (!nil)
        handler(nil)
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
