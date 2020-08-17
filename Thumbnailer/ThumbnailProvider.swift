
//  ThumbnailProvider.swift
//  Thumbnailer
//
//  Created by Tony Smith on 31/10/2019.
//  Copyright © 2019 Tony Smith. All rights reserved.


import Cocoa
import QuickLookThumbnailing
import SwiftyMarkdown


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
                    // NOTE This is always square, so adjust to a 3:4 aspect ratio to
                    //      maintain the macOS standard doc icon width
                    var thumbnailFrame: CGRect = .zero
                    thumbnailFrame.size = request.maximumSize
                    thumbnailFrame.size.width = CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ASPECT) * thumbnailFrame.size.height

                    // Set the drawing frame and a base font size
                    let drawFrame: CGRect = CGRect.init(x: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X,
                                                        y: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y,
                                                        width: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH,
                                                        height: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.HEIGHT)
                    let fontSize: CGFloat = CGFloat(BUFFOON_CONSTANTS.BASE_THUMB_FONT_SIZE)

                    // Instantiate an NSTextView to display the NSAttributedString render of the markdown
                    let renderTextView: NSTextView = NSTextView.init(frame: drawFrame)
                    renderTextView.backgroundColor = NSColor.white

                    if let renderTextStorage: NSTextStorage = renderTextView.textStorage {
                        let swiftyMarkdown: SwiftyMarkdown = SwiftyMarkdown.init(string: "")
                        self.setBaseValues(swiftyMarkdown, fontSize)
                        renderTextStorage.setAttributedString(swiftyMarkdown.attributedString(from: markdownString))
                    }

                    let imageRep: NSBitmapImageRep? = renderTextView.bitmapImageRepForCachingDisplay(in: drawFrame)

                    if imageRep != nil {
                        renderTextView.cacheDisplay(in: drawFrame, to: imageRep!)
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

        // We couldn't do any so set an appropriate error to report back
        handler(nil, reportError)
        
/*
        let fc: NSFileCoordinator = NSFileCoordinator()
        let intent: NSFileAccessIntent = NSFileAccessIntent.readingIntent(with: request.fileURL)
        fc.coordinate(with: [intent], queue: .main) { (err) in
            // FROM 1.1.0
            // Get an error message ready for use
            var reportError: NSError = NSError(domain: "com.bps.PreviewMarkdown.Previewer",
                                               code: BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN,
                                               userInfo: [NSLocalizedDescriptionKey: BUFFOON_CONSTANTS.ERRORS.MESSAGES.FILE_WONT_OPEN])
            if err != nil {
                do {
                    // Read in the markdown from the specified file
                    let markdownString: String = try String(contentsOf: intent.url, encoding: String.Encoding.utf8)

                    // Set the thumbnail frame
                    // NOTE This is always square, so adjust to a 3:4 aspect ratio to
                    //      maintain the macOS standard doc icon width
                    var thumbnailFrame: CGRect = .zero
                    thumbnailFrame.size = request.maximumSize
                    thumbnailFrame.size.width = CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ASPECT) * thumbnailFrame.size.height

                    // Set the drawing frame and a base font size
                    let drawFrame: CGRect = CGRect.init(x: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X,
                                                        y: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y,
                                                        width: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH,
                                                        height: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.HEIGHT)
                    let fontSize: CGFloat = CGFloat(BUFFOON_CONSTANTS.BASE_THUMB_FONT_SIZE)

                    // Instantiate an NSTextView to display the NSAttributedString render of the markdown
                    let renderTextView: NSTextView = NSTextView.init(frame: drawFrame)
                    renderTextView.backgroundColor = NSColor.white

                    if let renderTextStorage: NSTextStorage = renderTextView.textStorage {
                        let swiftyMarkdown: SwiftyMarkdown = SwiftyMarkdown.init(string: "")
                        self.setBaseValues(swiftyMarkdown, fontSize)
                        renderTextStorage.setAttributedString(swiftyMarkdown.attributedString(from: markdownString))
                    }

                    let imageRep: NSBitmapImageRep? = renderTextView.bitmapImageRepForCachingDisplay(in: drawFrame)

                    if imageRep != nil {
                        renderTextView.cacheDisplay(in: drawFrame, to: imageRep!)
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
                } catch {
                    // We couldn't read the file so set an appropriate error to report back
                    reportError = NSError(domain: "com.bps.PreviewMarkdown.Previewer",
                                          code: BUFFOON_CONSTANTS.ERRORS.CODES.BAD_MD_STRING,
                                          userInfo: [NSLocalizedDescriptionKey: BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_MD_STRING])
                }
            }

            // We couldn't do any so set an appropriate error to report back
            handler(nil, reportError)
        }
 */
    }


    // MARK:- Utility Functions

    func setBaseValues(_ sm: SwiftyMarkdown, _ baseFontSize: CGFloat) {

        // Set base style values for the markdown render

        sm.setFontSizeForAllStyles(with: baseFontSize)
        sm.setFontNameForAllStyles(with: "HelveticaNeue")
        sm.setFontColorForAllStyles(with: NSColor.black)
        sm.h4.fontSize = baseFontSize * 1.2
        sm.h3.fontSize = baseFontSize * 1.4
        sm.h2.fontSize = baseFontSize * 1.6
        sm.h1.fontSize = baseFontSize * 2.0
        sm.code.fontName = "AndaleMono"
        sm.code.color = NSColor.systemPurple
        sm.link.color = NSColor.systemBlue
    }
    
}
