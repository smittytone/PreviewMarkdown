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
    case line
    case character
    case indent
}


enum IndentType {
    case bullet
    case number
}


class Style {
    
    var name: String = ""
    var type: StyleType = .line
}


class Styler {
    
    var lineSpacing: CGFloat = 0.0
    var paraSpacing: CGFloat = 0.5
    var fontSize: CGFloat = 14.0
    
    var headColour: String = "#FFFFFF"
    var codeColour: String = "#00FF00"
    var bodyColour: String = "#FFFFFF"
    var linkColour: String = "#64ACDD"
    
    var bodyFontName: String = ""
    var codeFontName: String = ""
    
    var bodyFontFamily: PMFont = PMFont()

    private var tokenString: String = ""
    private var currentLink: String = ""
    private var fonts: FontStore!
    private let htmlTagStart: String = "<"
    private let htmlTagEnd: String = ">"
    private let tags: [String] = ["p", "a", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "code", "em", "strong", "li", "blockquote"]
    private let bullets: [String] = ["\u{25CF}", "\u{25CB}", "\u{25CF}", "\u{25CB}", "\u{25CF}", "\u{25CB}"]
    private let htmlEscape: NSRegularExpression = try! NSRegularExpression(pattern: "&#?[a-zA-Z0-9]+?;", options: .caseInsensitive)

    private var styles: [String: [NSAttributedString.Key: AnyObject]]!
    
    // Style definition objects, globalised for re-use across styles
    private var headColourValue: NSColor!
    private var codeColourValue: NSColor!
    private var bodyColourValue: NSColor!
    private var linkColourValue: NSColor!
    private var tabbedParaStyle: NSMutableParagraphStyle!
    private var insetParaStyle:  NSMutableParagraphStyle!
    private var lineParaStyle:   NSMutableParagraphStyle!


    // MARK: - Constructor
    
    /**
     The default initialiser.
    */
    init(_ htmlString: String) {
        
        self.tokenString = htmlString
    }
    
    
    func render(_ isThumbnail: Bool = false) -> NSAttributedString? {
        
        generateStyles()
        return processHTMLString()
    }
    
    
    private func processHTMLString() -> NSAttributedString? {

        var doAddBullet: Bool = false
        var isBlock: Bool = false
        var insetLevel: Int = 0
        var insetCounts: [Int] = Array.init(repeating: 0, count: 12)    // Start at zero to ensure correct counting
        var insetTypes: [IndentType] = Array.init(repeating: .bullet, count: 12)
        //var blockInsets: [Int] = Array.init(repeating: 1, count: 12)

        let hr = NSAttributedString(string: "\n\u{00A0} \u{0009} \u{00A0}\n",
                                    attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                                                 .strikethroughColor: self.bodyColourValue!,
                                                 .paragraphStyle: self.lineParaStyle!])

        // Do pre-processing
        self.tokenString = processCheckboxes(self.tokenString)
        //self.tokenString = self.tokenString.replacingOccurrences(of: "\n", with: "\n\r")

        // Render the HTML
        let scanner: Scanner = Scanner(string: self.tokenString)
        scanner.charactersToBeSkipped = nil

        var scannedString: String? = nil
        let resultString: NSMutableAttributedString = NSMutableAttributedString(string: self.tokenString,
                                                                                attributes: self.styles["p"])
        let baseStyle: Style = Style()
        baseStyle.name = "p"
        var propertiesStack: [Style] = [baseStyle]

