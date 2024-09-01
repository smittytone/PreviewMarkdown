//
//  Styler.swift
//  Previewer
//
//  Created by Tony Smith on 12/04/2023.
//  Copyright © 2023 Tony Smith. All rights reserved.
//


import Foundation
import AppKit


typealias StyleAttributes = [String: [NSAttributedString.Key: AnyObject]]
typealias FontStore = [String: [String: NSFont]]


enum StyleType {
    case none
    case paragraph  // A paragraph-level style, eg. P, H1
    case character  // Applied to a parent style, eg. EM, STRONG
    case indent     // Indented block, eg. PRE or BLOCKQUOTE
}


class Style {
    var name: String = "p"
    var type: StyleType = .paragraph
}


enum ListType {
    case bullet
    case number
}


class Styler {
    
    // MARK: - Publicly accessible properties
    
    var lineSpacing: CGFloat        = 14.0
    var paraSpacing: CGFloat        = 18.0
    var fontSize: CGFloat           = 24.0
    
    var headColour: String          = "#FFFFFF"
    var codeColour: String          = "#00FF00"
    var bodyColour: String          = "#FFFFFF"
    var linkColour: String          = "#64ACDD"
    
    var bodyFontName: String        = "SF Pro"
    var codeFontName: String        = "Menlo"
    
    var bodyFontFamily: PMFont      = PMFont()
    
    
    
    // MARK: - Private properties with defaults
    
    private var tokenString: String                 = ""
    private var currentLink: String                 = ""
    private var currentImagePath: String            = ""
    private var currentLanguage: String             = ""
    private let htmlTagStart: String                = "<"
    private let htmlTagEnd: String                  = ">"
    private let lineBreakSymbol: String             = "\u{2028}"
    private let appliedTags: [String]               = ["p", "a", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "code", "em", "strong", "blockquote", "s", "img"]
    private let bullets: [String]                   = ["\u{25CF}", "\u{25CB}", "\u{25CF}", "\u{25CB}", "\u{25CF}", "\u{25CB}"]
    private let htmlEscape: NSRegularExpression     = try! NSRegularExpression(pattern: "&#?[a-zA-Z0-9]+?;", options: .caseInsensitive)
    
    private var styles: [String: [NSAttributedString.Key: AnyObject]] = [:]
    
    
    // MARK: - Private properties without defaults
    
    private var fonts: FontStore!
    
    // Style definition objects, globalised for re-use across styles
    private var headColourValue: NSColor!
    private var codeColourValue: NSColor!
    private var bodyColourValue: NSColor!
    private var linkColourValue: NSColor!
    
    private var tabbedParaStyle: NSMutableParagraphStyle!
    private var insetParaStyle:  NSMutableParagraphStyle!
    private var lineParaStyle:   NSMutableParagraphStyle!
    
    private let H1_MULTIPLIER: CGFloat = 2.6
    private let H2_MULTIPLIER: CGFloat = 2.2
    private let H3_MULTIPLIER: CGFloat = 1.8
    private let H4_MULTIPLIER: CGFloat = 1.4
    private let H5_MULTIPLIER: CGFloat = 1.2
    private let H6_MULTIPLIER: CGFloat = 1.2
    


    // MARK: - Constructor
    
    /**
        The default initialiser.
     
        - Parameters
            - htmlString - The input HTML code generated from Markdown by mdit (or whatever).
    */
    init(_ htmlString: String) {
        
        self.tokenString = htmlString
    }
    
    
    /**
        Render the class' `tokenString` property.
     
        - Parameters
            - isThumbnail - Are we rendering text for thumbnail use? Default : `false`.
        
        - Returns NSAttributedString or nil or error.
     */
    func render(_ isThumbnail: Bool = false) -> NSAttributedString? {
        
        // Check we have an tokended string to render.
        if self.tokenString.isEmpty {
            return nil
        }
        
        // Generate the text styles we'll use
        generateStyles()
        
        // Render and return the tokened string
        return processHTMLString()
    }
    
    
    /**
        Convert the class' `tokenString` property to an attributed string
     
        - Returns NSAttributedString or nil or error.
     */
    private func processHTMLString() -> NSAttributedString? {
        
        // Rendering control variables
        var doAddBullet: Bool = false
        var isBlock: Bool = false
        var isPre: Bool = false
        
        var blockLevel: Int = 0
        var indentLevel: Int = 0
        var insetCounts: [Int] = Array.init(repeating: 0, count: 12)
        var listTypes: [ListType] = Array.init(repeating: .bullet, count: 12)
        
        // Font-less horizontal rule
        let hr = NSAttributedString(string: "\n\u{00A0} \u{0009} \u{00A0}\n",
                                    attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                                                 .strikethroughColor: self.bodyColourValue!,
                                                 .paragraphStyle: self.lineParaStyle!])

