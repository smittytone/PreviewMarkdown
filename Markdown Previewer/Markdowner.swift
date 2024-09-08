/*
 *  Markdownwer.swift
 *  Wrapper for MarkdownIt JavaScript
 *
 *  Created by Tony Smith on 23/09/2020.
 *  Copyright © 2024 Tony Smith. All rights reserved.
 */


import Foundation
import JavaScriptCore
import AppKit


public class Markdowner {
    
    // MARK: - Private Properties
    
    private let mdjs: JSValue
    
    
    // MARK: - Constructor
    
    /**
     The default initialiser.
     
     - returns: `nil` on failure to load or evaluate `markdownit.js`.
    */
    public init?() {
        
        // Get the file's bundle based on how it's
        // being included in the host app
        let bundle = Bundle(for: Markdowner.self)

        // Load the highlight.js code from the bundle or fail
        guard let mdjsPath: String = bundle.path(forResource: "markdown-it.min", ofType: "js") else {
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
        // NOTE We set "html" because Markdown-It 14 doesn't do this automatically
        let jsHtml: JSValue = JSValue.init(object: ["html": true], in: context)
        self.mdjs = mdjs.construct(withArguments: [jsHtml])
    }
    
    
    // MARK: - Primary Functions
    
    /**
     Convert the supplied Markdown file to HTML.
    
     - Parameters:
        - markdownString: The source code to highlight.
     
     - Returns: The HTML.
    */
    func tokenise(_ markdownString: Substring) -> String {
        
        let returnValue: JSValue = mdjs.invokeMethod("render", withArguments: [markdownString])
        let renderedHTMLString: String = returnValue.toString()
        return renderedHTMLString
    }

}
