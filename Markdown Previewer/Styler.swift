/*
 *  Styler.swift
 *  Convert a tokenised string into an NSAttributedString.
 *
 *  Created by Tony Smith on 23/09/2020.
 *  Copyright © 2024 Tony Smith. All rights reserved.
 */


import Foundation
import AppKit
import Highlighter


typealias StyleAttributes = [String: [NSAttributedString.Key: AnyObject]]


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

struct FontRecord {
    var postScriptName: String = ""
    var style: String = "regular"
    var size: CGFloat = 12.0
    var font: NSFont? = nil
}

class Styler {
    
    // MARK: - Publicly accessible properties
    
    var fontSize: CGFloat                           = 24.0
    var lineSpacing: CGFloat                        = BUFFOON_CONSTANTS.BASE_LINE_SPACING
    var paraSpacing: CGFloat                        = 18.0
    var viewWidth: CGFloat                          = 1024.0
    
    var colourValues: ColourValues                  = ColourValues()
    
    var bodyFontName: String                        = "SF Pro"
    var codeFontName: String                        = "Menlo"
    var bodyColour: NSColor                         = .white
    
    
    // MARK: - Private properties with defaults
    
    private var useLightMode: Bool                                      = true
    private var isThumbnail: Bool                                       = false
    private var tokenString: String                                     = ""
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
    
    // Headline size vs body font size scaler values
    private let H1_MULTIPLIER: CGFloat          = 2.6
    private let H2_MULTIPLIER: CGFloat          = 2.2
    private let H3_MULTIPLIER: CGFloat          = 1.8
    private let H4_MULTIPLIER: CGFloat          = 1.4
    private let H5_MULTIPLIER: CGFloat          = 1.2
    private let H6_MULTIPLIER: CGFloat          = 1.2
    
    private let htmlTagStart: String            = "<"
    private let htmlTagEnd: String              = ">"
#if DEBUG
    private let lineBreakSymbol: String         = "†\u{2028}"
    private let lineFeedSymbol: String          = "¶"
#else
    private let lineBreakSymbol: String         = "\u{2028}"
    private let lineFeedSymbol: String          = ""
#endif
    private let newLineSymbol: String           = "\n"
    private let windowsLineSymbol: String       = "\n\r"
    private let appliedTags: [String]           = ["p", "a", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "code", "kbd", "em", 
                                                   "strong", "blockquote", "s", "img", "li", "sub", "sup"]
    private let bullets: [String]               = ["\u{25CF}", "\u{25CB}", "\u{25CF}", "\u{25CB}", "\u{25CF}", "\u{25CB}"]
    private let htmlEscape: NSRegularExpression = try! NSRegularExpression(pattern: "&#?[a-zA-Z0-9]+?;", options: .caseInsensitive)
    
    private var blockAttStr: NSMutableAttributedString? = nil
    private var blockTable: NSTextTable?        = nil


    // MARK: - Constructor
    
    /**
        The default initialiser.
     
        - Parameters
            - useLightModeColours - `true` to use light colours.
    */
    init(_ useLightModeColours: Bool = true) {
        
        self.useLightMode = useLightModeColours
    }
    
    
    /**
        Render the class' `tokenString` property.
     
        - Parameters
            - tokenString - The tokenised string we're to render to NSAttributedString.
            - isThumbnail - Are we rendering text for thumbnail use? Default : `false`.
        
        - Returns NSAttributedString or nil or error.
     */
    func render(_ tokenString: String, _ isThumbnail: Bool = false) -> NSAttributedString? {
        
        // Check we have an tokended string to render.
        if tokenString.isEmpty {
            return nil
        } else {
            self.tokenString = tokenString
        }
        
        self.isThumbnail = isThumbnail
        if isThumbnail {
            // Always render for light mode when generating thumbnails
            self.useLightMode = true
        }
        
        // Generate the text styles we'll use
        generateStyles()
        
        // Render and return the tokened string
        return processTokenString()
    }
    
    
    /**
        Convert the class' `tokenString` property to an attributed string
     
        - Returns NSAttributedString or nil or error.
     */
    private func processTokenString() -> NSAttributedString? {
        
        // Rendering control variables
        var isListItem: Bool = false
        var isNested: Bool = false
        var isBlockquote: Bool = false
        var isPre: Bool = false
        
        var blockLevel: Int = 0
        var insetLevel: Int = 0
        var orderedListCounts: [Int] = Array.init(repeating: 0, count: 12)
        var listTypes: [ListType] = Array.init(repeating: .bullet, count: 12)
        
        var lastStyle: Style? = nil
        var previousToken: String = ""
        
        // Font-less horizontal rule
        let hr: NSAttributedString = NSAttributedString(string: "\u{00A0} \u{0009} \u{00A0}\n",
                                                        attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                                                                     .strikethroughColor: self.colours.body!,
                                                                     .paragraphStyle: self.paragraphs["line"]!])

