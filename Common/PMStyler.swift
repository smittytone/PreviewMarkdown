/*
 *  PMStyler.swift
 *  Convert a tokenised string into an NSAttributedString.
 *
 *  Created by Tony Smith on 23/09/2020.
 *  Copyright © 2025 Tony Smith. All rights reserved.
 */


import AppKit
import Highlighter


class PMStyler {
    
    // MARK: - Publicly accessible properties
    
    var fontSize: CGFloat                                               = 24.0
    var lineSpacing: CGFloat                                            = BUFFOON_CONSTANTS.BASE_LINE_SPACING
    var paraSpacing: CGFloat                                            = 18.0
    //var viewWidth: CGFloat                                              = 1024.0
    var bodyFontName: String                                            = "SF Pro"
    var codeFontName: String                                            = "Menlo"
    var workingDirectory: String                                        = "/Users/"
    var bodyColour: NSColor                                             = .labelColor
    var colourValues: ColourValues                                      = ColourValues()
    var presentForLightMode: Bool                                       = false
    var doLoadWebContent: Bool                                          = false


    // MARK: - Private properties with defaults
    
    private  var isThumbnail: Bool                                      = false
    internal var tokenString: String                                    = ""
    private  var outputString: String                                   = ""
    private  var currentLink: String                                    = ""
    private  var currentImagePath: String                               = ""
    private  var currentLanguage: String                                = ""
    private  var currentTable: String                                   = ""
    private  var styles: [String: [NSAttributedString.Key: AnyObject]]  = [:]
    private  var paragraphs: [String : NSMutableParagraphStyle]         = [:]
    private  var fonts: [FontRecord]                                    = []
    private  var bodyFontFamily: PMFont                                 = PMFont()
    private  var colours: Colours                                       = Colours()
    private  var highlighter: Highlighter?                              = nil


    // MARK: - Constants
    
    // Headline size vs body font size scaler values
    private let H1_MULTIPLIER: CGFloat                                  = 2.6
    private let H2_MULTIPLIER: CGFloat                                  = 2.2
    private let H3_MULTIPLIER: CGFloat                                  = 1.8
    private let H4_MULTIPLIER: CGFloat                                  = 1.4
    private let H5_MULTIPLIER: CGFloat                                  = 1.2
    private let H6_MULTIPLIER: CGFloat                                  = 1.2
    private let LIST_INSET_BASE: CGFloat                               = 50.0
    private let BLOCK_INSET_BASE: CGFloat                              = 50.0
    
    private let HTML_TAG_START: String                                  = "<"
    private let HTML_TAG_END: String                                    = ">"
    
#if PARASYM
    private let LINE_BREAK_SYMBOL: String                               = "†\u{2028}"
    private let LINE_FEED_SYMBOL: String                                = "¶\u{2029}"
#else
    private let LINE_BREAK_SYMBOL: String                               = "\u{2028}"
    private let LINE_FEED_SYMBOL: String                                = "\u{2029}"
#endif
    private let NEW_LINE_SYMBOL: String                                 = "\n"
    private let WINDOWS_LINE_SYMBOL: String                             = "\n\r"
    
    private let APPLIED_TAGS: [String]                                  = ["p", "a", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "code", "kbd", "em",
                                                                           "strong", "blockquote", "s", "img", "li", "sub", "sup"]
    private let BULLET_STYLES: [String]                                 = ["\u{25CF}", "\u{25CB}", "\u{25A0}", "\u{25A1}", "\u{25C6}", "\u{25C7}"]
    private let HTML_ESCAPE_REGEX: NSRegularExpression                  = try! NSRegularExpression(pattern: "&#?[a-zA-Z0-9]+?;", options: .caseInsensitive)


    // MARK: - Rendering Functions
    
    /**
        Render the class' `tokenString` property.
     
        - Parameters
            - tokenString:               The tokenised string we'll use to render an NSAttributedString.
            - isThumbnail:               Are we rendering text for thumbnail use? Default : `false`.
            - useLightColoursInDarkMode: Present previews in light colours, irrespective of mode. Default : `false`.
        
        - Returns NSAttributedString or `nil` or error.
     */
    public func render(_ tokenString: String, _ isThumbnail: Bool = false, _ useLightColoursInDarkMode: Bool = false) -> NSAttributedString? {
        
        // Check we have an tokened string to render.
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
        var isListItem: Bool                = false // Add a bullet or not
        var isBlockquote: Bool              = false
        var isPre: Bool                     = false
        
        var blockLevel: Int                 = 0
        var insetLevel: Int                 = 0
        
        var orderedListCounts: [Int]        = Array(repeating: 0, count: 12)
        var listTypes: [ListType]           = Array(repeating: .bullet, count: 12)
        var isListNested: [Bool]            = Array(repeating: false, count: 12)
        
        var previousCloseToken: String      = ""
        
        // Font-less horizontal rule
        let hr: NSAttributedString          = NSAttributedString(string: "\u{00A0} \u{0009} \u{00A0}\n",
                                                                 attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                                                                              .strikethroughColor: self.colours.body!,
                                                                              .paragraphStyle: self.paragraphs["line"]!])

        // Set up the Style stack
        var styleStack: [Style] = []
        styleStack.append(Style())
        
        // Perform pre-processing:
        // 1. Convert checkboxes, eg `[] checkbox`, `[x] checkbox`
        processCheckboxes()
        
