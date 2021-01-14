
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

                    // Instantiate an NSTextView to display the NSAttributedString render of the markdown
                    let renderTextView: NSTextView = NSTextView.init(frame: drawFrame)
                    renderTextView.backgroundColor = NSColor.white

                    if let renderTextStorage: NSTextStorage = renderTextView.textStorage {
                        renderTextStorage.setAttributedString(getAttributedString(markdownString, true))
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
    }
    
}