        // Perform pre-processing:
        // 1. Convert checkboxes, eg `[] checkbox`, `[x] checkbox`
        self.tokenString = processCheckboxes(self.tokenString)
        
        // 2. Convert Windows LFCR line endings
        self.tokenString = self.tokenString.replacingOccurrences(of: "\n\r", with: "\n")

        // Render the HTML
        var scannedString: String? = nil
        let scanner: Scanner = Scanner(string: self.tokenString)
        scanner.charactersToBeSkipped = nil

        let renderedString: NSMutableAttributedString = NSMutableAttributedString(string: self.tokenString, attributes: self.styles["p"])
        //let renderedString: NSMutableAttributedString = NSMutableAttributedString(string: "", attributes: self.styles["p"])
        
        // Need a base style to avoid over-emptying the property stack later
        // NOTE Adds an extra [p] we may not need -- check
        let baseStyle: Style = Style()
        var styleStack: [Style] = [baseStyle]
        
        // Iterate over the stored HTML string
        while !scanner.isAtEnd {
            // Flag to mark that the end of the string has been reached
            var ended: Bool = false

            // Scan up to the next HTML tag's '<' and get the substring
            if let contentString: String = scanner.scanUpToString(self.htmlTagStart) {
                // We have content ahead of the first token, so render that first
                scannedString = contentString
                ended = scanner.isAtEnd
            }

            // MARK: Content Processing
            // Have we got content to style? Do so now.
            // This will be content ahead of the first HTML tag or between tags
            if scannedString != nil && !scannedString!.isEmpty {
#if DEBUG
                NSLog("[CONTENT] \(scannedString!)")
#endif
                
                // Prepare a paragraph indent, eg. for bullet point
                var indent: String = ""
                
                // Should we add a bullet or numeral from a previous LI tag?
                // NOTE Indents are managed by a sequence of tab (\t) symbols
                if doAddBullet {
                    if scannedString!.hasPrefix("\n") {
                        // Instance where mdit has chosen to set the LI content as a
                        // separate P block. Ignore the CR
                        scannedString = ""
                    } else {
                        doAddBullet = false
                        if listTypes[indentLevel] == .bullet {
                            // Add a standard bullet. We set six types and we cycle around
                            // when the indent level is greater than that.
                            var index: Int = indentLevel
                            while index > self.bullets.count {
                                index -= self.bullets.count
                            }
                            
                            indent = String(repeating: "\t", count: indentLevel) + "\(self.bullets[index - 1]) "
                        } else {
                            // Add a numeral -- the value was calculated when we encountered the initial LI
                            indent = String(repeating: "\t", count: indentLevel) + "\(insetCounts[indentLevel]). "
                        }
                    }
                }
                
                // Pre-formatted lines should be presented as a single paragraph with inner line breaks,
                // so convert the content block's paragraph breaks (\n) to NSAttributedString-friendly
                // line-break codes.
                if isPre {
                    scannedString = scannedString!.replacingOccurrences(of: "\n", with: self.lineBreakSymbol)
                    NSLog("[CODE] \(self.currentLanguage)")
                }
                
                if isBlock {
                    let blockIndentParaStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
                    blockIndentParaStyle.lineSpacing = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
                    blockIndentParaStyle.paragraphSpacing = (self.paraSpacing >= 0.0 ? self.paraSpacing : self.lineSpacing)
                    blockIndentParaStyle.alignment = .left
                    blockIndentParaStyle.headIndent = 40.0 * CGFloat(blockLevel)
                    blockIndentParaStyle.firstLineHeadIndent = 40.0 * CGFloat(blockLevel)
                    self.styles["blockquote"]![.paragraphStyle] = blockIndentParaStyle
                }
                
                // Assemble the styled string...
                if !scannedString!.isEmpty {
                    var partialRenderedString: NSMutableAttributedString
                    if (indent.count > 0) {
                        // Style and apply the indent, then style and apply the content
                        // NOTE Indent should match body, not what follows
                        partialRenderedString = NSMutableAttributedString.init(attributedString: styleString(indent, [baseStyle]))
                        partialRenderedString.append(styleString(scannedString!, styleStack))
                    } else {
                        // Style and apply the unindented content
                        partialRenderedString = NSMutableAttributedString.init(attributedString: styleString(scannedString!, styleStack))
                    }
                    
                    // ...and add it to the store
                    renderedString.append(partialRenderedString)
                }
                
                // Break out of the upper scanner loop if we're done
                if ended {
                    continue
                }
            }
            
            // Reached an token delimiter: step over it
            scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)