        // 2. Convert Windows LFCR line endings and remove unwanted New Lines
        self.tokenString = self.tokenString.replacingOccurrences(of: self.WINDOWS_LINE_SYMBOL, with: "")
        
        // Render the HTML
        var prefixWidth: CGFloat = 0.0
        var scanned: String? = nil
        let scanner: Scanner = Scanner(string: self.tokenString)
        scanner.charactersToBeSkipped = nil
        
#if INCHTML
        let renderedString: NSMutableAttributedString = NSMutableAttributedString(string: self.tokenString + "\n", attributes: self.styles["p"])
        renderedString.append(hr)
#else
        let renderedString: NSMutableAttributedString = NSMutableAttributedString(string: "", attributes: self.styles["p"])
#endif
        // Iterate over the stored tokenised string
        while !scanner.isAtEnd {
            // Scan up to the next token delimiter
            scanned = scanner.scanUpToString(self.HTML_TAG_START)
            
            // MARK: Content Processing
            // Have we got content (ie. text between tags or right at the start) to style? Do so now.
            if var content = scanned, !content.isEmpty {
                var listItemPrefix: String = ""
                
                // Should we add a bullet or numeral from an LI tag?
                if isListItem {
                    // Text immediately following the LI - it's a single-line item.
                    isListItem = false
                    
                    // Process the list item to set the prefix
                    if listTypes[insetLevel] == .bullet {
                        // Add a standard bullet. We set six types and we cycle around
                        // when the indent level is greater than that that number.
                        var index: Int = insetLevel
                        while index > self.BULLET_STYLES.count {
                            index -= self.BULLET_STYLES.count
                        }
                        
                        if index < 1 {
                            index = 1
                        }
                        
                        listItemPrefix = "\(self.BULLET_STYLES[index - 1]) "
                    } else {
                        // Add a numeral. The value was calculated when we encountered the initial LI
                        listItemPrefix = "\(orderedListCounts[insetLevel]). "
                    }
                    
                    // Set the paragraph style with the current indent based on P style
                    prefixWidth = (listItemPrefix as NSString).size(withAttributes: self.styles["p"]).width
                }
                
                // Pre-formatted lines (ie. code) should be presented as a single paragraph with inner
                // line breaks, so convert the content block's paragraph breaks (\n) to
                // NSAttributedString-friendly line-break codes.
                if isPre && !self.isThumbnail {
                    let indent = insetLevel + blockLevel
                    renderedString.append(renderCode(content, indent))
                    content = ""
                }
                
                // Blockquotes should be styled with the current indent
                if isBlockquote {
                    // Just make a block cell for the current inset.
                    // The whole block will be rendered at the final </block>
                    self.styles["blockquote"]?[.paragraphStyle] = makeBlockParagraphStyle(insetLevel + blockLevel)
                }
                
                // Nested paragraphs (P tags under LIs) need special handling. The first paragraph (ie.
                // the one with the list prefix) is run on from the prefix; following paragraphs are
                // inset to the same level.
                if insetLevel > 0 {
                    // Add a suitable indented para spec to the LI style, inset as a multiple of 50pt
                    self.styles["li"]?[.paragraphStyle] = makeInsetParagraphStyle(insetLevel,
                                                                                  listItemPrefix.isEmpty ? prefixWidth : 0.0,
                                                                                  prefixWidth)
                }

                // Style the content if we have some
                if !content.isEmpty {
                    if listItemPrefix.count > 0 {
                        renderedString.append(NSMutableAttributedString(attributedString: styleString(listItemPrefix + content, styleStack)))
                    } else {
                        // Style all other non-list content
                        renderedString.append(styleString(content, styleStack))
                    }
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
                if let closeToken: String = scanner.scanUpToString(self.HTML_TAG_END) {
#if DEBUG
                    NSLog("[TOKEN] <- \(closeToken)")
#endif
                    // NOTE mdit generates lowercase HTML tags, but we should probably not assume that
                    
                    // Should we add a carriage return at the end of the line?
                    var doAddNewLine: Bool = true
                    
                    // Is the token one that adds a style to the stack?
                    // This so we don't pull a style from the stack in these cases
                    // NOTE BLOCKQUOTE, OL, UL and PRE do not
                    var isStackOp: Bool = true
                    
                    // Process the closing token by type
                    switch(closeToken) {
                        /* General paragraph */
                        case "p":
                            break
                        /* Ordered or unordered lists */
                        case "ol":
                            // Reset the current level's inset count
                            orderedListCounts[insetLevel] = 0
                            fallthrough
                        case "ul":
                            // Reduce the inset level
                            isListNested[insetLevel] = false
                            insetLevel -= 1
                            if insetLevel <= 0 {
                                insetLevel = 0
                                self.styles["li"]?[.paragraphStyle] = self.paragraphs["list"]!
                            }
                            
                            // No style stacked for these
                            isStackOp = false
                        /* List items */
                        case "li":
                            // If the current list contains nested items, eg. Ps,
                            // don't append a CR. Only do so if there is no nesting,
                            // ie. on simple list items
                            if isListNested[insetLevel] {
                                doAddNewLine = false
                                isListNested[insetLevel] = false
                            }
                        /* Blocks */
                        case "blockquote":
                            // Reduce the inset level
                            blockLevel -= 1
                            if blockLevel <= 0 {
                                blockLevel = 0
                                isBlockquote = false
                                self.styles["blockquote"]?[.paragraphStyle] = self.paragraphs["quote"]!
                            }
                            
                            // No style stacked for these
                            isStackOp = false
                        case "pre":
                            // Clear the current language
                            self.currentLanguage = ""
                            isPre = false
                            
                            // No style stacked for these
                            isStackOp = false
                        /* Tables */
                        case "table":
                            // Render the table here after detecting table end
                            renderedString.append(renderTable(self.currentTable))
                        default:
                            break
                    }

                    // Step over the token delimiter
                    scanner.skipNextCharacter()
                    
                    // Pop the last style
                    if styleStack.count > 0 && isStackOp {
                        // Get the style at the top of the stack...
                        let currentParagraphStyle = styleStack.removeLast()
#if DEBUG
                        print("[STACK] pulled \(currentParagraphStyle.name) (count: \(styleStack.count))")
#endif

                        // Add a tailing New Line if we need one after the para (only in certain cases)
                        if doAddNewLine && currentParagraphStyle.type != .character {
#if PARATAG
                            renderedString.append(NSMutableAttributedString(attributedString: styleString(">"+self.LINE_FEED_SYMBOL, [currentParagraphStyle])))
#else
                            renderedString.append(NSMutableAttributedString(attributedString: styleString(self.LINE_FEED_SYMBOL, [currentParagraphStyle])))
#endif
                        }
                    }
                    
                    // Record the tag we've just processed, provided it's not related to a character style
                    if !["strong", "b", "em", "i", "a", "s", "img", "code", "kbd"].contains(closeToken) {
                        previousCloseToken = closeToken
                    }
                }
            } else {
                // MARK: Opening Token
                // We've got a new token, so get it up to the delimiter
                if let openToken: String = scanner.scanUpToString(self.HTML_TAG_END) {
                    // NOTE mdit generates lowercase HTML tags, but we should probably not assume that
                    var token: String = openToken.lowercased()
                    
                    // This is the tag we will use to format the content. It may not
                    // be the actual tag detected, eg. for LI- or BLOCKQUOTE-nested Ps we use LI or BLOCK
                    var tokenToApply: String = token
                    
                    // In special circumstances we need to add a New Line to the output.
                    // This is the flag we set to do so
                    var doAddNewLineFirst = false
                    
                    /* Handle certain tokens outside of the switch statement
                       because the raw tokens contain extra, non-comparable text
                     */
                    
                    // Check for a link. If we have one, get the destination and
                    // record it for processing later
                    if token.hasPrefix("a") {
                        // We have a link -- get the destination from HREF
                        tokenToApply = "a"
                        self.currentLink = getLinkRef(openToken)
                    }
                    
                    // Check for an image. If we have one, get the source and
                    // record it for processing later
                    if token.hasPrefix("img") {
                        // TO-DO Do we want to retain the ALT tag?
                        tokenToApply = "img"
                        self.currentImagePath = getImageRef(token)
                    }
                    
                    // Look for a language specifier. If one exists, get it
                    // and retain it for processing later
                    if token.contains("code class") {
                        tokenToApply = "code"
                        self.currentLanguage = getCodeLanguage(token)
                    }
                    
                    // Look for ol start="x" which indicates use of a fixed starting
                    // point for a numbered list
                    var numberedListStart = 0
                    if token.contains("ol start") {
                        numberedListStart = getListStart(token) - 1
                        if numberedListStart < 0 { numberedListStart = 0 }
                        token = "ol"
                    }
                    
                    // Check for a table. If we have one, grab the whole of it up to the terminating token
                    if token.hasPrefix("table") {
                        tokenToApply = "none"
                        scanner.skipNextCharacter()
                        self.currentTable = getTable(scanner.scanUpToString("</table>"))

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
                                if insetLevel > 0 {
                                    isListNested[insetLevel] = true
                                }
                            } else if insetLevel > 0 {
                                tokenToApply = "li"
                                isListNested[insetLevel] = true
                            }
                            /* Ordered or unordered lists and items */
                        case "ul":
                            fallthrough
                        case "ol":
                            // Set the list type
                            let listItem: ListType = token == "ul" ? .bullet : .number
                            
                            // Increment the indentation level and add the bullet and number counts to the stack
                            insetLevel += 1
                            if insetLevel == listTypes.count {
                                listTypes.append(listItem)
                                orderedListCounts.append(numberedListStart)
                            } else {
                                listTypes[insetLevel] = listItem
                                orderedListCounts[insetLevel] = numberedListStart
                            }
                            
                            // Handle adjacent lists by adding a spacer between them.
                            // Handle sub-lists by adding a spacer between them, but ONLY if the
                            // parently list contains nested items
                            if insetLevel > 1 && !isListNested[insetLevel - 1] || previousCloseToken == "ul" || previousCloseToken == "ol" {
                                doAddNewLineFirst = true
                            }
                            
                            // Mark the parent list as containing nested items.
                            // This ensures correct line-breaking when the parent items's </LI> tag is found
                            isListNested[insetLevel - 1] = true
                        case "li":
                            // NOTE mdit has two LI modes: simple and nested.
                            //      Simple (short) text is placed immediately after the tag;
                            //      Long or multi-para text is place in paragraphs between
                            //      the LI tags
                            
                            // Mark that we need the subsequent content prefixed with a bullet or a numeral
                            isListItem = true
                            
                            // Increment the numeric list item, if we're in an OL
                            if listTypes[insetLevel] == .number {
                                orderedListCounts[insetLevel] += 1
                            }
                            /* Blocks openers */
                        case "blockquote":
                            isBlockquote = true
                            blockLevel += 1
                            tokenToApply = "none"   // Don't push style to stack
                        case "pre":
                            // ASSUMPTION PRE is ALWAYS followed by CODE (not in HTML, but certainly in MD->HTML)
                            isPre = true
                            tokenToApply = "none"   // Don't push style to stack
                            /* Tokens that can be handled immediately */
                        case "hr":
                            renderedString.append(hr)
                        case "br/":
                            // Trap <BR/> in embedded HTML
                            fallthrough
                        case "br /":
                            // Trap <BR /> in embedded HTML
                            tokenToApply = "br"
                            /* Character-level tokens */
                        case "i":
                            // Trap <I> tags in embedded HTML
                            tokenToApply = "em"
                        case "b":
                            // Trap <B> tags in embedded HTML
                            tokenToApply = "strong"
                        default:
                            // Covers all other tags, including headers: do nothing
                            break
                    }
                    
#if DEBUG
                    NSLog("[TOKEN] Found \(token), use as \(tokenToApply)")
#endif
                    
                    // Compare the tag to use with those we apply.
                    // Some, such as list markers, we do not style here
                    if self.APPLIED_TAGS.contains(tokenToApply) {
                        // Push the tag's style to the stack
                        let style: Style = Style()
                        style.name = tokenToApply
                        
                        // Set character styles (inherit style from parent)
                        if ["strong", "em", "a", "s", "img", "sub", "sup", "code", "kbd"].contains(tokenToApply) {
                            style.type = .character
                            
                            // Handle paragraph-level code, ie. code blocks not inlines
                            if tokenToApply == "code" && isPre {
                                style.type = .paragraph
                            }
                        }
                        
                        // Set other styles -- default is `.paragraph`
                        if tokenToApply == "li" {
                            style.type = .indent
                        }
                        
                        // Push the new style onto the stack
                        styleStack.append(style)
#if DEBUG
                        print("[STACK] pushed \(style.name) (count: \(styleStack.count))")
#endif
                    }
                    
                    // Step over the token's delimiter
                    scanner.skipNextCharacter()
                    
                    // Check for use of <br> within a paragraph, not at the end of a line.
                    // If we find one, add an LB as there's no LF to replace
                    if tokenToApply == "br" {
                        addNewLine(renderedString, withLineBreak: true)
                    }
                    
                    // Add a New Line before the content if we need to
                    if doAddNewLineFirst {
                        addNewLine(renderedString)
                    }
                
                    // Images have no content between token delimiters, or closing tags, so handle the styling here
                    // NOTE The image itself is inserted by `styleString()`.
                    if tokenToApply == "img" {
                        renderedString.append(styleString("", styleStack))
                        // Remove the IMG style added above
                        styleStack.removeLast()
                    }
                }
            }
            
            scanned = nil
        }
        
