/*
 *  Markdowner.swift
 *  Swift wrapper for MarkdownIt JavaScript
 *
 *  Created by Tony Smith on 23/09/2020.
 *  Copyright © 2024 Tony Smith. All rights reserved.
 */


import Foundation
import JavaScriptCore
import AppKit


public class Markdowner {
    
    // MARK: - Private Properties
    
    private let markdownerJavaScript: JSValue
    
    
    // MARK: - Constructor
    
    /**
        The default initialiser.
     
     - returns: 
        `nil` on failure to load, evaluate or configure `markdownit.js`.
    */
    public init?() {
        
        // Get the file's bundle based on how it's
        // being included in the host app
        let bundle = Bundle(for: Markdowner.self)

        // Load the highlight.js code from the bundle or fail
        guard let markdownerJavaScriptPath: String = bundle.path(forResource: "markdown-it.min", ofType: "js") else {
            return nil
        }

        // Check the JavaScript or fail
        let context: JSContext = JSContext.init()
        let markdownerJavaScriptString: String = try! String.init(contentsOfFile: markdownerJavaScriptPath)
        let _ = context.evaluateScript(markdownerJavaScriptString)
        guard let localMarkdownerJavaScript = context.globalObject.objectForKeyedSubscript("markdownit") else {
            return nil
        }
        
        // Store the results for later
        // NOTE We set "html" because Markdown-It 14 doesn't do this automatically
        let markdownerHtmlOption: JSValue = JSValue.init(object: ["html": true], in: context)
        self.markdownerJavaScript = localMarkdownerJavaScript.construct(withArguments: [markdownerHtmlOption])
    }
    
    
    // MARK: - Primary Functions
    
    /**
        Tokenise the supplied markdown-formatted document.
    
     - Parameters:
        - markdown: The markdown string to convert.
     
     - Returns:
        A string of tokenised data.
    */
    func tokenise(_ markdown: Substring) -> String {
        
        let returnValue: JSValue = self.markdownerJavaScript.invokeMethod("render", withArguments: [markdown])
        return returnValue.toString()
    }

}
