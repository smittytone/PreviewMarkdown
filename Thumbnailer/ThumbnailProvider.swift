
//  ThumbnailProvider.swift
//  Thumbnailer
//
//  Created by Tony Smith on 31/10/2019.
//  Copyright © 2021 Tony Smith. All rights reserved.


import Cocoa
import QuickLookThumbnailing


class ThumbnailProvider: QLThumbnailProvider {
    
    // MARK: Properties Held in Self for use in Closures
    
    // FROM 1.3.0
    // Add key required values to self
    var doShowTag: Bool = true

    // FROM 1.3.1
    private var appSuiteName: String = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME


    // MARK:- Lifecycle Required Functions
    
    override init() {
        // Must call the super class because we don't know
        // what operations it performs
        super.init()
        
        // Set the base values once per instantiation, not every
        // time a string is rendered (which risks race condition)
        setBaseValues(true)
        
        // Get the preference for showing a tag and do it once,
        // so it's only every read once
        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            defaults.synchronize()
            self.doShowTag = defaults.bool(forKey: "com-bps-previewmarkdown-do-show-tag")
        }
    }

    
    // MARK:- QLThumbnailProvider Required Functions

    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        
        // FROM 1.3.0
        // Run everything from this point on the main thread
        //DispatchQueue.main.async {
            // Set the thumbnail frame
            // NOTE This is always square, with height matched to width, so adjust
            //      to a 3:4 aspect ratio to maintain the macOS standard doc icon width
            let thumbnailFrame: CGRect = NSMakeRect(0.0,
                                                    0.0,
                                                    CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ASPECT) * request.maximumSize.height,
                                                    request.maximumSize.height)
            
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
                            
                            // Instantiate an NSTextView to display the NSAttributedString render of the markdown
                            // FROM 1.3.0 -- make sure it's not selectable, ie. non-interactive
                            let markdownTextView: NSTextView = NSTextView.init(frame: markdownFrame)
                            markdownTextView.isSelectable = false
                            markdownTextView.backgroundColor = NSColor.white
                            
                            // Write the markdown NSAttributedString into the NSTextView's text storage
                            guard let markdownTextStorage: NSTextStorage = markdownTextView.textStorage else { return false }
                            markdownTextStorage.beginEditing()
                            markdownTextStorage.setAttributedString(markdownAttString)
                            markdownTextStorage.endEditing()
                            
                            // FROM 1.2.0
                            // Also generate text for the bottom-of-thumbnail file type tag,
                            // if the user has this set as a preference
                            var tagTextField: NSTextField? = nil
                            var tagFrame: CGRect? = nil

                            if self.doShowTag {
                                // Define the frame of the tag area
                                tagFrame = CGRect.init(x: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_X,
                                                       y: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.ORIGIN_Y,
                                                       width: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH,
                                                       height: BUFFOON_CONSTANTS.THUMBNAIL_SIZE.TAG_HEIGHT)

                                /*
                                // Instantiate an NSTextView to display the NSAttributedString render of the tag,
                                // this time with a clear background
                                // FROM 1.3.0 -- make sure it's not selectable, ie. non-interactive
                                tagTextView = NSTextView.init(frame: tagFrame!)
                                tagTextView!.isSelectable = false
                                tagTextView!.backgroundColor = NSColor.clear

                                // Write the tag rendered as an NSAttributedString into the view's text storage
                                if let tagTextStorage: NSTextStorage = tagTextView!.textStorage {
                                    // Remove offsets
                                    tagTextView!.textContainer!.lineFragmentPadding = 0.0
                                    tagTextView!.textContainer!.maximumNumberOfLines = 1
                                    
                                    // NOTE We use 'request.maximumSize' for more accurate results
                                    tagTextStorage.beginEditing()
                                    tagTextStorage.setAttributedString(self.getTagString("MARKDOWN", request.maximumSize.width))
                                    tagTextStorage.endEditing()
                                } else {
                                    // Set this on error so we don't try and draw the tag later
                                    tagFrame = nil
                                }
                                */
                                
                                tagTextField = NSTextField.init(labelWithAttributedString: self.getTagString("MARKDOWN", request.maximumSize.width))
                                tagTextField!.alignment = .center
                                tagTextField!.frame = tagFrame!
                            }

                            // Generate the bitmap from the rendered markdown text view
                            guard let imageRep: NSBitmapImageRep = markdownTextView.bitmapImageRepForCachingDisplay(in: markdownFrame) else { return false }
                            
                            // Draw into the bitmap first the markdown view...
                            markdownTextView.cacheDisplay(in: markdownFrame, to: imageRep)

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
        //}
    }


    func getTagString(_ tag: String, _ width: CGFloat) -> NSAttributedString {

        // FROM 1.2.0
        // Set the text for the bottom-of-thumbnail file type tag

        // Set the paraghraph style we'll use -- just centred text
        let style: NSMutableParagraphStyle = NSMutableParagraphStyle.init()
        style.alignment = .center

        // FROM 1.3.1
        // Set the point size
        var fontSize: CGFloat = CGFloat(BUFFOON_CONSTANTS.TAG_TEXT_SIZE)
        let renderSize: NSSize = (tag as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: fontSize)])
        if renderSize.width > CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH) - 20 {
            let ratio: CGFloat = CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.WIDTH - 20) / renderSize.width
            fontSize *= ratio;
            if fontSize < CGFloat(BUFFOON_CONSTANTS.TAG_TEXT_MIN_SIZE) {
                fontSize = CGFloat(BUFFOON_CONSTANTS.TAG_TEXT_MIN_SIZE)
            }
        }
        
        // Build the string attributes
        // FROM 1.3.0 -- do this as a literal
        let tagAtts: [NSAttributedString.Key : Any] = [
            .paragraphStyle: style as NSParagraphStyle,
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: (NSColor.init(red: 0.58, green: 0.09, blue: 0.32, alpha: 1.0))
        ]

        // Return the attributed string built from the tag
        return NSAttributedString.init(string: tag, attributes: tagAtts)
    }
    
}
