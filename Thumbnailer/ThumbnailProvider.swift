
//  ThumbnailProvider.swift
//  Thumbnailer
//
//  Created by Tony Smith on 31/10/2019.
//  Copyright © 2019 Tony Smith. All rights reserved.


import QuickLookThumbnailing
import WebKit
import Quartz


class ThumbnailProvider: QLThumbnailProvider {
    
    
    var webView: WKWebView? = nil
    
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        
        let fc: NSFileCoordinator = NSFileCoordinator()
        let intent: NSFileAccessIntent = NSFileAccessIntent.readingIntent(with: request.fileURL)
        fc.coordinate(with: [intent], queue: .main) { (err) in
            do {
                // Read in the markdown from the specified file
                let markdownString: String = try String(contentsOf: intent.url, encoding: String.Encoding.utf8)

                // Get an HTML page string from the markdown
                let htmlString: String = self.renderMarkdown(markdownString, intent.url.deletingLastPathComponent())

                // Instantiate a WKWebView to display the HTML in our view
                let thumbRect: CGRect = NSMakeRect(0.0, 0.0, request.maximumSize.width, request.maximumSize.height)
                self.webView = WKWebView.init(frame: thumbRect, configuration: WKWebViewConfiguration())
                if self.webView != nil {
                    self.webView!.loadHTMLString(htmlString, baseURL: intent.url.deletingLastPathComponent())
                    self.webView!.display()
                }
                
                handler(QLThumbnailReply(contextSize: request.maximumSize, currentContextDrawing: { () -> Bool in
                    // Draw the thumbnail here.
                    let context: NSGraphicsContext? = NSGraphicsContext.current
                    if context != nil && self.webView != nil {
                        self.webView!.displayIgnoringOpacity(thumbRect, in: context!)
                        return true
                    }
                        
                    return false
                }), nil)
            } catch {
                handler(nil, nil)
            }
        }
        
        // There are three ways to provide a thumbnail through a QLThumbnailReply. Only one of them should be used.
        
        /* First way: Draw the thumbnail into the current context, set up with UIKit's coordinate system.
        handler(QLThumbnailReply(contextSize: request.maximumSize, currentContextDrawing: { () -> Bool in
            // Draw the thumbnail here.
            let context: NSGraphicsContext = NSGraphicsContext.current
            context.cgContext.draw
            // Return true if the thumbnail was successfully drawn inside this block.
            return true
        }), nil)
        
        
        
        // Second way: Draw the thumbnail into a context passed to your block, set up with Core Graphics's coordinate system.
        handler(QLThumbnailReply(contextSize: request.maximumSize, drawing: { (context) -> Bool in
            // Draw the thumbnail here.
         
            // Return true if the thumbnail was successfully drawn inside this block.
            return true
        }), nil)
         
        // Third way: Set an image file URL.
        handler(QLThumbnailReply(imageFileURL: Bundle.main.url(forResource: "fileThumbnail", withExtension: "jpg")!), nil)
        
        */
    }
    
    
    func renderMarkdown(_ markdown: String, _ baseURL: URL) -> String {

        // Convert the supplied markdown string to an HTML string - or an error string

        var errString: String = "ERROR:"
        var css: String = ""

        do {
            // Get the app extension's bundle...
            let bndl: Bundle? = Bundle.init(identifier: "com.bps.PreviewMarkdown.Previewer")
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
                return "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n<style>" + css + "</style>\n<base href=\"\(baseURL.absoluteString)\"/>\n</head>\n<body>" + render + "</body>\n</html>"
            } else {
                errString += " could not access Previewer’s bundle"
            }
        } catch {
            if css.count == 0 { errString += " could not load CSS" }
        }

        // Something went wrong loading or rendering...
        return errString
    }
}
