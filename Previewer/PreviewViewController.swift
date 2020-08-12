
//  PreviewViewController.swift
//  Previewer
//
//  Created by Tony Smith on 31/10/2019.
//  Copyright © 2019-20 Tony Smith. All rights reserved.


import Cocoa
import Quartz
import WebKit


class PreviewViewController: NSViewController, QLPreviewingController {
    
    @IBOutlet var errorReportField: NSTextField!


    override var nibName: NSNib.Name? {

        return NSNib.Name("PreviewViewController")
    }


    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {

        // Hide the error message field
        self.errorReportField.isHidden = true

        // Load the source file using a co-ordinator as we don't know what thread this function
        // will be executed in when it's called by macOS' QuickLook code


        var reportError: NSError = NSError(domain: "com.bps.PreviewMarkdown.Previewer",
                                            code: -201,
                                            userInfo: [NSLocalizedDescriptionKey: "BUFFOON can't access file"])

        let fs: FileManager = FileManager.default
        if fs.isReadableFile(atPath: url.path) {
            do {
                let data: Data = try Data.init(contentsOf: url)
                if let markdownString: String = String.init(data: data, encoding: .utf8) {

                    // Instantiate an NSTextView to display the NSAttributedString render of the markdown
                    let renderTextView: NSTextView = NSTextView.init(frame: self.view.frame)
                    renderTextView.backgroundColor = NSColor.white

                    if let tvs: NSTextStorage = renderTextView.textStorage {
                        let sm: SwiftyMarkdown = SwiftyMarkdown.init(string: "")
                        self.setBaseValues(sm, 14.0)
                        tvs.setAttributedString(sm.attributedString(markdownString))
                    }

                    self.view.addSubview(renderTextView)
                    self.setViewConstraints(renderTextView)
                    self.view.display()

                    handler(nil)
                    return
                } else {
                    reportError = NSError(domain: "com.bps.PreviewMarkdown.Previewer",
                                          code: -202,
                                          userInfo: [NSLocalizedDescriptionKey: "BUFFOON can't stringify file"])
                }
            } catch {
                reportError = NSError(domain: "com.bps.PreviewMarkdown.Previewer",
                                      code: -201,
                                      userInfo: [NSLocalizedDescriptionKey: "BUFFOON can't load file"])
            }
        }

        handler(reportError)
        showError(reportError.userInfo[NSLocalizedDescriptionKey] as! String)

        /*
        let fc: NSFileCoordinator = NSFileCoordinator()
        let intent: NSFileAccessIntent = NSFileAccessIntent.readingIntent(with: url)
        fc.coordinate(with: [intent], queue: .main) { (err) in
            if err == nil {
                // No error loading the file? Then continue
                do {
                    // Read in the markdown from the specified file
                    let markdownString: String = try String(contentsOf: intent.url, encoding: String.Encoding.utf8)

                    // Get an HTML page string from the markdown
                    let htmlString: String = self.renderMarkdown(markdownString, intent.url)

                    // Instantiate a WKWebView to display the HTML in our view
                    let prefs: WKPreferences = WKPreferences()
                    prefs.javaScriptEnabled = false

                    let config: WKWebViewConfiguration = WKWebViewConfiguration.init()
                    config.suppressesIncrementalRendering = true
                    config.preferences = prefs

                    let webView: WKWebView = WKWebView.init(frame: self.view.bounds, configuration: config)

                    NSLog(htmlString)

                    webView.loadHTMLString(htmlString, baseURL: nil)

                    // Display the WKWebView and add it to the superview, finally adding
                    // layout constraints to keep it anchored to the edges of the superview
                    self.view.addSubview(webView)
                    self.setViewConstraints(webView)
                    self.view.display()
                    
                    // Hand control back to QuickLook
                    handler(nil)
                } catch {
                    // 'try' to load file failed
                    self.showError("Could not load file \(intent.url.lastPathComponent) to preview it")
                    let reportError = NSError(domain: "com.bps.PreviewMarkdown.Previewer",
                                              code: -201,
                                              userInfo: nil)
                    handler(reportError)
                }
            } else {
                // coordinate operation failed
                self.showError("Could not find file \(intent.url.lastPathComponent) to preview it")
                handler(err)
            }
        }

         */
    }

    func setBaseValues(_ sm: SwiftyMarkdown, _ baseFontSize: CGFloat) {

        sm.setFontSizeForAllStyles(with: baseFontSize)

        sm.h4.fontSize = baseFontSize * 1.2
        sm.h3.fontSize = baseFontSize * 1.4
        sm.h2.fontSize = baseFontSize * 1.6
        sm.h1.fontSize = baseFontSize * 2.0
        sm.h1.color = NSColor.darkGray
        sm.code.fontName = "AndaleMono"
        sm.code.color = NSColor.gray
        sm.link.color = NSColor.blue
    }

    func showError(_ errString: String) {

        NSLog("BUFFOON " + errString)
        self.errorReportField.isHidden = false
        self.errorReportField.stringValue = errString
    }


    func preparePreviewOfSearchableItem(identifier: String, queryString: String?, completionHandler handler: @escaping (Error?) -> Void) {

        NSLog("BUFFOON searchable identifier: \(identifier)")
        NSLog("BUFFOON searchable query:      " + (queryString ?? "nil"))

        // Hand control back to QuickLook
        handler(nil)
    }


    func renderMarkdown(_ markdown: String, _ baseURL: URL) -> String {

        // Convert the supplied markdown string to an HTML string - or an error string

        var errString: String = "ERROR:"
        var css: String = ""

        let url: URL = baseURL.deletingLastPathComponent()

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
                return "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"initial-scale=1.0\" />\n<style>" + css + "</style>\n<base href=\"\(url)\"/>\n</head>\n<body>" + render + "</body>\n</html>"
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