        while !scanner.isAtEnd {
            // Flag to mark that the end of the string has been reached
            var ended: Bool = false

            // Scan up to the next HTML tag's '<' and get the substring
            if let contentString: String = scanner.scanUpToString(self.htmlTagStart) {
                scannedString = contentString
                ended = scanner.isAtEnd
            }

            // We have content to style, so do so
            if scannedString != nil && !scannedString!.isEmpty {
                // Set a paragraph indent, eg. for bullet point
                var indent: String = ""

                NSLog("[CONTENT] \(scannedString!)")

                // Are we adding a bullet from a previous <li> tag?
                if doAddBullet {
                    // Style the bullet by type and indent level
                    if insetTypes[insetLevel] == .bullet {
                        indent = String(repeating: "\t", count: insetLevel) + "\(bullets[insetLevel - 1]) "
                    } else {
                        indent = String(repeating: "\t", count: insetLevel) + "\(insetCounts[insetLevel]). "
                    }

                    doAddBullet = false
                }
                
                // Are we indenting a blockquote?
                if isBlock {
                    //indent = String(repeating: "\t", count: insetLevel)
                }

                // Assemble the styled string...
                var attrScannedString: NSMutableAttributedString
                if (indent.count > 0) {
                    // Style and apply the indent, then style and apply the content
                    // NOTE Indent should match body, not what follows
                    attrScannedString = NSMutableAttributedString.init(attributedString: styleString(indent, [baseStyle]))
                    attrScannedString.append(styleString(scannedString!, propertiesStack))
                } else if isBlock {
                    // Style and apply the content
                    attrScannedString = NSMutableAttributedString.init(attributedString: styleString(scannedString!, propertiesStack))
                } else {
                    // Style and apply the content
                    attrScannedString = NSMutableAttributedString.init(attributedString: styleString(scannedString!, propertiesStack))
                }

                // ...and add it to the store
                resultString.append(attrScannedString)

                // Break out of the upper loop if we're done
                if ended {
                    continue
                }
            }
            
            // Reached an HTML entry tag: step over it
            scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)

            // Get the first character of the tag
            let string: NSString = scanner.string as NSString
            let idx: Int = scanner.currentIndex.utf16Offset(in: self.tokenString)
            let nextChar: String = string.substring(with: NSMakeRange(idx, 1))

            if nextChar == "/" {
                // Found a close tag, so remove last attribute
                // Step over the `/`
                scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)