        // We have composed the string. Now process HTML escapes not already addressed
        let results: [NSTextCheckingResult] = self.HTML_ESCAPE_REGEX.matches(in: renderedString.string,
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
        
        // Hand back the rendered text
        return renderedString
    }


    /**
     Generate an attributed string from an individual source string by iterating through
     the style stack and applying each.

     - Parameters
        - plainText: The raw string.
        - styleList: The style stack to apply. It's a param so that we can apply
                     arbitrary stacks.

     - Returns An attributed string.
     */
    internal func styleString(_ plainText: String, _ styleList: [Style]) -> NSMutableAttributedString {

        if styleList.count > 0 {
            // Assemble the attributes from the style list, including the font
            var attributes = [NSAttributedString.Key: AnyObject]()
            var parentStyle: Style = Style()

            // Iterate over the stack, applying the style one after the other,
            // the most recent stack item last. We update attributes, so a newer
            // style can override an earlier one
            for style in styleList {
                var fontUsed: NSFont? = nil
                if let styles = self.styles[style.name] {
                    for (attributeName, attributeValue) in styles {
                        attributes.updateValue(attributeValue, forKey: attributeName)
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
                            // Check if we have an italic font. If not, we underline the text
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
                            // Check if we have a bold font. If not, flag we set a background behind the text
                            if fontUsed == nil || (!fontUsed!.fontName.contains("Bold") && !fontUsed!.fontName.contains("Black") && !fontUsed!.fontName.contains("Heavy") && !fontUsed!.fontName.contains("Medium")) {
                                attributes.updateValue(self.colours.body, forKey: .backgroundColor)
                                attributes.updateValue(NSColor.previewBackground, forKey: .foregroundColor)
                            }
                        case "img":
                            // Don't show images in thumbnails; in previews load the image
                            // in as an attachment. This doesn't currently work due to macOS
                            // sandbox limitations, alas
                            if !self.isThumbnail {
                                return loadImage()
                            }
                        default:
                            break
                    }
                } else {
                    parentStyle = style
                }
            }

            // Return the styled text
            return NSMutableAttributedString(string: plainText, attributes: attributes)
        }

        // No style list provided? Just return the plain string formatted for body text
        return NSMutableAttributedString(string: plainText, attributes: self.styles["p"])
    }


