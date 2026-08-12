/*
 *  ThumbnailProvider.swift
 *  Markdown Thumbnailer
 *
 *  Created by Tony Smith on 31/10/2019.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */


import Cocoa
import QuickLookThumbnailing


class ThumbnailProvider: QLThumbnailProvider {

    // MARK: - Private Properties

    // FROM 1.4.0
    // Add possible errors returned by autorelease pool
    private enum ThumbnailerError: Error {
        case badFileLoad(String)
        case badFileUnreadable(String)
        case badFileUnsupportedEncoding(String)
        case badFileUnsupportedFile(String)
        case badGfxBitmap
        case badGfxDraw
        case appComponentMissing
    }


    // MARK: - QLThumbnailProvider Required Functions

    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {

        /*
         * This is the main entry point for the macOS thumbnailing system
         */

        do {
            // Get the file contents as a string, making sure it's not cached
            // as we're not going to read it again any time soon
            let data = try Data(contentsOf: request.fileURL, options: [.uncached])

            // FROM 1.4.3
            // Get the string's encoding, or fail back to .utf8
            let encoding = data.stringEncoding ?? .utf8

            guard let markdown = String(data: data, encoding: encoding) else {
                handler(nil, ThumbnailerError.badFileLoad(request.fileURL.path))
                return
            }

            // Instantiate the common code for a thumbnail ('true')
            guard let common = Common(forThumbnail: true) else {
                handler(nil, ThumbnailerError.appComponentMissing)
                return
            }

            // Set the primary NSTextView drawing frame and a base font size
            let markdownTextFieldFrame = NSMakeRect(CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X),
                                                    CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y),
                                                    CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH),
                                                    CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.HEIGHT))

            // Instantiate an NSTextField to display the NSAttributedString render of the Markdown,
            // and extend the size of its frame
            let markdownTextField = NSTextField(frame: markdownTextFieldFrame)
            markdownTextField.lineBreakMode = .byTruncatingTail
            markdownTextField.attributedStringValue = common.getAttributedString(markdown[...])

            // FROM 2.3.0
            // From macOS 26.1, make sure thumbnail backgrounds remain white
            // NOTE This may become a setting in future, but for now retain the styling
            //      we have always presented.
            if #available(macOS 26.1, *) {
                if !common.settings.thumbnailMatchFinderMode {
                    markdownTextField.isBezeled = false
                    markdownTextField.drawsBackground = true
                    markdownTextField.backgroundColor = .white
                }
            }

            // Generate the bitmap from the rendered markdown text view
            guard let bodyImageRep = markdownTextField.bitmapImageRepForCachingDisplay(in: markdownTextFieldFrame) else {
                handler(nil, ThumbnailerError.badGfxBitmap)
                return
            }

            // Draw the view into the bitmap
            markdownTextField.cacheDisplay(in: markdownTextFieldFrame, to: bodyImageRep)

            if let image = bodyImageRep.cgImage {
                let thumbnailFrame = NSMakeRect(0.0,
                                                0.0,
                                                CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ASPECT) * request.maximumSize.height,
                                                request.maximumSize.height)

                // NOTE The `+2.0` is a hack to avoid a line above the image
                let scaleFrame = NSMakeRect(0.0,
                                            0.0,
                                            thumbnailFrame.width * request.scale,
                                            (thumbnailFrame.height * request.scale) + 2.0)

                // Pass a QLThumbnailReply and no error to the supplied handler
                handler(QLThumbnailReply(contextSize: thumbnailFrame.size) { (context) -> Bool in
                    // `scaleFrame` and `cgImage` are immutable
                    context.draw(image, in: scaleFrame, byTiling: false)
                    return true
                }, nil)

                return
            }

            handler(nil, ThumbnailerError.badGfxDraw)
            return
        } catch {
            // NOP: fall through to error
        }

        // We didn't draw anything because of 'can't find file' error
        handler(nil, ThumbnailerError.badFileUnreadable(request.fileURL.path))
    }

}
