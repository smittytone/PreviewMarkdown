
//  ThumbnailProvider.swift
//  Thumbnailer
//
//  Created by Tony Smith on 31/10/2019.
//  Copyright © 2019 Tony Smith. All rights reserved.


import QuickLookThumbnailing
import WebKit


class ThumbnailProvider: QLThumbnailProvider {
    
    
    var webView: WKWebView? = nil


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
                let htmlString: String = self.renderMarkdown(markdownString, intent.url)
                NSLog("BUFFOON \(htmlString)")

                // Instantiate a WKWebView to display the HTML in our view
                let prefs: WKPreferences = WKPreferences()
                prefs.javaScriptEnabled = false

                let config: WKWebViewConfiguration = WKWebViewConfiguration.init()
                config.suppressesIncrementalRendering = false
                config.preferences = prefs

                let viewRect: CGRect = CGRect.init(x: 0.0, y: 0.0, width: 768.0, height: 1024.0)
                self.webView = WKWebView.init(frame: viewRect, configuration: config)

                if self.webView != nil {
                    self.webView!.loadHTMLString(htmlString, baseURL: nil)
                    self.webView!.display()
                } else {
                    NSLog("BUFFOON WK FAIL");
                }

                // Call the supplied handler to draw the thumbnail
                handler(QLThumbnailReply(contextSize: request.maximumSize, currentContextDrawing: { () -> Bool in

                    if let nsContext: NSGraphicsContext = NSGraphicsContext.current {
                        let context: CGContext = nsContext.cgContext
                        if let webView: WKWebView = self.webView {
                            let renderHeight: CGFloat = CGFloat(context.height)
                            let renderWidth: CGFloat = CGFloat(context.width)
                            NSLog("BUFFOON Context Size: \(renderWidth), \(renderHeight). Flipped: " + (nsContext.isFlipped ? "YES" : "NO"))
                            let renderCentre: CGFloat = (renderWidth - (renderHeight * 0.75)) / 2.0
                            let renderRect: CGRect = CGRect.init(x: renderCentre, y: 0, width: renderWidth * 0.75, height: renderHeight)

                            NSGraphicsContext.saveGraphicsState()

                            //context.setFillColor(CGColor.clear)
                            //context.fill(CGRect.init(x: 0, y: 0, width: renderWidth, height: renderHeight))

                            let imageRep: NSBitmapImageRep? = webView.bitmapImageRepForCachingDisplay(in: webView.bounds)
                            if imageRep != nil {
                                webView.cacheDisplay(in: webView.bounds, to: imageRep!)
                                let success: Bool = imageRep!.draw(in: renderRect)
                                NSLog("BUFFOON imagrep " + (success ? "drawn" : "not drawn"))
                            }

                            NSGraphicsContext.restoreGraphicsState()

                            return true
                        }
                    }

                    return false
                }), nil)
            } catch {
                handler(nil, nil)
            }
        }
    }
    
    
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
                return "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"initial-scale=1.0\" />\n<style>" + css + "</style>\n<base href=\"\(url)\"/>\n</head>\n<body>" + render + "</body>\n</html>"
            } else {
                errString += " could not access Thumbnailer’s bundle"
            }
        } catch {
            if css.count == 0 { errString += " could not load CSS" }
        }

        // Something went wrong loading or rendering...
        return errString
    }

    
}
