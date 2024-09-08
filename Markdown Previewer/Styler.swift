/*
 *  Styler.swift
 *  Convert a tokenised string into an NSAttributedString.
 *
 *  Created by Tony Smith on 23/09/2020.
 *  Copyright © 2024 Tony Smith. All rights reserved.
 */


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
    
    var lineSpacing: CGFloat                        = 14.0
    var paraSpacing: CGFloat                        = 18.0
    var fontSize: CGFloat                           = 24.0
    var initialViewWidth: CGFloat                   = 1024.0
    
    var headColour: String                          = "#FFFFFF"
    var codeColour: String                          = "#00FF00"
    var linkColour: String                          = "#64ACDD"
    var quoteColour: String                         = "#FFFFFF"
    var bodyColourValue: NSColor                    = NSColor.labelColor
    
    var bodyFontName: String                        = "SF Pro"
    var codeFontName: String                        = "Menlo"
    
    
    // MARK: - Private properties with defaults
    
    private var useLightMode: Bool                  = true
    private var isThumbnail: Bool                   = false
    private var tokenString: String                 = ""
    private var currentLink: String                 = ""
    private var currentImagePath: String            = ""
    private var currentLanguage: String             = ""
    private let htmlTagStart: String                = "<"
    private let htmlTagEnd: String                  = ">"
    #if DEBUG
    private let lineBreakSymbol: String             = "†\u{2028}"
    #else
    private let lineBreakSymbol: String             = "\u{2028}"
    #endif
    private let newLineSymbol: String               = "\n"
    private let windowsLineSymbol: String           = "\n\r"
    private let appliedTags: [String]               = ["p", "a", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "code", "kbd", "em", "strong", "blockquote", "s", "img", "li", "sub", "sup"]
    private let bullets: [String]                   = ["\u{25CF}", "\u{25CB}", "\u{25CF}", "\u{25CB}", "\u{25CF}", "\u{25CB}"]
    private let htmlEscape: NSRegularExpression     = try! NSRegularExpression(pattern: "&#?[a-zA-Z0-9]+?;", options: .caseInsensitive)
    
    private var styles: [String: [NSAttributedString.Key: AnyObject]] = [:]
    private var bodyFontFamily: PMFont              = PMFont()
    
    // MARK: - Private properties without defaults
    
    private var fonts: FontStore!
    
    // Style definition objects, globalised for re-use across styles
    private var headColourValue: NSColor!
    private var codeColourValue: NSColor!
    private var linkColourValue: NSColor!
    private var quoteColourValue: NSColor!
    
    private var tabbedParaStyle: NSMutableParagraphStyle!
    private var insetParaStyle:  NSMutableParagraphStyle!
    private var lineParaStyle:   NSMutableParagraphStyle!
    private var listParaStyle:   NSMutableParagraphStyle!
    
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
    init(_ htmlString: String, _ useLight: Bool = true) {
        
        self.tokenString = htmlString
        self.useLightMode = useLight
    }
    
    
    /**
        Set the class' `tokenString` property.
     
        - Parameters
            - isThumbnail - Are we rendering text for thumbnail use? Default : `false`.
        
        - Returns NSAttributedString or nil or error.
     */
    func setTokenString(_ tokenisedString: String) {
        
        self.tokenString = tokenisedString
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
        
        self.isThumbnail = isThumbnail
        if isThumbnail {
            self.useLightMode = true
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
        var isListItem: Bool = false
        var isNested: Bool = false
        var isBlock: Bool = false
        var isPre: Bool = false
        
        var tableString: String = ""
        
        var blockLevel: Int = 0
        var insetLevel: Int = 0
        var orderedListCounts: [Int] = Array.init(repeating: 0, count: 12)
        var listTypes: [ListType] = Array.init(repeating: .bullet, count: 12)
        
        var lastStyle: Style? = nil
        var previousTag: String = ""
        
        // Font-less horizontal rule
        let hr: NSAttributedString = NSAttributedString(string: "\u{00A0} \u{0009} \u{00A0}\n",
                                                        attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                                                                     .strikethroughColor: self.bodyColourValue,
                                                                     .paragraphStyle: self.lineParaStyle!])

        // Perform pre-processing:
        // 1. Convert checkboxes, eg `[] checkbox`, `[x] checkbox`
        self.tokenString = processCheckboxes(self.tokenString)
        
        // 2. Convert Windows LFCR line endings
        self.tokenString = self.tokenString.replacingOccurrences(of: self.windowsLineSymbol, with: self.newLineSymbol)

        // Render the HTML
        var scannedString: String? = nil
        let scanner: Scanner = Scanner(string: self.tokenString)
        scanner.charactersToBeSkipped = nil

        //let renderedString: NSMutableAttributedString = NSMutableAttributedString(string: self.tokenString, attributes: self.styles["p"])
        let renderedString: NSMutableAttributedString = NSMutableAttributedString(string: "", attributes: self.styles["p"])
        
        // Need a base style to avoid over-emptying the property stack later
        // NOTE Adds an extra [p] we may not need -- check
        //let baseStyle: Style = Style()
        var styleStack: [Style] = []
        
        // Iterate over the stored HTML string
        while !scanner.isAtEnd {
            // Flag to mark that the end of the string has been reached
            var ended: Bool = false

            // Scan up to the next token delimiter
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
                // Flag for nested paragraphs LI detection
                var itemListNestFound: Bool = false
                var listPrefix: String = ""
                
                // Should we add a bullet or numeral from an LI tag?
                if isListItem {
                    if scannedString!.hasPrefix("\n") {
                        // markdownIt has chosen to set the LI content as a
                        // interior P blocks. Ignore the CR in the content string,
                        // and set a flag to record we're in nested mode.
                        scannedString = ""
                        itemListNestFound = true
                    } else {
                        isListItem = false
                        if listTypes[insetLevel] == .bullet {
                            // Add a standard bullet. We set six types and we cycle around
                            // when the indent level is greater than that that number.
                            var index: Int = insetLevel
                            while index > self.bullets.count {
                                index -= self.bullets.count
                            }
                            
                            listPrefix = "\(self.bullets[index - 1]) "
                        } else {
                            // Add a numeral. The value was calculated when we encountered the initial LI
                            listPrefix = "\(orderedListCounts[insetLevel]). "
                        }
                        
                        // Set the paragraph style with the current indent
                        self.styles["li"]![.paragraphStyle] = getInsetParagraphStyle(insetLevel)
                    }
                }
                
                // Pre-formatted lines should be presented as a single paragraph with inner line breaks,
                // so convert the content block's paragraph breaks (\n) to NSAttributedString-friendly
                // line-break codes.
                if isPre {
                    scannedString = scannedString!.trimmingCharacters(in: .newlines)
                    scannedString = scannedString!.replacingOccurrences(of: "\n", with: self.lineBreakSymbol)
                    renderedString.append(makeCodeBlockParagraph(scannedString!))
                    scannedString = ""
                }
                
                // Blockquotes should be styled with the current indent
                if isBlock {
                    //self.styles["blockquote"]![.paragraphStyle] = getInsetParagraphStyle(blockLevel)
                    renderedString.append(makeBlockParagraph(blockLevel, scannedString!))
                    scannedString = ""
                }
                
                // Nested paragraphs (P tags under LIs) need special handling. The first paragraph (ie.
                // the one with the list prefix) is run on from the prefix; following paragraphs are
                // inset to the same level.
                // NOTE This is why we don't set `isNested` when we discover nesting above
                if isNested {
                    self.styles["li"]![.paragraphStyle] = getInsetParagraphStyle(insetLevel, 16.0, listPrefix.isEmpty ? 16.0 : 0.0)
                }
                
                // Style the content if we have some...
                if !scannedString!.isEmpty {
                    var partialRenderedString: NSMutableAttributedString
                    if (listPrefix.count > 0) {
                        // Style the list prefix and then the content
                        partialRenderedString = NSMutableAttributedString.init(attributedString: styleString(listPrefix, styleStack))
                        partialRenderedString.append(styleString(scannedString!, styleStack))
                    } else {
                        // Style the content
                        if scannedString!.hasPrefix("\n") && lastStyle != nil {
                            // Match the CR after a P, H or LI to that item's style
                            partialRenderedString = NSMutableAttributedString.init(attributedString: styleString("¶" + scannedString!, [lastStyle!]))
                        } else {
                            // All other text
                            partialRenderedString = NSMutableAttributedString.init(attributedString: styleString(scannedString!, styleStack))
                        }
                    }
                    
                    // ...and add it to the store
                    renderedString.append(partialRenderedString)
                }
                
                // We've detected a nest structure (see above)
                if itemListNestFound {
                    isNested = true
                }
                
                // Break out of the upper scanner loop if we're done
                if ended {
                    continue
                }
            }
            
            // Reached a token delimiter: step over it
            scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)

            // Get the first character of the tag
            //let string: NSString = scanner.string as NSString
            //let idx: Int = scanner.currentIndex.utf16Offset(in: self.tokenString)
            let nextChar: String = scanner.getNextCharacter(in: self.tokenString)
            
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
                    var doSkipNewLine: Bool = false
                    
                    // Should be convert the end-of-line LF to LB?
                    var doReplaceNewLine: Bool = false
                    
                    // Process the closing token by type
                    switch(closeTag) {
                        case "p":
                            if isBlock {
                                doSkipNewLine = true
                            }
                        // Ordered or unordered lists
                        case "ul":
                            fallthrough
                        case "ol":
                            // Reset the current level's inset count
                            orderedListCounts[insetLevel] = 0
                            
                            // Reduce the inset level
                            insetLevel -= 1
                            if insetLevel <= 0 {
                                insetLevel = 0
                                self.styles["li"]![.paragraphStyle] = self.listParaStyle
                            }

                            // Remove the tag's LF
                            doSkipNewLine = true
                        // List items
                        case "li":
                            // TO-DO See what happens with inner nests
                            if isNested {
                               isNested = false
                            }
                            
                            // Zap CRs on nested solitary /LI tags
                            if previousTag != "li" {
                                doSkipNewLine = true
                            }
                        // Blocks
                        case "blockquote":
                            doSkipNewLine = true
                            blockLevel -= 1
                            if blockLevel < 0 {
                                blockLevel = 0
                            }
                            
                            if blockLevel == 0 {
                                isBlock = false
                                doSkipNewLine = false
                                //self.styles["blockquote"]![.paragraphStyle] = self.blockParaStyle
                            }
                        case "pre":
                            // TO-DO Is this needed?
                            isPre = false
                        case "table":
                            // Run through the generated table's cells to update the font and colours
                            if let data: Data = tableString.data(using: .utf16) {
                                if let tableAttStr: NSMutableAttributedString = NSMutableAttributedString.init(html: data, documentAttributes: nil) {
                                    tableAttStr.beginEditing()
                                    
                                    // Set the font for each element within the table
                                    tableAttStr.enumerateAttribute(.font, in: NSMakeRange(0, tableAttStr.length)) { (value: Any?, range: NSRange, got: UnsafeMutablePointer<ObjCBool>) in
                                        if value != nil {
                                            let font: NSFont = value as! NSFont
                                            var cellFont: NSFont = self.makeFont("plain", self.fontSize)!
                                            
                                            if let fontName: String = font.displayName {
                                                if fontName.contains("Bold") {
                                                    cellFont = self.makeFont("strong", self.fontSize)!
                                                } else if fontName.contains("Italic") {
                                                    cellFont = self.makeFont("em", self.fontSize)!
                                                }
                                            }
                                            
                                            // Style the cell's font and colour
                                            tableAttStr.addAttribute(.font, value: cellFont, range: range)
                                            tableAttStr.addAttribute(.foregroundColor, value: self.bodyColourValue, range: range)
                                        }
                                    }
                                    
                                    tableAttStr.endEditing()
                                    renderedString.append(tableAttStr)
                                }
                            }
                        default:
                            break
                    }

                    // Step over the token delimiter
                    scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
                    
                    if doSkipNewLine || doReplaceNewLine {
                        // Remove the tailing LF
                        scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
                    }
                    
                    // If required, replace the LF at the end of the line with an LB.
                    // This will be for simple list items.
                    /*
                    if doReplaceNewLine {
                        renderedString.append(NSAttributedString.init(string: self.lineBreakSymbol))
                    }
                    */
                    
                    // Pop the last style
                    if styleStack.count > 0 {
                        // Get the style at the top of the stack...
                        lastStyle = styleStack[styleStack.count - 1]
                        
                        // ...unless it's one we don't need
                        if lastStyle!.type != .paragraph && lastStyle!.type != .indent {
                            lastStyle = nil
                        }
                        
                        // Remove the style at the top of the stack
                        styleStack.removeLast()
                    }
                    
                    // Record the tag we've just processed, provided it's not
                    // related to a character style
                    if !["strong", "b", "em", "i", "a", "s", "img", "code", "kbd"].contains(closeTag) {
                        previousTag = closeTag
                    }
                }
            } else {
                // MARK: Opening Token
                // We've got a new token, so get it up to the delimiter
                if let openTag: String = scanner.scanUpToString(self.htmlTagEnd) {
                    // NOTE mdit generates lowercase HTML tags, but we should probably not assume that
                    let startTag: String = openTag.lowercased()
                    
                    // This is the tag we will use to format the content. It may not
                    // be the actual tag detected, eg. for LI-nested Ps we use LI
                    var tagToApply: String = startTag
                    
                    // Should we remove the new line symbol from the end of the line?
                    // This is required when single tokens appear on a per-line basis, eg UL, OL, BLOCKQUOTE
                    var doSkipNewLine: Bool = false
                    
                    // Should be convert the end-of-line LF to LB?
                    var doReplaceNewLine: Bool = false
                    
                    // Handle A and IMG tags outside of the switch statement because
                    // they're not straightforward comparisons: the tags contain extra data
                    if startTag.hasPrefix("a") {
                        // We have a link -- get the destination from HREF
                        tagToApply = "a"
                        getLinkRef(startTag)
                    }
                    
                    if startTag.hasPrefix("img") {
                        // We have an IMG -- get the destination from SRC
                        // TO-DO Do we want to retain the ALT tag?
                        tagToApply = "img"
                        getImageRef(startTag)
                    }
                    
                    if startTag.contains("code class") {
                        tagToApply = "none"
                        getCodeLanguage(startTag)
                        // TO-DO Use code highlighting
                    }
                    
                    // TO-DO Support tables here
                    if startTag.contains("table") {
                        scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
                        tagToApply = "none"
                        
                        // Get the table content and then style here
                        tableString = "<table width=\"1024px\" style=\"border: 2px solid #\(self.headColour);border-collapse: collapse;\">"
                        if let ts = scanner.scanUpToString("</table>\n") {
                            tableString += ts + "</table>\n"
                        }
                        
                        tableString = tableString.replacingOccurrences(of: "<th style=\"", with: "<th style=\"border: 2px solid #\(self.headColour);padding: 12px;")
                        tableString = tableString.replacingOccurrences(of: "<th>", with: "<th style=\"border: 2px solid #\(self.headColour);padding: 12px;\">")

                        tableString = tableString.replacingOccurrences(of: "<td style=\"", with: "<td style=\"border: 2px solid #\(self.headColour);padding: 12px;")
                        tableString = tableString.replacingOccurrences(of: "<td>", with: "<td style=\"border: 2px solid #\(self.headColour);padding: 12px;\">")
                        
                        scanner.currentIndex = scanner.string.index(before: scanner.currentIndex)
                    }
                
                    // Process the new token by type
                    switch(startTag) {
                            // Paragraph-level tags with context-sensitivity
                        case "p":
                            if isBlock {
                                // Inside a block, so apply the correct style
                                tagToApply = "blockquote"
                            } else if isNested {
                                tagToApply = "li"
                            }
                            // Ordered or unordered lists and items
                        case "ul":
                            fallthrough
                        case "ol":
                            // Set the list type and increment the current indent
                            let listItem: ListType = startTag == "ul" ? .bullet : .number
                            insetLevel += 1
                            if insetLevel == listTypes.count {
                                listTypes.append(listItem)
                                orderedListCounts.append(0)
                            } else {
                                listTypes[insetLevel] = listItem
                                orderedListCounts[insetLevel] = 0
                            }
                            
                            // Remove the tailing LF unless the previous block was a list too
                            if previousTag != "ul" && previousTag != "ol" {
                                doSkipNewLine = true
                            }
                        case "li":
                            // NOTE mdit has two LI modes: simple and nested.
                            //      Simple (short) text is placed immediately after the tag;
                            //      Long or multi-para text is place in paragraphs between
                            //      the LI tags
                            
                            // Mark that we need the subsequent content prefixed with a
                            // bullet or a numeral
                            isListItem = true
                            
                            // Increment the numeric list item, if we're in an OL
                            if listTypes[insetLevel] == .number {
                                orderedListCounts[insetLevel] += 1
                            }
                            // Blocks
                        case "blockquote":
                            isBlock = true
                            blockLevel += 1
                            doSkipNewLine = true
                            
                            // Rely on the inner P for styling
                            tagToApply = "none"
                        case "pre":
                            // ASSUMPTION PRE is ALWAYS followed by CODE (not in HTML, but in MD->HTML)
                            isPre = true
                            // Tokens that can be handled immediately
                        case "hr":
                            renderedString.append(hr)
                            doSkipNewLine = true
                        case "br":
                            fallthrough
                        case "br /":
                            // Doesn't change the current style, just the line ending
                            doReplaceNewLine = true
                            // Character-level tokens
                        case "i":
                            tagToApply = "em"
                        case "b":
                            tagToApply = "strong"
                        case "code":
                            // If CODE is in a PRE, we rely on the PRE for styling,
                            // otherwise we use CODE as a character style
                            if isPre {
                                tagToApply = "none"
                            }
                        default:
                            // Covers all other tags, including headers: do nothing
                            break
                    }
                    
                    // Compare the tag to use with those we apply.
                    // Some, such as list markers, we do not style here
                    if self.appliedTags.contains(tagToApply) {
#if DEBUG
                        NSLog("[TAG] -> \(startTag) as \(tagToApply)")
#endif
                        // Push the tag's style to the stack
                        let tagStyle: Style = Style()
                        tagStyle.name = tagToApply
                        
                        // Set character styles (inherit style from parent)
                        if ["strong", "em", "a", "s", "img", "sub", "sup", "code", "kbd"].contains(tagToApply) {
                            tagStyle.type = .character
                        }
                        
                        // Set other styles -- default is `.paragraph`
                        if tagToApply == "li" {
                            tagStyle.type = .indent
                        }
                        
                        // Record the tag for later use
                        if tagStyle.type == .paragraph || tagStyle.type == .indent {
                            previousTag = tagToApply
                        }
                        
                        // Push the new style onto the stack
                        styleStack.append(tagStyle)
                    }
                    
                    // Step over the token's delimiter
                    scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
                    
                    if tagToApply == "br" && scanner.getNextCharacter(in: self.tokenString) != "\n" {
                        doReplaceNewLine = false
                        renderedString.append(NSAttributedString.init(string: self.lineBreakSymbol))
                    }
                    
                    // If required, remove the LF at the end of the line (ie. right after the tag)
                    // This will be for OL, UL, BLOCKQUOTE, PRE+CODE, HR, BR, LI+P
                    if doSkipNewLine || doReplaceNewLine {
                        scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
                    }
                    
                    // If required, replace the LF at the end of the line with an LB.
                    // This will be for BR
                    if doReplaceNewLine{
                        renderedString.append(NSAttributedString.init(string: self.lineBreakSymbol))
                    }
                    
                    // Images have no content between tags, so handle the styling here
                    // NOTE Image is inserted by `styleString()`.
                    if tagToApply == "img" {
                        let partialRenderedString: NSMutableAttributedString = NSMutableAttributedString.init(attributedString: styleString("", styleStack))
                        renderedString.append(partialRenderedString)
                        styleStack.removeLast()
                    }
                }
            }
            
            scannedString = nil
        }

        // We have composed the string. Now process HTML escapes...
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
        
        // ...and hand back the rendered text
        return renderedString
    }
    
    
    /**
        Get a URL or path embedded in an A HREF tag.
     
        - Parameters
            - tag - The full token.
     */
    internal func getLinkRef(_ tag: String) {
        
        self.currentLink = splitTag(tag)
    }
    
    
    /**
        Get a URL or path embedded in an IMG SRC tag.
     
        - Parameters
            - tag - The full token.
     */
    internal func getImageRef(_ tag: String) {
        
        self.currentImagePath = splitTag(tag)
    }
    
    
    /**
        Get the software languges in an CODE CLASS tag.
     
        - Parameters
            - tag - The full token.
     */
    internal func getCodeLanguage(_ tag: String) {
        
        let parts: [String] = splitTag(tag).components(separatedBy: "-")
        if parts.count > 0 {
            self.currentLanguage = parts[1]
        } else {
            self.currentLanguage = parts[0]
        }
    }
    
    
    /**
        Split a string on a double quote marks.
     
        - Parameters
            - tag       - The full token.
            - partIndex - The index of the element we want returned.
    
        - Returns The requested string.
     */
    internal func splitTag(_ tag: String, _ partIndex: Int = 1) -> String {
        
        let parts: [String] = tag.components(separatedBy: "\"")
        if parts.count > partIndex {
            return parts[partIndex]
        }
        
        return ""
    }
    
    
    /**
        Prepare and return a paragraph inset to the requested depth.
     
        - Parameters
            - inset      - The indentation factor. This is multiplied by 40 points.
            - headInset  - Any offset to apply to the whole para other than line 1. Default: 0.0..
            - firstInset - Any offset to apply to the first line. Default: 0.0, ie. matches the para as whole.
     */
    internal func getInsetParagraphStyle(_ inset: Int, _ headInset: CGFloat = 0.0, _ firstInset: CGFloat = 0.0) -> NSMutableParagraphStyle {
        
        let insetParaStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
        insetParaStyle.lineSpacing = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        insetParaStyle.paragraphSpacing = (self.paraSpacing >= 0.0 ? self.paraSpacing : 0.0)
        insetParaStyle.alignment = .left
        insetParaStyle.headIndent = 40.0 * CGFloat(inset) + headInset
        insetParaStyle.firstLineHeadIndent = 40.0 * CGFloat(inset) + firstInset
        
        
        let table: NSTextTable = NSTextTable.init()
        table.numberOfColumns = 1
        let block: NSTextTableBlock = NSTextTableBlock.init(table: table, startingRow: 0, rowSpan: 1, startingColumn: 0, columnSpan: 1)
        block.setValue(512.0, type: .absoluteValueType, for: .minimumWidth)
        block.setBorderColor(self.headColourValue, for: .minX)
        insetParaStyle.textBlocks.append(block)
        return insetParaStyle
    }
    
    
    internal func makeBlockParagraph(_ inset: Int, _ cellString: String) -> NSAttributedString {
        
        /*
         To implement a text table programmatically, use the following sequence of steps:
         1 Create an attributed string for the table.
         2 Create the table object, setting the number of columns.
         3 Create the text table block for the first cell of the row, referring to the table object.
         4 Set the attributes for the text block.
         5 Create a paragraph style object for the cell, setting the text block as an attribute (along with any other paragraph attributes, such as alignment).
         6 Create an attributed string for the cell, adding the paragraph style as an attribute. The cell string must end with a paragraph marker, such as a newline character.
         7 Append the cell string to the table string.
         Repeat steps 3–7 for each cell in the table.
         */
        
        let table = NSTextTable.init()
        table.numberOfColumns = 1
        
        let cellBlockColour: NSColor = self.useLightMode ? NSColor.init(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.1) : NSColor.init(white: 1.0, alpha: 0.05)
        let cellblock = NSTextTableBlock(table: table, startingRow: 0, rowSpan: 1, startingColumn: 0, columnSpan: 1)
        cellblock.setWidth(8.0, type: NSTextBlock.ValueType.absoluteValueType, for: NSTextBlock.Layer.border)
        cellblock.setWidth(10.0, type: NSTextBlock.ValueType.absoluteValueType, for: NSTextBlock.Layer.padding)
        cellblock.setBorderColor(cellBlockColour)
        cellblock.setBorderColor(self.headColourValue, for: .minX)
        cellblock.backgroundColor = cellBlockColour
        
        let cellParagraphStyle = NSMutableParagraphStyle()
        cellParagraphStyle.alignment = .left
        cellParagraphStyle.lineSpacing = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        cellParagraphStyle.paragraphSpacing = (self.paraSpacing >= 0.0 ? self.paraSpacing : 0.0)
        cellParagraphStyle.headIndent = 10.0 + 50.0 * CGFloat(inset - 1)
        cellParagraphStyle.firstLineHeadIndent = 10.0 + 50.0 * CGFloat(inset - 1)
        cellParagraphStyle.textBlocks = [cellblock]
        
        return NSAttributedString(string: cellString + "\n",
                                  attributes: [.paragraphStyle: cellParagraphStyle,
                                               .foregroundColor: self.quoteColourValue!,
                                               .font: makeFont("strong", self.fontSize * H4_MULTIPLIER)!])
    }
    
    
    internal func makeCodeBlockParagraph(_ codeString: String) -> NSAttributedString {
        
        let table = NSTextTable.init()
        table.numberOfColumns = 1
        
        let cellBlockColour: NSColor = self.useLightMode ? NSColor.init(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.1) : NSColor.init(white: 1.0, alpha: 0.05)
        let cellblock = NSTextTableBlock(table: table, startingRow: 0, rowSpan: 1, startingColumn: 0, columnSpan: 1)
        cellblock.backgroundColor = cellBlockColour
        cellblock.setWidth(10.0, type: NSTextBlock.ValueType.absoluteValueType, for: NSTextBlock.Layer.padding)
        
        let cellParagraphStyle = NSMutableParagraphStyle()
        cellParagraphStyle.alignment = .left
        cellParagraphStyle.lineSpacing = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        cellParagraphStyle.paragraphSpacing = (self.paraSpacing >= 0.0 ? self.paraSpacing : 0.0)
        cellParagraphStyle.textBlocks = [cellblock]
        
        return NSAttributedString(string: codeString + "\n",
                                  attributes: [.paragraphStyle: cellParagraphStyle,
                                               .foregroundColor: self.codeColourValue!,
                                               .font: makeFont("code", self.fontSize)!])
    }

    
    /**
        Generate an attributed string from an individual source string.
     
        - Parameters
            - plain     - The raw string.
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
                var fontUsed: NSFont? = nil
                if let styles = self.styles[style.name] {
                    for (attributeName, attributeValue) in styles {
                        attributes.updateValue(attributeValue,
                                               forKey: attributeName)
                        if attributeName == .font {
                            fontUsed = attributeValue as? NSFont
                        }
                    }
                }
                
                // Does the style apply to character sequences within paras?
                if style.type == .character {
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
                                    lineColour = self.bodyColourValue
                                }
                                
                                attributes.updateValue(NSUnderlineStyle.single.rawValue as NSNumber, forKey: .underlineStyle)
                                attributes.updateValue(lineColour, forKey: .underlineColor)
                            }
                        case "strong":
                            // Check if the font used is italic. If not, flag we need to set the background color
                            if fontUsed == nil || (!fontUsed!.fontName.contains("Bold") && !fontUsed!.fontName.contains("Black") && !fontUsed!.fontName.contains("Heavy") && !fontUsed!.fontName.contains("Medium")) {
                                attributes.updateValue(self.bodyColourValue, forKey: .backgroundColor)
                                attributes.updateValue(self.useLightMode ? NSColor.white : NSColor.black, forKey: .foregroundColor)
                            }
                        case "img":
                            if !self.isThumbnail {
                                let imageAttachment = NSTextAttachment()
                                let baseImageName: String = self.useLightMode ? BUFFOON_CONSTANTS.IMG_PLACEHOLDER_LIGHT : BUFFOON_CONSTANTS.IMG_PLACEHOLDER_DARK
                                if let image: NSImage = NSImage.init(contentsOfFile: self.currentImagePath) {
                                    imageAttachment.image = image
                                } else if let image: NSImage = NSImage.init(named: NSImage.Name(stringLiteral: baseImageName)) {
                                    imageAttachment.image = image
                                }
                                
                                let imageAttString = NSAttributedString(attachment: imageAttachment)
                                return imageAttString
                            }
                        default:
                            break
                    }
                } else {
                    parentStyle = style
                }
            }
            
            returnString = NSMutableAttributedString(string: plain, attributes: attributes)
        } else {
            // No style list provided? Just return the plain string
            // TO-DO This will probably break
            returnString = NSMutableAttributedString(string: plain, attributes: self.styles["p"])
        }

        return returnString! as NSAttributedString
    }
    
    
    /**
        At the start of a rendering run, set up all the base styles we will need.
     */
    internal func generateStyles() {
        
        // Prepare the fonts we'll use
        prepFonts()
        
        // Set the paragraph styles
        // Base paragraph style: No left inset
        self.tabbedParaStyle = NSMutableParagraphStyle()
        self.tabbedParaStyle.lineSpacing        = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        self.tabbedParaStyle.paragraphSpacing   = (self.paraSpacing >= 0.0 ? self.paraSpacing : 0.0)
        self.tabbedParaStyle.alignment          = .left
        self.tabbedParaStyle.tabStops           = [NSTextTab(textAlignment: .left, location: 30.0, options: [:]),
                                                   NSTextTab(textAlignment: .left, location: 60.0, options: [:])]
        self.tabbedParaStyle.defaultTabInterval = 30.0
        
        // Inset paragraph style for PRE
        self.insetParaStyle = NSMutableParagraphStyle()
        self.insetParaStyle.lineSpacing         = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        self.insetParaStyle.paragraphSpacing    = (self.paraSpacing >= 0.0 ? self.paraSpacing : 0.0)
        self.insetParaStyle.alignment           = .left
        self.insetParaStyle.headIndent          = 40.0
        self.insetParaStyle.firstLineHeadIndent = 40.0
        self.insetParaStyle.defaultTabInterval  = 40.0
        self.insetParaStyle.tabStops            = []
        
        // Nested list
        self.listParaStyle = NSMutableParagraphStyle()
        self.listParaStyle.lineSpacing          = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        self.listParaStyle.paragraphSpacing     = (self.paraSpacing >= 0.0 ? self.paraSpacing : 0.0)
        self.listParaStyle.alignment            = .left
        self.listParaStyle.headIndent           = 56.0
        self.listParaStyle.firstLineHeadIndent  = 40.0
        
        //  HR paragraph
        self.lineParaStyle = NSMutableParagraphStyle()
        self.lineParaStyle.lineSpacing          = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        self.lineParaStyle.paragraphSpacing     = (self.paraSpacing >= 0.0 ? self.paraSpacing : 0.0)
        self.lineParaStyle.alignment            = .left
        self.lineParaStyle.tabStops             = [NSTextTab(textAlignment: .right, location: 120.0, options: [:])]
        
        // Set the colours
        self.headColourValue = colourFromHexString(self.headColour)
        self.codeColourValue = colourFromHexString(self.codeColour)
        self.linkColourValue = colourFromHexString(self.linkColour)
        self.quoteColourValue = colourFromHexString(self.quoteColour)
        
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
        
        
        self.styles["t"] = [.foregroundColor: self.bodyColourValue,
                            .font: makeFont("plain", self.fontSize)!]
        
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
        
        // KBD
        self.styles["kbd"] = [.foregroundColor: useLightMode ? NSColor.lightGray : NSColor.black,
                              .underlineColor: useLightMode ? NSColor.black : NSColor.white,
                              .underlineStyle: NSUnderlineStyle.double.rawValue as NSNumber,
                              .font: makeFont("code", self.fontSize)!]
        
        // S
        self.styles["s"] = [.strikethroughStyle: NSUnderlineStyle.single.rawValue as NSNumber,
                            .strikethroughColor: self.bodyColourValue]
        
        // Block styles
        // PRE
        self.styles["pre"] = [.foregroundColor: self.codeColourValue,
                              .font: makeFont("code", self.fontSize)!,
                              .paragraphStyle: self.tabbedParaStyle]
        
        // BLOCKQUOTE
        self.styles["blockquote"] = [.foregroundColor: self.bodyColourValue,
                                     .font: makeFont("plain", self.fontSize * H4_MULTIPLIER)!,
                                     .paragraphStyle: self.tabbedParaStyle]
        
        // LI
        self.styles["li"] = [.foregroundColor: self.bodyColourValue,
                             .font: makeFont("plain", self.fontSize)!,
                             .paragraphStyle: self.listParaStyle]
        
        // IMG
        self.styles["img"] = [.foregroundColor: self.bodyColourValue,
                              .font: makeFont("plain", self.fontSize)!]
        
        // SUB
        self.styles["sub"] = [.font: makeFont("plain", self.fontSize / 1.5)!,
                              .baselineOffset: -1.0 as NSNumber]
        
        self.styles["sup"] = [.font: makeFont("plain", self.fontSize / 1.5)!,
                              .baselineOffset: 10.0 as NSNumber]
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


extension Scanner {
    
    func getNextCharacter(in outer: String) -> String {
        
        let string: NSString = self.string as NSString
        let idx: Int = self.currentIndex.utf16Offset(in: outer)
        let nextChar: String = string.substring(with: NSMakeRange(idx, 1))
        return nextChar
    }
}
