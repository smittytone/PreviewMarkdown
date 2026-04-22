/*
 *  PreviewViewController.swift
 *  PreviewMarkdown
 *
 *  Created by Tony Smith on 31/10/2019.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */

import AppKit
import Quartz


class PreviewViewController: NSViewController,
                             QLPreviewingController {

    // MARK: - Class UI Properties

    @IBOutlet weak var renderTextView: NSTextView!
    @IBOutlet weak var renderTextScrollView: NSScrollView!


    // MARK: - Public Properties

    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }


    // MARK: - QLPreviewingController Required Functions

    // FROM 2.4.0
    // Update to use Swift Concurrency
    func preparePreviewOfFile(at url: URL) async throws {

        /*
         * This is the main entry point for the macOS QuickLook previewing system
         */

        // Hide the error message field
        var reportError: NSError? = nil

        // Load and process the source file
        do {
            // Get the file contents as a string
            let data = try Data(contentsOf: url, options: [.uncached])
            let encoding = data.stringEncoding ?? .utf8

            // Convert the data to a string
            if let markdown = String(data: data, encoding: encoding) {
                /*
                 Instantiate the common code within the closure
                 */
                guard let common = Common(forThumbnail: false) else {
                    reportError = makeError(BUFFOON_CONSTANTS.ERRORS.CODES.BAD_STYLER_LOAD)
                    throw reportError!
                }

                // FROM 2.0.0
                // Pass in the source file's directory
                common.workingDirectory = (url.path as NSString).deletingLastPathComponent

                /*
                 Attributed string acquisition
                 */

                let attributedMarkdown = common.getAttributedString(markdown[...])

                /*
                 Window and mode configuration
                 */

                // FROM 2.2.0
                // Set the parent window's size
                setPreviewWindowSize(common.settings)

                // FROM 2.4.0
                // The force-light-mode-preview-in-dark-mode setting is now a general
                // preview-colours-should-be-opposite-the-mode setting.
                var renderPreviewLight = NSApplication.shared.inLightMode
                if common.settings.doReverseMode {
                    // Invert the colour scheme based on the current mode
                    renderPreviewLight = !renderPreviewLight
                }

                // Update the NSTextView
                self.renderTextView.backgroundColor = renderPreviewLight ? NSColor.white : NSColor.textBackgroundColor
                self.renderTextScrollView.scrollerKnobStyle = renderPreviewLight ? .dark : .light
                self.view.appearance = renderPreviewLight ? NSAppearance(named: .aqua) : NSAppearance(named: .darkAqua)

                // FROM 2.1.0
                // Add margin if required
                // FROM 2.3.0
                // Margin size is a setting
                if common.settings.previewMarginWidth > 0.0 {
                    self.renderTextView.textContainerInset = NSSize(width: common.settings.previewMarginWidth,
                                                                    height: common.settings.previewMarginWidth)
                }

                // FROM 2.0.0
                // Correct way to set a text view's link colouring, etc. - and have it stick
                self.renderTextView.linkTextAttributes = [NSAttributedString.Key.foregroundColor: common.linkColor,
                                                          NSAttributedString.Key.cursor: NSCursor.pointingHand]

                /*
                 Attributed String Presentation
                 */

                // Access the text view's storage to place the rendered Markdown string
                if let renderTextStorage = self.renderTextView.textStorage {
                    if let renderTextContainer: NSTextContainer = self.renderTextView.textContainer {
                        // Add a custom layout manager to trap double-underlines, which
                        // we are using as a proxy for lozenged text - the layouter will
                        // do the replacement work
                        let layouter = PMLayouter()
                        layouter.marginDelta = common.settings.doShowMargin ? common.settings.previewMarginWidth : 0.0
                        layouter.fontSize = common.settings.fontSize
                        layouter.lineSpacing = common.settings.lineSpacing

                        // This line is a sort of fix for the table border rendering issue
                        // It helps - missing borders do get drawn eventually - but doesn't
                        // get them drawn immediately.
                        layouter.allowsNonContiguousLayout = true
                        renderTextContainer.replaceLayoutManager(layouter)
                    }

                    renderTextStorage.beginEditing()
                    renderTextStorage.setAttributedString(attributedMarkdown)
                    renderTextStorage.endEditing()
                    return
                }

                // We couldn't access the preview NSTextView's NSTextStorage
                reportError = makeError(BUFFOON_CONSTANTS.ERRORS.CODES.BAD_TS_STRING)
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
            reportError = makeError(BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN)
        }

        // FROM 2.4.3
        // Throw to indicate an error
        throw reportError!
    }


    // MARK: - Utility Functions

    /**
     Generate an NSError for an internal error, specified by its code.

     Codes are listed in `Constants.swift`

     - Parameters:
        - code: The internal error code.

     - Returns: The described error as an NSError.
     */
    func makeError(_ code: Int) -> NSError {

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
            case BUFFOON_CONSTANTS.ERRORS.CODES.BAD_STYLER_LOAD:
                errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_STYLER_LOAD
        default:
            errDesc = "UNKNOWN ERROR"
        }

        return NSError(domain: BUFFOON_CONSTANTS.APP_CODE_PREVIEWER,
                       code: code,
                       userInfo: [NSLocalizedDescriptionKey: errDesc])
    }


    /**
     Specify the content size of the parent view.
    */
    private func setPreviewWindowSize(_ settings: PMSettings) {

        var screen: NSScreen = NSScreen.screens[0]

        // We've set `screen` to the primary, ie. menubar-displaying,
        // screen, but ideally we should pick the screen with user focus.
        // They may be one and the same, of course...
        if let mainScreen = NSScreen.main, mainScreen != screen {
            screen = mainScreen
        }

        let height: CGFloat = screen.frame.size.height * settings.previewWindowScale
        let width: CGFloat = screen.frame.size.width * settings.previewWindowScale
        self.preferredContentSize = NSSize(width: width, height: height)
    }
}
