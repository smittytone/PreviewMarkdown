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

class Style {
    
    var name: String = ""
    var type: StyleType = .line
}


class Styler {
    
    var lineSpacing: CGFloat = 0.0
    var paraSpacing: CGFloat = 0.0
    var fontSize: CGFloat = 14.0
    
    var headColour: String = "#FFFFFF"
    var codeColour: String = "#00FF00"
    var bodyColour: String = "#FFFFFF"
    
    var bodyFontName: String = ""
    var codeFontName: String = ""
    
    var bodyFontFamily: PMFont = PMFont()
    
    
    private var tokenString: String = ""
    private var styles: [String: [NSAttributedString.Key: AnyObject]]!
    private var fonts: FontStore!
    private var spacedParaStyle: NSMutableParagraphStyle!
    
    private let htmlStart: String = "<"
    private let htmlEnd: String = ">"
    private let tags: [String] = ["p", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "code", "em", "strong", "li"]
    private let bullets: [String] = ["•", "›", "»", "†"]
    private let htmlEscape: NSRegularExpression = try! NSRegularExpression(pattern: "&#?[a-zA-Z0-9]+?;", options: .caseInsensitive)
    
   
    
    
    // MARK: - Constructor
    
    /**
     The default initialiser.
     
     - returns: `nil` on failure to load or evaluate `markdownit.min.js`.
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
        var insetLevel: Int = 0
        var insetCounts: [Int] = [1, 1, 1, 1, 1, 1]
        var insetTypes: [Int]  = [0, 0, 0, 0, 0, 0]
        
        let scanner: Scanner = Scanner(string: self.tokenString)
        scanner.charactersToBeSkipped = nil
        
        var scannedString: NSString? = nil
        let resultString: NSMutableAttributedString = NSMutableAttributedString(string: "",
                                                                                attributes: self.styles["p"])
        let baseStyle: Style = Style()
        baseStyle.name = "p"
        var propertiesStack: [Style] = [baseStyle]
        
        while !scanner.isAtEnd {
            var ended: Bool = false
            
            if let contentString: String = scanner.scanUpToString(self.htmlStart) {
                scannedString = contentString as NSString
                ended = scanner.isAtEnd
            }
            
            // We have content to style, so do so
            if scannedString != nil && scannedString!.length > 0 {
                
                if doAddBullet {
                    doAddBullet = false
                    let style = self.styles["p"]
                }
                
                let attrScannedString: NSAttributedString = styleString((scannedString! as String),
                                                                        propertiesStack)
                resultString.append(attrScannedString)
                
                if ended {
                    continue
                }
            }
            
            // Step over the `<`
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
                if let closeTag: String = scanner.scanUpToString(self.htmlEnd) {
                    // Closing a list? Then reduce the current indent
                    if closeTag == "ul" || closeTag == "ol"{
                        insetLevel -= 1
                        if insetLevel < 1 {
                            insetLevel = 0
                        }
                        
                        // Remove the following CR
                        let _: String? = scanner.scanUpToString("\n")
                        
                        // Remove the next tag's CR
                        if (insetLevel != 0) {
                            scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
                            let _: String? = scanner.scanUpToString("\n")
                        }
                    }
                    
                    // Step over the final `>`
                    scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
                    
                    // Remove the last style, as set by the opening tag
                    if propertiesStack.count > 1 {
                        propertiesStack.removeLast()
                    }
                    
                    // Write out the close tag for now
                    // Write out the tag for now
                    /*
                    let attrScannedString: NSAttributedString = applyStyleToString("[/\(closeTag)]",
                                                                                       ["base"],
                                                                                       StylingInformation())
                    resultString.append(attrScannedString)
                    */
                }
            } else {
                // We're opening a new tag, so get it up to the `>`
                if let tagString: String = scanner.scanUpToString(self.htmlEnd) {
                    var useTag: String = tagString
                    var doSkipCR: Bool = false
                    
                    // Opening a list? Then increment the current indent
                    if tagString == "ul" {
                        insetLevel += 1
                        insetTypes[insetLevel] = 1
                        doSkipCR = true
                    }
                    
                    if tagString == "ol" {
                        insetLevel += 1
                        insetTypes[insetLevel] = 2
                        insetCounts[insetLevel] = 1
                        doSkipCR = true
                    }
                    
                    if tagString == "li" {
                        if insetTypes[insetLevel] == 2 {
                            insetCounts[insetLevel] += 1
                        }
                        
                        useTag = "p"
                        doAddBullet = true
                    }
                    
                    if self.tags.contains(tagString) {
                        // The tag is one we look for
                        // Add the tag to the list of properties
                        let tagStyle: Style = Style()
                        tagStyle.name = useTag
                        
                        if useTag == "strong" {
                            tagStyle.name = "bold"
                            tagStyle.type = .character
                        }
                        
                        if useTag == "em" {
                            tagStyle.name = "italic"
                            tagStyle.type = .character
                        }
                        
                        if useTag == "strike" {
                            tagStyle.type = .character
                        }
                        
                        propertiesStack.append(tagStyle)
                        
                        // Write out the tag for now
                        /*
                        let attrScannedString: NSAttributedString = applyStyleToString("[\(tagString)]",
                                                                                       ["base"],
                                                                                       StylingInformation())
                        resultString.append(attrScannedString)
                         */
                    }
                    
                    if doSkipCR {
                        let _: String? = scanner.scanUpToString("\n")
                    }
                    
                    // Step over the final `>`
                    scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
                }
            }
            
            scannedString = nil
        }

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
                            case "bold":
                                // Try to get a bold font that matches the parent (h1, p etc)
                                if let font: NSFont = makeFont(parentStyle.name,
                                                               style.name,
                                                               setSize(parentStyle.name)) {
                                    attrs.updateValue(font,
                                                      forKey: .font)
                                } else {
                                    // Otherwise use the parent font and just back-tint it
                                    attrs.updateValue(NSColor.darkGray,
                                                      forKey: .backgroundColor)
                                }
                            case "italic":
                                // Try to get an italic font that matches the parent (h1, p etc)
                                if let font: NSFont = makeFont(parentStyle.name,
                                                               style.name,
                                                               setSize(parentStyle.name)) {
                                    attrs.updateValue(font,
                                                      forKey: .font)
                                } else {
                                    // Otherwise use the parent font and just underline it
                                    attrs.updateValue(NSColor.labelColor,
                                                      forKey: .underlineColor)
                                }
                            case "strike":
                                attrs.updateValue(NSColor.labelColor,
                                                  forKey: .strikethroughColor)
                            default:
                                break
                        }
                        
                    }
                } else if style.type == .indent {
                
                } else {
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
        } else {
            // No specified attributes? Just set the font
            returnString = NSMutableAttributedString(string: string,
                                                     attributes: self.styles["p"])
        }

        return returnString! as NSAttributedString
    }
    
    
    internal func generateStyles() {
        
        // Base paragraph style
        self.spacedParaStyle = NSMutableParagraphStyle()
        self.spacedParaStyle.lineSpacing = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        self.spacedParaStyle.paragraphSpacing = (self.paraSpacing >= 0.0 ? self.paraSpacing : self.lineSpacing)
        
        // H1
        self.styles = ["h1": [.foregroundColor: colourFromHexString(self.headColour),
                             .font: makeFont("h1", "plain", self.fontSize * 2.0)!,
                             .paragraphStyle: self.spacedParaStyle]]
        
        // H2
        self.styles["h2"] = [.foregroundColor: colourFromHexString(self.headColour),
                             .font: makeFont("h2", "plain", self.fontSize * 1.6)!,
                             .paragraphStyle: self.spacedParaStyle]
        
        // H3
        self.styles["h3"] = [.foregroundColor: colourFromHexString(self.headColour),
                             .font: makeFont("h3", "plain", self.fontSize * 1.4)!,
                             .paragraphStyle: self.spacedParaStyle]
        
        // H4
        self.styles["h4"] = [.foregroundColor: colourFromHexString(self.headColour),
                             .font: makeFont("h4", "plain", self.fontSize * 1.2)!,
                             .paragraphStyle: self.spacedParaStyle]
        
        // H5
        self.styles["h5"] = [.foregroundColor: colourFromHexString(self.headColour),
                             .font: makeFont("h5", "plain", self.fontSize * 1.1)!,
                             .paragraphStyle: self.spacedParaStyle]
        
        // H6
        self.styles["h6"] = [.foregroundColor: colourFromHexString(self.headColour),
                             .font: makeFont("h6", "plain", self.fontSize)!,
                             .paragraphStyle: self.spacedParaStyle]
        
        // P
        self.styles["p"] = [.foregroundColor: colourFromHexString(self.bodyColour),
                            .font: makeFont("p", "plain", self.fontSize)!,
                            .paragraphStyle: self.spacedParaStyle]
        
        // CODE
        self.styles["code"] = [.foregroundColor: colourFromHexString(self.codeColour),
                               .font: makeFont("code", "plain", self.fontSize)!,
                               .paragraphStyle: self.spacedParaStyle]
    }
    
    
    internal func makeFont(_ tagName: String, _ fontStyle: String, _ size: CGFloat) -> NSFont? {
        
        // Got the font already? Return a reference
        if let tagFonts: [String: NSFont] = self.fonts[tagName] {
            if let tagFont: NSFont = tagFonts[fontStyle] {
                return tagFont
            }
        }
        
        switch fontStyle {
            case "bold":
                if let styles: [PMFont] = self.bodyFontFamily.styles {
                    for style: PMFont in styles {
                        for styleName: String in ["Bold", "Black", "Heavy", "Medium"] {
                            if styleName == style.styleName {
                                if let font: NSFont = NSFont.init(name: style.postScriptName, size: size) {
                                    
                                    // Store font if we need it again
                                    if var tagFonts: [String: AnyObject] = self.fonts[tagName] {
                                        if tagFonts[fontStyle] == nil {
                                            tagFonts[fontStyle] = font
                                        }
                                    } else {
                                        self.fonts[tagName] = [fontStyle: font]
                                    }
                                    
                                    return font
                                }
                            }
                        }
                    }
                    
                    return nil
                }
                
            case "italic":
                if let styles: [PMFont] = self.bodyFontFamily.styles {
                    for style: PMFont in styles {
                        for styleName: String in ["Italic", "Oblique"] {
                            if styleName == style.styleName {
                                if let font: NSFont = NSFont.init(name: style.postScriptName, size: size) {
                                    
                                    // Store font if we need it again
                                    if var tagFonts: [String: AnyObject] = self.fonts[tagName] {
                                        if tagFonts[fontStyle] == nil {
                                            tagFonts[fontStyle] = font
                                        }
                                    } else {
                                        self.fonts[tagName] = [fontStyle: font]
                                    }
                                    
                                    return font
                                }
                            }
                        }
                    }
                    
                    return nil
                }
            default:
                break
        }
            
        var useFont: NSFont? = nil
        if let aFont: NSFont = NSFont.init(name: self.bodyFontName, size: size) {
            useFont = aFont
        }
        
        if useFont == nil {
            useFont = NSFont.systemFont(ofSize: size, weight: .regular)
        }
        
        return useFont!
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
                return self.fontSize * 2.0
            case "h2":
                return self.fontSize * 1.6
            case "h3":
                return self.fontSize * 1.4
            case "h4":
                return self.fontSize * 1.2
            case "h5":
                return self.fontSize * 1.1
            default:
                return self.fontSize
            
        }
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