    // MARK: - Value Extraction Functions

    /**
     Get a URL or path embedded in an A HREF tag.
     
     - Parameters
        - tag: The full token, eg. `a href="https://smittytone.net"`

     - Returns The embedded URL.
     */
    internal func getLinkRef(_ tag: String) -> String {

        return splitTag(tag)
    }


    /**
     Get a URL or path embedded in an IMG SRC tag.
     
     - Parameters
         - tag: The full token, eg. `img src="/Users/smitty/emu/monitor_main.png"`

     - Returns The embedded path.
     */
    internal func getImageRef(_ tag: String) -> String {

        let basePath = splitTag(tag)
        if basePath.hasPrefix("http") {
            return basePath
        }

        return getFullPath(basePath)
    }


    /**
     Get the software languges in an CODE CLASS tag.
     
     - Parameters
         - tag: The full token, eg. `code class="language-swift"`

     - Returns The language.
     */
    internal func getCodeLanguage(_ tag: String) -> String {

        let parts: [String] = splitTag(tag).components(separatedBy: "-")
        if parts.count > 0 {
            return parts[1]
        }

        return parts[0]
    }


    /**
     Get the numbered list start value in an OL START tag.
     
     - Parameters
        - tag: The full token, eg. `ol start="20"`

     - Returns The count start value as an integer.
     */
    internal func getListStart(_ tag: String) -> Int {
        
        let parts: [String] = splitTag(tag).components(separatedBy: "\"")
        return Int(parts[0]) ?? 0
    }


