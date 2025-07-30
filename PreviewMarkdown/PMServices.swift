/*
 *  PMServices.swift
 *  PreviewMarkdown
 *
 *  Created by Tony Smith on 28/01/2025.
 *  Copyright © 2025 Tony Smith. All rights reserved.
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
        
        // Convert the markdown and paste it back
        let html = converter.tokenise(markdown[...])
        pasteboard.clearContents()
        pasteboard.setString(html, forType: .string)
    }
}
