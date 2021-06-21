/*
 *  ThumbnailProvider.swift
 *  Thumbnailer
 *
 *  Created by Tony Smith on 31/10/2019.
 *  Copyright © 2021 Tony Smith. All rights reserved.
 */


import Cocoa
import QuickLookThumbnailing


class ThumbnailProvider: QLThumbnailProvider {

    // MARK:- Public Properties

    // FROM 1.3.0
    // Add key required values to self
    private var doShowTag: Bool = true


    // MARK:- Private Properties

    // FROM 1.3.1
    private var appSuiteName: String = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME


    // MARK:- Lifecycle Required Functions

    override init() {

        /*
         * Override the init() function so that we can do crucial
         * setup in a thread-friendly way and avoid race conditions
         */

        // Must call the super class because we don't know
        // what operations it performs
        super.init()

        // Set the base values once per instantiation, not every
        // time a string is rendered (which risks race condition)
        setBaseValues(true)

        // Get the preference for showing a tag and do it once,
        // so it's only every read once
        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            self.doShowTag = defaults.bool(forKey: "com-bps-previewmarkdown-do-show-tag")
        }
    }


    // MARK:- QLThumbnailProvider Required Functions

    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {

        /*
         * This is the main entry point for the macOS thumbnailing system
         */

        // Set the thumbnail frame
        // NOTE This is always square, with height matched to width, so adjust
        //      to a 3:4 aspect ratio to maintain the macOS standard doc icon width
        let doShowTag: Bool = self.doShowTag
        let targetWidth: CGFloat = CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ASPECT) * request.maximumSize.height
        let targetHeight: CGFloat = request.maximumSize.height
        let thumbnailFrame: CGRect = NSMakeRect(0.0,
                                                0.0,
                                                targetWidth,
                                                targetHeight)

        // FROM 1.3.0
        // Place all the remaining code within the closure passed to 'handler()'
        handler(QLThumbnailReply.init(contextSize: thumbnailFrame.size) { () -> Bool in
            // FROM 1.3.0
            // Place the key code within an autorelease pool to trap possible memory issues
            let success = autoreleasepool { () -> Bool in
                // Load the source file using a co-ordinator as we don't know what thread this function
                // will be executed in when it's called by macOS' QuickLook code
                if FileManager.default.isReadableFile(atPath: request.fileURL.path) {
                    // Only proceed if the file is accessible from here
                    do {
                        // Get the file contents as a string, making sure it's not cached
                        // as we're not going to read it again any time soon
                        let data: Data = try Data.init(contentsOf: request.fileURL, options: [.uncached])
                        guard let markdownString: String = String.init(data: data, encoding: .utf8) else { return false }


                        // Get the Attributed String
                        // TODO Can we save some time by reducing the length of the string before
                        //      processing? We don't need all of a long file for the thumbnail, eg.
                        //      3000 chars or 50 lines?
                        // let mds = String(markdownString.prefix(3000))
                        let markdownAttString: NSAttributedString = getAttributedString(markdownString, true)

                        // Set the primary NSTextView drawing frame and a base font size
                        let markdownFrame: CGRect = CGRect.init(x: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X,
                                                                y: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y,
                                                                width: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH,
                                                                height: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.HEIGHT)

                        // FROM 1.3.1
                        // Instantiate an NSTextField to display the NSAttributedString render of the YAML,
                        // and extend the size of its frame
                        let markdownTextField: NSTextField = NSTextField.init(labelWithAttributedString: markdownAttString)
                        markdownTextField.frame = markdownFrame

                        // FROM 1.2.0
                        // Also generate text for the bottom-of-thumbnail file type tag,
                        // if the user has this set as a preference
                        // FROM 1.3.1 -- implement tag as NSTextField label
                        var tagTextField: NSTextField? = nil
                        var tagFrame: CGRect? = nil

                        if doShowTag {
                            // Define the frame of the tag area
                            tagFrame = CGRect.init(x: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X,
                                                    y: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y,
                                                    width: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH,
                                                    height: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.TAG_HEIGHT)
                            
                            // Build the tag
                            let style: NSMutableParagraphStyle = NSMutableParagraphStyle.init()
                            style.alignment = .center

                            // Build the string attributes
                            // FROM 1.3.0 -- do this as a literal
                            let tagAtts: [NSAttributedString.Key: Any] = [
                                .paragraphStyle: style as NSParagraphStyle,
                                .font: NSFont.systemFont(ofSize: CGFloat(BUFFOON_CONSTANTS.TAG_TEXT_SIZE)),
                                .foregroundColor: (NSColor.init(red: 0.58, green: 0.09, blue: 0.32, alpha: 1.0))
                            ]

                            let tag: NSAttributedString = NSAttributedString.init(string: "MD", attributes: tagAtts)
                            
                            // FROM 1.3.1
                            // Instantiate an NSTextField to display the NSAttributedString render of the YAML,
                            // and extend the size of its frame
                            tagTextField = NSTextField.init(labelWithAttributedString: tag)
                            tagTextField!.frame = tagFrame!
                        }

                        // Generate the bitmap from the rendered markdown text view
                        guard let imageRep: NSBitmapImageRep = markdownTextField.bitmapImageRepForCachingDisplay(in: markdownFrame) else { return false }

                        // Draw into the bitmap first the markdown view...
                        markdownTextField.cacheDisplay(in: markdownFrame, to: imageRep)

                        // ...then the tag view
                        if tagFrame != nil && tagTextField != nil {
                            tagTextField!.cacheDisplay(in: tagFrame!, to: imageRep)
                        }

                        // This is the drawing block. It returns true (thumbnail drawn into current context)
                        // or false (thumbnail not drawn)
                        return imageRep.draw(in: thumbnailFrame)
                    } catch {
                        // NOP: fall through to error
                    }
                }

                // We didn't draw anything because of an error
                // NOTE Technically we should call 'handler(nil, error)'
                return false
            }

            // Pass the outcome up from out of the autorelease
            // pool code to the handler
            return success
        }, nil)
    }


    // MARK:- Misc Functions

    /**
     Create an attributed string for a file icon tag.
     
     FROM 1.2.0

     - Parameters:
        - tag:   The text of the tag.
        - width: The fractional pixel width we need to tag to fit into.

     - Returns: The tag as an NSAttributedString.
     */
    /*func getTagString(_ tag: String, _ width: CGFloat) -> NSAttributedString {

        // Set the paraghraph style we'll use -- just centred text
        let style: NSMutableParagraphStyle = NSMutableParagraphStyle.init()
        style.alignment = .center

        // Build the string attributes
        // FROM 1.3.0 -- do this as a literal
        let tagAtts: [NSAttributedString.Key: Any] = [
            .paragraphStyle: style as NSParagraphStyle,
            .font: NSFont.systemFont(ofSize: CGFloat(BUFFOON_CONSTANTS.TAG_TEXT_SIZE)),
            .foregroundColor: (NSColor.init(red: 0.58, green: 0.09, blue: 0.32, alpha: 1.0))
        ]

        // Return the attributed string built from the tag
        return NSAttributedString.init(string: tag, attributes: tagAtts)
    }
    */

}
