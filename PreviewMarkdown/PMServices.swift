/*
 *  PMServices.swift
 *  PreviewMarkdown
 *
 *  Created by Tony Smith on 28/01/2025.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */


import AppKit


class HTMLServiceProvider: NSObject {

    // MARK: -  Enumerations
    
    enum Errors: NSString {
        case badText = "Cannot access Markdown text to convert"
        case badConverter = "Cannot load essential app components"
    }


    // MARK: - Service Provider Functions

    @objc
    func convertToHtml(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>) {

        convert(pasteboard, userData: userData, error: error, false)
    }


    @objc
    func convertToPlainText(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>) {

        convert(pasteboard, userData: userData, error: error, true)
    }


    @objc
    func convert(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>, _ removeTags: Bool) {

        // Ensure we have a string to process...
        guard let markdown = pasteboard.string(forType: .string) else {
            error.pointee = Errors.badText.rawValue
            return
        }
        
        // ...and that we can load markdowner to convert it
        guard let converter = PMMarkdowner() else {
            error.pointee = Errors.badConverter.rawValue
            return
        }
        
        // Convert the markdown to HTML
        var html = converter.tokenise(markdown[...])

        // If we're converting to plain text, excise the tags
        if removeTags {
            // Replace most close tags with line breaks to preserve text structure
            for regEx in ["</h[1-6]+>", "</p[re]*>", "</[ou]l*>", "</t[hd]*>", "</block>"] {
                html = html.replacingOccurrences(of: regEx, with: "\n", options: .regularExpression)
            }

            // Now zap all of the remaining tags
            html = html.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
        }

        // Drop the converted text onto the pasteboard
        pasteboard.clearContents()
        pasteboard.setString(html, forType: .string)
    }
}
