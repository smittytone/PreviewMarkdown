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
    var fontSize: CGFloat = 14.0
    var fontFamily: PMFont!
    var bodyFontName: String = ""
    var codeFontName: String = ""
    var styles: ThemeStringDict!
    private var attributes: ThemeAttrDict!
    private var underlineItalics: Bool = false
    private var backgroundBold: Bool = false
    
    // MARK: - Private Properties
    
    private let mdjs: JSValue
    private let bundle: Bundle
    
    private let htmlStart: String = "<"
    private let htmlEnd: String = ">"
    private let tags: [String] = ["p", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "code", "em", "strong", "li"]
    private let bullets: [String] = ["•", "›", "»", "†"]
    private let htmlEscape: NSRegularExpression = try! NSRegularExpression(pattern: "&#?[a-zA-Z0-9]+?;", options: .caseInsensitive)
    
    private var spacedParaStyle: NSMutableParagraphStyle!
    private var insetFont: NSFont!
    private var plainFont: NSFont!
    
    
    // MARK: - Constructor
    
    /**
     The default initialiser.
     
     - returns: `nil` on failure to load or evaluate `markdownit.min.js`.
    */
    public init?() {
        
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

        // Generate and store the theme variants
        self.attributes = processStyles(self.styles)
        
        // Apply the font choice
        setFonts()
        
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
                                                                                attributes: self.attributes["base"])
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
                    
                    let style = self.attributes["base"]!
                    let insetString = NSAttributedString.init(string: spacer, attributes: [.font: self.insetFont!,
                                                                                           .foregroundColor: style[.foregroundColor]!,
                                                                                           .paragraphStyle: self.spacedParaStyle!])
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
                        
                        // Remove the following CR
                        let _: String? = scanner.scanUpToString("\n")
                        
                        // Remove the next tag's CR
                        if (si.currentIndent != 0) {
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
                        si.currentIndent += 1
                        si.currentListType = 1
                        doSkipCR = true
                    }
                    
                    if tagString == "ol" {
                        si.currentIndent += 1
                        si.currentListType = 2
                        si.currentListCountIndex += 1
                        si.currentListCounts.append(1)
                        doSkipCR = true
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
       
        if styleList.count > 0 {
            // Build the attributes from the style list, including the font
            var attrs = [NSAttributedString.Key: Any]()
            for style in styleList {
                if let tagStyle = self.attributes[style] {
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
                                                                 .paragraphStyle: self.spacedParaStyle!])
        }

        return returnString! as NSAttributedString
    }
    
    
    func setFonts() {

        // Set up the standard para spacing
        self.spacedParaStyle = NSMutableParagraphStyle()
        self.spacedParaStyle.lineSpacing = (self.lineSpacing >= 0.0 ? self.lineSpacing : 0.0)
        self.spacedParaStyle.paragraphSpacing = (self.paraSpacing >= 0.0 ? self.paraSpacing : self.lineSpacing)
         
        self.plainFont = NSFont(name: self.bodyFontName, size: self.fontSize)
        if self.plainFont == nil {
            self.plainFont = NSFont.systemFont(ofSize: self.fontSize)
        }
        
        self.insetFont = NSFont.monospacedSystemFont(ofSize: self.fontSize,
                                                     weight: .regular)
    }
    
    
    /**
     Convert an instance's string dictionary to a base dictionary.
        
     - Parameters:
        - themeStringDict: The dictionary of styles and values.
     
     - Returns: The base dictionary.
    */
    private func processStyles(_ themeStringDict: ThemeStringDict) -> ThemeAttrDict {

        var returnTheme: ThemeAttrDict = ThemeAttrDict()
        
        for (styleName, properties) in themeStringDict {
            
            if styleName == "base" {
                self.fontSize = properties["size"] as! CGFloat
            }
            
            // Cumulative values
            var fontSize: CGFloat = 14.0
            var fontName: String = ""
            var fontStyle: String = "plain"
            var doRenderFont: Bool = false
            
            var keyProperties: [NSAttributedString.Key: AnyObject] = [NSAttributedString.Key: AnyObject]()
            keyProperties[.paragraphStyle] = self.spacedParaStyle
            
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
                keyProperties[.font] = fontForStyle(fontName, fontStyle, fontSize)
                
                // Handle styles not supported by font variants
                if (fontStyle == "italic" && self.underlineItalics) {
                    keyProperties[.underlineColor] = NSColor.red
                    //keyProperties[.underlineStyle] = NSUnderlineStyle.patternDot as AnyObject
                }
                
                if (fontStyle == "bold" && self.backgroundBold) {
                    keyProperties[.backgroundColor] = NSColor.darkGray
                }
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
    internal func fontForStyle(_ fontName: String, _ fontStyle: String, _ size: CGFloat) -> NSFont {
        
        switch fontStyle {
            case "bold":
                var descriptor: NSFontDescriptor = NSFontDescriptor.init(fontAttributes: [.family: self.fontFamily.displayName,
                                                                                          .size: size])
                
                for faceName: String in ["Bold", "Black", "Heavy", "Medium"] {
                    descriptor = descriptor.addingAttributes([.face: faceName])
                    var aFont: NSFont? = NSFont.init(descriptor: descriptor, size: size)
                    if aFont != nil {
                        return aFont!
                    }
                }
                
                self.backgroundBold = true
                return NSFont.init(name: fontName, size: size)!
                
            case "italic":
                var descriptor: NSFontDescriptor = NSFontDescriptor.init(fontAttributes: [.family: self.fontFamily.displayName,
                                                                                          .size: size])
                for faceName: String in ["Italic", "Oblique"] {
                    descriptor = descriptor.addingAttributes([.face: faceName])
                    var aFont: NSFont? = NSFont.init(descriptor: descriptor, size: size)
                    if aFont != nil {
                        return aFont!
                    }
                }
                
                self.underlineItalics = true
                return NSFont.init(name: fontName, size: size)!
                
            default:
                break
        }
        
        var useFont: NSFont? = nil
        if let aFont: NSFont = NSFont.init(name: fontName, size: size) {
            useFont = aFont
        }
        
        if useFont == nil {
            useFont = NSFont.systemFont(ofSize: size, weight: .regular)
        }
        
        return useFont!
    }


    /**
     Emit a colour object to match a hex string or CSS colour identifiier.
     
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
