/*
 *  ThumbnailProvider.swift
 *  Thumbnailer
 *
 *  Created by Tony Smith on 31/10/2019.
 *  Copyright © 2023 Tony Smith. All rights reserved.
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
        case badGfxBitmap
        case badGfxDraw
    }


    // MARK: - QLThumbnailProvider Required Functions

    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {

        /*
         * This is the main entry point for the macOS thumbnailing system
         */

        // Set the thumbnail frame
        // NOTE This is always square, with height matched to width, so adjust
        //      to a 3:4 aspect ratio to maintain the macOS standard doc icon width
        let iconScale: CGFloat = request.scale
        let thumbnailFrame: CGRect = NSMakeRect(0.0,
                                                0.0,
                                                CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ASPECT) * request.maximumSize.height,
                                                request.maximumSize.height)
        
        // FROM 1.4.1
        // First ensure we are running on Mojave or above - Dark Mode is not supported by earlier versons
        let sysVer: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
        let isMontereyPlus: Bool = (sysVer.majorVersion >= 12)

        // FROM 1.3.0
        // Place all the remaining code within the closure passed to 'handler()'
        handler(QLThumbnailReply.init(contextSize: thumbnailFrame.size) { (context) -> Bool in
            
            // FROM 1.3.0
            // Place the key code within an autorelease pool to trap possible memory issues
            let result: Result<Bool, ThumbnailerError> = autoreleasepool { () -> Result<Bool, ThumbnailerError> in
                
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
                            return .failure(ThumbnailerError.badFileLoad(request.fileURL.path))
                        }
                        
                        // Instantiate the common code for a thumbnail ('true')
                        let common: Common = Common.init(true)

                        // FROM 1.4.1
                        // Only render the lines *likely* to appear in the thumbnail
                        let lines: [String] = (markdownString as NSString).components(separatedBy: "\n")
                        var shortString: String = ""
                        var gotFrontMatter: Bool = false
                        var markdownStart: Int = 0
                        
                        if lines.count < BUFFOON_CONSTANTS.THUMBNAIL_LINE_COUNT {
                            shortString = markdownString
                        } else {
                            // Check for static site YAML/TOML front matter
                            for i in 0..<lines.count {
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
                                // Break at line THUMBNAIL_LINE_COUNT
                                if (i - markdownStart) >= BUFFOON_CONSTANTS.THUMBNAIL_LINE_COUNT || shortString.count > 3400 { break }
                                shortString += (lines[i] + "\n")
                            }
                        }
                        
                        // Get the Attributed String
                        // TODO Can we save some time by reducing the length of the string before
                        //      processing? We don't need all of a long file for the thumbnail, eg.
                        //      3000 chars or 50 lines?
                        let markdownAtts: NSAttributedString = common.getAttributedString(shortString, true)

                        // Set the primary NSTextView drawing frame and a base font size
                        let markdownFrame: CGRect = NSMakeRect(CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X),
                                                               CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y),
                                                               CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH),
                                                               CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.HEIGHT))

                        // FROM 1.3.1
                        // Instantiate an NSTextField to display the NSAttributedString render of the YAML,
                        // and extend the size of its frame
                        let markdownTextField: NSTextField = NSTextField.init(labelWithAttributedString: markdownAtts)
                        markdownTextField.lineBreakMode = .byTruncatingTail
                        markdownTextField.frame = markdownFrame
                        
                        // Generate the bitmap from the rendered markdown text view
                        guard let bodyImageRep: NSBitmapImageRep = markdownTextField.bitmapImageRepForCachingDisplay(in: markdownFrame) else {
                            return .failure(ThumbnailerError.badGfxBitmap)
                        }
                        
                        // Draw the view into the bitmap
                        markdownTextField.cacheDisplay(in: markdownFrame, to: bodyImageRep)

                        // FROM 1.2.0
                        // Also generate text for the bottom-of-thumbnail file type tag,
                        // if the user has this set as a preference
                        var tagImageRep: NSBitmapImageRep? = nil
                        if common.doShowTag && !isMontereyPlus {
                            // Define the frame of the tag area
                            let tagFrame: CGRect = NSMakeRect(CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X),
                                                              CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y),
                                                              CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH),
                                                              CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.TAG_HEIGHT))
                            
                            // Build the tag
                            let style: NSMutableParagraphStyle = NSMutableParagraphStyle.init()
                            style.alignment = .center
                            
                            // Build the string attributes
                            // FROM 1.3.0 -- do this as a literal
                            let tagAtts: [NSAttributedString.Key: Any] = [
                                .paragraphStyle: style,
                                .font: NSFont.systemFont(ofSize: CGFloat(BUFFOON_CONSTANTS.TAG_TEXT_SIZE)),
                                .foregroundColor: (NSColor.init(red: 0.58, green: 0.09, blue: 0.32, alpha: 1.0))
                            ]

                            // FROM 1.3.1
                            // Instantiate an NSTextField to display the NSAttributedString render of the YAML,
                            // and extend tbhe size of its frame
                            let tag: NSAttributedString = NSAttributedString.init(string: "MD", attributes: tagAtts)
                            let tagTextField: NSTextField = NSTextField.init(labelWithAttributedString: tag)
                            tagTextField.frame = tagFrame
                            
                            // Draw the view into the bitmap
                            if let imageRep: NSBitmapImageRep = tagTextField.bitmapImageRepForCachingDisplay(in: tagFrame) {
                                tagTextField.cacheDisplay(in: tagFrame, to: imageRep)
                                tagImageRep = imageRep
                            }
                        }

                        // Alternative drawing code to make use of a supplied context,
                        // scaling as required (retina vs non-retina screen)
                        // NOTE 'context' passed in by the caller, ie. macOS QL server
                        var drawResult: Bool = false
                        var scaleFrame: CGRect = NSMakeRect(0.0,
                                                            0.0,
                                                            thumbnailFrame.width * iconScale,
                                                            thumbnailFrame.height * iconScale)
                        if let image: CGImage = bodyImageRep.cgImage {
                            context.draw(image, in: scaleFrame, byTiling: false)
                            drawResult = true
                        }
                        
                        // Add the tag
                        if let image: CGImage = tagImageRep?.cgImage {
                            scaleFrame = NSMakeRect(0.0,
                                                    0.0,
                                                    thumbnailFrame.width * iconScale,
                                                    thumbnailFrame.height * iconScale * 0.2)
                            context.draw(image, in: scaleFrame, byTiling: false)
                        }

                        // Required to prevent 'thread ended before CA actions committed' errors in log
                        CATransaction.commit()
                        
                        if drawResult {
                            return .success(true)
                        } else {
                            return .failure(ThumbnailerError.badGfxDraw)
                        }
                        
                        //return drawResult
                    } catch {
                        // NOP: fall through to error
                    }
                }

                // We didn't draw anything because of 'can't find file' error
                return .failure(ThumbnailerError.badFileUnreadable(request.fileURL.path))
            }

            // Pass the outcome up from out of the autorelease
            // pool code to the handler as a bool, logging an error
            // if appropriate
            switch result {
                case .success(_):
                    return true
                case .failure(let error):
                    switch error {
                        case .badFileUnreadable(let filePath):
                            NSLog("Could not access file \(filePath)")
                        case .badFileLoad(let filePath):
                            NSLog("Could not render file \(filePath)")
                        default:
                            NSLog("Could not render thumbnail")
                    }
            }
            
            return false
            
        }, nil)
    }

}
