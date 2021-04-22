
//  ThumbnailProvider.swift
//  Thumbnailer
//
//  Created by Tony Smith on 31/10/2019.
//  Copyright © 2021 Tony Smith. All rights reserved.


import Cocoa
import QuickLookThumbnailing


class ThumbnailProvider: QLThumbnailProvider {


    // MARK:- QLThumbnailProvider Required Functions

    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {

        // FROM 1.1.0
        // Get an error message ready for use
        var reportError: NSError? = nil

        // Load the source file using a co-ordinator as we don't know what thread this function
        // will be executed in when it's called by macOS' QuickLook code
        if FileManager.default.isReadableFile(atPath: request.fileURL.path) {
            // Only proceed if the file is accessible from here
            do {
                // Get the file contents as a string
                let data: Data = try Data.init(contentsOf: request.fileURL)
                if let markdownString: String = String.init(data: data, encoding: .utf8) {

                    // Set the thumbnail frame
                    // NOTE This is always square, with height matched to width, so adjust
                    //      to a 3:4 aspect ratio to maintain the macOS standard doc icon width
                    var thumbnailFrame: CGRect = .zero
                    thumbnailFrame.size = request.maximumSize
                    thumbnailFrame.size.width = CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ASPECT) * thumbnailFrame.size.height

                    // Set the primary drawing frame and a base font size
                    let markdownFrame: CGRect = CGRect.init(x: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X,
                                                        y: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y,
                                                        width: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH,
                                                        height: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.HEIGHT)

                    // Instantiate an NSTextView to display the NSAttributedString render of the markdown
                    let markdownTextView: NSTextView = NSTextView.init(frame: markdownFrame)
                    markdownTextView.backgroundColor = NSColor.white

                    // Write the markdown rendered as an NSAttributedString into the view's text storage
                    if let markdownTextStorage: NSTextStorage = markdownTextView.textStorage {
                        markdownTextStorage.setAttributedString(getAttributedString(markdownString, true))
                    } else {
                        // Error
                        reportError = NSError(domain: "com.bps.PreviewMarkdown.Thumbnailer",
                                              code: BUFFOON_CONSTANTS.ERRORS.CODES.BAD_TS_STRING,
                                              userInfo: [NSLocalizedDescriptionKey: BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_TS_STRING])
                        handler(nil, reportError)
                        return
                    }

                    // FROM 1.2.0
                    // Also generate text for the bottom-of-thumbnail file type tag,
                    // if the user has this set as a preference
                    var tagTextView: NSTextView? = nil
                    var tagFrame: CGRect? = nil
                    var doShowTag: Bool = true

                    // Get the preference
                    if let defaults = UserDefaults(suiteName: MNU_SECRETS.PID + ".suite.previewmarkdown") {
                        defaults.synchronize()
                        doShowTag = defaults.bool(forKey: "com-bps-previewmarkdown-do-show-tag")
                    }

                    if doShowTag {
                        // Define the frame of the tag area
                        tagFrame = CGRect.init(x: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X,
                                               y: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y,
                                               width: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH,
                                               height: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.TAG_HEIGHT)

                        // Instantiate an NSTextView to display the NSAttributedString render of the tag,
                        // this time with a clear background
                        tagTextView = NSTextView.init(frame: tagFrame!)
                        tagTextView!.backgroundColor = NSColor.clear

                        // Write the tag rendered as an NSAttributedString into the view's text storage
                        if let tagTextStorage: NSTextStorage = tagTextView!.textStorage {
                            // NOTE We use 'request.maximumSize' for more accurate results
                            tagTextStorage.setAttributedString(getTagString("MARKDOWN", request.maximumSize.width))
                        }
                    }

                    // Generate the bitmap from the rendered markdown text view
                    let imageRep: NSBitmapImageRep? = markdownTextView.bitmapImageRepForCachingDisplay(in: markdownFrame)
                    if imageRep != nil {
                        // Draw into the bitmap first the markdown view...
                        markdownTextView.cacheDisplay(in: markdownFrame, to: imageRep!)

                        // ...then the tag view
                        if tagTextView != nil && tagFrame != nil {
                            tagTextView!.cacheDisplay(in: tagFrame!, to: imageRep!)
                        }
                    }

                    let reply: QLThumbnailReply = QLThumbnailReply.init(contextSize: thumbnailFrame.size) { () -> Bool in
                        // This is the drawing block. It returns true (thumbnail drawn into current context)
                        // or false (thumbnail not drawn)
                        if imageRep != nil {
                            let _ = imageRep!.draw(in: thumbnailFrame)
                            return true
                        }

                        //  We didn't draw anything
                        return false
                    }

                    // Hand control back to QuickLook, supplying the QLThumbnailReply instance and no error
                    handler(reply, nil)
                    return
                } else {
                    // We couldn't get the markdwn string so set an appropriate error to report back
                    reportError = NSError(domain: "com.bps.PreviewMarkdown.Thumbnailer",
                                          code: BUFFOON_CONSTANTS.ERRORS.CODES.BAD_MD_STRING,
                                          userInfo: [NSLocalizedDescriptionKey: BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_MD_STRING])
                }
            } catch {
                // We couldn't read the file so set an appropriate error to report back
                reportError = NSError(domain: "com.bps.PreviewMarkdown.Thumbnailer",
                                      code: BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN,
                                      userInfo: [NSLocalizedDescriptionKey: BUFFOON_CONSTANTS.ERRORS.MESSAGES.FILE_WONT_OPEN])
            }
        }

        // We couldn't do any so set an appropriate error to report back
        handler(nil, reportError)
    }


    func getTagString(_ tag: String = "MARKDOWN", _ width: CGFloat) -> NSAttributedString {

        // FROM 1.2.0
        // Set the text for the bottom-of-thumbnail file type tag
        // Default: MARKDOWN

        // Set the paraghraph style we'll use -- just centred text
        let style: NSMutableParagraphStyle = NSMutableParagraphStyle.init()
        style.alignment = .center

        // Build the string attributes
        var atts: [NSAttributedString.Key : Any] = [:]
        atts[.paragraphStyle] = style
        atts[.font] = NSFont.systemFont(ofSize: 120.0)

        // Set the colour based on the thumbnail size
        atts[.foregroundColor] = width < 128 ? NSColor.black : NSColor.gray

        // Return the attributed string built from the tag
        return NSAttributedString.init(string: tag, attributes: atts)
    }
    
}
