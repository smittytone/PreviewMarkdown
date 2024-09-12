/*
 *  ThumbnailProvider.swift
 *  Thumbnailer
 *
 *  Created by Tony Smith on 31/10/2019.
 *  Copyright © 2024 Tony Smith. All rights reserved.
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
    }


    // MARK: - QLThumbnailProvider Required Functions

    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {

        /*
         * This is the main entry point for the macOS thumbnailing system
         */

        // Load the source file using a co-ordinator as we don't know what thread this function
        // will be executed in when it's called by macOS' QuickLook code
        if FileManager.default.isReadableFile(atPath: request.fileURL.path) {
            // Only proceed if the file is accessible from here
            do {
                // Get the file contents as a string, making sure it's not cached
                // as we're not going to read it again any time soon
                let data: Data = try Data.init(contentsOf: request.fileURL, options: [.uncached])

                // FROM 1.4.3
                // Get the string's encoding, or fail back to .utf8
                let encoding: String.Encoding = data.stringEncoding ?? .utf8

                guard let markdownString: String = String.init(data: data, encoding: encoding) else {
                    handler(nil, ThumbnailerError.badFileLoad(request.fileURL.path))
                    return
                }

                // Instantiate the common code for a thumbnail ('true')
                let common: Common = Common.init(true)

                // FROM 1.4.1
                // Only render the lines *likely* to appear in the thumbnail
                let lines: [Substring] = markdownString.split(separator: "\n", maxSplits: BUFFOON_CONSTANTS.THUMBNAIL_LINE_COUNT + 1, omittingEmptySubsequences: false)
                var displayString: String = ""
                var displayLineCount: Int = 0
                var gotFrontMatter: Bool = false
                var markdownStart: Int = 0

                for i in 0..<lines.count {
                    // Check for static site YAML/TOML front matter
                    if (lines[i].hasPrefix("---") || lines[i].hasPrefix("+++")) && !gotFrontMatter {
                        // Head YAML/TOML delimiter
                        gotFrontMatter = true
                        continue
                    }

                    if (lines[i].hasPrefix("---") || lines[i].hasPrefix("+++")) && gotFrontMatter {
                        // Tail YAML/TOML delimiter: set the start of the Markdown
                        markdownStart = i + 1
                        break
                    }
                }

                // Count Markdown lines from the start or after any front matter
                for i in markdownStart..<lines.count {
                    // Split the line into words and count them (approx.)
                    let words: [Substring] = lines[i].split(separator: " ")
                    let approxParagraphLineCount: Int = words.count / 12

                    // Estimate the number of lines the paragraph requires
                    if approxParagraphLineCount > 1 {
                        displayLineCount += (approxParagraphLineCount + 1)
                    } else {
                        displayLineCount += 1
                    }

                    // Add the paragraph to the string we'll present
                    displayString += (String(lines[i]) + "\n")

                    if displayLineCount >= BUFFOON_CONSTANTS.THUMBNAIL_LINE_COUNT {
                        break
                    }
                }

                // Set the primary NSTextView drawing frame and a base font size
                let markdownFrame: CGRect = NSMakeRect(CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X),
                                                       CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y),
                                                       CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH),
                                                       CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.HEIGHT))

                // Instantiate an NSTextField to display the NSAttributedString render of the YAML,
                // and extend the size of its frame
                let markdownTextField: NSTextField = NSTextField.init(frame: markdownFrame)
                markdownTextField.lineBreakMode = .byTruncatingTail
                markdownTextField.attributedStringValue = common.getAttributedString(displayString)

                // Generate the bitmap from the rendered markdown text view
                guard let bodyImageRep: NSBitmapImageRep = markdownTextField.bitmapImageRepForCachingDisplay(in: markdownFrame) else {
                    handler(nil, ThumbnailerError.badGfxBitmap)
                    return
                }

                // Draw the view into the bitmap
                markdownTextField.cacheDisplay(in: markdownFrame, to: bodyImageRep)

                if let image: CGImage = bodyImageRep.cgImage {
                    if let cgImage: CGImage = image.copy() {
                        // Set the thumbnail frame
                        let thumbnailFrame: CGRect = NSMakeRect(0.0,
                                                                0.0,
                                                                CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ASPECT) * request.maximumSize.height,
                                                                request.maximumSize.height)
                        
                        let scaleFrame: CGRect = NSMakeRect(0.0,
                                                            0.0,
                                                            thumbnailFrame.width * request.scale,
                                                            thumbnailFrame.height * request.scale)

                        // Pass a QLThumbnailReply and no error to the supplied handler
                        handler(QLThumbnailReply.init(contextSize: thumbnailFrame.size) { (context) -> Bool in
                            // `scaleFrame` and `cgImage` are immutable
                            context.draw(cgImage, in: scaleFrame, byTiling: false)
                            return true
                        }, nil)
                        return
                    }
                }

                handler(nil, ThumbnailerError.badGfxDraw)
                return
            } catch {
                // NOP: fall through to error
            }
        }

        // We didn't draw anything because of 'can't find file' error
        handler(nil, ThumbnailerError.badFileUnreadable(request.fileURL.path))
    }

}
