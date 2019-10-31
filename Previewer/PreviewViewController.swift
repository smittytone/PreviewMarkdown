
//  PreviewViewController.swift
//  Previewer
//
//  Created by Tony Smith on 31/10/2019.
//  Copyright © 2019 Tony Smith. All rights reserved.


import Cocoa
import Quartz
import WebKit


class PreviewViewController: NSViewController, QLPreviewingController {
    
    override var nibName: NSNib.Name? {

        return NSNib.Name("PreviewViewController")
    }

    override func loadView() {
        super.loadView()
        // Do any additional setup after loading the view.
    }


    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        
        // Load the source file using a co-ordinator as we don't know what thread this function
        // will be executed in when it's called by macOS' QuickLook code
        let fc: NSFileCoordinator = NSFileCoordinator()
        let intent: NSFileAccessIntent = NSFileAccessIntent.readingIntent(with: url)
        fc.coordinate(with: [intent], queue: .main) { (err) in
            do {
                // Read in the markdown from the specified file
                let markdownString: String = try String(contentsOf: intent.url, encoding: String.Encoding.utf8)

                // Get an HTML page string from the markdown
                let htmlString: String = self.renderMarkdown(markdownString, intent.url.deletingLastPathComponent())

                // Instantiate a WKWebView to display the HTML in our view
                let webView: WKWebView = WKWebView.init(frame: self.view.bounds, configuration: WKWebViewConfiguration())
                webView.loadHTMLString(htmlString, baseURL: nil)

                // Add the WKWebView to the superview, adding laytout constraints
                // to keep it anchored to the edges of the superview, and then
                // redraw the superview
                self.view.addSubview(webView)
                self.setViewConstraints(webView)
                self.view.display()

                // Hand control back to QuickLook
                handler(nil)
            } catch {
                handler(err)
            }
        }
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


    func setViewConstraints(_ view: NSView) {

        // Programmatically apply constraints which bind the specified view to
        // the edges of the view controller's primary view

        view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint(item: view, attribute: .leading, relatedBy: .equal, toItem: self.view, attribute: .leading, multiplier: 1.0, constant: 0.0).isActive = true
        NSLayoutConstraint(item: view, attribute: .trailing, relatedBy: .equal, toItem: self.view, attribute: .trailing, multiplier: 1.0, constant: 0.0).isActive = true
        NSLayoutConstraint(item: view, attribute: .top, relatedBy: .equal, toItem: self.view, attribute: .top, multiplier: 1.0, constant: 0.0).isActive = true
        NSLayoutConstraint(item: view, attribute: .bottom, relatedBy: .equal, toItem: self.view, attribute: .bottom, multiplier: 1.0, constant: 0.0).isActive = true
    }
}
