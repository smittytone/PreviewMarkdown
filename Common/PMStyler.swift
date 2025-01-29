/*
 *  Styler.swift
 *  Convert a tokenised string into an NSAttributedString.
 *
 *  Created by Tony Smith on 23/09/2020.
 *  Copyright © 2025 Tony Smith. All rights reserved.
 */


import Foundation
import AppKit
import Highlighter


typealias StyleAttributes = [String: [NSAttributedString.Key: AnyObject]]


enum ListType {
    case bullet
    case number
}

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


struct FontRecord {
    var postScriptName: String = ""
    var style: String = "regular"
    var size: CGFloat = 12.0
    var font: NSFont? = nil
}


struct ColourValues {
    var head: String                  = "#FFFFFF"
    var code: String                  = "#00FF00"
    var link: String                  = "#64ACDD"
    var quote: String                 = "#FFFFFF"
}


struct Colours {
    var head: NSColor!
    var body: NSColor!
    var code: NSColor!
    var link: NSColor!
    var quote: NSColor!
}



class PMStyler {
    
    // MARK: - Publicly accessible properties
    
    var fontSize: CGFloat                                               = 24.0
    var lineSpacing: CGFloat                                            = BUFFOON_CONSTANTS.BASE_LINE_SPACING
    var paraSpacing: CGFloat                                            = 18.0
    var viewWidth: CGFloat                                              = 1024.0
    var bodyFontName: String                                            = "SF Pro"
    var codeFontName: String                                            = "Menlo"
    var bodyColour: NSColor                                             = .labelColor
    var presentForLightMode: Bool                                       = false
    var colourValues: ColourValues                                      = ColourValues()
    
    // MARK: - Private properties with defaults
    
    private var isThumbnail: Bool                                       = false
    internal var tokenString: String                                     = ""
    private var outputString: String                                    = ""
    private var currentLink: String                                     = ""
    private var currentImagePath: String                                = ""
    private var currentLanguage: String                                 = ""
    private var currentTable: String                                    = ""
    
    private var styles: [String: [NSAttributedString.Key: AnyObject]]   = [:]
    private var bodyFontFamily: PMFont                                  = PMFont()
    
    private var colours: Colours                                        = Colours()
    private var fonts: [FontRecord]                                     = []
    private var paragraphs: [String : NSMutableParagraphStyle]          = [:]
    
    private var highlighter: Highlighter?                               = nil
    
    // MARK: - Constants
    
    // Headline size vs body font size scaler values
    private let H1_MULTIPLIER: CGFloat                                  = 2.6
    private let H2_MULTIPLIER: CGFloat                                  = 2.2
    private let H3_MULTIPLIER: CGFloat                                  = 1.8
    private let H4_MULTIPLIER: CGFloat                                  = 1.4
    private let H5_MULTIPLIER: CGFloat                                  = 1.2
    private let H6_MULTIPLIER: CGFloat                                  = 1.2
    
    private let htmlTagStart: String                                    = "<"
    private let htmlTagEnd: String                                      = ">"
    
#if DEBUG
    private let lineBreakSymbol: String                                 = "†\u{2028}"
    private let lineFeedSymbol: String                                  = "¶\u{2029}"
#else
    private let lineBreakSymbol: String                                 = "\u{2028}"
    private let lineFeedSymbol: String                                  = "\u{2029}"
#endif
    private let newLineSymbol: String                                   = "\n"
    private let windowsLineSymbol: String                               = "\n\r"
    
    private let appliedTags: [String]                                   = ["p", "a", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "code", "kbd", "em",
                                                                           "strong", "blockquote", "s", "img", "li", "sub", "sup"]
    private let bullets: [String]                                       = ["\u{25CF}", "\u{25CB}", "\u{25CF}", "\u{25CB}", "\u{25CF}", "\u{25CB}"]
    private let htmlEscape: NSRegularExpression                         = try! NSRegularExpression(pattern: "&#?[a-zA-Z0-9]+?;", options: .caseInsensitive)
    
    private var blockAttStr: NSMutableAttributedString?                 = nil
    private var blockTable: NSTextTable?                                = nil

    // MARK: - Rendering Functions
    
    /**
        Render the class' `tokenString` property.
     
        - Parameters
            - tokenString:               The tokenised string we'll use to render an NSAttributedString.
            - isThumbnail:               Are we rendering text for thumbnail use? Default : `false`.
            - useLightColoursInDarkMode: Present previews in light colours, irrespective of mode. Default : `false`.
        
        - Returns NSAttributedString or `nil` or error.
     */
    func render(_ tokenString: String, _ isThumbnail: Bool = false, _ useLightColoursInDarkMode: Bool = false) -> NSAttributedString? {
        
        // Check we have an tokended string to render.
        if tokenString.isEmpty {
            return nil
        } else {
            self.tokenString = tokenString
        }
        
        // Always render for light mode when generating thumbnail, we;'re in dakr mode but want
        // to use light mode colours anyway, or we're actually in light mode
        self.isThumbnail = isThumbnail
        self.presentForLightMode = isThumbnail || useLightColoursInDarkMode
        self.bodyColour = self.isThumbnail ? NSColor.black : .labelColor
        
        // Generate the text styles we'll use
        generateStyles()
        
        // Render and return the tokened string
        return processTokenString()
    }
    
    
    /**
        Convert the class' `tokenString` property to an attributed string.
     
        - Returns NSAttributedString or `nil` on error.
     */
    private func processTokenString() -> NSAttributedString? {
        
        // Rendering control variables
        var isListItem: Bool                = false
        var isNested: Bool                  = false
        var isBlockquote: Bool              = false
        var isPre: Bool                     = false
        
        var blockLevel: Int                 = 0
        var insetLevel: Int                 = 0
        var orderedListCounts: [Int]        = Array.init(repeating: 0, count: 12)
        var listTypes: [ListType]           = Array.init(repeating: .bullet, count: 12)
        
        var currentParagraphStyle: Style?   = nil
        var previousToken: String           = ""
        
        // Font-less horizontal rule
        let hr: NSAttributedString          = NSAttributedString(string: "\u{00A0} \u{0009} \u{00A0}\n",
                                                                 attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                                                                              .strikethroughColor: self.colours.body!,
                                                                              .paragraphStyle: self.paragraphs["line"]!])

        // Perform pre-processing:
        // 1. Convert checkboxes, eg `[] checkbox`, `[x] checkbox`
        processCheckboxes()
        
        // 2. Convert Windows LFCR line endings
        self.tokenString = self.tokenString.replacingOccurrences(of: self.windowsLineSymbol, with: self.newLineSymbol)
        
        // Set up the Style stack
        var styleStack: [Style] = []
        styleStack.append(Style())
        
