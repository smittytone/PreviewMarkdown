/*
 *  Common.swift
 *  Code common to Previewer and Thumbnailer
 *
 *  Created by Tony Smith on 23/09/2020.
 *  Copyright © 2024 Tony Smith. All rights reserved.
 */


import Foundation
import Yaml
import AppKit


class MarkdownComponents {
    // TO-DO Replace with ranges
    var frontMatterStart: String.Index? = nil
    var frontMatterEnd: String.Index?   = nil
    var markdownStart: String.Index?    = nil
    var markdownEnd: String.Index?      = nil
}


// FROM 1.4.0
// Implement as a class
class Common: NSObject {
    
    // MARK: - Public Properties
    
    var doShowLightBackground: Bool         = false
    // FROM 2.0.0
    var viewWidth: CGFloat                  = 512
    
    // MARK: - Private Properties
    
    private var doIndentScalars: Bool       = true
    private var doShowYaml: Bool            = false
    private var fontSize: CGFloat           = CGFloat(BUFFOON_CONSTANTS.PREVIEW_FONT_SIZE)

    // FROM 1.3.0
    // Front Matter string attributes...
    private var keyAtts: [NSAttributedString.Key:Any] = [:]
    private var valAtts: [NSAttributedString.Key:Any] = [:]
    
    // Front Matter rendering artefacts...
    private var hr: NSAttributedString      = NSAttributedString.init(string: "")
    private var newLine: NSAttributedString = NSAttributedString.init(string: "")
    
    // FROM 1.4.0
            var codeColourHex: String       = BUFFOON_CONSTANTS.CODE_COLOUR_HEX
    private var headColourHex: String       = BUFFOON_CONSTANTS.HEAD_COLOUR_HEX
    private var linkColourHex: String       = BUFFOON_CONSTANTS.LINK_COLOUR_HEX
    private var codeFontName: String        = BUFFOON_CONSTANTS.CODE_FONT_NAME
    private var bodyFontName: String        = BUFFOON_CONSTANTS.BODY_FONT_NAME
    
    // FROM 1.5.0
    private var lineSpacing: CGFloat        = BUFFOON_CONSTANTS.BASE_LINE_SPACING
    private var quoteColourHex: String      = BUFFOON_CONSTANTS.LINK_COLOUR_HEX
    
    // FROM 2.0.0
    private var markdowner: Markdowner?     = nil
    private var isThumbnail: Bool           = false

    /*
     Replace the following string with your own team ID. This is used to
     identify the app suite and so share preferences set by the main app with
     the previewer and thumbnailer extensions.
     */
    private var appSuiteName: String = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME


    // MARK: - Lifecycle Functions
    