    /**
     Extract a table we have found, format it using HTML (we will use NSAttributedString's HTML
     parsing later to convert it) and set the current table string.
     
     - Parameters
         - tableCode: The table HTML from the processed markdown.
     */
    private func getTable(_ tableCode: String?) -> String {

        // Get the table content and style it: set it up with a coloured border around table and cells
        var table: String = "<table width=\"200%\" style=\"border-collapse:collapse;\">"

        guard let code = tableCode else {
            table += "<tr><td>Malformed table</td></tr></table>\n"
            return table
        }
        
        table += code + "</table>\n\n"

        // Set the style for all the table cells, including header cells, retaining any existing
        // styling (typically `text-align`)
        table = table.replacingOccurrences(of: "<th style=\"", with: "<th style=\"border:0.5px solid #444444;padding:12px;")
        table = table.replacingOccurrences(of: "<th>", with: "<th style=\"border:0.5px solid #444444;padding:12px;\">")
        table = table.replacingOccurrences(of: "<td style=\"", with: "<td style=\"border:0.5px solid #444444;padding:12px;")
        table = table.replacingOccurrences(of: "<td>", with: "<td style=\"border:0.5px solid #444444;padding:12px;\">")

        // HACK Remove weird space char inserted by MarkdownIt in place of &nbsp;
        table = table.replacingOccurrences(of: " ", with: " ")
        return table
    }
    
    
    // MARK: - Paragraph Generation Functions
    
    /**
     Prepare a paragraph inset to the requested depth.
     
     - Parameters
        - inset:      The indentation factor. This is multiplied by LIST_INSET_BASE points.
        - headInset:  Any offset to apply to the whole para other than line 1. Default: 0.0.
        - firstInset: Any offset to apply to the first line. Default: 0.0, ie. matches the para as whole.
     
     - Returns The inset NSParagraphStyle.
     */
    internal func makeInsetParagraphStyle(_ inset: Int, _ first: CGFloat = 0.0, _ rest: CGFloat = 0.0) -> NSMutableParagraphStyle {

        let styleName: String = String(format: "inset%02d-%03.02f-%03.02f", inset, first, rest)

        if self.paragraphs[styleName] != nil {
            return self.paragraphs[styleName]!
        }

        let newParaStyle: NSMutableParagraphStyle = makeBaseParagraphStyle(styleName)
        newParaStyle.headIndent = rest + (self.LIST_INSET_BASE * CGFloat(inset))
        newParaStyle.firstLineHeadIndent = first + (self.LIST_INSET_BASE * CGFloat(inset))
        return newParaStyle
    }


    /**
     Prepare a block paragraph inset to the requested depth.
     
     - Parameters
        - inset: The indentation factor. This is multiplied by BLOCK_INSET_BASE points.
     
     - Returns The inset NSParagraphStyle.
     */
    internal func makeBlockParagraphStyle(_ inset: Int) -> NSMutableParagraphStyle {
        
        let styleName: String = String(format: "block%02d", inset)
        
        if self.paragraphs[styleName] != nil {
            return self.paragraphs[styleName]!
        }

        let newParaStyle: NSMutableParagraphStyle = makeBaseParagraphStyle(styleName)
        newParaStyle.headIndent = self.BLOCK_INSET_BASE * CGFloat(inset)
        newParaStyle.firstLineHeadIndent = newParaStyle.headIndent
        return newParaStyle
    }


    /**
     Create a generic inset/block paragraph style.

     - Parameters
        - name: The style name to record.

     - Returns A base MutableParagraphStyle ready for adding insets.
     */
    internal func makeBaseParagraphStyle(_ name: String) -> NSMutableParagraphStyle {

        let table: NSTextTable = NSTextTable()
        table.numberOfColumns = 1

        let block: NSTextTableBlock = NSTextTableBlock(table: table, startingRow: 0, rowSpan: 1, startingColumn: 0, columnSpan: 1)
        block.setValue(512.0, type: .absoluteValueType, for: .minimumWidth)

        let newParaStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
        newParaStyle.lineSpacing = self.lineSpacing
        newParaStyle.paragraphSpacing = self.paraSpacing
        newParaStyle.alignment = .left
        newParaStyle.textBlocks.append(block)
        self.paragraphs[name] = newParaStyle
        return newParaStyle
    }