        // Render the HTML
        var scanned: String? = nil
        let scanner: Scanner = Scanner(string: self.tokenString)
        scanner.charactersToBeSkipped = nil
        
#if DEBUG2
        let renderedString: NSMutableAttributedString = NSMutableAttributedString(string: self.tokenString + "\n", attributes: self.styles["p"])
        renderedString.append(hr)
#else
        let renderedString: NSMutableAttributedString = NSMutableAttributedString(string: "", attributes: self.styles["p"])
#endif
        // Iterate over the stored tokenised string
        while !scanner.isAtEnd {
            // Scan up to the next token delimiter
            scanned = scanner.scanUpToString(self.htmlTagStart)
            
            // MARK: Content Processing
            // Have we got content (ie. text between tags or right at the start) to style? Do so now.
            if var content = scanned, !content.isEmpty {
#if DEBUG
                let printContent = content.replacingOccurrences(of: self.newLineSymbol, with: "[NL]")
                NSLog("[CONTENT] \(printContent) (\(content.count))")
#endif
                // Flag for nested paragraphs LI detection
                var itemListNestFound: Bool = false
                var listItemPrefix: String = ""
                
                // Should we add a bullet or numeral from an LI tag?
                if isListItem {
                    if content.hasPrefix(self.newLineSymbol) {
                        // markdownIt has chosen to set the LI content as
                        // interior P blocks. Ignore the CR in the content string,
                        // and set a flag to record we're in nested mode.
                        content = ""
                        itemListNestFound = true
                    } else {
                        // Text immediately following the LI - it's a single-line item.
                        isListItem = false
                        if listTypes[insetLevel] == .bullet {
                            // Add a standard bullet. We set six types and we cycle around
                            // when the indent level is greater than that that number.
                            var index: Int = insetLevel
                            while index > self.bullets.count {
                                index -= self.bullets.count
                            }
                            
                            if index < 1 {
                                index = 1
                            }
                            
                            listItemPrefix = "\(self.bullets[index - 1]) "
                        } else {
                            // Add a numeral. The value was calculated when we encountered the initial LI
                            listItemPrefix = "\(orderedListCounts[insetLevel]). "
                        }
                        
                        // Set the paragraph style with the current indent
                        self.styles["li"]?[.paragraphStyle] = getInsetParagraphStyle(insetLevel)
                    }
                }
                
                // Pre-formatted lines (ie. code) should be presented as a single paragraph with inner
                // line breaks, so convert the content block's paragraph breaks (\n) to
                // NSAttributedString-friendly line-break codes.
                if isPre {
                    // Tidy up the code
                    content = content.trimmingCharacters(in: .newlines)
                    content = content.replacingOccurrences(of: self.newLineSymbol, with: self.lineBreakSymbol)
                    content += self.lineFeedSymbol
                    
                    // Are we rendering a preview?
                    if !self.isThumbnail && !self.currentLanguage.isEmpty {
                        // Have we a highlighter available? If not, generate one
                        makeHighlighter()
                        
                        // First try to render the code in the detected language;
                        // if that fails, try to use the highlighter to detect the language
                        if let cas: NSAttributedString = self.highlighter?.highlight(content, as: self.currentLanguage) {
                            renderedString.append(makeHighlightedCodeParagraph(NSMutableAttributedString(attributedString: cas)))
                            content = ""
                        } else if let cas: NSAttributedString = self.highlighter?.highlight(content, as: nil) {
                            renderedString.append(makeHighlightedCodeParagraph(NSMutableAttributedString(attributedString: cas)))
                            content = ""
                        }
                    }
                    
                    // No highlighter, or no language detected, so render as plain
                    if !content.isEmpty {
                        renderedString.append(makePlainCodeParagraph(content))
                        content = ""
                    }
                }
                
                // Blockquotes should be styled with the current indent
                if isBlockquote {
                    // Just make a block cell for the current inset.
                    // The whole block will be rendered at the final </block>
                    makeBlockquoteParagraph(blockLevel, content)
                    content = ""
                }
                
                // Nested paragraphs (P tags under LIs) need special handling. The first paragraph (ie.
                // the one with the list prefix) is run on from the prefix; following paragraphs are
                // inset to the same level.
                // NOTE This is why we don't set `isNested` when we discover nesting above
                if isNested {
                    self.styles["li"]![.paragraphStyle] = getInsetParagraphStyle(insetLevel, 16.0, listItemPrefix.isEmpty ? 16.0 : 0.0)
                }
                
                // Style the content if we have some...
                if !content.isEmpty {
                    var partialRenderedString: NSMutableAttributedString
                    if listItemPrefix.count > 0 {
                        // Style the list prefix and then the content
                        let listItemPrefixStyle: Style = Style.init()
                        listItemPrefixStyle.name = "li"
                        listItemPrefixStyle.type = .indent
                        partialRenderedString = NSMutableAttributedString.init(attributedString: styleString(listItemPrefix, [listItemPrefixStyle]))
                        partialRenderedString.append(styleString(content, styleStack))
                    } else {
                        // Style the non-list content
                        if content.hasPrefix(self.newLineSymbol) && currentParagraphStyle != nil {
                            // Match the CR after a P, H or LI to that item's style
                            partialRenderedString = NSMutableAttributedString.init(attributedString: styleString(self.lineFeedSymbol + String(content.dropFirst()), [currentParagraphStyle!]))
                        } else {
                            // All other text
                            partialRenderedString = NSMutableAttributedString.init(attributedString: styleString(content, styleStack))
                        }
                    }
                    
                    // ...and add it to the store
                    renderedString.append(partialRenderedString)
                }
                
                // We've detected a nest structure (see above) flag it for next time round
                if itemListNestFound {
                    isNested = true
                }
                
                // Break out of the upper scanner loop if we're done
                // NOTE This is for pre-html text
                if scanner.isAtEnd {
                    continue
                }
            }
            
            // Reached a token delimiter: step over it
            scanner.skipNextCharacter()

            // Get the first character of the tag
            let nextChar: String = scanner.getNextCharacter(in: self.tokenString)
            
            // MARK: Closing Token
            if nextChar == "/" {
                // Found a close tag, so step over the `/`
                scanner.skipNextCharacter()

                // Get the remainder of the tag up to the delimiter
                if let closeToken: String = scanner.scanUpToString(self.htmlTagEnd) {
#if DEBUG
                    NSLog("[CLOSING TOKEN] <- \(closeToken)")
#endif
                    // NOTE mdit generates lowercase HTML tags, but we should probably not assume that
                    
                    // Should we remove the carriage return from the end of the line?
                    // This is required when single tokens appear on a per-line basis, eg. UL, OL, BLOCKQUOTE
                    var doSkipNewLine: Bool = false
                    
                    // Should be convert the end-of-line LF to LB?
                    var doReplaceNewLine: Bool = false
                    
                    // Process the closing token by type
                    switch(closeToken) {
                        case "p":
                            if isBlockquote {
                                // Remove the final LF when we're nested in a blockquote
                                doSkipNewLine = true
                            }
                        /* Ordered or unordered lists */
                        case "ul":
                            fallthrough
                        case "ol":
                            // Reset the current level's inset count
                            orderedListCounts[insetLevel] = 0
                            
                            // Reduce the inset level
                            insetLevel -= 1
                            if insetLevel <= 0 {
                                insetLevel = 0
                                self.styles["li"]![.paragraphStyle] = self.paragraphs["list"]!
                            }

                            // Remove the tag's LF
                            doSkipNewLine = true
                        /* List items */
                        case "li":
                            // TO-DO See what happens with inner nests
                            if isNested {
                               isNested = false
                            }
                            
                            // Remove LFs on nested solitary </LI> tags
                            if previousToken != "li" {
                                doSkipNewLine = true
                            } else {
                                doReplaceNewLine = true
                                previousToken = ""
                            }
                        /* Blocks */
                        case "blockquote":
                            // Remove the LF
                            doSkipNewLine = true
                            blockLevel -= 1
                            if blockLevel < 0 {
                                blockLevel = 0
                            }
                            
                            // Are we out of the outermost block?
                            if blockLevel == 0 {
                                // Don't remove the LF to ensure unit separation
                                doSkipNewLine = false
                                isBlockquote = false
                                
                                // Render the stored blockquote content
                                if let bas = self.blockAttStr {
                                    renderedString.append(bas)
                                    self.blockAttStr = nil
                                    self.blockTable = nil
                                }
                            }
                        case "pre":
                            isPre = false
                            // Clear the <PRE><CODE...>...</CODE></PRE> current language
                            self.currentLanguage = ""
                        /* Tables */
                        case "table":
                            // Use NSMutableAttributedString to convert the table HTML
                            if let data: Data = self.currentTable.data(using: .utf8) {
                                if let tableAttStr: NSMutableAttributedString = NSMutableAttributedString.init(html: data, documentAttributes: nil) {
                                    // Now we have to set our font style for each element within the table
                                    tableAttStr.enumerateAttribute(.font, in: NSMakeRange(0, tableAttStr.length)) { (value: Any?, range: NSRange, got: UnsafeMutablePointer<ObjCBool>) in
                                        if value != nil {
                                            let font: NSFont = value as! NSFont
                                            var cellFont: NSFont
                                            
                                            if let fontName: String = font.displayName {
                                                if fontName.contains("Bold") {
                                                    cellFont = self.makeFont("strong", self.fontSize)
                                                } else if fontName.contains("Italic") {
                                                    cellFont = self.makeFont("em", self.fontSize)
                                                } else {
                                                    cellFont = self.makeFont("plain", self.fontSize)
                                                }
                                            } else {
                                                cellFont = self.makeFont("plain", self.fontSize)
                                            }
                                            
                                            // Style the cell's font and colour
                                            tableAttStr.addAttribute(.font, value: cellFont, range: range)
                                            tableAttStr.addAttribute(.foregroundColor, value: self.colours.body!, range: range)
                                        }
                                    }

                                    // Add the rendered table to the display string
                                    renderedString.append(tableAttStr)
                                }
                            }
                            
                            self.currentTable = ""
                        default:
                            break
                    }

                    // Step over the token delimiter
                    scanner.skipNextCharacter()
                    
                    if doSkipNewLine {
                        // Step over the tailing LF
                        scanner.skipNextCharacter()
                    }
                    
                    // Pop the last style
                    if styleStack.count > 0 {
                        // Get the style at the top of the stack...
                        currentParagraphStyle = styleStack.removeLast()
                        
                        // ...unless it's one we don't need
                        if currentParagraphStyle?.type != .paragraph && currentParagraphStyle?.type != .indent {
                            currentParagraphStyle = nil
                        }
                    }
                    
                    // Record the tag we've just processed, provided it's not
                    // related to a character style
                    if !["strong", "b", "em", "i", "a", "s", "img", "code", "kbd"].contains(closeToken) {
                        previousToken = closeToken
                    }
                }
            } else {
                // MARK: Opening Token
                // We've got a new token, so get it up to the delimiter
                if let openToken: String = scanner.scanUpToString(self.htmlTagEnd) {
                    // NOTE mdit generates lowercase HTML tags, but we should probably not assume that
                    let token: String = openToken.lowercased()
                    
                    // This is the tag we will use to format the content. It may not
                    // be the actual tag detected, eg. for LI- or BLOCKQUOTE-nested Ps we use LI
                    var tokenToApply: String = token
                    
                    // Should we remove the new line symbol from the end of the line?
                    // This is required when single tokens appear on a per-line basis, eg UL, OL, BLOCKQUOTE
                    var doSkipNewLine: Bool = false
                    
                    // Should we convert the end-of-line LF to LB?
                    var doReplaceNewLine: Bool = false
                    
                    /* Handle certain tokens outside of the switch statement
                       because the raw tokens contain extra, non-comparable text */
                    
                    // Check for a link. If we have one, get the destination and
                    // record it for processing later
                    if token.hasPrefix("a") {
                        // We have a link -- get the destination from HREF
                        tokenToApply = "a"
                        getLinkRef(token)
                    }
                    
                    // Check for an image. If we have one, get the source and
                    // record it for processing later
                    if token.hasPrefix("img") {
                        // TO-DO Do we want to retain the ALT tag?
                        tokenToApply = "img"
                        getImageRef(token)
                    }
                    
                    // Look for a language specifier. If one exists, get it
                    // and retain it for processing later
                    if token.contains("code class") {
                        tokenToApply = "none"
                        getCodeLanguage(token)
                    }
                    
                    // Check for a table. If we have one, style it's heading grab the whole of
                    // it up to the terminating token
                    if token.hasPrefix("table") {
                        // Clear the tag as we'll do all the content processing here
                        tokenToApply = "none"
                        
                        // Step over the tag's delimiter
                        // TO-DO Check this works with pre-styled tables
                        scanner.skipNextCharacter()
                        
                        // Get the table content and style it: set it up with a coloured border around table and cells
                        //self.currentTable = "<table width=\"100%\" style=\"border: 2px solid #\(self.colourValues.head);border-collapse: collapse;\">"
                        self.currentTable = "<table width=\"100%\" style=\"border-collapse:collapse;\">"
                        
                        // Scan up to the closing </table> tag and add the closing tag manually to the table text.
                        // NOTE Table will be rendered when the scanner code process the closing tag
                        if let tableCode = scanner.scanUpToString("</table>") {
                            self.currentTable += tableCode + "</table>\n"
                        } else {
                            // No table code present so set a warning
                            self.currentTable += "<tr><td>Malformed table</td></tr></table>\n"
                        }
                        
                        // Set the style for all the table cells, including header cells, retaining any existing
                        // styling (typically `text-align`)
                        
                        self.currentTable = self.currentTable.replacingOccurrences(of: "<th style=\"", with: "<th style=\"border:0.5px solid #444444;padding:12px;")
                        self.currentTable = self.currentTable.replacingOccurrences(of: "<th>", with: "<th style=\"border:0.5px solid #444444;padding:12px;\">")
                        self.currentTable = self.currentTable.replacingOccurrences(of: "<td style=\"", with: "<td style=\"border:0.5px solid #444444;padding:12px;")
                        self.currentTable = self.currentTable.replacingOccurrences(of: "<td>", with: "<td style=\"border:0.5px solid #444444;padding:12px;\">")
                        
                        /*
                        self.currentTable = self.currentTable.replacingOccurrences(of: "<th style=\"", with: "<th style=\"padding:12px;")
                        self.currentTable = self.currentTable.replacingOccurrences(of: "<th>", with: "<th style=\"padding:12px;\">")
                        self.currentTable = self.currentTable.replacingOccurrences(of: "<td style=\"", with: "<td style=\"padding:12px;")
                        self.currentTable = self.currentTable.replacingOccurrences(of: "<td>", with: "<td style=\"padding:12px;\">")
                         */
                        // Remove weird space char inserted by MarkdownIt in place of &nbsp;
                        self.currentTable = self.currentTable.replacingOccurrences(of: " ", with: " ")
                        
                        // Move the scanner back to face the final </table> so we can trap it
                        // as a closing tag and process the formatted table we've just made
                        scanner.currentIndex = scanner.string.index(before: scanner.currentIndex)
#if DEBUG
                        NSLog("[TABLE] \(self.currentTable)")
#endif
                    }
                
                    // Process the new token by type
                    switch(token) {
                        /* Paragraph-level tags with context-sensitivity */
                        case "p":
                            // Already inside another element? Set the style accordingly
                            if isBlockquote {
                                tokenToApply = "blockquote"
                            } else if isNested {
                                tokenToApply = "li"
                            }
                        /* Ordered or unordered lists and items */
                        case "ul":
                            fallthrough
                        case "ol":
                            // Set the list type and increment the current indent
                            let listItem: ListType = token == "ul" ? .bullet : .number
                            
                            // Add an indentation level if we need to
                            insetLevel += 1
                            if insetLevel == listTypes.count {
                                listTypes.append(listItem)
                                orderedListCounts.append(0)
                            } else {
                                listTypes[insetLevel] = listItem
                                orderedListCounts[insetLevel] = 0
                            }
                            
                            // Remove the tailing LF unless the previous block was a list too.
                            // This is to enforce a clear line between separate lists
                            if previousToken != "ul" && previousToken != "ol" {
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
                        /* Blocks openers */
                        case "blockquote":
                            isBlockquote = true
                            blockLevel += 1
                            doSkipNewLine = true
                            tokenToApply = "none"
                        case "pre":
                            // ASSUMPTION PRE is ALWAYS followed by CODE (not in HTML, but certainly in MD->HTML)
                            isPre = true
                        /* Tokens that can be handled immediately */
                        case "hr":
                            renderedString.append(hr)
                            doSkipNewLine = true
                        case "br":
                            fallthrough
                        case "br/":
                            // Trap <BR/> in embedded HTML
                            fallthrough
                        case "br /":
                            // Trap <BR /> in embedded HTML
                            doReplaceNewLine = true
                        /* Character-level tokens */
                        case "i":
                            // Trap <I> tags in embedded HTML
                            tokenToApply = "em"
                        case "b":
                            // Trap <B> tags in embedded HTML
                            tokenToApply = "strong"
                        case "code":
                            // If CODE is in a PRE, we rely on the PRE for styling,
                            // otherwise we use CODE as a character style
                            if isPre {
                                tokenToApply = "none"
                            }
                        default:
                            // Covers all other tags, including headers: do nothing
                            break
                    }
                    
#if DEBUG
                    NSLog("[OPENING TOKEN] -> \(token) as \(tokenToApply)")
#endif
                    
                    // Compare the tag to use with those we apply.
                    // Some, such as list markers, we do not style here
                    if self.appliedTags.contains(tokenToApply) {
                        // Push the tag's style to the stack
                        let style: Style = Style()
                        style.name = tokenToApply
                        
                        // Set character styles (inherit style from parent)
                        if ["strong", "em", "a", "s", "img", "sub", "sup", "code", "kbd"].contains(tokenToApply) {
                            style.type = .character
                        }
                        
                        // Set other styles -- default is `.paragraph`
                        if tokenToApply == "li" {
                            style.type = .indent
                        }
                        
                        // Record the tag for later use
                        if style.type == .paragraph || style.type == .indent {
                            previousToken = tokenToApply
                        }
                        
                        // Push the new style onto the stack
                        styleStack.append(style)
                    }
                    
                    // Step over the token's delimiter
                    scanner.skipNextCharacter()
                    
                    // Check for use of <br> within a paragraph, not at the end of a line.
                    // If we find one, add an LB as there's no LF to replace
                    if tokenToApply == "br" && scanner.getNextCharacter(in: String(self.tokenString)) != self.newLineSymbol {
                        doReplaceNewLine = false
                        renderedString.append(NSAttributedString.init(string: self.lineBreakSymbol))
                    }
                    
                    // If required, remove the LF at the end of the line (ie. right after the tag)
                    // This will be for OL, UL, BLOCKQUOTE, PRE+CODE, HR, BR, LI+P
                    if doSkipNewLine {
                        scanner.skipNextCharacter()
                    }
                    
                    // If required, replace the LF at the end of the line with an LB.
                    // This will be for BR
                    if doReplaceNewLine {
                        //renderedString.append(NSAttributedString.init(string: self.lineBreakSymbol))
                    }
                
                    // Images have no content between token delimiters, or closing tags, so handle the styling here
                    // NOTE The image itself is inserted by `styleString()`.
                    if tokenToApply == "img" {
                        let partialRenderedString: NSMutableAttributedString = NSMutableAttributedString.init(attributedString: styleString("", styleStack))
                        renderedString.append(partialRenderedString)
                        styleStack.removeLast()
                    }
                }
            }
            
            scanned = nil
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
    
    
    // MARK: - Value Extraction Functions
    
    /**
        Get a URL or path embedded in an A HREF tag.
     
        - Parameters
            - tag: The full token.
     */
    internal func getLinkRef(_ tag: String) {
        
        self.currentLink = splitTag(tag)
    }
    
    
    /**
        Get a URL or path embedded in an IMG SRC tag.
     
        - Parameters
            - tag: The full token.
     */
    internal func getImageRef(_ tag: String) {
        
        self.currentImagePath = splitTag(tag)
    }
    
    
    /**
        Get the software languges in an CODE CLASS tag.
     
        - Parameters
            - tag: The full token.
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
            - tag:       The full token.
            - partIndex: The index of the element we want returned.
    
        - Returns The requested string.
     */
    internal func splitTag(_ tag: String, _ partIndex: Int = 1) -> String {
        
        let parts: [String] = tag.components(separatedBy: "\"")
        if parts.count > partIndex {
            return parts[partIndex]
        }
        
        return ""
    }
    
    
    // MARK: - Paragraph Generation Functions
    
    /**
     Prepare a paragraph inset to the requested depth.
     
     - Parameters
        - inset:      The indentation factor. This is multiplied by 40 points.
        - headInset:  Any offset to apply to the whole para other than line 1. Default: 0.0.
        - firstInset: Any offset to apply to the first line. Default: 0.0, ie. matches the para as whole.
     
     - Returns The inset NSParagraphStyle.
     */
    internal func getInsetParagraphStyle(_ inset: Int, _ headInset: CGFloat = 0.0, _ firstInset: CGFloat = 0.0) -> NSMutableParagraphStyle {
        
        var insetParaStyle: NSMutableParagraphStyle
        let styleName: String = String.init(format: "inset%02d", inset)
        
        if self.paragraphs[styleName] != nil {
            insetParaStyle = self.paragraphs[styleName]!
        } else {
            let table: NSTextTable = NSTextTable.init()
            table.numberOfColumns = 1
            
            let block: NSTextTableBlock = NSTextTableBlock.init(table: table, startingRow: 0, rowSpan: 1, startingColumn: 0, columnSpan: 1)
            block.setValue(512.0, type: .absoluteValueType, for: .minimumWidth)
            
            insetParaStyle = NSMutableParagraphStyle.init()
            insetParaStyle.lineSpacing = self.lineSpacing
            insetParaStyle.paragraphSpacing = self.paraSpacing
            insetParaStyle.alignment = .left
            insetParaStyle.headIndent = 48.0 * CGFloat(inset) + headInset
            insetParaStyle.firstLineHeadIndent = 40.0 * CGFloat(inset) + firstInset
            insetParaStyle.textBlocks.append(block)
            self.paragraphs[styleName] = insetParaStyle
        }
        
        return insetParaStyle
    }
    
    
    /**
        Prepare a paragraph to hold one or more blockquote paragraphs,
        inset as necessary.
     
        See https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextLayout/Articles/TextTables.html
     
        - Parameters
            - inset:    The indent level.
            - cellText: The text of the paragraph.
     */
    internal func makeBlockquoteParagraphCell(_ inset: Int, _ cellText: String) {
        
        
        // Make sure we have an NSMutableAttributedString for the whole table...
        if self.blockAttStr == nil {
            self.blockAttStr = NSMutableAttributedString.init(string: "")
        }
        
        // ...and a table objectx
        if self.blockTable == nil {
            self.blockTable = NSTextTable.init()
            self.blockTable?.numberOfColumns = 1
            //self.blockTable?.collapsesBorders = false
            //self.blockTable?.hidesEmptyCells = true
        }
        
        // Create the cell block
        let cellblock = NSTextTableBlock(table: self.blockTable!, startingRow: inset, rowSpan: 1, startingColumn: 0, columnSpan: 1)
        cellblock.setWidth(16.0, type: NSTextBlock.ValueType.absoluteValueType, for: NSTextBlock.Layer.padding)
        cellblock.verticalAlignment = .middleAlignment
        cellblock.backgroundColor = .previewBlock
        
        cellblock.setWidth(8.0, type: NSTextBlock.ValueType.absoluteValueType, for: NSTextBlock.Layer.border)
        cellblock.setBorderColor(.previewBlock)
        cellblock.setBorderColor(self.colours.quote!, for: .minX)
        
        // Set the cell text's parastyle
        let cellParagraphStyle = NSMutableParagraphStyle()
        cellParagraphStyle.alignment = .left
        cellParagraphStyle.lineSpacing = self.lineSpacing
        cellParagraphStyle.paragraphSpacing = self.paraSpacing
        cellParagraphStyle.headIndent = 100.0 + 100.0 * CGFloat(inset - 1)
        cellParagraphStyle.firstLineHeadIndent = 100.0 + 100.0 * CGFloat(inset - 1)
        cellParagraphStyle.textBlocks.append(cellblock)
        
        // Generate an NSMutableAttributedString for the cell text using the above attributes...
        let cellAttributedString: NSMutableAttributedString = NSMutableAttributedString(string: inset > 1 ? self.lineFeedSymbol + cellText : cellText,
                                                                                        attributes: [.paragraphStyle: cellParagraphStyle,
                                                                                                     .foregroundColor: self.colours.quote!,
                                                                                                     .font: makeFont("strong", self.fontSize * H4_MULTIPLIER)])
        
        // ...and add it to the table NSMutableAttributedString
        self.blockAttStr!.append(cellAttributedString)
    }
    
    
    internal func makeBlockquoteParagraph(_ inset: Int, _ cellText: String) {
        
        // Make sure we have an NSMutableAttributedString for the whole table...
        if self.blockAttStr == nil {
            self.blockAttStr = NSMutableAttributedString.init(string: "")
        }
        
        let cellParagraphStyle = NSMutableParagraphStyle()
        cellParagraphStyle.alignment = .left
        cellParagraphStyle.lineSpacing = self.lineSpacing
        cellParagraphStyle.paragraphSpacing = self.paraSpacing
        cellParagraphStyle.headIndent = 100 + 100.0 * CGFloat(inset - 1)
        cellParagraphStyle.firstLineHeadIndent = 100 + 100.0 * CGFloat(inset - 1)
        
        // Generate an NSMutableAttributedString for the cell text using the above attributes...
        let cellAttributedString: NSMutableAttributedString = NSMutableAttributedString(string: inset > 1 ? self.lineFeedSymbol + cellText : cellText,
                                                                                        attributes: [.paragraphStyle: cellParagraphStyle,
                                                                                                     .foregroundColor: self.colours.quote!,
                                                                                                     .font: makeFont("strong", self.fontSize * H4_MULTIPLIER)])
        
        // ...and add it to the table NSMutableAttributedString
        self.blockAttStr!.append(cellAttributedString)
    }

    /**
        Create a styled string containing plain text code or just plain text
        set against a background. This is typically for PRE and PRE+CODE
        structures.
     
        - Parameters
            - plainCode: The plain text code.
     
        - Returns The assembled paragraph as an attributed string.
     */
    internal func makePlainCodeParagraph(_ plainCode: String) -> NSMutableAttributedString {
        
        // Make the single paragraph style
        let cellParagraphStyle = makeCodeParagraphStyle()
        
        // Return the plain code on the background block
        return NSMutableAttributedString(string: plainCode,
                                         attributes: [.paragraphStyle: cellParagraphStyle,
                                                      .foregroundColor: self.colours.code!,
                                                      .font: makeFont("code", self.fontSize)])
    }
    
    
    /**
     Create a styled string setting highlighted code against a background.
     
     - Parameters
        - highlightedCode: The background-less highlighted code.
 
     - Returns The assembled paragraph as an attributed string.
     */
    internal func makeHighlightedCodeParagraph(_ highlightedCode: NSMutableAttributedString) -> NSMutableAttributedString {
        
        let cellParagraphStyle = makeCodeParagraphStyle()
        highlightedCode.addAttributes([.paragraphStyle: cellParagraphStyle],
                                      range: NSMakeRange(0, highlightedCode.length))
        return highlightedCode
    }
    
    
    /**
     Generate a generic code paragraph style.
     
     - Returns The paragraph style.
     */
    internal func makeCodeParagraphStyle() -> NSMutableParagraphStyle {
        
        // Make the single paragraph style
        // TO-DO Cache for later usage
        let cellParagraphStyle = NSMutableParagraphStyle()
        cellParagraphStyle.alignment = .left
        cellParagraphStyle.lineSpacing = self.lineSpacing
        cellParagraphStyle.paragraphSpacing = self.paraSpacing
        cellParagraphStyle.textBlocks = [makeCodeParagraphBlock()]
        return cellParagraphStyle
    }
    
    
    /**
     Generate a single table block for presenting code of any kind.
     
     - Returns A text table block.
     */
    internal func makeCodeParagraphBlock() -> NSTextTableBlock {
        
        // Make a table for the block: it will be 1 x 1
        let paragraphTable = NSTextTable.init()
        paragraphTable.numberOfColumns = 1
        paragraphTable.collapsesBorders = true
        
        // Make the table's single cell
        let paragraphBlock = NSTextTableBlock(table: paragraphTable, startingRow: 0, rowSpan: 1, startingColumn: 0, columnSpan: 1)
        paragraphBlock.backgroundColor = .previewCode
        paragraphBlock.setWidth(8.0, type: NSTextBlock.ValueType.absoluteValueType, for: NSTextBlock.Layer.padding)
        return paragraphBlock
    }
    
    
    /**
     Generate an attributed string from an individual source string by iterating through
     the style stack and applying each.
     
     - Parameters
        - plainText: The raw string.
        - styleList: The style stack.
     
     - Returns An attributed string.
     */
    internal func styleString(_ plainText: String, _ styleList: [Style]) -> NSMutableAttributedString {
       
        var returnString: NSMutableAttributedString
        
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
                    // Extra adjustments need to be made here -- additions that cannot be applied generically
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
                                    lineColour = self.colours.body
                                }
                                
                                attributes.updateValue(NSUnderlineStyle.single.rawValue as NSNumber, forKey: .underlineStyle)
                                attributes.updateValue(lineColour, forKey: .underlineColor)
                            }
                        case "strong":
                            // Check if the font used is italic. If not, flag we need to set the background color
                            if fontUsed == nil || (!fontUsed!.fontName.contains("Bold") && !fontUsed!.fontName.contains("Black") && !fontUsed!.fontName.contains("Heavy") && !fontUsed!.fontName.contains("Medium")) {
                                attributes.updateValue(self.colours.body, forKey: .backgroundColor)
                                attributes.updateValue(NSColor.previewBackground, forKey: .foregroundColor)
                            }
                        case "img":
                            // Don't show images in thumbnails
                            if !self.isThumbnail {
                                // SEE https://developer.apple.com/documentation/foundation/nsurl for secure resources
                                let imageUrl = URL.init(fileURLWithPath: self.currentImagePath)
                                var imageAttachment: NSTextAttachment
                                if let image = NSImage.init(contentsOf: imageUrl) {
                                    imageAttachment = NSTextAttachment.init()
                                    imageAttachment.image = image
                                } else {
                                    let baseImageName: String = BUFFOON_CONSTANTS.IMG_PLACEHOLDER
                                    imageAttachment = NSTextAttachment.init()
                                    if let image: NSImage = NSImage.init(named: NSImage.Name(stringLiteral: baseImageName)) {
                                        imageAttachment.image = image
                                    }
                                }
                                
                                // IMG should be at the top the the stack, so we can return immediately
                                let imageAttString = NSMutableAttributedString(attachment: imageAttachment)
                                imageAttString.append(NSAttributedString.init(string: self.lineFeedSymbol))
                                return imageAttString
                            }
                        default:
                            break
                    }
                } else {
                    parentStyle = style
                }
            }
            
            returnString = NSMutableAttributedString(string: plainText, attributes: attributes)
        } else {
            // No style list provided? Just return the plain string formatted for body text
            returnString = NSMutableAttributedString(string: plainText, attributes: self.styles["p"])
        }

        return returnString
    }
    
    
    /**
     Convert all the occurences of `[ ]` and `[x]` in the specified
     string into emoji symbols.
     */
    internal func processCheckboxes() {

        // Hack to present checkboxes a la GitHub
        let patterns: [String] = [#"\[\s?\](?!\()"#, #"\[[xX]{1}\](?!\()"#]
        let symbols: [String] = ["❎", "✅"]

        var i = 0
        for pattern in patterns {
            var range = self.tokenString.range(of: pattern, options: .regularExpression)

            while range != nil {
                // Swap out the HTML symbol code for the actual symbol
                self.tokenString = self.tokenString.replacingCharacters(in: range!, with: symbols[i])

                // Get the next occurence of the pattern ready for the 'while...' check
                range = self.tokenString.range(of: pattern, options: .regularExpression)
            }

            i += 1
        }
    }
    
    
    // MARK: - Data Initialisation Functions
    
    /**
     At the start of a rendering run, set up all the base styles we will need,
     including all the fonts and colours we will use.
     */
    internal func generateStyles() {
        
        // Prepare the fonts we'll use
        prepareFonts()
        
        self.lineSpacing = ((self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0) - 1.0) * self.fontSize
        self.paraSpacing = self.paraSpacing >= 0.0 ? self.paraSpacing : 0.0
        
        // Set the paragraph styles
        // Base paragraph style: No left inset
        let tabbedParaStyle: NSMutableParagraphStyle    = NSMutableParagraphStyle()
        tabbedParaStyle.lineSpacing                     = self.lineSpacing
        tabbedParaStyle.paragraphSpacing                = self.paraSpacing
        tabbedParaStyle.paragraphSpacingBefore          = 0.5
        tabbedParaStyle.alignment                       = .left
        tabbedParaStyle.tabStops                        = [NSTextTab(textAlignment: .left, location: 30.0, options: [:]),
                                                           NSTextTab(textAlignment: .left, location: 60.0, options: [:])]
        tabbedParaStyle.defaultTabInterval              = 30.0
        self.paragraphs["tabbed"]                       = tabbedParaStyle
        
        // Nested list
        let listParaStyle: NSMutableParagraphStyle      = NSMutableParagraphStyle()
        listParaStyle.lineSpacing                       = self.lineSpacing
        listParaStyle.paragraphSpacing                  = self.paraSpacing
        listParaStyle.alignment                         = .left
        listParaStyle.headIndent                        = 60.0
        listParaStyle.firstLineHeadIndent               = 40.0
        self.paragraphs["list"]                         = listParaStyle
        
        // HR paragraph
        let lineParaStyle: NSMutableParagraphStyle      = NSMutableParagraphStyle()
        lineParaStyle.lineSpacing                       = self.lineSpacing
        lineParaStyle.paragraphSpacing                  = self.paraSpacing
        lineParaStyle.alignment                         = .left
        lineParaStyle.tabStops                          = [NSTextTab(textAlignment: .right, location: 120.0, options: [:])]
        self.paragraphs["line"]                         = lineParaStyle
        
        // HR paragraph
        let imgParaStyle: NSMutableParagraphStyle       = NSMutableParagraphStyle()
        imgParaStyle.lineSpacing                        = self.lineSpacing
        imgParaStyle.paragraphSpacing                   = self.paraSpacing
        imgParaStyle.alignment                          = .left
        self.paragraphs["img"]                          = imgParaStyle
        
        // Set the colours
        self.colours.head  = NSColor.colourFromHexString(self.colourValues.head)
        self.colours.code  = NSColor.colourFromHexString(self.colourValues.code)
        self.colours.link  = NSColor.colourFromHexString(self.colourValues.link)
        self.colours.quote = NSColor.colourFromHexString(self.colourValues.quote)
        self.colours.body  = self.bodyColour
        
        // Generate specific paragraph entity styles
        // H1
        self.styles["h1"]           = [.foregroundColor: self.colours.head,
                                       .font: makeFont("strong", self.fontSize * H1_MULTIPLIER),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        // H2
        self.styles["h2"]           = [.foregroundColor: self.colours.head,
                                       .font: makeFont("strong", self.fontSize * H2_MULTIPLIER),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        // H3
        self.styles["h3"]           = [.foregroundColor: self.colours.head,
                                       .font: makeFont("strong", self.fontSize * H3_MULTIPLIER),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        // H4
        self.styles["h4"]           = [.foregroundColor: self.colours.head,
                                       .font: makeFont("strong", self.fontSize * H4_MULTIPLIER),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        // H5
        self.styles["h5"]           = [.foregroundColor: self.colours.head,
                                       .font: makeFont("strong", self.fontSize * H5_MULTIPLIER),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        // H6
        self.styles["h6"]           = [.foregroundColor: self.colours.head,
                                       .font: makeFont("plain", self.fontSize *  H6_MULTIPLIER),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        // P
        self.styles["p"]            = [.foregroundColor: self.colours.body,
                                       .font: makeFont("plain", self.fontSize),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        self.styles["t"]            = [.foregroundColor: self.colours.body,
                                       .font: makeFont("plain", self.fontSize),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        // Set the character styles we need
        // A
        self.styles["a"]            = [.foregroundColor: self.colours.link,
                                       .underlineStyle: NSUnderlineStyle.single.rawValue as NSNumber,
                                       .underlineColor: self.colours.link]
        
        // EM
        self.styles["em"]           = [.foregroundColor: self.colours.body,
                                       .font: makeFont("em", self.fontSize)]
        
        // STRONG
        self.styles["strong"]       = [.foregroundColor: self.colours.body,
                                       .font: makeFont("strong", self.fontSize)]
        
        // CODE
        self.styles["code"]         = [.foregroundColor: self.colours.code,
                                       .font: makeFont("code", self.fontSize)]
        
        // KBD
        self.styles["kbd"]          = [.foregroundColor: NSColor.white,
                                       .underlineColor: NSColor.gray,
                                       .underlineStyle: NSUnderlineStyle.double.rawValue as NSNumber,
                                       .font: makeFont("code", self.fontSize)]
        
        // S
        self.styles["s"]            = [.strikethroughStyle: NSUnderlineStyle.single.rawValue as NSNumber,
                                       .strikethroughColor: self.colours.body]
        
        // SUB
        self.styles["sub"]          = [.font: makeFont("plain", self.fontSize / 1.5),
                                       .baselineOffset: -5.0 as NSNumber]
        
        self.styles["sup"]          = [.font: makeFont("plain", self.fontSize / 1.5),
                                       .baselineOffset: 10.0 as NSNumber]
        
        // Set up the block styles we need
        // PRE
        self.styles["pre"]          = [.foregroundColor: self.colours.code,
                                       .font: makeFont("code", self.fontSize),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        // BLOCKQUOTE
        self.styles["blockquote"]   = [.foregroundColor: self.colours.body,
                                       .font: makeFont("plain", self.fontSize * H4_MULTIPLIER),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        // LI
        self.styles["li"]           = [.foregroundColor: self.colours.body,
                                       .font: makeFont("plain", self.fontSize),
                                       .paragraphStyle: self.paragraphs["list"]!]
        
        // IMG
        self.styles["img"]          = [.foregroundColor: self.colours.body,
                                       .font: makeFont("plain", self.fontSize),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        // MISC
        self.styles["line"]         = [.foregroundColor: self.colours.body,
                                       .font: makeFont("plain", self.fontSize),
                                       .paragraphStyle: self.paragraphs["img"]!]
    }


    /**
     Determine what styles are available for the chosen body font,
     which is set by the calling code (as is the base font size).
     */
    internal func prepareFonts() {
        
        // Make the body font in order to get its family name
        if let bodyFont: NSFont = NSFont.init(name: self.bodyFontName, size: self.fontSize) {
            self.bodyFontFamily.displayName = bodyFont.familyName ?? self.bodyFontName
            
            // Get a list of available members (styles) for the font family
            let fm: NSFontManager = NSFontManager.shared
            if let availableMembers = fm.availableMembers(ofFontFamily: self.bodyFontFamily.displayName) {
                for member in availableMembers {
                    var fontStyle: PMFont = PMFont()
                    fontStyle.postScriptName = member[0] as! String
                    fontStyle.styleName = member[1] as! String
                    self.bodyFontFamily.styles?.append(fontStyle)
                }
            }
        } else {
            // TO-DO
            // Set the body to a generic font
        }
    }
    
    
    /**
     Generate a specific font to match the specified style and size.
     
     - Parameters
        - fontStyle: The style, eg. `strong`.
        - size:      The point size.
     
     - Returns A font that can be used.
     */
    internal func makeFont(_ requiredStyle: String, _ size: CGFloat) -> NSFont {
        
        // Check through the fonts we've already made in case we have the
        // required one already.
        for fontRecord: FontRecord in self.fonts {
            if fontRecord.style == requiredStyle && fontRecord.size.isClose(to: size) {
                if let font: NSFont = fontRecord.font {
                    return font
                } else {
                    break
                }
            }
        }
        
        // No existing font available, so make one
        switch requiredStyle {
            case "strong":
                if let font = matchFont("strong", ["Bold", "Black", "Heavy", "Medium", "Semi-Bold"], self.bodyFontFamily, size) {
                    return font
                } else {
                    let fm: NSFontManager = NSFontManager.shared
                    if let font: NSFont = fm.font(withFamily: self.bodyFontFamily.displayName,
                                                  traits: .boldFontMask,
                                                  weight: 10,
                                                  size: size) {
                        recordFont(requiredStyle, size, font)
                        return font
                    }
                }
                // Still no font? Fall back to the base body font
                
            case "em":
                // Try to get an actual italic font
                if let font = matchFont("em", ["Italic", "Oblique"], self.bodyFontFamily, size) {
                    return font
                } else {
                    let fm: NSFontManager = NSFontManager.shared
                    if let font: NSFont = fm.font(withFamily: self.bodyFontFamily.displayName,
                                                  traits: .italicFontMask,
                                                  weight: 5,
                                                  size: size) {
                        recordFont(requiredStyle, size, font)
                        return font
                    }
                }

                // Still no font? Fall back to the base body font

            case "code":
                if let font: NSFont = NSFont(name: self.codeFontName, size: size) {
                    recordFont(requiredStyle, size, font)
                    return font
                }
                
                let font: NSFont = NSFont.monospacedSystemFont(ofSize: size, weight: NSFont.Weight(5.0))
                recordFont(requiredStyle, size, font)
                return font
                
            default:
                break
        }

        // Just use the body font as a fallback
        // NOTE `bodyFontName` will be a PostScript name
        if let font: NSFont = NSFont.init(name: self.bodyFontName, size: size) {
            recordFont(requiredStyle, size, font)
            return font
        }
        
        // Still no joy? Fall right back to the system font
        let font: NSFont = NSFont.systemFont(ofSize: size)
        recordFont(requiredStyle, size, font)
        return font
    }
    
    /**
     Try and find an installed font that matches our requirements. Hopefully, the
     user has selected sensibly, but in case not, we need to try and get something
     approximately right.
     
     - Parameters
        - requiredStyle: The style we want, eg. 'strong'
        - styleNames:    An array of possible font style names we might use, eg. 'Heavy', 'Bold'.
        - family:        An existing font family mapping.
        - size:          The size we want.
     
     - Returns The font we want or `nil` on error.
     */
    internal func matchFont(_ requiredStyle: String, _ styleNames: [String], _ family: PMFont, _ size: CGFloat) -> NSFont? {
        
        if let styles: [PMFont] = family.styles {
            for styleName: String in styleNames {
                 for style: PMFont in styles {
                    if styleName == style.styleName {
                        if let font: NSFont = NSFont.init(name: style.postScriptName, size: size) {
                            recordFont(requiredStyle, size, font)
                            return font
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    
    /**
     Store a font record for subsequent use.
     
     - Parameters
        - style: The style using the font.
        - size:  The point size of the font.
        - font:  The font itself.
     */
    internal func recordFont(_ style: String, _ size: CGFloat, _ font: NSFont?) {
        
        var fontRecord: FontRecord = FontRecord()
        fontRecord.style = style
        fontRecord.size = size
        fontRecord.font = font
        self.fonts.append(fontRecord)
    }
    
    
    /**
     Calculate the real size of a style entity from the
     base font size.
     
     - Parameters
        - tagName: An HTML tag.
     
     - Returns The font size to use.
     */
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
    
    
    /**
     Instantiate a Highlighter object for code colouring.
     
     - Note This should only be called if required.
     */
    internal func makeHighlighter() {
        
        if self.highlighter == nil {
            // Attempt to instantiate the highlighter
            self.highlighter = Highlighter.init()
            
            if self.highlighter == nil {
                // Couldn't create the highlighter
                NSLog("Could not load the highlighter")
            } else {
                // TO-DO Make theme selection more responsive to current mode
                self.highlighter?.setTheme(self.presentForLightMode ? "atom-one-light" : "atom-one-dark")
                self.highlighter?.theme.setCodeFont(makeFont("code", self.fontSize))
            }
        }
    }
    
    
    // MARK: - Utility Functions

    /***** TEST CODE -- REMOVE BEFORE RELEASE *****/
    func addStyles(_ base: String) -> String {
        
        
        let a = """
        <html>
            <head><style>
                h1 {
                    color: #\(self.colourValues.head);
                    font-size: \(self.setSize("h1"));
                    font-family: \(self.bodyFontName);
                }
                h2 {
                    color: #\(self.colourValues.head);
                    font-size: \(self.setSize("h2"));
                    font-family: \(self.bodyFontName);
                }
                body {
                    color: #\(self.colours.body.hexString);
                    font-size: \(self.fontSize);
                    font-family: \(self.bodyFontName);
                }
                code {
                    color: #\(self.colourValues.code);
                    font-size: \(self.fontSize);
                    font-family: \(self.codeFontName);
                }
                a {
                    color: #\(self.colourValues.link);
                }
            </style></head><body>
        """
        
        var b = base
        b = b.replacingOccurrences(of: "<table>", with: "<table width=\"100%\" style=\"border: 1px solid #\(self.colourValues.head);border-collapse: collapse;\">")
        b = b.replacingOccurrences(of: "<th style=\"", with: "<th style=\"border: 1px solid #\(self.colourValues.head);padding: 12px;")
        b = b.replacingOccurrences(of: "<th>", with: "<th style=\"border: 1px solid #\(self.colourValues.head);padding: 12px;\">")
        b = b.replacingOccurrences(of: "<td style=\"", with: "<td style=\"border: 1px solid #\(self.colourValues.head);padding: 12px;")
        b = b.replacingOccurrences(of: "<td>", with: "<td style=\"border: 1px solid #\(self.colourValues.head);padding: 12px;\">")
        b = b.replacingOccurrences(of: "</table>", with: "</table><p> </p")
        
        
        return a + b + "</body></html>"
    }
    
 
}
