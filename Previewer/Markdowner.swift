/*
 *  Markdownwer.swift
 *  Wrapper for MarkdownIt JavaScript
 *
 *  Created by Tony Smith on 23/09/2020.
 *  Copyright © 2023 Tony Smith. All rights reserved.
 */


import Foundation
import JavaScriptCore
import AppKit


typealias ThemeAttrDict   = [String: [NSAttributedString.Key: AnyObject]]
public typealias ThemeStringDict = [String: [String: Any]]


class StylingInformation {
    
    var currentIndent: Int = 0
    var currentListType: Int = 0
    var currentListCountIndex: Int = 0
    var currentListCounts: [Int] = []
}


public class Markdowner {
    
    // MARK: - Public Properties
    
    var styleString: String = "body {font-family:sans-serif;cursor:default;}"
    var lineSpacing: CGFloat = 0.0
    var paraSpacing: CGFloat = 0.0
    
    var plainFont: NSFont!
    var boldFont: NSFont!
    var italicFont: NSFont!
    var codeFont: NSFont!
    var headFont: NSFont!
    var insetFont: NSFont!
    
    // MARK: - Private Properties
    
    private let mdjs: JSValue
    private let bundle: Bundle
    
    private let htmlStart: String = "<"
    private let htmlEnd: String = ">"
    private let tags: [String] = ["p", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "code", "em", "strong", "li"]
    private let bullets: [String] = ["•", "°", "∆", "†"]
    
    private let htmlEscape: NSRegularExpression = try! NSRegularExpression(pattern: "&#?[a-zA-Z0-9]+?;", options: .caseInsensitive)
    
    private var themeAttrDict: ThemeAttrDict!
    private var strippedTheme: ThemeStringDict!
    
    
    
    // MARK: - Constructor
    
    /**
     The default initialiser.
     
     - returns: `nil` on failure to load or evaluate `markdownit.min.js`.
    */
    public init?(_ mainFont: NSFont, _ codeFont: NSFont, _ styles: ThemeStringDict) {
        
        // Get the file's bundle based on how it's
        // being included in the host app
        let bundle = Bundle(for: Markdowner.self)

        // Load the highlight.js code from the bundle or fail
        guard let mdjsPath: String = bundle.path(forResource: "markdown-it", ofType: "js") else {
            return nil
        }

        // Check the JavaScript or fail
        let context = JSContext.init()!
        let mdjsString: String = try! String.init(contentsOfFile: mdjsPath)
        let _ = context.evaluateScript(mdjsString)
        guard let mdjs = context.globalObject.objectForKeyedSubscript("markdownit") else {
            return nil
        }
        
        // Store the results for later
        self.mdjs = mdjs.construct(withArguments: ["default"])
        self.bundle = bundle
        
        // Apply the font choice
        setFonts(mainFont, codeFont)
        
        // Generate and store the theme variants
        self.strippedTheme = styles
        self.themeAttrDict = strippedThemeToTheme(self.strippedTheme)
    }
    
    
    // MARK: - Primary Functions
    
    /**
     Highlight the supplied code in the specified language.
    
     - Parameters:
        - markdownString: The source code to highlight.
        - doFastRender:   Should fast rendering be used? Default: `true`.
     
     - Returns: The highlighted code as an NSAttributedString, or `nil`
    */
    open func render(_ markdownString: String, doAltRender: Bool = false) -> NSAttributedString? {

        // NOTE Will return 'undefined' (trapped below) if it's a unknown language
        let returnValue: JSValue = mdjs.invokeMethod("render", withArguments: [markdownString])
        var renderedHTMLString: String = returnValue.toString()
        
        // Trap 'undefined' output as this is effectively an error condition
        // and should not be returned as a valid result -- it's actually a fail
        if renderedHTMLString == "undefined" {
            return nil
        }

        // Convert the HTML received from Markdownit.js to an NSAttributedString or nil
        var returnAttrString: NSAttributedString? = nil
        
        if doAltRender {
            // Use fast rendering -- not yet implemented
            //return NSAttributedString.init(string: renderedHTMLString)
            return processHTMLString(renderedHTMLString)
        } else {
            // Add the HTML styling
            renderedHTMLString = "<style type=\"text/css\">" + self.styleString + "</style>" + renderedHTMLString
            //return NSAttributedString.init(string: renderedHTMLString)
            
            // Use NSAttributedString's own HTML -> NSAttributedString conversion
            let data = renderedHTMLString.data(using: String.Encoding.utf8)!
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]

            // This must be run on the main thread as it used WebKit under the hood
            safeMainSync {
                returnAttrString = try? NSMutableAttributedString(data:data,
                                                                  options: options,
                                                                  documentAttributes:nil)
            }
        }

