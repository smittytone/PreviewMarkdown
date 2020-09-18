
//  PreviewViewController.swift
//  Previewer
//
//  Created by Tony Smith on 31/10/2019.
//  Copyright © 2019-20 Tony Smith. All rights reserved.


import Cocoa
import Quartz
import SwiftyMarkdown


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

                    // Render HTML symbols
                    let processedString = processSymbols(markdownString)

                    // Update the NSTextView
                    self.renderTextView.backgroundColor = NSColor.textBackgroundColor

                    if let renderTextStorage: NSTextStorage = self.renderTextView.textStorage {
                        let swiftyMarkdown: SwiftyMarkdown = SwiftyMarkdown.init(string: "")
                        self.setBaseValues(swiftyMarkdown, CGFloat(BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE))
                        renderTextStorage.setAttributedString(swiftyMarkdown.attributedString(from: processedString))
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

    
    func processSymbols(_ base: String) -> String {

        // FROM 1.1.0
        // FInd and and replace any HTML symbol markup
        let finds = ["&quot;", "&amp;", "&frasl;", "&lt;", "&gt;", "&lsquo;", "&rsquo;", "&ldquo;", "&rdquo;", "&bull;", "&ndash;", "&mdash;", "&trade;", "&nbsp;",  "&iexcl;", "&cent;", "&pound;", "&copy;", "&reg;", "&deg;", "&plusmn;", "&sup2;", "&sup3;", "&micro;"]
        let reps = ["\"", "&", "/", "<", ">", "‘", "’", "“", "”", "•", "-", "—", "™", " ", "¡", "¢", "£", "©", "®", "º", "±", "²", "³", "µ"]
        let pattern = #"&[a-zA-Z]+[1-9]*;"#
        var result = base
        var range = result.range(of: pattern, options: .regularExpression)
        while range != nil {
            var repText = ""
            let find = String(result[range!])
            if finds.contains(find) {
                repText = reps[finds.firstIndex(of: find)!]
            } else {
                repText = "SOMETHING"
            }

            result = result.replacingCharacters(in: range!, with: repText)
            range = result.range(of: pattern, options: .regularExpression)
        }

        return result;
    }


    // MARK:- Utility Functions

    func setBaseValues(_ sm: SwiftyMarkdown, _ baseFontSize: CGFloat) {

        // Set base style values for the markdown render

        sm.setFontSizeForAllStyles(with: baseFontSize)
        sm.setFontNameForAllStyles(with: "HelveticaNeue")
        sm.setFontColorForAllStyles(with: NSColor.labelColor)
        sm.h4.fontSize = baseFontSize * 1.2
        sm.h3.fontSize = baseFontSize * 1.4
        sm.h2.fontSize = baseFontSize * 1.6
        sm.h1.fontSize = baseFontSize * 2.0
        sm.code.fontName = "AndaleMono"
        sm.code.color = NSColor.systemPurple
        sm.link.color = NSColor.systemBlue
    }


    func showError(_ errString: String) {

        // Relay an error message to its various outlets

        NSLog("BUFFOON " + errString)
        self.errorReportField.stringValue = errString
        self.errorReportField.isHidden = false
    }
    
}