    /**
     Generate a generic code paragraph style.

     - Parameters
        - inset: Any inset level to apply.

     - Returns The paragraph style.
     */
    internal func makeCodeParagraphStyle(_ inset: Int = 0) -> NSMutableParagraphStyle {

        // Make the single paragraph style
        // TO-DO Cache for later usage
        let newParaStyle = NSMutableParagraphStyle()
        newParaStyle.lineSpacing = self.lineSpacing
        newParaStyle.paragraphSpacing = self.paraSpacing
        newParaStyle.alignment = .left
        newParaStyle.textBlocks.append(makeCodeParagraphBlock(inset))
        newParaStyle.firstLineHeadIndent = CGFloat(inset) * 40.0
        newParaStyle.headIndent = CGFloat(inset) * 40.0

        return newParaStyle
    }


    /**
     Create a styled string containing plain text code or just plain text
     set against a background. This is typically for PRE and PRE+CODE
     structures.
     
     - Parameters
         - plainCode: The plain text code.
         - inset:     Any inset level to apply.

     - Returns The assembled paragraph as an attributed string.
     */
    internal func makePlainCodeParagraph(_ plainCode: String, _ inset: Int) -> NSMutableAttributedString {
        
        // Make the single paragraph style
        let cellParagraphStyle = makeCodeParagraphStyle(inset)
        
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
        - inset:           Any inset level to apply.

     - Returns The assembled paragraph as an attributed string.
     */
    internal func makeHighlightedCodeParagraph(_ highlightedCode: NSMutableAttributedString, _ inset: Int = 0) -> NSMutableAttributedString {
        
        let cellParagraphStyle = makeCodeParagraphStyle(inset)
        highlightedCode.addAttributes([.paragraphStyle: cellParagraphStyle],
                                      range: NSMakeRange(0, highlightedCode.length))
        return highlightedCode
    }


    /**
     Generate a single table block for presenting code of any kind.

     - Parameters
        - inset: Any inset level to apply.

     - Returns A text table block.
     */
    internal func makeCodeParagraphBlock(_ inset: Int = 0) -> NSTextTableBlock {
        
        // Make a table for the block: it will be 1 x 1
        let paragraphTable = NSTextTable()
        paragraphTable.numberOfColumns = 1
        paragraphTable.collapsesBorders = true
        
        // Make the table's single cell
        let paragraphBlock = NSTextTableBlock(table: paragraphTable, startingRow: 0, rowSpan: 1, startingColumn: 0, columnSpan: 1)
        paragraphBlock.backgroundColor = .previewCode
        paragraphBlock.setWidth(8.0, type: .absoluteValueType, for: .padding)
        return paragraphBlock
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


    /**
     Use NSMutableAttributedString to convert the current HTML table.
     
     - Returns The table as an NSMutableAttributedString, or an empty NSMutableAttributedString.
     */
    private func renderTable(_ table: String) -> NSMutableAttributedString {

        if let data: Data = table.data(using: .utf16) {
            if let tableString: NSMutableAttributedString = NSMutableAttributedString(html: data, documentAttributes: nil) {
                // Now we have to set our font style for each element within the table
                tableString.enumerateAttribute(.font, in: NSMakeRange(0, tableString.length)) { (value: Any?, range: NSRange, got: UnsafeMutablePointer<ObjCBool>) in
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
                        tableString.addAttribute(.font, value: cellFont, range: range)
                        tableString.addAttribute(.foregroundColor, value: self.colours.body!, range: range)
                    }
                }

                return tableString
            }
        }

        return NSMutableAttributedString()
    }


    /**
     Formmat a code string for presentation.
     
     - Parameters
        - someCode: The raw code.
     
     - Returns The code presented as an NSAttributedString block.
     */
    private func renderCode(_ someCode: String, _ inset: Int) -> NSAttributedString {
        
        // Tidy up the code
        let code = someCode.trimmingCharacters(in: .newlines).replacingOccurrences(of: self.NEW_LINE_SYMBOL, with: self.LINE_BREAK_SYMBOL)

        if !self.currentLanguage.isEmpty {
            // Have we a highlighter available? If not, generate one
            makeHighlighter()
            
            // First try to render the code in the detected language;
            // if that fails, try to use the highlighter to detect the language
            if let cas: NSAttributedString = self.highlighter?.highlight(code, as: self.currentLanguage) {
                return makeHighlightedCodeParagraph(NSMutableAttributedString(attributedString: cas), inset)
            } else if let cas: NSAttributedString = self.highlighter?.highlight(code, as: nil) {
                return makeHighlightedCodeParagraph(NSMutableAttributedString(attributedString: cas), inset)
            }
        }
        
        // No highlighter, or no language detected, so render as plain
        return makePlainCodeParagraph(code, inset)
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
        
        let quoteParaStyle: NSMutableParagraphStyle     = NSMutableParagraphStyle()
        quoteParaStyle.lineSpacing                      = self.lineSpacing
        quoteParaStyle.paragraphSpacing                 = self.paraSpacing * 2.0
        quoteParaStyle.alignment                        = .right
        quoteParaStyle.paragraphSpacingBefore           = self.paraSpacing
        quoteParaStyle.headIndent                       = self.BLOCK_INSET_BASE
        quoteParaStyle.firstLineHeadIndent              = self.BLOCK_INSET_BASE
        self.paragraphs["quote"]                        = quoteParaStyle
        
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
        
        // Set the colours
        self.colours.head  = NSColor.hexToColour(self.colourValues.head)
        self.colours.code  = NSColor.hexToColour(self.colourValues.code)
        self.colours.link  = NSColor.hexToColour(self.colourValues.link)
        self.colours.quote = NSColor.hexToColour(self.colourValues.quote)
        self.colours.body  = self.bodyColour
        
        // Generate specific paragraph entity styles
        self.styles["h1"]           = [.foregroundColor: self.colours.head,
                                       .font: makeFont("strong", self.fontSize * H1_MULTIPLIER),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        self.styles["h2"]           = [.foregroundColor: self.colours.head,
                                       .font: makeFont("strong", self.fontSize * H2_MULTIPLIER),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        self.styles["h3"]           = [.foregroundColor: self.colours.head,
                                       .font: makeFont("strong", self.fontSize * H3_MULTIPLIER),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        self.styles["h4"]           = [.foregroundColor: self.colours.head,
                                       .font: makeFont("strong", self.fontSize * H4_MULTIPLIER),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        self.styles["h5"]           = [.foregroundColor: self.colours.head,
                                       .font: makeFont("strong", self.fontSize * H5_MULTIPLIER),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        self.styles["h6"]           = [.foregroundColor: self.colours.head,
                                       .font: makeFont("plain", self.fontSize *  H6_MULTIPLIER),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        self.styles["p"]            = [.foregroundColor: self.colours.body,
                                       .font: makeFont("plain", self.fontSize),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        self.styles["t"]            = [.foregroundColor: self.colours.body,
                                       .font: makeFont("plain", self.fontSize),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        // Set the character styles we need
        self.styles["a"]            = [.foregroundColor: self.colours.link,
                                       .underlineStyle: NSUnderlineStyle.single.rawValue as NSNumber,
                                       .underlineColor: self.colours.link]
        
        self.styles["em"]           = [.foregroundColor: self.colours.body,
                                       .font: makeFont("em", self.fontSize)]
        
        self.styles["strong"]       = [.foregroundColor: self.colours.body,
                                       .font: makeFont("strong", self.fontSize)]
        
        self.styles["code"]         = [.foregroundColor: self.colours.code,
                                       .font: makeFont("code", self.fontSize)]
        
        self.styles["kbd"]          = [.foregroundColor: NSColor.white,
                                       .underlineColor: NSColor.gray,
                                       .underlineStyle: NSUnderlineStyle.double.rawValue as NSNumber,
                                       .font: makeFont("code", self.fontSize)]
        
        self.styles["s"]            = [.strikethroughStyle: NSUnderlineStyle.single.rawValue as NSNumber,
                                       .strikethroughColor: self.colours.body]
        
        self.styles["sub"]          = [.font: makeFont("plain", self.fontSize / 1.5),
                                       .baselineOffset: -5.0 as NSNumber]
        
        self.styles["sup"]          = [.font: makeFont("plain", self.fontSize / 1.5),
                                       .baselineOffset: 10.0 as NSNumber]
        
        // Set up the block styles we need
        self.styles["pre"]          = [.foregroundColor: self.colours.code,
                                       .font: makeFont("code", self.fontSize),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        self.styles["blockquote"]   = [.foregroundColor: self.colours.quote,
                                       .font: makeFont("strong", self.fontSize * H4_MULTIPLIER),
                                       .paragraphStyle: self.paragraphs["quote"]!]
        
        self.styles["li"]           = [.foregroundColor: self.colours.body,
                                       .font: makeFont("plain", self.fontSize),
                                       .paragraphStyle: self.paragraphs["list"]!]
        
        self.styles["img"]          = [.foregroundColor: self.colours.body,
                                       .font: makeFont("plain", self.fontSize),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
        
        self.styles["line"]         = [.foregroundColor: self.colours.body,
                                       .font: makeFont("plain", self.fontSize),
                                       .paragraphStyle: self.paragraphs["tabbed"]!]
    }


    /**
     Determine what styles are available for the chosen body font,
     which is set by the calling code (as is the base font size).
     */
    internal func prepareFonts() {
        
        // Make the body font in order to get its family name
        var bodyFont: NSFont? = NSFont(name: self.bodyFontName, size: self.fontSize)

        // Can't make the body font? Default to System
        if bodyFont == nil {
            bodyFont = NSFont.systemFont(ofSize: self.fontSize)
        }

        self.bodyFontFamily.displayName = bodyFont?.familyName ?? self.bodyFontName

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


    /**
     Generate a specific font to match the specified style and size.
     
     - Parameters
        - requiredStyle: The style wanted, eg. `strong`.
        - size:          The point size.

     - Returns A font that can be used.
     */
    internal func makeFont(_ requiredStyle: String, _ size: CGFloat) -> NSFont {
        
        // Check through the fonts we've already made in case we have the
        // required one already.
        for fontRecord: FontRecord in self.fonts {
            if fontRecord.style == requiredStyle && fontRecord.size.isClose(to: size) {
                if let font: NSFont = fontRecord.font {
                    return font
                }

                break
            }
        }
        
        // No existing font available, so make one
        let fm: NSFontManager = NSFontManager.shared
        switch requiredStyle {
            case "strong":
                if let font = matchFont("strong", ["Bold", "Black", "Heavy", "Medium", "Semi-Bold"], self.bodyFontFamily, size) {
                    return font
                } else {
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
        if let font: NSFont = NSFont(name: self.bodyFontName, size: size) {
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
                        if let font: NSFont = NSFont(name: style.postScriptName, size: size) {
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
     Calculate the real size of a style entity from the base font size.
     
     - Parameters
        - tagName: An HTML tag.
     
     - Returns The font size to use.
     */
    internal func setFontSize(_ tagName: String) -> CGFloat {
        
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


    // MARK: - Utility Functions
    
    /**
     Instantiate a Highlighter object for code colouring.
     
     - Note This should only be called if required.
     */
    internal func makeHighlighter() {
        
        if self.highlighter == nil {
            // Attempt to instantiate the highlighter
            self.highlighter = Highlighter()
            
            if self.highlighter == nil {
                // Couldn't create the highlighter
                NSLog("Could not load the highlighter")
            } else {
                // Make theme selection more responsive to current mode
                self.highlighter?.setTheme(self.presentForLightMode ? "atom-one-light" : "atom-one-dark")
                self.highlighter?.theme.setCodeFont(makeFont("code", self.fontSize))
            }
        }
    }


    /**
     Load an image from disk.
     
     TODO Handle HTTP images.
     
     - Returns The image as an NSAttributedString attachment.
     */
    private func loadImage() -> NSMutableAttributedString {
        
        let imageAttachment = NSTextAttachment()

        if self.currentImagePath.hasPrefix("http") {
            // TODO load in internet image
            if self.doLoadWebContent {
                // TODO
            } else {
                setMissingImage(imageAttachment)
            }
        } else {
            // SEE https://developer.apple.com/documentation/foundation/nsurl for secure resources
            if FileManager.default.isReadableFile(atPath: self.currentImagePath) {
                if let image = NSImage(contentsOfFile: self.currentImagePath) {
                    imageAttachment.image = image
                } else {
                    setMissingImage(imageAttachment)
                }
            } else {
                setMissingImage(imageAttachment)
            }
        }
        
        // IMG should be at the top the the stack, so we can return immediately
        let renderedImage = NSMutableAttributedString(attachment: imageAttachment)
        renderedImage.append(NSAttributedString(string: "\n" + self.currentImagePath, attributes: self.styles["p"]))
        
        // Add the path as a tooltip. Does this even show? No, doesn't look like it
        // renderedImage.addAttribute(.toolTip, value: self.currentImagePath, range: NSRange(location: 0, length: renderedImage.length))
        return renderedImage
    }


    /**
     Get a placeholder for an image we're not allowed by macOS to access or which can't be found.
     
     - Parameters
        - imageAttachment: The text attachment to add the image to.
        - isSandboxLocked: `true` of macOS has blocks the image, otherwise `false`. Default: `false`.
     */
    private func setMissingImage(_ imageAttachment: NSTextAttachment, _ isSandboxLocked: Bool = false) {

        guard let image = NSImage(named: NSImage.Name(stringLiteral: isSandboxLocked ? BUFFOON_CONSTANTS.LOCKED_IMG : BUFFOON_CONSTANTS.MISSING_IMG)) else { return }
        imageAttachment.image = image
    }


    /**
     Convert a partial path to an absolute path.
     
     - Parameters
        - relativePath: A path.

     - Returns An absolute path.
     */
    func getFullPath(_ relativePath: String) -> String {
        
        // Standardise the path as best as we can (this covers most cases)
        var absolutePath: String = (relativePath as NSString).standardizingPath
        
        // Check for a unresolved relative path -- and if it is one, resolve it
        // NOTE This includes raw filenames
        if (absolutePath as NSString).contains("..") || !(absolutePath as NSString).hasPrefix("/") {
            absolutePath = processRelativePath(absolutePath)
        }
        
        // Return the absolute path
        return absolutePath
    }


    /**
     Add the basepath (the current working directory of the call) to the
     supplied relative path - and then resolve it.
    
     - Parameters
        - relativePath: A path.

     - Returns An absolute path.
     */
    func processRelativePath(_ relativePath: String) -> String {
        
        let absolutePath = self.workingDirectory != "" ? self.workingDirectory + "/" + relativePath : relativePath
        return (absolutePath as NSString).standardizingPath
    }


    /**
     Split a string on a double quote marks.
     
     - Parameters
        - tag:           The full token.
        - requiredIndex: The index of the element we want returned.

     - Returns The requested string.
     */
    internal func splitTag(_ tag: String, _ requiredIndex: Int = 1) -> String {

        let parts: [String] = tag.components(separatedBy: "\"")
        if parts.count > requiredIndex {
            return parts[requiredIndex]
        }
        
        return ""
    }


    /**
     Add a base paragraph styled New Line symbol to the supplied attributed string.
     String passed by reference so this function only has side effects.

     - Parameters
        - renderedString: The attributed string to update.
        - withLineBreak:  `true` to add a Line Break in place of a New Line. Default `false`.
     */
    private func addNewLine(_ renderedString: NSMutableAttributedString, withLineBreak: Bool = false) {

#if PARATAG
        let symbol = "<"+self.LINE_FEED_SYMBOL
#else
        let symbol = self.LINE_FEED_SYMBOL
#endif
        renderedString.append(NSAttributedString(string: (withLineBreak ? self.LINE_BREAK_SYMBOL : symbol), attributes: self.styles["p"]))
    }

}