                // Get the remainder of the tag up to `>`
                if let closeTag: String = scanner.scanUpToString(self.htmlTagEnd) {

                    NSLog("[TAG] * \(closeTag)")
                    // NOTE Probably need to watch for spaces in tags?

                    var doSkipCR: Bool = false;

                    // Closing a list? Then reduce the current indent
                    if closeTag == "ul" || closeTag == "ol" {
                        insetLevel -= 1
                        if insetLevel < 0 {
                            insetLevel = 0
                        }

                        // Remove the next tag's CR
                        if (insetLevel > 0) {
                            doSkipCR = true
                        }
                    }

                    if closeTag == "blockquote" || closeTag == "pre" {
                        isBlock = false;
                        insetLevel -= 1;
                        propertiesStack = [baseStyle]
                    }

                    // Step over the final `>`
                    scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
                    if doSkipCR {
                        //let _: String? = scanner.scanUpToString("\n")
                        scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
                    }

                    // Remove the last style, as set by the opening tag
                    if propertiesStack.count > 1 {
                        propertiesStack.removeLast()
                    }

                    // Write out the tag for now
/*
                    let aStyle: Style = Style()
                    aStyle.name = "p"
                    let attrScannedString: NSAttributedString = styleString("|\(closeTag)|", [aStyle])
                    resultString.append(attrScannedString)
*/
                }
            } else {
                // We're opening a new tag, so get it up to the `>`
                if let tagString: String = scanner.scanUpToString(self.htmlTagEnd) {
                    var tagToUse: String = tagString
                    var doSkipCR: Bool = false
                    
                    if tagString == "hr" {
                        resultString.append(hr)
                    }

                    // Opening a list? Then increment the current indent and set the list type
                    if tagString == "ul" || tagString == "ol" {
                        let insetItem: IndentType = tagString == "ul" ? .bullet : .number
                        insetLevel += 1
                        if insetLevel == insetTypes.count {
                            insetTypes.append(insetItem)
                        } else {
                            insetTypes[insetLevel] = insetItem
                        }

                        doSkipCR = true
                    }
                    
                    // List item
                    // NOTE mdit usually embeds text in <li> tags, but in nested
                    //      lists can include <p> tags
                    if tagString == "li" {
                        if insetTypes[insetLevel] == .number {
                            insetCounts[insetLevel] += 1
                        }
                        
                        tagToUse = "p"
                        doAddBullet = true
                    }
                    
                    if tagString == "blockquote" {
                        doSkipCR = true
                        isBlock = true
                        insetLevel += 1
                        let aStyle: Style = Style()
                        aStyle.name = "blockquote"
                        propertiesStack = [aStyle]
                        tagToUse = ""
                    }

                    if tagString == "pre" {
                        tagToUse = "code"
                        isBlock = true
                        insetLevel += 1
                    }

                    if tagString == "p" && isBlock {
                        // Para nested within a blockquote or list item
                        tagToUse = "blockquote"
                    }

                    if tagString == "p" && doAddBullet {
                        // Para nested within a list item
                        tagToUse = ""
                        doSkipCR = true
                    }

                    if tagString == "code" && isBlock {
                        tagToUse = ""
                    }

                    if tagString.hasPrefix("a") {
                        // We have a link -- get the destination from HREF
                        tagToUse = "a"
                        let parts: [String] = tagString.components(separatedBy: "\"")
                        if parts.count > 1 {
                            self.currentLink = parts[1]
                        }
                    }
                    
                    NSLog("[TAG] \(tagString)")

                    // Compare the tag to use with those we apply.
                    // NOTE Some, such as list markers, we do not style here
                    if self.tags.contains(tagToUse) {
                        // The tag is one we look for
                        // Add the tag to the list of properties
                        let tagStyle: Style = Style()
                        tagStyle.name = tagToUse
                        
                        // Set character styles (inherit from parent)
                        if ["strong", "em", "a", "strike"].contains(tagToUse) {
                            tagStyle.type = .character
                        }

                        propertiesStack.append(tagStyle)
                        
                        // Write out the tag for now
/*
                        let aStyle: Style = Style()
                        aStyle.name = "p"
                        let attrScannedString: NSAttributedString = styleString("{\(tagString)}",
                                                                                [aStyle])
                        resultString.append(attrScannedString)
*/
                    }
                    
                    // Step over the final `>`
                    scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)

                    if doSkipCR {
                        //let _: String? = scanner.scanUpToString("\n")
                        scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
                    }
                }
            }
            
            scannedString = nil
        }

        // Composed the string; now replace HTML escapes
        let results: [NSTextCheckingResult] = self.htmlEscape.matches(in: resultString.string,
                                                                      options: [.reportCompletion],
                                                                      range: NSMakeRange(0, resultString.length))
        var localOffset: Int = 0
        for result: NSTextCheckingResult in results {
            let fixedRange: NSRange = NSMakeRange(result.range.location - localOffset, result.range.length)
            let entity: String = (resultString.string as NSString).substring(with: fixedRange)
            if let decodedEntity = HTMLUtils.decode(entity) {
                resultString.replaceCharacters(in: fixedRange, with: String(decodedEntity))
                localOffset += (result.range.length - 1);
            }
        }

        return resultString
    }


    internal func styleString(_ string: String, _ styleList: [Style]) -> NSAttributedString {
       
        var returnString: NSMutableAttributedString? = nil
        var isItalic: Bool = false
       
        if styleList.count > 0 {
            // Build the attributes from the style list, including the font
            var attrs = [NSAttributedString.Key: AnyObject]()
            var parentStyle: Style = Style()
            for style in styleList {
                if style.type == .character {
                    if let tagStyle = self.styles[parentStyle.name] {
                        for (attrName, attrValue) in tagStyle {
                            attrs.updateValue(attrValue,
                                              forKey: attrName)
                        }
                        
                        switch style.name {
                            case "strong":
                                // Try to get a bold font that matches the parent (h1, p etc)
                                if let font: NSFont = makeFont(parentStyle.name,
                                                               style.name,
                                                               setSize(parentStyle.name)) {
                                    attrs.updateValue(font,
                                                      forKey: .font)
                                } else {
                                    // Otherwise use the parent font and just back-tint it
                                    attrs.updateValue(NSColor.red,
                                                      forKey: .backgroundColor)
                                }
                            case "em":
                                // Try to get an italic font that matches the parent (h1, p etc)
                                if let font: NSFont = makeFont(parentStyle.name,
                                                               style.name,
                                                               setSize(parentStyle.name)) {
                                    attrs.updateValue(font,
                                                      forKey: .font)
                                } else {
                                    // Otherwise use the parent font and just underline it
                                    isItalic = true
                                }
                            case "strike":
                                attrs.updateValue(NSColor.labelColor,
                                                  forKey: .strikethroughColor)
                            case "a":
                                //attrs.updateValue(self.currentLink as NSString, forKey: .link)
                                attrs.updateValue(self.currentLink as NSString, forKey: .toolTip)
                            default:
                                break
                        }
                    }
                } else if style.type != .indent {
                    if let tagStyle = self.styles[style.name] {
                        for (attrName, attrValue) in tagStyle {
                            attrs.updateValue(attrValue,
                                              forKey: attrName)
                        }
                    }
                    
                    parentStyle = style
                }
            }
            
            returnString = NSMutableAttributedString(string: string,
                                                     attributes: attrs)
            
            // Apply underline-as-italic if we need to
            if isItalic {
                let underlineRange = NSMakeRange(0, returnString!.length)
                returnString!.addAttributes([.underlineStyle: NSUnderlineStyle.single.rawValue,
                                             .underlineColor: NSColor.red],
                                             range: underlineRange)
            }
        } else {
            // No specified attributes? Just set the font
            returnString = NSMutableAttributedString(string: string,
                                                     attributes: self.styles["p"])
        }

        return returnString! as NSAttributedString
    }
    
    
    internal func generateStyles() {
        
        // Base paragraph style
        self.tabbedParaStyle = NSMutableParagraphStyle()
        self.tabbedParaStyle.lineSpacing = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        self.tabbedParaStyle.paragraphSpacing = (self.paraSpacing >= 0.0 ? self.paraSpacing : self.lineSpacing)
        self.tabbedParaStyle.alignment = .left
        self.tabbedParaStyle.tabStops = [NSTextTab(textAlignment: .left, location: 30.0, options: [:]),
                                         NSTextTab(textAlignment: .left, location: 30.0, options: [:])]
        self.tabbedParaStyle.defaultTabInterval = 30.0
        
        // Inset paragraph style for
        self.insetParaStyle = NSMutableParagraphStyle()
        self.insetParaStyle.lineSpacing = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        self.insetParaStyle.paragraphSpacing = (self.paraSpacing >= 0.0 ? self.paraSpacing : self.lineSpacing)
        self.insetParaStyle.alignment = .center
        self.insetParaStyle.firstLineHeadIndent = 20.0
        self.insetParaStyle.headIndent = 20.0

        self.lineParaStyle = NSMutableParagraphStyle()
        self.lineParaStyle.alignment = .left
        self.lineParaStyle.tabStops = [NSTextTab(textAlignment: .right, location: 120.0, options: [:])]

        self.headColourValue = colourFromHexString(self.headColour)
        self.bodyColourValue = colourFromHexString(self.bodyColour)
        self.codeColourValue = colourFromHexString(self.codeColour)
        self.linkColourValue = colourFromHexString(self.linkColour)
        
        // H1
        self.styles = ["h1": [.foregroundColor: self.headColourValue,
                             .font: makeFont("h1", "plain", self.fontSize * 2.0)!,
                             .paragraphStyle: self.tabbedParaStyle]]
        
        // H2
        self.styles["h2"] = [.foregroundColor: self.headColourValue,
                             .font: makeFont("h2", "plain", self.fontSize * 1.6)!,
                             .paragraphStyle: self.tabbedParaStyle]
        
        // H3
        self.styles["h3"] = [.foregroundColor: self.headColourValue,
                             .font: makeFont("h3", "plain", self.fontSize * 1.4)!,
                             .paragraphStyle: self.tabbedParaStyle]
        
        // H4
        self.styles["h4"] = [.foregroundColor: self.headColourValue,
                             .font: makeFont("h4", "plain", self.fontSize * 1.2)!,
                             .paragraphStyle: self.tabbedParaStyle]
        
        // H5
        self.styles["h5"] = [.foregroundColor: self.headColourValue,
                             .font: makeFont("h5", "plain", self.fontSize * 1.1)!,
                             .paragraphStyle: self.tabbedParaStyle]
        
        // H6
        self.styles["h6"] = [.foregroundColor: self.headColourValue,
                             .font: makeFont("h6", "plain", self.fontSize)!,
                             .paragraphStyle: self.tabbedParaStyle]
        
        // P
        self.styles["p"] = [.foregroundColor: self.bodyColourValue,
                            .font: makeFont("p", "plain", self.fontSize)!,
                            .paragraphStyle: self.tabbedParaStyle]
                            //.underlineStyle: NSUnderlineStyle.init(rawValue: 0) as AnyObject]

        // A
        self.styles["a"] = [.foregroundColor: self.linkColourValue,
                            .font: makeFont("p", "plain", self.fontSize)!,
                            .underlineStyle: NSUnderlineStyle.init(rawValue: 1) as AnyObject,
                            .underlineColor: self.linkColourValue]

        // CODE
        self.styles["code"] = [.foregroundColor: self.codeColourValue,
                               .font: makeFont("code", "code", self.fontSize)!]
        
        // PRE
        self.styles["pre"] = [.foregroundColor: self.codeColourValue,
                              .font: makeFont("code", "code", self.fontSize)!,
                              .paragraphStyle: self.insetParaStyle]
        
        // LI
        self.styles["li"] = [.foregroundColor: self.bodyColourValue,
                             .font: makeFont("li", "plain", self.fontSize)!]
        
        // BLOCKQUOTE
        self.styles["blockquote"] = [.foregroundColor: self.codeColourValue,
                                     .font: makeFont("blockquote", "em", self.fontSize * 1.4)!,
                                     .paragraphStyle: self.insetParaStyle]
    }
    
    
    internal func makeFont(_ tagName: String, _ fontStyle: String, _ size: CGFloat) -> NSFont? {
        
        // Got the font already? Return a reference

        switch fontStyle {
            case "strong":
                /*
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
                */
                let fm: NSFontManager = NSFontManager.shared
                var font: NSFont? = fm.font(withFamily: self.bodyFontFamily.displayName,
                                            traits: .boldFontMask,
                                            weight: 10,
                                            size: size)
                
                if font == nil {
                    // There is no bold version of the font
                    font = fm.font(withFamily: self.bodyFontFamily.displayName,
                                   traits: .unboldFontMask,
                                   weight: 5,
                                   size: size)
                }
                
                return font
                
            case "em":
                /*
                if let styles: [PMFont] = self.bodyFontFamily.styles {
                    for style: PMFont in styles {
                        for styleName: String in ["Italic", "Oblique"] {
                            if styleName == style.styleName {
                                if let font: NSFont = NSFont.init(name: style.postScriptName, size: size) {
                                    return font
                                }
                            }
                        }
                    }
                }
                */
                let fm: NSFontManager = NSFontManager.shared
                let font: NSFont? = fm.font(withFamily: self.bodyFontFamily.displayName,
                                            traits: .italicFontMask,
                                            weight: 5,
                                            size: size)
                return font

                /*
                if font == nil {
                    let names: [String] = self.bodyFontName.components(separatedBy: "-")
                    if names.count > 1 && names[0] != "System" {
                        font = NSFont.init(name: names[0] + "-Italc", size: size)
                    } else {
                        font = NSFont.systemFont(ofSize: size)
                    }
                }
                
                return font
                */
            
            case "code":
                if let font: NSFont = NSFont(name: self.codeFontName, size: size) {
                    return font
                }
                
                return NSFont.systemFont(ofSize: size, weight: .regular)
                
            default:
                break
        }

        // Just use some generic fonts as a fallback
        var useFont: NSFont? = nil
        if let aFont: NSFont = NSFont.init(name: self.bodyFontName, size: size) {
            useFont = aFont
        }
        
        if useFont == nil {
            useFont = NSFont.systemFont(ofSize: size, weight: .regular)
        }
        
        return useFont
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
                return self.fontSize * 2.2
            case "h2":
                return self.fontSize * 1.8
            case "h3":
                return self.fontSize * 1.6
            case "h4":
                fallthrough
            case "blockquote":
                return self.fontSize * 1.4
            case "h5":
                return self.fontSize * 1.2
            case "h6":
                return self.fontSize * 1.1
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