        return returnAttrString
    }
    
    // MARK: - Fast HTML Rendering Function

    /**
     Generate an NSAttributedString from HTML source.
    
     - Parameters:
        - htmlString: The HTML to be converted.
     
     - Returns: The rendered HTML as an NSAttibutedString, or `nil` if an error occurred.
    */
    private func processHTMLString(_ htmlString: String) -> NSAttributedString? {

        let si: StylingInformation = StylingInformation()
        var doAddBullet: Bool = false
        
        let scanner: Scanner = Scanner(string: htmlString)
        scanner.charactersToBeSkipped = nil
        
        var scannedString: NSString? = nil
        let resultString: NSMutableAttributedString = NSMutableAttributedString(string: "",
                                                                                attributes: self.themeAttrDict["base"])
        var propertiesStack: [String] = ["base"]

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
                    
                    var spacer: String = String.init(repeating: " ", count: si.currentIndent * 4)
                    if si.currentListType == 1 {
                        spacer += self.bullets[si.currentIndent - 1] + " "
                    } else if si.currentListType == 2 {
                        spacer += "\(si.currentListCounts[si.currentListCountIndex]). "
                    }
                    
                    let style = self.themeAttrDict["base"]!
                    let insetString = NSAttributedString.init(string: spacer, attributes: [.font: self.insetFont!,
                                                                                           .foregroundColor: style[.foregroundColor]!])
                    resultString.append(insetString)
                }
                
                let attrScannedString: NSAttributedString = applyStyleToString((scannedString! as String),
                                                                               propertiesStack,
                                                                               si)
                resultString.append(attrScannedString)
                
                if ended {
                    continue
                }
            }
            
            // Step over the `<`
            scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
            
            // Get the first character of the tag
            let string: NSString = scanner.string as NSString
            let idx: Int = scanner.currentIndex.utf16Offset(in: htmlString)
            let nextChar: String = string.substring(with: NSMakeRange(idx, 1))
            
            if nextChar == "/" {
                // Found a close tag, so remove last attribute
                // Step over the `/`
                scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
                
                // Get the remainder of the tag up to `>`
                if let closeTag: String = scanner.scanUpToString(self.htmlEnd) {
                    // Closing a list? Then reduce the current indent
                    if closeTag == "ul" || closeTag == "ol"{
                        si.currentIndent -= 1
                        si.currentListCountIndex -= 1
                        
                        if si.currentIndent <= 0 {
                            si.currentIndent = 0
                            si.currentListType = 0
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
                    
                    // Opening a list? Then increment the current indent
                    if tagString == "ul" {
                        si.currentIndent += 1
                        si.currentListType = 1
                    }
                    
                    if tagString == "ol" {
                        si.currentIndent += 1
                        si.currentListType = 2
                        si.currentListCountIndex += 1
                        si.currentListCounts.append(1)
                    }
                    
                    if tagString == "li" && si.currentListType == 2 {
                        si.currentListCounts[si.currentListCountIndex] += 1
                    }
                    
                    if tagString == "li" {
                        useTag = "p"
                        doAddBullet = true
                    }
                    
                    if self.tags.contains(tagString) {
                        // The tag is one we look for
                        // Add the tag to the list of properties
                        propertiesStack.append(useTag)
                        
                        // Write out the tag for now
                        /*
                        let attrScannedString: NSAttributedString = applyStyleToString("[\(tagString)]",
                                                                                       ["base"],
                                                                                       StylingInformation())
                        resultString.append(attrScannedString)
                         */
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
    
    /**
     Convert a string to an NSAttributedString styled using the theme.
        
     Automatically applies the theme's font.
    
     - Parameters:
        - string:    The source code string.
        - styleList: An array of attribute keys (strings).
    
     - Returns: The styled text as an NSAttributedString.
   */
    internal func applyStyleToString(_ string: String, _ styleList: [String], _ details: StylingInformation) -> NSAttributedString {
       
        var returnString: NSMutableAttributedString? = nil
       
        let spacedParaStyle: NSMutableParagraphStyle = NSMutableParagraphStyle.init()
        spacedParaStyle.lineSpacing = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        spacedParaStyle.paragraphSpacing = (self.paraSpacing >= 0.0 ? self.paraSpacing : 0.0)
       
        if styleList.count > 0 {
            // Build the attributes from the style list, including the font
            var attrs = [NSAttributedString.Key: Any]()
            var useStyle = ""
           
            //attrs[.font] = self.plainFont
            attrs[.paragraphStyle] = spacedParaStyle
            
            for style in styleList {
                if let tagStyle = self.themeAttrDict[style] {
                    for (attrName, attrValue) in tagStyle {
                        attrs.updateValue(attrValue, forKey: attrName)
                    }
                }
            }
            
            returnString = NSMutableAttributedString(string: string,
                                                     attributes: attrs)
        } else {
            // No specified attributes? Just set the font
            returnString = NSMutableAttributedString(string: string,
                                                     attributes:[.font: self.plainFont as Any,
                                                                 .paragraphStyle: spacedParaStyle])
        }

        return returnString! as NSAttributedString
    }
    
    
    func setFonts(_ mainfont: NSFont, _ aCodeFont: NSFont) {

        self.plainFont = mainfont
        
        // Generate the bold and italic variants
        let boldDescriptor    = NSFontDescriptor(fontAttributes: [.family: mainfont.familyName!,
                                                                  .face: "Bold"])
        let italicDescriptor  = NSFontDescriptor(fontAttributes: [.family: mainfont.familyName!,
                                                                  .face: "Italic"])
        let obliqueDescriptor = NSFontDescriptor(fontAttributes: [.family: mainfont.familyName!,
                                                                  .face: "Oblique"])

        self.boldFont   = NSFont(descriptor: boldDescriptor,   size: mainfont.pointSize)
        self.italicFont = NSFont(descriptor: italicDescriptor, size: mainfont.pointSize)

        if (self.italicFont == nil || self.italicFont.familyName != mainfont.familyName) {
            self.italicFont = NSFont(descriptor: obliqueDescriptor, size: mainfont.pointSize)
        }

        if (self.italicFont == nil) {
            self.italicFont = mainfont
        }

        if (self.boldFont == nil) {
            self.boldFont = mainfont
        }
        
        self.codeFont = aCodeFont
        self.headFont = NSFont.init(name: mainfont.familyName!, size: mainfont.pointSize * 2.0)
        self.insetFont = NSFont.monospacedSystemFont(ofSize: mainfont.pointSize, weight: .regular)
    }
    
    
    /**
     Convert am instance's string dictionary to a base dictionary.
        
     - Parameters:
        - themeStringDict: The dictionary of styles and values.
     
     - Returns: The base dictionary.
    */
    private func strippedThemeToTheme(_ themeStringDict: ThemeStringDict) -> ThemeAttrDict {

        var returnTheme: ThemeAttrDict = ThemeAttrDict()
         
        for (styleName, properties) in themeStringDict {
            
            // Cumulative values
            var fontSize: CGFloat = 14.0
            var fontName: String = ""
            var fontStyle: String = ""
            var doRenderFont: Bool = false
            
            var keyProperties: [NSAttributedString.Key: AnyObject] = [NSAttributedString.Key: AnyObject]()
            
            for (key, property) in properties {
                switch key {
                    case "name":
                        fontName = property as! String
                        doRenderFont = true
                    case "size":
                        fontSize = property as! CGFloat
                        doRenderFont = true
                    case "style":
                        doRenderFont = true
                        fontStyle = property as! String
                    case "color":
                        keyProperties[.foregroundColor] = colourFromHexString(property as! String)
                    default:
                        break
                }
            }
            
            if doRenderFont {
                keyProperties[.font] = fontForCSSStyle(fontName, fontStyle, fontSize)
            }

            if keyProperties.count > 0 {
                returnTheme[styleName] = keyProperties
            }
        }

        return returnTheme
    }
    
    
    /**
     Get font information from a CSS string and use it to generate a font object.
        
     - Parameters:
        - fontStyle: The CSS font definition.
     
     - Returns: An NSFont.
    */
    internal func fontForCSSStyle(_ fontName: String, _ fontStyle: String, _ size: CGFloat) -> NSFont {
        
        var descriptor: NSFontDescriptor = NSFontDescriptor.init(fontAttributes: [.name: fontName,
                                                                                  .size: size])
        switch fontStyle {
            case "strong":
                descriptor = descriptor.withFace("Bold")
            case "em":
                descriptor = descriptor.withFace("Italic")
            case "plain":
                descriptor = descriptor.withFace("Regular")
            default:
                break
        }
        
        var useFont: NSFont!
        if let aFont: NSFont = NSFont.init(descriptor: descriptor, size: size) {
            useFont = aFont
        } else {
            useFont = NSFont.systemFont(ofSize: size,
                                        weight: fontStyle == "strong" ? .bold : .regular)
        }
        
        return useFont
    }

    
    /**
     Emit an AttributedString key based on the a style key from a CSS file.
        
     - Parameters:
        - key: The CSS attribute key.
     
     - Returns: The NSAttributedString key.
    */
    internal func attributeForCSSKey(_ key: String) -> NSAttributedString.Key {

        switch key {
        case "color":
            return .foregroundColor
        case "background-color":
            return .backgroundColor
        default:
            return .font
        }
    }

    /**
     Emit a colour object to match a hex string or CSS colour identifiier.
     
     Identifiers supported:
     
     * `white`
     * `black`
     * `red`
     * `green`
     * `blue`
     * `navy`
     * `silver`
     
     Unknown colour identifiers default to grey.
        
     - Parameters:
        - colourValue: The CSS colour specification.
     
     - Returns: A UIColor or NSColor.
    */
    internal func colourFromHexString(_ colourValue: String) -> NSColor {
        
        var colourString: String = colourValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if (colourString.hasPrefix("#")) {
            // The colour is defined by a hex value
            colourString = (colourString as NSString).substring(from: 1)
        } else {
            switch colourString {
            case "white":
                return NSColor.init(white: 1.0, alpha: 1.0)
            case "black":
                return NSColor.init(white: 0.0, alpha: 1.0)
            case "red":
                return NSColor.init(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
            case "green":
                return NSColor.init(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0)
            case "blue":
                return NSColor.init(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            case "navy":
                return NSColor.init(red: 0.0, green: 0.0, blue: 0.5, alpha: 1.0)
            case "silver":
                return NSColor.init(red: 0.75, green: 0.75, blue: 0.75, alpha: 1.0)
            default:
                return NSColor.gray
            }
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
    
    
    /**
     Convert a CSS to a string dictionary.
        
     - Parameters:
        - themeString: The theme's CSS string.
     
     - Returns: A dictionary of styles and values.
    */
    private func stripTheme(_ themeString : String) -> ThemeStringDict {
        
        /* DEFAULT THEME
         
         .hljs{display:block;overflow-x:auto;padding:.5em;background:#f0f0f0}.hljs,.hljs-subst{color:#444}.hljs-comment{color:#888}.hljs-attribute,.hljs-doctag,.hljs-keyword,.hljs-meta-keyword,.hljs-name,.hljs-selector-tag{font-weight:700}.hljs-deletion,.hljs-number,.hljs-quote,.hljs-selector-class,.hljs-selector-id,.hljs-string,.hljs-template-tag,.hljs-type{color:#800}.hljs-section,.hljs-title{color:#800;font-weight:700}.hljs-link,.hljs-regexp,.hljs-selector-attr,.hljs-selector-pseudo,.hljs-symbol,.hljs-template-variable,.hljs-variable{color:#bc6060}.hljs-literal{color:#78a960}.hljs-addition,.hljs-built_in,.hljs-bullet,.hljs-code{color:#397300}.hljs-meta{color:#1f7199}.hljs-meta-string{color:#4d99bf}.hljs-emphasis{font-style:italic}.hljs-strong{font-weight:700}
        
         
        h1 {font-family:\(baseFontName);font-size:\(self.fontSize * 2.0);color:#\(self.headColourHex);margin-top:1em} "
         
         */
        
        let objcString: NSString = (themeString as NSString)
        let cssRegex = try! NSRegularExpression(pattern: "(?:(\\.[a-zA-Z0-9\\-_]*(?:[, ]\\.[a-zA-Z0-9\\-_]*)*)\\{([^\\}]*?)\\})",
                                                options:[.caseInsensitive])
        let results = cssRegex.matches(in: themeString,
                                       options: [.reportCompletion],
                                       range: NSMakeRange(0, objcString.length))
        var resultDict = [String: [String: String]]()

        for result in results {
            if result.numberOfRanges == 3 {
                var attributes = [String: String]()
                let cssPairs = objcString.substring(with: result.range(at: 2)).components(separatedBy: ";")
                for pair in cssPairs {
                    let cssPropComp = pair.components(separatedBy: ":")
                    if (cssPropComp.count == 2) {
                        attributes[cssPropComp[0]] = cssPropComp[1]
                    }
                }

                if attributes.count > 0 {
                    // Check if we're adding attributes to an existing hljs key
                    if resultDict[objcString.substring(with: result.range(at: 1))] != nil {
                        // We have the key already so merge in the latest attribute dictionary
                        let existingAttributes: [String: String] = resultDict[objcString.substring(with: result.range(at: 1))]!
                        resultDict[objcString.substring(with: result.range(at: 1))] = existingAttributes.merging(attributes, uniquingKeysWith: { (first, _) in first })
                    } else {
                        // Set the attributes to a new key
                        resultDict[objcString.substring(with: result.range(at: 1))] = attributes
                    }
                }
            }
        }

        var returnDict = [String: [String: String]]()
        for (keys, result) in resultDict {
            let keyArray = keys.replacingOccurrences(of: " ", with: ",").components(separatedBy: ",")
            for key in keyArray {
                var props : [String: String]?
                props = returnDict[key]
                if props == nil {
                    props = [String:String]()
                }

                for (pName, pValue) in result {
                    props!.updateValue(pValue, forKey: pName)
                }

                returnDict[key] = props!
            }
        }

        return returnDict
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