        // Perform pre-processing:
        // 1. Convert checkboxes, eg `[] checkbox`, `[x] checkbox`
        self.tokenString = processCheckboxes(self.tokenString)
        
        // 2. Convert Windows LFCR line endings
        self.tokenString = self.tokenString.replacingOccurrences(of: self.windowsLineSymbol, with: self.newLineSymbol)
        
        // 3. Trim whitspace
        //self.tokenString = self.tokenString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Render the HTML
        var scannedString: String? = nil
        let scanner: Scanner = Scanner(string: self.tokenString)
        scanner.charactersToBeSkipped = nil
        var styleStack: [Style] = []
        
        //let renderedString: NSMutableAttributedString = NSMutableAttributedString(string: self.tokenString, attributes: self.styles["p"])
        let renderedString: NSMutableAttributedString = NSMutableAttributedString(string: self.newLineSymbol, attributes: self.styles["p"])
        
        // Iterate over the stored tokenised string
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
                NSLog("[CONTENT] \((scannedString! == self.newLineSymbol) ? "\\n" : scannedString!)")
#endif
                // Flag for nested paragraphs LI detection
                var itemListNestFound: Bool = false
                var listPrefix: String = ""
                
                // Should we add a bullet or numeral from an LI tag?
                if isListItem {
                    if scannedString!.hasPrefix(self.newLineSymbol) {
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
                            
                            if index < 1 {
                                index = 1
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
                
                // Pre-formatted lines (ie. code) should be presented as a single paragraph with inner
                // line breaks, so convert the content block's paragraph breaks (\n) to
                // NSAttributedString-friendly line-break codes.
                if isPre {
                    // Tidy up the code
                    scannedString = scannedString!.trimmingCharacters(in: .newlines)
                    scannedString = scannedString!.replacingOccurrences(of: self.newLineSymbol, with: self.lineBreakSymbol)
                    scannedString = scannedString! + self.newLineSymbol
                    
                    // Have we a detected language to use?
                    if !self.currentLanguage.isEmpty {
                        // Have we a highlighter available? If not, generate one
                        if self.highlighter == nil {
                            // Attempt to instantiate the highlighter
                            self.highlighter = Highlighter.init()
                            
                            if self.highlighter == nil {
                                // Couldn't create the highlighter
                                NSLog("Could not load the highlighter")
                            } else {
                                self.highlighter!.setTheme(self.useLightMode ? "atom-one-light" : "atom-one-dark")
                                self.highlighter!.theme.setCodeFont(makeFont("code", self.fontSize))
                            }
                        }
                        
                        // First try to render the code in the detected language;
                        // if that fails, try to use the highlighter to detect the language
                        if let cas: NSAttributedString = self.highlighter?.highlight(scannedString!, as: self.currentLanguage) {
                            renderedString.append(makeHighlightedCodeParagraph(NSMutableAttributedString(attributedString: cas)))
                            scannedString = ""
                        } else if let cas: NSAttributedString = self.highlighter?.highlight(scannedString!, as: nil) {
                            renderedString.append(makeHighlightedCodeParagraph(NSMutableAttributedString(attributedString: cas)))
                            scannedString = ""
                        }
                    } 
                    
                    // No highlighter, or no language detected, so render as plain
                    if !scannedString!.isEmpty {
                        renderedString.append(makePlainCodeParagraph(scannedString!))
                        scannedString = ""
                    }
                }
                
                // Blockquotes should be styled with the current indent
                if isBlockquote {
                    // Just make a block cell for the current inset. 
                    // The while block will be rendered at the final </block>
                    makeBlockquoteParagraphCell(blockLevel, scannedString!)
                    
                    // Clear the content to prevent immediate rendering
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
                        let liStyle: Style = Style.init()
                        liStyle.name = "li"
                        liStyle.type = .indent
                        partialRenderedString = NSMutableAttributedString.init(attributedString: styleString(listPrefix, [liStyle]))
                        partialRenderedString.append(styleString(scannedString!, styleStack))
                    } else {
                        // Style the content
                        if scannedString!.hasPrefix(self.newLineSymbol) && lastStyle != nil {
                            // Match the CR after a P, H or LI to that item's style
                            partialRenderedString = NSMutableAttributedString.init(attributedString: styleString(self.lineFeedSymbol + scannedString!, [lastStyle!]))
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
                if let closeToken: String = scanner.scanUpToString(self.htmlTagEnd) {
#if DEBUG
                    NSLog("[CLOSING TOKEN] <- \(closeToken)")
#endif
                    // NOTE mdit generates lowercase HTML tags, but we should probably not assume that
                    // startTag = startTag.lowercased()
                    
                    // Should we remove the carriage return from the end of the line?
                    // This is required when single tokens appear on a per-line basis, eg UL, OL, BLOCKQUOTE
                    var doSkipNewLine: Bool = false
                    
                    // Should be convert the end-of-line LF to LB?
                    var doReplaceNewLine: Bool = false
                    
                    // Process the closing token by type
                    switch(closeToken) {
                        case "p":
                            if isBlockquote {
                                // Remove the final LF when we're in a blockquote
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
                                
                                // Have we stored all the nested content? Then render it
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
                            if let data: Data = self.currentTable.data(using: .utf16) {
                                if let tableAttStr: NSMutableAttributedString = NSMutableAttributedString.init(html: data, documentAttributes: nil) {
                                    // Now we have to set our font style for each element within the table
                                    tableAttStr.enumerateAttribute(.font, in: NSMakeRange(0, tableAttStr.length)) { (value: Any?, range: NSRange, got: UnsafeMutablePointer<ObjCBool>) in
                                        if value != nil {
                                            let font: NSFont = value as! NSFont
                                            var cellFont: NSFont = self.makeFont("plain", self.fontSize)
                                            
                                            if let fontName: String = font.displayName {
                                                if fontName.contains("Bold") {
                                                    cellFont = self.makeFont("strong", self.fontSize)
                                                } else if fontName.contains("Italic") {
                                                    cellFont = self.makeFont("em", self.fontSize)
                                                }
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
                        if lastStyle?.type != .paragraph && lastStyle?.type != .indent {
                            lastStyle = nil
                        }
                        
                        // Remove the style at the top of the stack
                        styleStack.removeLast()
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
                    // be the actual tag detected, eg. for LI-nested Ps we use LI
                    var tokenToApply: String = token
                    
                    // Should we remove the new line symbol from the end of the line?
                    // This is required when single tokens appear on a per-line basis, eg UL, OL, BLOCKQUOTE
                    var doSkipNewLine: Bool = false
                    
                    // Should be convert the end-of-line LF to LB?
                    var doReplaceNewLine: Bool = false
                    
                    /* Handle certain tokens outside of the swith statement
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
                    if token.contains("table") {
                        // Clear the tag as we'll do all the processing here
                        tokenToApply = "none"
                        
                        // Step over the tag's delimiter
                        // TD-DO Check this works with pre-styled tables
                        scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
                        
                        // Get the table content and style it here: scan up to the </table> tag.
                        // Add a border to the table and cells: set it to 2px thickness in the head colour
                        self.currentTable = "<table width=\"\(self.viewWidth)px\" style=\"border: 2px solid #\(self.colourValues.head);border-collapse: collapse;\">"
                        
                        // Scan up to the closing tag and add the closing tag manually to the table text.
                        // NOTE Table will be rendered when the scanner code process the closing tag
                        if let tableCode = scanner.scanUpToString("</table>\n") {
                            self.currentTable += tableCode + "</table>\n"
                        } else {
                            // No table code present so set a warning
                            self.currentTable += "<tr><td>Malformed table</td></tr></table>\n"
                        }
                        
                        // Set the style for table cells, including header cells
                        self.currentTable = self.currentTable.replacingOccurrences(of: "<th style=\"", with: "<th style=\"border: 2px solid #\(self.colourValues.head);padding: 12px;")
                        self.currentTable = self.currentTable.replacingOccurrences(of: "<th>", with: "<th style=\"border: 2px solid #\(self.colourValues.head);padding: 12px;\">")
                        self.currentTable = self.currentTable.replacingOccurrences(of: "<td style=\"", with: "<td style=\"border: 2px solid #\(self.colourValues.head);padding: 12px;")
                        self.currentTable = self.currentTable.replacingOccurrences(of: "<td>", with: "<td style=\"border: 2px solid #\(self.colourValues.head);padding: 12px;\">")
                        
                        // Move the scanner back to face the final </table>
                        scanner.currentIndex = scanner.string.index(before: scanner.currentIndex)
#if DEBUG
                        NSLog("[TABLE] \(self.currentTable)")
#endif
                    }
                
                    // Process the new token by type
                    switch(token) {
                        /* Paragraph-level tags with context-sensitivity */
                        case "p":
                            // Inside another element? Set the style accordingly
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
                            insetLevel += 1
                            
                            // Add an indentation level if we need to
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
                            // ASSUMPTION PRE is ALWAYS followed by CODE (not in HTML, but in MD->HTML)
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
                    scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
                    
                    // Check for use of <br> within a parapgraph, not at the end of a line.
                    // If we find one, add an LB as there's no LF to replace
                    if tokenToApply == "br" && scanner.getNextCharacter(in: self.tokenString) != self.newLineSymbol {
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
                    
                    // Images have no content between token delimiters, or closing tags, so handle the styling here
                    // NOTE The image itself is inserted by `styleString()`.
                    if tokenToApply == "img" {
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
        
        var insetParaStyle: NSMutableParagraphStyle
        let styleName: String = String.init(format: "inset%02d", inset)
        if self.paragraphs[styleName] != nil {
            insetParaStyle = self.paragraphs[styleName]!
        } else {
            insetParaStyle = NSMutableParagraphStyle.init()
            insetParaStyle.lineSpacing = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
            insetParaStyle.paragraphSpacing = (self.paraSpacing >= 0.0 ? self.paraSpacing : 0.0)
            insetParaStyle.alignment = .left
            insetParaStyle.headIndent = 40.0 * CGFloat(inset) + headInset
            insetParaStyle.firstLineHeadIndent = 40.0 * CGFloat(inset) + firstInset
            
            let table: NSTextTable = NSTextTable.init()
            table.numberOfColumns = 1
            let block: NSTextTableBlock = NSTextTableBlock.init(table: table, startingRow: 0, rowSpan: 1, startingColumn: 0, columnSpan: 1)
            block.setValue(512.0, type: .absoluteValueType, for: .minimumWidth)
            block.setBorderColor(self.colours.head, for: .minX)
            insetParaStyle.textBlocks.append(block)
            
            self.paragraphs[styleName] = insetParaStyle
        }
        
        return insetParaStyle
    }
    
    
    internal func makeBlockquoteParagraphCell(_ inset: Int, _ cellString: String) {
        
        // Make sure we have an NSMutableAttributedString for the whole table...
        if self.blockAttStr == nil {
            self.blockAttStr = NSMutableAttributedString()
        }
        
        // ...and a table object
        if self.blockTable == nil {
            self.blockTable = NSTextTable()
            self.blockTable!.numberOfColumns = 1
            self.blockTable!.collapsesBorders = true
        }
        
        // Create the cell block
        let cellBlockColour: NSColor = self.useLightMode ? NSColor.init(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0) : NSColor.init(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        let cellblock = NSTextTableBlock(table: self.blockTable!, startingRow: inset - 1, rowSpan: 1, startingColumn: 0, columnSpan: 1)
        cellblock.setWidth(16.0, type: NSTextBlock.ValueType.absoluteValueType, for: NSTextBlock.Layer.border)
        cellblock.setWidth(10.0, type: NSTextBlock.ValueType.absoluteValueType, for: NSTextBlock.Layer.padding)
        cellblock.setBorderColor(cellBlockColour)
        cellblock.setBorderColor(self.colours.head!, for: .minX)
        cellblock.backgroundColor = cellBlockColour
        cellblock.verticalAlignment = .bottomAlignment
        
        // Set the cell text's parastyle
        let cellParagraphStyle = NSMutableParagraphStyle()
        cellParagraphStyle.alignment = .left
        cellParagraphStyle.lineSpacing = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        cellParagraphStyle.paragraphSpacing = (self.paraSpacing >= 0.0 ? self.paraSpacing : 0.0)
        cellParagraphStyle.headIndent = 50.0 * CGFloat(inset - 1)
        cellParagraphStyle.firstLineHeadIndent = 50.0 * CGFloat(inset - 1)
        cellParagraphStyle.textBlocks = [cellblock]
        
        // Generate an NSMutableAttributedString for the cell text using the above attributes...
        let cellAttributedString: NSMutableAttributedString = NSMutableAttributedString(string: cellString + self.newLineSymbol,
                                                                                        attributes: [.paragraphStyle: cellParagraphStyle,
                                                                                                     .foregroundColor: self.colours.quote!,
                                                                                                     .font: makeFont("strong", self.fontSize * H4_MULTIPLIER)])
        
        // ...and add it to the table NSMutableAttributedString
        self.blockAttStr!.append(cellAttributedString)
    }
    
    
    internal func makePlainCodeParagraph(_ codeString: String) -> NSMutableAttributedString {
        
        // Make the single paragraph style
        // TO-DO Cache for later usage
        let cellParagraphStyle = NSMutableParagraphStyle()
        cellParagraphStyle.alignment = .left
        cellParagraphStyle.lineSpacing = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        cellParagraphStyle.paragraphSpacing = (self.paraSpacing >= 0.0 ? self.paraSpacing : 0.0)
        cellParagraphStyle.textBlocks = [makeCodeParagraphCell()]
        
        // Return the plain code on the background block
        return NSMutableAttributedString(string: codeString,
                                         attributes: [.paragraphStyle: cellParagraphStyle,
                                                      .foregroundColor: self.colours.code!,
                                                      .font: makeFont("code", self.fontSize)])
    }
    
    
    internal func makeHighlightedCodeParagraph(_ attCodeString: NSMutableAttributedString) -> NSMutableAttributedString {
        
        // Make the single paragraph style
        // TO-DO Cache for later usage
        let cellParagraphStyle = NSMutableParagraphStyle()
        cellParagraphStyle.alignment = .left
        cellParagraphStyle.lineSpacing = 2.0
        cellParagraphStyle.paragraphSpacing = 0.0
        cellParagraphStyle.textBlocks = [makeCodeParagraphCell()]
        
        attCodeString.addAttributes([.paragraphStyle: cellParagraphStyle], 
                                    range: NSMakeRange(0, attCodeString.length))
        return attCodeString
    }
    
    
    internal func makeCodeParagraphCell() -> NSTextTableBlock {
        
        // Make a table for the block: it will be 1 x 1
        let paragraphTable = NSTextTable.init()
        paragraphTable.numberOfColumns = 1
        paragraphTable.collapsesBorders = true
        
        // Make the table's single cell
        let paragraphBlock = NSTextTableBlock(table: paragraphTable, startingRow: 0, rowSpan: 1, startingColumn: 0, columnSpan: 1)
        paragraphBlock.backgroundColor = self.useLightMode ? NSColor.init(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0) : NSColor.init(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        paragraphBlock.setWidth(5.0, type: NSTextBlock.ValueType.absoluteValueType, for: NSTextBlock.Layer.padding)
        return paragraphBlock
    }
    
    
    /**
        Generate an attributed string from an individual source string.
     
        - Parameters
            - plain     - The raw string.
            - styleList - The style stack.
     
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
                                    lineColour = self.colours.body
                                }
                                
                                attributes.updateValue(NSUnderlineStyle.single.rawValue as NSNumber, forKey: .underlineStyle)
                                attributes.updateValue(lineColour, forKey: .underlineColor)
                            }
                        case "strong":
                            // Check if the font used is italic. If not, flag we need to set the background color
                            if fontUsed == nil || (!fontUsed!.fontName.contains("Bold") && !fontUsed!.fontName.contains("Black") && !fontUsed!.fontName.contains("Heavy") && !fontUsed!.fontName.contains("Medium")) {
                                attributes.updateValue(self.colours.body, forKey: .backgroundColor)
                                attributes.updateValue(self.useLightMode ? NSColor.white : NSColor.black, forKey: .foregroundColor)
                            }
                        case "img":
                            if !self.isThumbnail {
                                var imageAttachment: NSTextAttachment
                                do {
                                    let wrapper: FileWrapper = try FileWrapper.init(url: URL.init(fileURLWithPath: self.currentImagePath), options: [.immediate])
                                    imageAttachment = NSTextAttachment.init(fileWrapper: wrapper)
                                } catch {
                                    NSLog("[ERROR] \(error.localizedDescription)")
                                    let baseImageName: String = self.useLightMode ? BUFFOON_CONSTANTS.IMG_PLACEHOLDER_LIGHT : BUFFOON_CONSTANTS.IMG_PLACEHOLDER_DARK
                                    imageAttachment = NSTextAttachment.init()
                                    if let image: NSImage = NSImage.init(named: NSImage.Name(stringLiteral: baseImageName)) {
                                        imageAttachment.image = image
                                    }
                                }
                                
                                /*
                                 let baseImageName: String = self.useLightMode ? BUFFOON_CONSTANTS.IMG_PLACEHOLDER_LIGHT : BUFFOON_CONSTANTS.IMG_PLACEHOLDER_DARK
                                if let image: NSImage = NSImage.init(contentsOfFile: self.currentImagePath) {
                                    imageAttachment.image = image
                                } else if let image: NSImage = NSImage.init(named: NSImage.Name(stringLiteral: baseImageName)) {
                                    imageAttachment.image = image
                                }
                                */
                                let imageAttString = NSMutableAttributedString(attachment: imageAttachment)
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
            // No style list provided? Just return the plain string
            returnString = NSMutableAttributedString(string: plainText, attributes: self.styles["p"])
        }

        return returnString
    }
    
    
    // MARK: - Data Initialisation Functions
    /**
        At the start of a rendering run, set up all the base styles we will need.
     */
    internal func generateStyles() {
        
        // Prepare the fonts we'll use
        prepareFonts()
        
        // Set the paragraph styles
        // Base paragraph style: No left inset
        let tabbedParaStyle: NSMutableParagraphStyle    = NSMutableParagraphStyle()
        tabbedParaStyle.lineSpacing                     = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        tabbedParaStyle.paragraphSpacing                = (self.paraSpacing >= 0.0 ? self.paraSpacing : 0.0)
        tabbedParaStyle.alignment                       = .left
        tabbedParaStyle.tabStops                        = [NSTextTab(textAlignment: .left, location: 30.0, options: [:]),
                                                           NSTextTab(textAlignment: .left, location: 60.0, options: [:])]
        tabbedParaStyle.defaultTabInterval              = 30.0
        self.paragraphs["tabbed"]                       = tabbedParaStyle
        
        /* Inset paragraph style for PRE
        let insetParaStyle: NSMutableParagraphStyle     = NSMutableParagraphStyle()
        insetParaStyle.lineSpacing                      = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        insetParaStyle.paragraphSpacing                 = (self.paraSpacing >= 0.0 ? self.paraSpacing : 0.0)
        insetParaStyle.alignment                        = .left
        insetParaStyle.headIndent                       = 40.0
        insetParaStyle.firstLineHeadIndent              = 40.0
        insetParaStyle.defaultTabInterval               = 40.0
        insetParaStyle.tabStops                         = []
        self.paragraphs["inset"]                        = insetParaStyle
        */
        
        // Nested list
        let listParaStyle: NSMutableParagraphStyle      = NSMutableParagraphStyle()
        listParaStyle.lineSpacing                       = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        listParaStyle.paragraphSpacing                  = (self.paraSpacing >= 0.0 ? self.paraSpacing : 0.0)
        listParaStyle.alignment                         = .left
        listParaStyle.headIndent                        = 56.0
        listParaStyle.firstLineHeadIndent               = 40.0
        self.paragraphs["list"]                         = listParaStyle
        
        //  HR paragraph
        let lineParaStyle: NSMutableParagraphStyle      = NSMutableParagraphStyle()
        lineParaStyle.lineSpacing                       = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        lineParaStyle.paragraphSpacing                  = (self.paraSpacing >= 0.0 ? self.paraSpacing : 0.0)
        lineParaStyle.alignment                         = .left
        lineParaStyle.tabStops                          = [NSTextTab(textAlignment: .right, location: 120.0, options: [:])]
        self.paragraphs["line"]                         = lineParaStyle
        
        // Set the colours
        self.colours.head  = Styler.colourFromHexString(self.colourValues.head)
        self.colours.code  = Styler.colourFromHexString(self.colourValues.code)
        self.colours.link  = Styler.colourFromHexString(self.colourValues.link)
        self.colours.quote = Styler.colourFromHexString(self.colourValues.quote)
        self.colours.body  = self.bodyColour
        
        /* Paragraph styles */
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
        
        /* Character styles */
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
        self.styles["kbd"]          = [.foregroundColor: self.colours.body,
                                       .underlineColor: useLightMode ? NSColor.black : NSColor.white,
                                       .underlineStyle: NSUnderlineStyle.double.rawValue as NSNumber,
                                       .font: makeFont("strong", self.fontSize)]
        
        // S
        self.styles["s"]            = [.strikethroughStyle: NSUnderlineStyle.single.rawValue as NSNumber,
                                       .strikethroughColor: self.colours.body]
        
        // SUB
        self.styles["sub"]          = [.font: makeFont("plain", self.fontSize / 1.5),
                                       .baselineOffset: -1.0 as NSNumber]
        
        self.styles["sup"]          = [.font: makeFont("plain", self.fontSize / 1.5),
                                       .baselineOffset: 10.0 as NSNumber]
        
        /* Block styles */
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
    }


    /**
        Determine what styles are available for the chosen body font,
        whihc is set by the calling code (as is the base font size).
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
        }
    }
    
    
    /**
        Generate a specific font to match the specified style and size.
     
        - Parameters
            - fontStyle - The style, eg. `strong`.
            - size      - The point size.
     
        - Returns The NSFont, or nil on error.
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
                if let styles: [PMFont] = self.bodyFontFamily.styles {
                    for styleName: String in ["Bold", "Black", "Heavy", "Medium", "Semi-Bold"]{
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
                
                let fm: NSFontManager = NSFontManager.shared
                if let font: NSFont = fm.font(withFamily: self.bodyFontFamily.displayName,
                                              traits: .boldFontMask,
                                              weight: 10,
                                              size: size) {
                    recordFont(requiredStyle, size, font)
                    return font
                }
                
                // Still no font? Fall back to the base body font
                
            case "em":
                // Try to get an actual italic font
                if let styles: [PMFont] = self.bodyFontFamily.styles {
                    for styleName: String in ["Italic", "Oblique"] {
                        // Any other italic style names to consider?
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
                
                let fm: NSFontManager = NSFontManager.shared
                if let font: NSFont = fm.font(withFamily: self.bodyFontFamily.displayName,
                                              traits: .italicFontMask,
                                              weight: 5,
                                              size: size) {
                    recordFont(requiredStyle, size, font)
                    return font
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
    
    
    internal func recordFont(_ style: String, _ size: CGFloat, _ font: NSFont?) {
        
        var fontRecord: FontRecord = FontRecord()
        fontRecord.style = style
        fontRecord.size = size
        fontRecord.font = font
        self.fonts.append(fontRecord)
    }
    
    
    static func colourFromHexString(_ colourValue: String) -> NSColor {
        
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


// MARK: - Extensions

extension Scanner {
    
    func getNextCharacter(in outer: String) -> String {
        
        let string: NSString = self.string as NSString
        let idx: Int = self.currentIndex.utf16Offset(in: outer)
        let nextChar: String = string.substring(with: NSMakeRange(idx, 1))
        return nextChar
    }
}


extension CGFloat {

    func isClose(to value: CGFloat) -> Bool {
        let absA: CGFloat = abs(self)
        let absB: CGFloat = abs(value)
        let diff: CGFloat = abs(self - value)
        
        if self == value {
            return true
        } else if self == .zero || value == .zero || (absA + absB) < Self.leastNormalMagnitude {
            return diff < Self.ulpOfOne * Self.leastNormalMagnitude
        } else {
            return (diff / Self.minimum(CGFloat(absA + absB), Self.greatestFiniteMagnitude)) < .ulpOfOne
        }
    }
}
