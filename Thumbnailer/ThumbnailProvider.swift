
//  ThumbnailProvider.swift
//  Thumbnailer
//
//  Created by Tony Smith on 31/10/2019.
//  Copyright © 2019 Tony Smith. All rights reserved.


import QuickLookThumbnailing
import WebKit


class ThumbnailProvider: QLThumbnailProvider {


    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {

        // Load the source file using a co-ordinator as we don't know what thread this function
        // will be executed in when it's called by macOS' QuickLook code
        let fc: NSFileCoordinator = NSFileCoordinator()
        let intent: NSFileAccessIntent = NSFileAccessIntent.readingIntent(with: request.fileURL)
        fc.coordinate(with: [intent], queue: .main) { (err) in
            do {
                // Read in the markdown from the specified file
                let markdownString: String = try String(contentsOf: intent.url, encoding: String.Encoding.utf8)

                // Get an HTML page string from the markdown
                // HOLD Until we get WKWebView working
                // let htmlString: String = self.renderMarkdown(markdownString, intent.url)

                // Set the thumbnail frame
                // NOTE This is always square, so adjust to a 3:4 aspect ratio to
                //      maintain the macOS standard doc icon width
                var thumbnailFrame: CGRect = .zero
                thumbnailFrame.size = request.maximumSize
                thumbnailFrame.size.width = 0.75 * thumbnailFrame.size.height

                // Set the drawing frame and a base font size
                let drawFrame: CGRect = CGRect.init(x: 0.0, y: 0.0, width: 768, height: 1024.00)
                let fontSize: CGFloat = 14.0

                // Instantiate an NSTextView to display the NSAttributedString render of the markdown
                let tv: NSTextView = NSTextView.init(frame: drawFrame)
                tv.backgroundColor = NSColor.white

                if let tvs: NSTextStorage = tv.textStorage {
                    let sm: SwiftyMarkdown = SwiftyMarkdown.init(string: "")
                    self.setBaseValues(sm, fontSize)
                    tvs.setAttributedString(sm.attributedString(markdownString))
                }

                /*
                // Instantiate a WKWebView to display the HTML in our view
                let prefs: WKPreferences = WKPreferences()
                prefs.javaScriptEnabled = false

                let config: WKWebViewConfiguration = WKWebViewConfiguration.init()
                config.suppressesIncrementalRendering = true
                config.preferences = prefs

                let webView: WKWebView = WKWebView.init(frame: viewFrame, configuration: config)
                webView.loadHTMLString(htmlString, baseURL: nil)
                webView.display()
                */

                let imageRep: NSBitmapImageRep? = tv.bitmapImageRepForCachingDisplay(in: drawFrame)

                if imageRep != nil {
                    tv.cacheDisplay(in: drawFrame, to: imageRep!)
                }

                let reply: QLThumbnailReply = QLThumbnailReply.init(contextSize: thumbnailFrame.size) { () -> Bool in
                    // This is the drawing block. It returns true (thumbnail drawn into current context)
                    // or false (thumbnail not drawn)
                    if imageRep != nil {
                        let _ = imageRep!.draw(in: thumbnailFrame)
                        // webView.displayIgnoringOpacity(webView.bounds, in: NSGraphicsContext.current!)
                        return true
                    }

                    //  We didn't draw anything
                    return false
                }

                // Hand control back to QuickLook, supplying the QLThumbnailReply instanace
                // and no error
                handler(reply, nil)
            } catch {
                handler(nil, nil)
            }
        }
    }


    func setBaseValues(_ sm: SwiftyMarkdown, _ baseFontSize: CGFloat) {

        sm.body.fontSize = baseFontSize
        sm.h6.fontSize = baseFontSize
        sm.h5.fontSize = baseFontSize
        sm.h4.fontSize = baseFontSize * 1.2
        sm.h3.fontSize = baseFontSize * 1.4
        sm.h2.fontSize = baseFontSize * 1.6
        sm.h1.fontSize = baseFontSize * 2.0
        sm.h1.color = NSColor.red
        sm.code.fontName = "AndaleMono"
        sm.code.color = NSColor.gray
        sm.bold.fontSize = baseFontSize
    }


    // NOTE Remove pending fixing of WKWebView issue
    /*
    func renderMarkdown(_ markdown: String, _ baseURL: URL) -> String {

        // Convert the supplied markdown string to an HTML string - or an error string

        var errString: String = "ERROR:"
        var css: String = ""

        let url: URL = baseURL.deletingLastPathComponent()

        do {
            // Get the app extension's bundle...
            let bndl: Bundle? = Bundle.init(identifier: "com.bps.PreviewMarkdown.Thumbnailer")
            if bndl != nil {
                // ...and therefore its location, and that of the CSS file, which we load
                let path: String = bndl!.path(forResource: "styles", ofType: "css")!
                css = try String.init(contentsOfFile: path)

                // Convert the markdown string to an NSString to ease its representation
                // as a C string, which we pass (as reference) to 'markdownToHTML()', which
                // is a C function that bridges the Discount markdown rendering engine
                let source: NSString = markdown as NSString
                let render: String = String.init(utf8String: markdownToHTML(source.utf8String))!

                // Assemble a final HTML string, with boilerplate code, the loaded CSS file,
                // the specifiec base URL and the rendered markdown, and return in
                // <meta name=\"viewport\" content=\"initial-scale=1.0\" />
                return "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><style>" + css + "</style><base href=\"\(url)\"/></head><body>" + render + "</body></html>"
            } else {
                errString += " could not access Thumbnailer’s bundle"
            }
        } catch {
            if css.count == 0 { errString += " could not load CSS" }
        }

        // Something went wrong loading or rendering...
        return errString
    }
    */
    
}
