/*
 *  Markdownwer.swift
 *  Wrapper for MarkdownIt JavaScript
 *
 *  Created by Tony Smith on 23/09/2020.
 *  Copyright © 2023 Tony Smith. All rights reserved.
 */


import Foundation
import JavaScriptCore
import AppKit


public class Markdowner {
    
    // MARK: - Public Properties
    
    var styleString: String = "body {font-family:sans-serif;cursor:default;}"
    
    
    // MARK: - Private Properties
    
    private let mdjs: JSValue
    private let bundle: Bundle
    
    
    // MARK: - Constructor
    
    /**
     The default initialiser.
     
     - returns: `nil` on failure to load or evaluate `markdownit.min.js`.
    */
    public init?() {
        
        // Get the file's bundle based on how it's
        // being included in the host app
        let bundle = Bundle(for: Markdowner.self)

        // Load the highlight.js code from the bundle or fail
        guard let mdjsPath: String = bundle.path(forResource: "markdown-it", ofType: "js") else {
            return nil
        }

        // Check the JavaScript or fail
        let context = JSContext.init()!
        let mdjsString: String = try! String.init(contentsOfFile: mdjsPath)
        let _ = context.evaluateScript(mdjsString)
        guard let mdjs = context.globalObject.objectForKeyedSubscript("markdownit") else {
            return nil
        }
        
        // Store the results for later
        self.mdjs = mdjs.construct(withArguments: ["default"])
        self.bundle = bundle
    }
    
    
    // MARK: - Primary Functions
    
    /**
     Highlight the supplied code in the specified language.
    
     - Parameters:
        - markdownString: The source code to highlight.
        - doFastRender:   Should fast rendering be used? Default: `true`.
     
     - Returns: The highlighted code as an NSAttributedString, or `nil`
    */
    open func render(_ markdownString: String, doAltRender: Bool = false) -> NSAttributedString? {

        // NOTE Will return 'undefined' (trapped below) if it's a unknown language
        let returnValue: JSValue = mdjs.invokeMethod("render", withArguments: [markdownString])
        var renderedHTMLString: String = returnValue.toString()
        
        // Trap 'undefined' output as this is effectively an error condition
        // and should not be returned as a valid result -- it's actually a fail
        if renderedHTMLString == "undefined" {
            return nil
        }

        // Convert the HTML received from Markdownit.js to an NSAttributedString or nil
        var returnAttrString: NSAttributedString? = nil
        
        if doAltRender {
            // Use fast rendering -- not yet implemented
            return nil
        } else {
            // Add the HTML styling
            renderedHTMLString = "<style type=\"text/css\">" + self.styleString + "</style>" + renderedHTMLString
            //return NSAttributedString.init(string: renderedHTMLString)
            
            // Use NSAttributedString's own HTML -> NSAttributedString conversion
            let data = renderedHTMLString.data(using: String.Encoding.utf8)!
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]

            // This must be run on the main thread as it used WebKit under the hood
            safeMainSync {
                returnAttrString = try? NSMutableAttributedString(data:data,
                                                                  options: options,
                                                                  documentAttributes:nil)
            }
        }

        return returnAttrString
    }
    
    
    // MARK: - Utility Functions

    /**
     Execute the supplied block on the main thread.
    */
    private func safeMainSync(_ block: @escaping ()->()) {

        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.sync {
                block()
            }
        }
    }

}