            // Get the first character of the tag
            let string: NSString = scanner.string as NSString
            let idx: Int = scanner.currentIndex.utf16Offset(in: self.tokenString)
            let nextChar: String = string.substring(with: NSMakeRange(idx, 1))
            
            // MARK: Closing Token
            if nextChar == "/" {
                // Found a close tag, so step over the `/`
                scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)

                // Get the remainder of the tag up to the delimiter
                if let closeTag: String = scanner.scanUpToString(self.htmlTagEnd) {
#if DEBUG
                    NSLog("[TAG] <- \(closeTag)")
#endif
                    // NOTE mdit generates lowercase HTML tags, but we should probably not assume that
                    // startTag = startTag.lowercased()
                    
                    // Should we remove the carriage return from the end of the line?
                    // This is required when single tokens appear on a per-line basis, eg UL, OL, BLOCKQUOTE
                    var doSkipCR: Bool = false
                    
                    // Should be convert the end-of-line LF to LB?
                    var doReplaceCR: Bool = false
                    
                    // Process the closing token by type
                    switch(closeTag) {
                        // Ordered or unordered lists
                        case "ul":
                            fallthrough
                        case "ol":
                            // Reset the current level's inset count
                            insetCounts[indentLevel] = 0
                            
                            // Reduce the inset level
                            indentLevel -= 1
                            if indentLevel < 0 {
                                indentLevel = 0
                            }

                            // Remove the next tag's CR if we're nested
                            if (indentLevel > 0) {
                                doSkipCR = true
                            }
                        // List items
                        case "li":
                            // Use line breaks for LI
                            doReplaceCR = true
                        // Blocks
                        case "blockquote":
                            doSkipCR = true
                            blockLevel -= 1
                            if blockLevel < 0 {
                                blockLevel = 0
                            }
                            
                            if blockLevel == 0 {
                                isBlock = false
                            }
                            fallthrough
                        case "pre":
                            isPre = false
                            // Restore the base style
                            //styleStack = [baseStyle]
                        default:
                            break
                    }

                    // Step over the token delimiter
                    scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
                    
                    if doSkipCR || doReplaceCR {
                        // Remove the tailing LF
                        scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
                    }
                    
                    // If required, replace the LF at the end of the line with an LB.
                    // This will be for BR
                    if doReplaceCR {
                        renderedString.append(NSAttributedString.init(string: self.lineBreakSymbol))
                    }
                    
                    // Remove the last style, as set by the opening tag
                    if styleStack.count > 1 {
                        styleStack.removeLast()
                    }
                }
            } else {
                // MARK: Opening Token
                // We've got a new token, so get it up to the delimiter
                if let startTag: String = scanner.scanUpToString(self.htmlTagEnd) {
                    // NOTE mdit generates lowercase HTML tags, but we should probably not assume that
                    // startTag = startTag.lowercased()
                    
                    // This is the tag we will use to format the content. It may not
                    // be the actual tag detected, eg. for BLOCKQUOTE we use the inner P
                    var tagToUse: String = startTag
                    
                    // Should we remove the carriage return from the end of the line?
                    // This is required when single tokens appear on a per-line basis, eg UL, OL, BLOCKQUOTE
                    var doSkipCR: Bool = false
                    
                    // Should be convert the end-of-line LF to LB?
                    var doReplaceCR: Bool = false
                    
                    // Handle A and IMG tags outside of the switch statement because
                    // they're not straightforward comparisons: the tags contain extra data
                    if startTag.hasPrefix("a") {
                        // We have a link -- get the destination from HREF
                        tagToUse = "a"
                        getLinkRef(startTag)
                    }
                    
                    if startTag.hasPrefix("i") {
                        // We have an IMG -- get the destination from SRC
                        // TO-DO Do we want to retain the ALT tag?
                        tagToUse = "img"
                        getImageRef(startTag)
                    }
                    
                    if startTag.contains("code class") {
                        tagToUse = "code"
                        getCodeLanguage(startTag)
                    }
                    
                    // TO-DO Support tables here
                    
                    // Process the new token by type
                    switch(startTag) {
                        // Paragraph-level tags with context-sensitivity
                        case "p":
                            if isBlock {
                                // Inside a block, so apply the correct style
                                tagToUse = "blockquote"
                            } else if doAddBullet {
                                // Inside a list item
                                //tagToUse = "none"
                            }
                        // Ordered or unordered lists and items
                        case "ul":
                            fallthrough
                        case "ol":
                            // Set the list type and increment the current indent
                            let listItem: ListType = startTag == "ul" ? .bullet : .number
                            indentLevel += 1
                            if indentLevel == listTypes.count {
                                listTypes.append(listItem)
                            } else {
                                listTypes[indentLevel] = listItem
                            }

                            doSkipCR = true
                        case "li":
                            // NOTE mdit usually embeds text in LI tags, but in nested
                            //      lists can include P tags, so latter needs to check
                            //      later if it's indented, ie. `self.indentLevel`
                            doAddBullet = true
                            tagToUse = "p"
                            
                            // Increment the numeric list item, if it's an OL
                            if listTypes[indentLevel] == .number {
                                insetCounts[indentLevel] += 1
                            }
                        // Blocks
                        case "blockquote":
                            isBlock = true
                            doSkipCR = true
                            blockLevel += 1
                            
                            // Rely on the inner P for styling
                            tagToUse = "none"
                        case "pre":
                            // ASSUMPTION PRE is ALWAYS followed by CODE (not in HTML, but in MD->HTML)
                            isPre = true
                        // Tokens that can be handled immediately
                        case "hr":
                            renderedString.append(hr)
                            doSkipCR = true
                        case "br":
                            // Doesn't change the current style, just the line ending
                            doReplaceCR = true
                        // Character-level tokens
                        // TO-DO Use code highligting
                        case "code":
                            // If CODE is in a PRE, we rely on the PRE for styling, otherwise
                            // we use CODE as a character style
                            if isPre {
                                tagToUse = "none"
                            }
                        default:
                            // Covers all other tags, including headers
                            break
                    }
                    
                    // Compare the tag to use with those we apply.
                    // Some, such as list markers, we do not style here
                    if self.appliedTags.contains(tagToUse) {
#if DEBUG
                        NSLog("[TAG] -> \(startTag) as \(tagToUse)")
#endif
                        // The tag is one we look for
                        // Push the tag's style to the stack
                        let tagStyle: Style = Style()
                        tagStyle.name = tagToUse
                        
                        // Set character styles (inherit style from parent)
                        if ["strong", "em", "a", "s", "img"].contains(tagToUse) {
                            tagStyle.type = .character
                        }
                        
                        if ["p", "h1", "h2", "h3", "h4", "h5", "h6", "blockquote", "pre"].contains(tagToUse) {
                            tagStyle.type = .paragraph
                        }

                        styleStack.append(tagStyle)
                    }
                    
                    // Step over the token's delimiter
                    scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
                    
                    // If required, remove the LF at the end of the line (ie. right after the tag)
                    // This will be for OL, UL, BLOCKQUOTE, PRE+CODE, HR, BR, LI+P
                    if doSkipCR || doReplaceCR {
                        scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
                    }
                    
                    // If required, replace the LF at the end of the line with an LB.
                    // This will be for BR
                    if doReplaceCR {
                        renderedString.append(NSAttributedString.init(string: self.lineBreakSymbol))
                    }
                    
                    // Images have no content between tags, so handle the styling here
                    // NOTE Image is inserted by `styleString()`.
                    if tagToUse == "img" {
                        let partialRenderedString: NSMutableAttributedString = NSMutableAttributedString.init(attributedString: styleString("", styleStack))
                        renderedString.append(partialRenderedString)
                    }
                }
            }
            
            scannedString = nil
        }

        // We have now composed the string. Before returning it, process HTML escapes
        let results: [NSTextCheckingResult] = self.htmlEscape.matches(in: renderedString.string,
                                                                      options: [.reportCompletion],
                                                                      range: NSMakeRange(0, renderedString.length))
        if results.count > 0 {
            var localOffset: Int = 0
            for result: NSTextCheckingResult in results {
                let fixedRange: NSRange = NSMakeRange(result.range.location - localOffset, result.range.length)
                let entity: String = (renderedString.string as NSString).substring(with: fixedRange)
                if let decodedEntity = HTMLUtils.decode(entity) {
                    renderedString.replaceCharacters(in: fixedRange, with: String(decodedEntity))
                    localOffset += (result.range.length - 1);
                }
            }
        }
        
        return renderedString
    }
    
    
    internal func getLinkRef(_ tag: String) {
        
        self.currentLink = splitTag(tag)
    }
    
    
    internal func getImageRef(_ tag: String) {
        
        self.currentImagePath = splitTag(tag)
    }
    
    
    internal func getCodeLanguage(_ tag: String) {
        
        let parts: [String] = splitTag(tag).components(separatedBy: "-")
        if parts.count > 0 {
            self.currentLanguage = parts[1]
        } else {
            self.currentLanguage = parts[0]
        }
    }
    
    
    internal func splitTag(_ tag: String, _ partIndex: Int = 1) -> String {
        
        let parts: [String] = tag.components(separatedBy: "\"")
        if parts.count > partIndex {
            return parts[partIndex]
        }
        
        return ""
    }

    
    /**
        Generate an attributed string from an individual source string.
     
        - Parameters
            - plain - The raw string.
            - styleList - The style stack.
     
        - Returns An attributed string.
     */
    internal func styleString(_ plain: String, _ styleList: [Style]) -> NSAttributedString {
       
        var returnString: NSMutableAttributedString? = nil
        
        if styleList.count > 0 {
            // Build the attributes from the style list, including the font
            var attributes = [NSAttributedString.Key: AnyObject]()
            var parentStyle: Style = Style()
            
            // Iterate over the stack, applying the style one after the other,
            // the most recent stack item last. We update attributes, so a newer
            // style can override an earlier one
            for style in styleList {
                // Does the style apply to character sequences within paras?
                if style.type == .character {
                    // Character-sequence styles should be the last to be applied
                    if let styleToUse = self.styles[parentStyle.name] {
                        // Iterate over the parent styles and apply them
                        for (attributeName, attributeValue) in styleToUse {
                            attributes.updateValue(attributeValue,
                                                   forKey: attributeName)
                        }
                    }
                    
                    // Apply the additional styling
                    if let styleToUse = self.styles[style.name] {
                        var fontUsed: NSFont? = nil
                        // Iterate over the parent styles and apply them
                        for (attributeName, attributeValue) in styleToUse {
                            attributes.updateValue(attributeValue,
                                                   forKey: attributeName)
                            
                            if attributeName == .font {
                                fontUsed = attributeValue as? NSFont
                                //let name: String = fontUsed!.fontName
                            }
                        }
                        
                        // Extra adjustments -- additions that cannot be applied generically
                        switch style.name {
                            case "a":
                                attributes.updateValue(self.currentLink as NSString, forKey: .toolTip)
                                attributes.updateValue(self.currentLink as NSString, forKey: .link)
                            case "em":
                                // Check if the font used is italic. If not, we need to underline
                                if fontUsed == nil || (!fontUsed!.fontName.contains("Italic") && !fontUsed!.fontName.contains("Oblique")) {
                                    var lineColour: NSColor
                                    if let c: Any = self.styles[parentStyle.name]![.foregroundColor] {
                                        lineColour = c as! NSColor
                                    } else {
                                        lineColour = NSColor.white
                                    }
                                    
                                    attributes.updateValue(NSUnderlineStyle.single.rawValue as NSNumber, forKey: .underlineStyle)
                                    attributes.updateValue(lineColour, forKey: .underlineColor)
                                }
                            case "strong":
                                // Check if the font used is italic. If not, flag we need to set the background color
                                if fontUsed == nil || (!fontUsed!.fontName.contains("Bold") && !fontUsed!.fontName.contains("Black") && !fontUsed!.fontName.contains("Heavy") && !fontUsed!.fontName.contains("Medium")) {
                                    attributes.updateValue(self.bodyColourValue, forKey: .backgroundColor)
                                    attributes.updateValue(NSColor.black, forKey: .foregroundColor)
                                }
                            case "img":
                                let imageAttachment = NSTextAttachment()
                                if let image: NSImage = NSImage.init(contentsOfFile: self.currentImagePath) {
                                    imageAttachment.image = image
                                } else if let image: NSImage = NSImage.init(named: NSImage.Name(stringLiteral: "base")) {
                                    imageAttachment.image = image
                                }
                                let imageAttString = NSAttributedString(attachment: imageAttachment)
                                return imageAttString
                            default:
                                break
                         }
                    } else {
                        // ERROR!!!!!
                    }
                } else {
                    // Apply the style to all the characters
                    if let tagStyle = self.styles[style.name] {
                        for (attributeName, attributeValue) in tagStyle {
                            attributes.updateValue(attributeValue,
                                                   forKey: attributeName)
                        }
                    }
                    
                    // Retain this style for the next iteration
                    parentStyle = style
                }
            }
            
            returnString = NSMutableAttributedString(string: plain, attributes: attributes)
        } else {
            // No style list provided? Just return the plain string
            returnString = NSMutableAttributedString(string: plain, attributes: self.styles["p"])
        }

        return returnString! as NSAttributedString
    }
    
    
    internal func generateStyles() {
        
        // Prepare the fonts we'll uses
        prepFonts()
        
        // Set the paragraph styles
        // Base paragraph style: No left inset
        self.tabbedParaStyle = NSMutableParagraphStyle()
        self.tabbedParaStyle.lineSpacing = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        self.tabbedParaStyle.paragraphSpacing = (self.paraSpacing >= 0.0 ? self.paraSpacing : self.lineSpacing)
        self.tabbedParaStyle.alignment = .left
        self.tabbedParaStyle.tabStops = [NSTextTab(textAlignment: .left, location: 30.0, options: [:]),
                                         NSTextTab(textAlignment: .left, location: 60.0, options: [:])]
        self.tabbedParaStyle.defaultTabInterval = 30.0
        
        // Inset paragraph style for PRE and BLOCKQUOTE
        self.insetParaStyle = NSMutableParagraphStyle()
        self.insetParaStyle.lineSpacing = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        self.insetParaStyle.paragraphSpacing = (self.paraSpacing >= 0.0 ? self.paraSpacing : self.lineSpacing)
        self.insetParaStyle.alignment = .left
        self.insetParaStyle.headIndent = 40.0
        self.insetParaStyle.firstLineHeadIndent = 40.0
        self.insetParaStyle.defaultTabInterval = 40.0
        self.insetParaStyle.tabStops = []
        
        //  HR paragraph
        self.lineParaStyle = NSMutableParagraphStyle()
        self.lineParaStyle.alignment = .left
        self.lineParaStyle.tabStops = [NSTextTab(textAlignment: .right, location: 120.0, options: [:])]
        self.lineParaStyle.lineSpacing = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        self.lineParaStyle.paragraphSpacing = (self.paraSpacing >= 0.0 ? self.paraSpacing : self.lineSpacing)
        
        // Set the colours
        self.headColourValue = colourFromHexString(self.headColour)
        self.bodyColourValue = colourFromHexString(self.bodyColour)
        self.codeColourValue = colourFromHexString(self.codeColour)
        self.linkColourValue = colourFromHexString(self.linkColour)
        
        // Paragraph styles
        // H1
        self.styles["h1"] = [.foregroundColor: self.headColourValue,
                             .font: makeFont("strong", self.fontSize * H1_MULTIPLIER)!,
                             .paragraphStyle: self.tabbedParaStyle]
        
        // H2
        self.styles["h2"] = [.foregroundColor: self.headColourValue,
                             .font: makeFont("strong", self.fontSize * H2_MULTIPLIER)!,
                             .paragraphStyle: self.tabbedParaStyle]
        
        // H3
        self.styles["h3"] = [.foregroundColor: self.headColourValue,
                             .font: makeFont("strong", self.fontSize * H3_MULTIPLIER)!,
                             .paragraphStyle: self.tabbedParaStyle]
        
        // H4
        self.styles["h4"] = [.foregroundColor: self.headColourValue,
                             .font: makeFont("strong", self.fontSize * H4_MULTIPLIER)!,
                             .paragraphStyle: self.tabbedParaStyle]
        
        // H5
        self.styles["h5"] = [.foregroundColor: self.headColourValue,
                             .font: makeFont("strong", self.fontSize * H5_MULTIPLIER)!,
                             .paragraphStyle: self.tabbedParaStyle]
        
        // H6
        self.styles["h6"] = [.foregroundColor: self.headColourValue,
                             .font: makeFont("plain", self.fontSize *  H6_MULTIPLIER)!,
                             .paragraphStyle: self.tabbedParaStyle]
        
        // P
        self.styles["p"] = [.foregroundColor: self.bodyColourValue,
                            .font: makeFont("plain", self.fontSize)!,
                            .paragraphStyle: self.tabbedParaStyle]
        
        // Character styles
        // A
        self.styles["a"] = [.foregroundColor: self.linkColourValue,
                            .underlineStyle: NSUnderlineStyle.single.rawValue as NSNumber,
                            .underlineColor: self.linkColourValue]
        
        // EM
        self.styles["em"] = [.foregroundColor: self.bodyColourValue,
                            .font: makeFont("em", self.fontSize)!]
        
        // STRONG
        self.styles["strong"] = [.foregroundColor: self.bodyColourValue,
                                 .font: makeFont("strong", self.fontSize)!]
        
        // CODE
        self.styles["code"] = [.foregroundColor: self.codeColourValue,
                               .font: makeFont("code", self.fontSize)!]
        
        // S
        self.styles["s"] = [.strikethroughStyle: NSUnderlineStyle.single.rawValue as NSNumber,
                            .strikethroughColor: self.bodyColourValue]
        
        // Block styles
        // PRE
        self.styles["pre"] = [.foregroundColor: self.codeColourValue,
                              .font: makeFont("code", self.fontSize)!,
                              .paragraphStyle: self.insetParaStyle]
        
        // LI
        self.styles["li"] = [.foregroundColor: self.bodyColourValue,
                             .font: makeFont("plain", self.fontSize)!]
        
        // BLOCKQUOTE
        self.styles["blockquote"] = [.foregroundColor: self.codeColourValue,
                                     .font: makeFont("plain", self.fontSize * H4_MULTIPLIER)!]
        
        // IMG
        self.styles["img"] = [.foregroundColor: self.bodyColourValue,
                              .font: makeFont("plain", self.fontSize)!]
    }


    /**
        Determine what styles are available for the chosen body font,
        set by the calling code (as is the base font size)
     */
    internal func prepFonts() {
        
        if let bodyFont: NSFont = NSFont.init(name: self.bodyFontName, size: self.fontSize) {
            self.bodyFontFamily.displayName = bodyFont.familyName ?? self.bodyFontName
            let fm: NSFontManager = NSFontManager.shared
            if let available = fm.availableMembers(ofFontFamily: self.bodyFontFamily.displayName) {
                for avail in available {
                    var fontStyle: PMFont = PMFont()
                    fontStyle.postScriptName = avail[0] as! String
                    fontStyle.styleName = avail[1] as! String
                    self.bodyFontFamily.styles?.append(fontStyle)
                }
            }
        }
        
    }
    
    
    /**
        Generate a specific font to match the specified trait and size.
     
        - Parameters
            - fontStyle - The style, eg. `strong`.
            - size      - The point size.
     
        - Returns The NSFont or nil on error.
     */
    internal func makeFont(_ fontStyle: String, _ size: CGFloat) -> NSFont? {
        
        switch fontStyle {
            case "strong":
                if let styles: [PMFont] = self.bodyFontFamily.styles {
                    for style: PMFont in styles {
                        for styleName: String in ["Bold", "Black", "Heavy", "Medium"] {
                            if styleName == style.styleName {
                                if let font: NSFont = NSFont.init(name: style.postScriptName, size: size) {
                                    return font
                                }
                            }
                        }
                    }
                }
                
                let fm: NSFontManager = NSFontManager.shared
                if let font: NSFont = fm.font(withFamily: self.bodyFontFamily.displayName,
                                              traits: .boldFontMask,
                                              weight: 10,
                                              size: size) {
                    return font
                }
                
                // Still no font? Fall back to the base body font
                
            case "em":
                // Try to get an actual italic font
                if let styles: [PMFont] = self.bodyFontFamily.styles {
                    for style: PMFont in styles {
                        // Any other italic style names to consider?
                        for styleName: String in ["Italic", "Oblique"] {
                            if styleName == style.styleName {
                                if let font: NSFont = NSFont.init(name: style.postScriptName, size: size) {
                                    return font
                                }
                            }
                        }
                    }
                }
                
                let fm: NSFontManager = NSFontManager.shared
                if let font: NSFont = fm.font(withFamily: self.bodyFontFamily.displayName,
                                              traits: .italicFontMask,
                                              weight: 5,
                                              size: size) {
                    return font
                }

                // Still no font? Fall back to the base body font

            case "code":
                if let font: NSFont = NSFont(name: self.codeFontName, size: size) {
                    return font
                }
                
                return NSFont.monospacedSystemFont(ofSize: size, weight: NSFont.Weight(5.0))
                
            default:
                break
        }

        // Just use some generic fonts as a fallback
        if let font: NSFont = NSFont.init(name: self.bodyFontName, size: size) {
            return font
        }
        
        return NSFont.systemFont(ofSize: size)
    }
    
    
    internal func colourFromHexString(_ colourValue: String) -> NSColor {
        
        var colourString: String = colourValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if (colourString.hasPrefix("#")) {
            // The colour is defined by a hex value
            colourString = (colourString as NSString).substring(from: 1)
        }
        
        // Colours in hex strings have 3, 6 or 8 (6 + alpha) values
        if colourString.count != 8 && colourString.count != 6 && colourString.count != 3 {
            return NSColor.gray
        }

        var r: UInt64 = 0, g: UInt64 = 0, b: UInt64 = 0, a: UInt64 = 0
        var divisor: CGFloat
        var alpha: CGFloat = 1.0

        if colourString.count == 6 || colourString.count == 8 {
            // Decode a six-character hex string
            let rString: String = (colourString as NSString).substring(to: 2)
            let gString: String = ((colourString as NSString).substring(from: 2) as NSString).substring(to: 2)
            let bString: String = ((colourString as NSString).substring(from: 4) as NSString).substring(to: 2)

            Scanner(string: rString).scanHexInt64(&r)
            Scanner(string: gString).scanHexInt64(&g)
            Scanner(string: bString).scanHexInt64(&b)

            divisor = 255.0
            
            if colourString.count == 8 {
                // Decode the eight-character hex string's alpha value
                let aString: String = ((colourString as NSString).substring(from: 6) as NSString).substring(to: 2)
                Scanner(string: aString).scanHexInt64(&a)
                alpha = CGFloat(a) / divisor
            }
        } else {
            // Decode a three-character hex string
            let rString: String = (colourString as NSString).substring(to: 1)
            let gString: String = ((colourString as NSString).substring(from: 1) as NSString).substring(to: 1)
            let bString: String = ((colourString as NSString).substring(from: 2) as NSString).substring(to: 1)

            Scanner(string: rString).scanHexInt64(&r)
            Scanner(string: gString).scanHexInt64(&g)
            Scanner(string: bString).scanHexInt64(&b)
            divisor = 15.0
        }

        return NSColor(red: CGFloat(r) / divisor, green: CGFloat(g) / divisor, blue: CGFloat(b) / divisor, alpha: alpha)
    }
    
    
    internal func setSize(_ tagName: String) -> CGFloat {
        
        switch tagName {
            case "h1":
                return self.fontSize * H1_MULTIPLIER
            case "h2":
                return self.fontSize * H2_MULTIPLIER
            case "h3":
                return self.fontSize * H3_MULTIPLIER
            case "h4":
                fallthrough
            case "blockquote":
                return self.fontSize * H4_MULTIPLIER
            case "h5":
                return self.fontSize * H5_MULTIPLIER
            case "h6":
                return self.fontSize * H6_MULTIPLIER
            default:
                return self.fontSize
        }
    }


    private func processCheckboxes(_ base: String) -> String {

        // Hack to present checkboxes a la GitHub
        let patterns: [String] = [#"\[\s?\](?!\()"#, #"\[[xX]{1}\](?!\()"#]
        let symbols: [String] = ["❎", "✅"]

        var i = 0
        var result = base
        for pattern in patterns {
            var range = result.range(of: pattern, options: .regularExpression)

            while range != nil {
                // Swap out the HTML symbol code for the actual symbol
                result = result.replacingCharacters(in: range!, with: symbols[i])

                // Get the next occurence of the pattern ready for the 'while...' check
                range = result.range(of: pattern, options: .regularExpression)
            }

            i += 1
        }

        return result
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