    init(_ isThumbnail: Bool = false) {
    
        super.init()
        
        // Load in the user's preferred values, or set defaults
        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            self.fontSize = CGFloat(isThumbnail
                                    ? BUFFOON_CONSTANTS.THUMBNAIL_FONT_SIZE
                                    : defaults.float(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_SIZE))

            self.doShowLightBackground = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_USE_LIGHT)
            self.doShowYaml            = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_YAML)
            
            // FROM 1.4.0
            self.codeColourHex  = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_COLOUR) ?? BUFFOON_CONSTANTS.CODE_COLOUR_HEX
            self.headColourHex  = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_HEAD_COLOUR) ?? BUFFOON_CONSTANTS.HEAD_COLOUR_HEX
            self.linkColourHex  = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINK_COLOUR) ?? BUFFOON_CONSTANTS.LINK_COLOUR_HEX
            self.codeFontName   = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_FONT_NAME) ?? BUFFOON_CONSTANTS.CODE_FONT_NAME
            self.bodyFontName   = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_NAME) ?? BUFFOON_CONSTANTS.BODY_FONT_NAME
            
            // FROM 1.5.0
            self.lineSpacing    = CGFloat(defaults.float(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINE_SPACE))
            self.quoteColourHex = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_QUOTE_COLOUR) ?? BUFFOON_CONSTANTS.QUOTE_COLOUR_HEX
        }
        
        // Just in case the above block reads in zero values
        // NOTE The other values CAN be zero
        if self.fontSize < BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[0] ||
            self.fontSize > BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS.count - 1] {
            self.fontSize = CGFloat(BUFFOON_CONSTANTS.PREVIEW_FONT_SIZE)
        }

        // FROM 1.3.0
        // Set the front matter key:value fonts and sizes
        var font: NSFont
        if let otherFont = NSFont.init(name: self.codeFontName, size: self.fontSize) {
            font = otherFont
        } else {
            // This should not be hit, but just in case...
            font = NSFont.systemFont(ofSize: self.fontSize)
        }
        
        self.keyAtts = [
            .foregroundColor: NSColor.hexToColour(self.codeColourHex),
            .font: font
        ]
        
        self.valAtts = [
            .foregroundColor: (isThumbnail || self.doShowLightBackground ? NSColor.black : NSColor.white),
            .font: font
        ]
        
        // NOTE Requires NSTextView to use TextKit 1 for this to work
        self.hr = NSAttributedString(string: "\n\u{00A0}\u{0009}\u{00A0}\n\n",
                                     attributes: [.strikethroughStyle: NSUnderlineStyle.thick.rawValue,
                                                  .strikethroughColor: (self.doShowLightBackground ? NSColor.black : NSColor.white)])
        
        self.newLine = NSAttributedString.init(string: "\n", attributes: self.valAtts)
        self.isThumbnail = isThumbnail
    }
    
    
    // MARK: - The Primary Function

    /**
        Render the provided markdown.
     
     - parameters:
        - markdownString: The raw file contents.
     
     - returns: The rendered markdown as an NSAttributedString.
     */
    func getAttributedString(_ rawText: String) -> NSAttributedString {

        // Process the markdown string
        var output: NSMutableAttributedString = NSMutableAttributedString.init(string: "")
        
        // Look for YAML front matter
        var frontMatter: Substring = ""
        let components: MarkdownComponents = getFrontMatter(rawText)
        if components.frontMatterStart != nil {
            if !self.isThumbnail {
                frontMatter = rawText[components.frontMatterStart!...components.frontMatterEnd!]
            }
        }
        
        // If we're rendering a thumbnail, count the lines and paragraphcs,
        // and update `components.markdownEnd` to skip lines we won't show
        if self.isThumbnail {
            var wordCount: Int = 0
            var lineCount: Int = 0
            
            // Iterate over the raw string's markdown area
            for index in rawText[components.markdownStart!..<components.markdownEnd!].indices {
                // Get the character at each index
                let characterAtIndex = rawText[index]
                if characterAtIndex == " " {
                    wordCount += 1
                } else if characterAtIndex == "\n" {
                    if wordCount > 0 {
                        lineCount += 1 + (wordCount / 12)
                        wordCount = 0
                    } else {
                        lineCount += 1
                    }
                }
                
                // Got the max. number of paragraphs? Break out
                if lineCount >= BUFFOON_CONSTANTS.THUMBNAIL_LINE_COUNT {
                    components.markdownEnd = index
                    break
                }
            }
        }
        
        // Get the markdown content that comes after the front matter (if there is any)
        let markdownToRender: Substring = rawText[components.markdownStart!..<components.markdownEnd!]
        
        // Load in the Markdown converter
        let markdowner: Markdowner? = Markdowner.init()
        if markdowner == nil {
            // Missing JS code file or other init error
            output = NSMutableAttributedString.init(string: "Could not instantiate MDJS",
                                                    attributes: self.valAtts)
        }
        
        if output.length == 0 {
            // No error encountered getting the JavaScript so proceed to render the string
            // First set up the styler with the chosen settings
            let styler: Styler = Styler.init(self.isThumbnail || self.doShowLightBackground)
            styler.bodyFontName = self.bodyFontName
            styler.codeFontName = self.codeFontName
            styler.bodyColour = self.isThumbnail || self.doShowLightBackground ? NSColor.black : NSColor.white
            styler.fontSize = self.fontSize
            styler.lineSpacing = (self.lineSpacing - 1.0) * self.fontSize
            styler.paraSpacing = 12.0
            styler.colourValues.head = self.headColourHex
            styler.colourValues.code = self.codeColourHex
            styler.colourValues.link = self.linkColourHex
            styler.colourValues.quote = self.quoteColourHex
            styler.viewWidth = self.viewWidth
            
            if let attStr: NSAttributedString = styler.render(markdowner!.tokenise(markdownToRender), self.isThumbnail) {
                output = NSMutableAttributedString.init(attributedString: attStr)
                
                // Render YAML front matter if requested by the user, and we're not
                // rendering a thumbnail image (this is for previews only)
                if !isThumbnail && self.doShowYaml && frontMatter.count > 0 {
                    do {
                        let yaml: Yaml = try Yaml.load(String(frontMatter))
                        
                        // Assemble the front matter string
                        let renderedString: NSMutableAttributedString = NSMutableAttributedString.init(string: "", attributes: self.valAtts)
                        
                        // Initial line
                        renderedString.append(self.hr)
                        
                        // Render the YAML to NSAttributedString
                        if let yamlString = renderYaml(yaml, 0, false) {
                            renderedString.append(yamlString)
                        }
                        
                        // Add a line after the front matter
                        renderedString.append(self.hr)
                        
                        // Add in the orignal rendered markdown and then set the
                        // output string to the combined string
                        renderedString.append(output)
                        output = renderedString
                    } catch {
                        // No YAML to render, or mis-formatted
                        // No YAML to render, or the YAML was mis-formatted
                        // Get the error as reported by YamlSwift
                        let yamlErr: Yaml.ResultError = error as! Yaml.ResultError
                        var yamlErrString: String
                        switch(yamlErr) {
                            case .message(let s):
                                yamlErrString = s ?? "unknown"
                        }
                        
                        // Assemble the error string
                        let errorString: NSMutableAttributedString = NSMutableAttributedString.init(string: "Could not render the YAML. Error: " + yamlErrString,
                                                                                                    attributes: self.keyAtts)
                        
                        // Should we include the raw text?
                        // At least the user can see the data this way
#if DEBUG
                        errorString.append(self.hr)
                        errorString.append(NSMutableAttributedString.init(string: String(frontMatter),
                                                                          attributes: self.valAtts))
#endif
                        
                        errorString.append(self.hr)
                        errorString.append(output)
                        output = errorString
                    }
                }
            } else {
                output = NSMutableAttributedString.init(string: "Could not render markdown string",
                                                        attributes: self.valAtts)
            }
        }

        // FROM 1.3.0
        // Guard against non-trapped errors
        if output.length == 0 {
            return NSAttributedString.init(string: "No valid Markdown to render.",
                                           attributes: self.keyAtts)
        }
        
        // Return the rendered NSAttributedString to Previewer or Thumbnailer
        return output as NSAttributedString
    }


    // MARK: - Front Matter Functions


    /**
     Extract and return initial front matter.

     FROM 1.3.0, updated 1.5.1, 2.0.0

     - Parameters:
        - markdown:     The markdown file content.

     - Returns: A data structure indicating front matter, markdown ranges.
     */
    func getFrontMatter(_ markdown: String) -> MarkdownComponents {
        
        // Assume the data is ALL markdown
        let components: MarkdownComponents = MarkdownComponents.init()
        components.markdownEnd = markdown.endIndex
        components.markdownStart = markdown.startIndex
        
        // Look for YAML symbol code
        let lineFindRegex = #"(?s)(?<=---\n).*(?=\n---)"#
        let dotFindRegex  = #"(?s)(?<=---\n).*(?=\n\.\.\.)"#
        
        // First look for ... to ...
        if let range = markdown.range(of: dotFindRegex, options: .regularExpression) {
            components.frontMatterStart = range.lowerBound
            components.frontMatterEnd = range.upperBound
        }
        
        // Didn't find ... to ... so look for --- to ---
        if let range = markdown.range(of: lineFindRegex, options: .regularExpression) {
            components.frontMatterStart = range.lowerBound
            components.frontMatterEnd = range.upperBound
        }
        
        // Make sure the front matte, if any, is no preceded by any text
        if components.frontMatterStart != nil {
            let endIndex: String.Index = markdown.index(components.frontMatterStart!, offsetBy: -4)
            let start: String = String(markdown[markdown.startIndex..<endIndex])
            if !start.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Front matter comes after text, ie. it is NOT front matter
                components.frontMatterStart = nil
                components.frontMatterEnd = nil
            }
        }
        
        // Set the start of the markdown content (after the front matter, if any)
        if let end = components.frontMatterEnd {
            components.markdownStart = markdown.index(end, offsetBy: 4)
        } else {
            components.markdownStart = markdown.startIndex
        }
        
        return components
    }


    /**
     Render a supplied YAML sub-component ('part') to an NSAttributedString.

     Indents the value as required.
     
     FROM 1.3.0

     - Parameters:
        - part:   A partial Yaml object.
        - indent: The number of indent spaces to add.
        - isKey:  Is the Yaml part a key?

     - Returns: The rendered string as an NSAttributedString, or nil on error.
     */
    func renderYaml(_ part: Yaml, _ indent: Int, _ isKey: Bool) -> NSAttributedString? {
        
        let returnString: NSMutableAttributedString = NSMutableAttributedString.init(string: "",
                                                                                     attributes: keyAtts)
        
        switch (part) {
        case .array:
            if let value = part.array {
                // Iterate through array elements
                // NOTE A given element can be of any YAML type
                for i in 0..<value.count {
                    if let yamlString = renderYaml(value[i], indent, false) {
                        // Apply a prefix to separate array and dictionary elements
                        if i > 0 && (value[i].array != nil || value[i].dictionary != nil) {
                            returnString.append(self.newLine)
                        }
                        
                        // Add the element itself
                        returnString.append(yamlString)
                    }
                }
                
                return returnString
            }
        case .dictionary:
            if let dict = part.dictionary {
                // Iterate through the dictionary's keys and their values
                // NOTE A given value can be of any YAML type
                
                // Sort the dictionary's keys (ascending)
                // We assume all keys will be strings, ints, doubles or bools
                var keys: [Yaml] = Array(dict.keys)
                keys = keys.sorted(by: { (a, b) -> Bool in
                    // Strings?
                    if let a_s: String = a.string {
                        if let b_s: String = b.string {
                            return (a_s.lowercased() < b_s.lowercased())
                        }
                    }
                    
                    // Ints?
                    if let a_i: Int = a.int {
                        if let b_i: Int = b.int {
                            return (a_i < b_i)
                        }
                    }
                    
                    // Doubles?
                    if let a_d: Double = a.double {
                        if let b_d: Double = b.double {
                            return (a_d < b_d)
                        }
                    }
                    
                    // Bools
                    if let a_b: Bool = a.bool {
                        if let b_b: Bool = b.bool {
                            return (a_b && !b_b)
                        }
                    }
                    
                    return false
                })
                
                // Iterate through the sorted keys array
                for i in 0..<keys.count {
                    // Prefix root-level key:value pairs after the first with a new line
                    if indent == 0 && i > 0 {
                        returnString.append(self.newLine)
                    }
                    
                    // Get the key:value pairs
                    let key: Yaml = keys[i]
                    let value: Yaml = dict[key] ?? ""
                    
                    // Render the key
                    if let yamlString = renderYaml(key, indent, true) {
                        returnString.append(yamlString)
                    }
                    
                    // If the value is a collection, we drop to the next line and indent
                    var valueIndent: Int = 0
                    if value.array != nil || value.dictionary != nil || self.doIndentScalars {
                        valueIndent = indent + BUFFOON_CONSTANTS.YAML_INDENT
                        returnString.append(self.newLine)
                    }
                    
                    // Render the key's value
                    if let yamlString = renderYaml(value, valueIndent, false) {
                        returnString.append(yamlString)
                    }
                }
                
                return returnString
            }
        case .string:
            if let keyOrValue = part.string {
                let parts: [String] = keyOrValue.components(separatedBy: "\n")
                if parts.count > 2 {
                    for i in 0..<parts.count {
                        let part: String = parts[i]
                        returnString.append(getIndentedString(part + (i < parts.count - 2 ? "\n" : ""), indent))
                    }
                } else {
                    returnString.append(getIndentedString(keyOrValue, indent))
                }

                returnString.setAttributes((isKey ? self.keyAtts : self.valAtts),
                                           range: NSMakeRange(0, returnString.length))
                returnString.append(isKey ? NSAttributedString.init(string: " ", attributes: self.valAtts) : self.newLine)
                return returnString
            }
        case .null:
            returnString.append(getIndentedString(isKey ? "NULL KEY/n" : "NULL VALUE/n", indent))
            returnString.setAttributes((isKey ? self.keyAtts : self.valAtts),
                                       range: NSMakeRange(0, returnString.length))
            returnString.append(isKey ? NSAttributedString.init(string: " ") : self.newLine)
            return returnString
        default:
            // Place all the scalar values here
            // TODO These *may* be keys too, so we need to check that
            if let val = part.int {
                returnString.append(getIndentedString("\(val)\n", indent))
            } else if let val = part.bool {
                returnString.append(getIndentedString((val ? "TRUE\n" : "FALSE\n"), indent))
            } else if let val = part.double {
                returnString.append(getIndentedString("\(val)\n", indent))
            } else {
                returnString.append(getIndentedString("UNKNOWN-TYPE\n", indent))
            }
            
            returnString.setAttributes(self.valAtts,
                                       range: NSMakeRange(0, returnString.length))
            return returnString
        }
        
        // Error condition
        return nil
    }


    /**
     Return a space-prefix NSAttributedString.
     
     FROM 1.3.0

     - Parameters:
        - baseString: The string to be indented.
        - indent:     The number of indent spaces to add.

     - Returns: The indented string as an NSAttributedString.
     */
    func getIndentedString(_ baseString: String, _ indent: Int) -> NSAttributedString {
        
        let trimmedString = baseString.trimmingCharacters(in: .whitespaces)
        let spaces = "                                                     "
        let spaceString = String(spaces.suffix(indent))
        let indentedString: NSMutableAttributedString = NSMutableAttributedString.init()
        indentedString.append(NSAttributedString.init(string: spaceString))
        indentedString.append(NSAttributedString.init(string: trimmedString))
        return indentedString.attributedSubstring(from: NSMakeRange(0, indentedString.length))
    }
    
}


/**
Get the encoding of the string formed from data.

- Returns: The string's encoding or nil.
*/

extension Data {
    
    var stringEncoding: String.Encoding? {
        var nss: NSString? = nil
        guard case let rawValue = NSString.stringEncoding(for: self,
                                                          encodingOptions: nil,
                                                          convertedString: &nss,
                                                          usedLossyConversion: nil), rawValue != 0 else { return nil }
        return .init(rawValue: rawValue)
    }
}


/**
Swap the paragraph style in all of the attributes of
 an NSMutableAttributedString.

- Parameters:
 - paraStyle: The injected NSParagraphStyle.
*/
extension NSMutableAttributedString {
    
    func addParaStyle(with paraStyle: NSParagraphStyle) {
        beginEditing()
        self.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: self.length)) { (value, range, stop) in
            if let _ = value as? NSParagraphStyle {
                addAttribute(.paragraphStyle, value: paraStyle, range: range)
            }
        }
        endEditing()
    }
}
