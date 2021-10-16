/*
 *  Common.swift
 *  Code common to Previewer and Thumbnailer
 *
 *  Created by Tony Smith on 23/09/2020.
 *  Copyright © 2021 Tony Smith. All rights reserved.
 */


import Foundation
import SwiftyMarkdown
import Yaml
import AppKit


// FROM 1.4.0
// Implement as a class
class Common: NSObject {
    
    // MARK:- Public Properties
    
    var doShowLightBackground: Bool = false
    var doShowTag: Bool             = true
    
    // MARK:- Private Properties
    
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
    private var codeColourHex: String = BUFFOON_CONSTANTS.CODE_COLOUR_HEX
    private var headColourHex: String = BUFFOON_CONSTANTS.HEAD_COLOUR_HEX
    private var linkColourHex: String = BUFFOON_CONSTANTS.LINK_COLOUR_HEX
    private var codeFontName: String  = BUFFOON_CONSTANTS.CODE_FONT_NAME
    private var bodyFontName: String  = BUFFOON_CONSTANTS.BODY_FONT_NAME


    // MARK:- Lifecycle Functions
    
    init(_ isThumbnail: Bool) {
    
        super.init()
        
        // Load in the user's preferred values, or set defaults
        if let prefs = UserDefaults(suiteName: MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME) {
            self.fontSize = CGFloat(isThumbnail
                                    ? BUFFOON_CONSTANTS.THUMBNAIL_FONT_SIZE
                                    : prefs.float(forKey: "com-bps-previewmarkdown-base-font-size"))

            self.doShowLightBackground = prefs.bool(forKey: "com-bps-previewmarkdown-do-use-light")
            self.doShowYaml            = prefs.bool(forKey: "com-bps-previewmarkdown-do-show-front-matter")
            
            // FROM 1.4.0
            self.codeColourHex = prefs.string(forKey: "com-bps-previewmarkdown-code-colour-hex") ?? BUFFOON_CONSTANTS.CODE_COLOUR_HEX
            self.headColourHex = prefs.string(forKey: "com-bps-previewmarkdown-head-colour-hex") ?? BUFFOON_CONSTANTS.HEAD_COLOUR_HEX
            self.linkColourHex = prefs.string(forKey: "com-bps-previewmarkdown-link-colour-hex") ?? BUFFOON_CONSTANTS.LINK_COLOUR_HEX
            self.codeFontName  = prefs.string(forKey: "com-bps-previewmarkdown-code-font-name")  ?? BUFFOON_CONSTANTS.CODE_FONT_NAME
            self.bodyFontName  = prefs.string(forKey: "com-bps-previewmarkdown-body-font-name")  ?? BUFFOON_CONSTANTS.BODY_FONT_NAME
            self.doShowTag     = prefs.bool(forKey: "com-bps-previewmarkdown-do-show-tag")
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
            .foregroundColor: (isThumbnail || self.doShowLightBackground ? NSColor.black : NSColor.labelColor),
            .font: font
        ]
        
        self.hr = NSAttributedString(string: "\n\u{00A0}\u{0009}\u{00A0}\n\n",
                                     attributes: [.strikethroughStyle: NSUnderlineStyle.thick.rawValue,
                                                  .strikethroughColor: (self.doShowLightBackground ? NSColor.black : NSColor.white)])
        
        self.newLine = NSAttributedString.init(string: "\n",
                                               attributes: self.valAtts)
    }
    
    
    // MARK:- The Primary Function

    /**
     Use SwiftyMarkdown to render the input markdown.
     
     - parameters:
        - markdownString: The markdown file contents.
        - isThumbnail:    Are we rendering for a thumbnail (`true`) or a preview (`false`)?
     
     - returns: The rendered markdown as an NSAttributedString.
     */
    func getAttributedString(_ markdownString: String, _ isThumbnail: Bool) -> NSAttributedString {

        let swiftyMarkdown: SwiftyMarkdown = SwiftyMarkdown.init(string: "")
        setSwiftStyles(swiftyMarkdown, isThumbnail)
        var processed: String = processCodeTags(markdownString)
        processed = convertSpaces(processed)
        processed = processSymbols(processed)
        
        // Process the markdown string
        var output: NSMutableAttributedString = NSMutableAttributedString.init(attributedString: swiftyMarkdown.attributedString(from: processed))
        
        // FROM 1.3.0
        // Render YAML front matter if requested by the user, and we're not
        // rendering a thumbnail image (this is for previews only)
        if !isThumbnail && self.doShowYaml {
            // Extract the front matter
            let frontMatter: String = getFrontMatter(markdownString, #"^(-)+"#)
            if frontMatter.count > 0 {
                // Only attempt to render the front matter if there is any
                do {
                    let yaml: Yaml = try Yaml.load(frontMatter)
                    
                    // Assemble the front matter string
                    let renderedString: NSMutableAttributedString = NSMutableAttributedString.init(string: "",
                                                                                                   attributes: self.valAtts)
                    
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
                        errorString.append(NSMutableAttributedString.init(string: frontMatter,
                                                                          attributes: self.valAtts))
                    #endif
                    
                    errorString.append(self.hr)
                    errorString.append(output)
                    output = errorString
                }
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


    // MARK:- SwiftyMarkdown Rendering Support Functions

    func processSymbols(_ base: String) -> String {

        // FROM 1.1.0
        // Find and and replace any HTML symbol markup
        // Processed here because SwiftyMarkdown doesn't handle this markup

        let codes = ["&quot;", "&amp;", "&frasl;", "&lt;", "&gt;", "&lsquo;", "&rsquo;", "&ldquo;", "&rdquo;", "&bull;", "&ndash;", "&mdash;", "&trade;", "&nbsp;",  "&iexcl;", "&cent;", "&pound;", "&yen;", "&sect;", "&copy;", "&ordf;", "&reg;", "&deg;", "&ordm;", "&plusmn;", "&sup2;", "&sup3;", "&micro;", "&para;", "&middot;", "&iquest;", "&divide;", "&euro;", "&dagger;", "&Dagger;"]
        let symbols = ["\"", "&", "/", "<", ">", "‘", "’", "“", "”", "•", "-", "—", "™", " ", "¡", "¢", "£", "¥", "§", "©", "ª", "®", "º", "º", "±", "²", "³", "µ", "¶", "·", "¿", "÷", "€", "†", "‡"]

        // Look for HTML symbol code '&...;' substrings, eg. '&sup2;'
        let pattern = #"&[a-zA-Z]+[1-9]*;"#
        var result = base
        var range = base.range(of: pattern, options: .regularExpression)

        while range != nil {
            // Get the symbol from the 'symbols' array that has the same index
            // as the symbol code from the 'codes' array
            var repText = ""
            let find = String(result[range!])
            if codes.contains(find) {
                repText = symbols[codes.firstIndex(of: find)!]
            }

            // Swap out the HTML symbol code for the actual symbol
            result = result.replacingCharacters(in: range!, with: repText)

            // Get the next occurence of the pattern ready for the 'while...' check
            range = result.range(of: pattern, options: .regularExpression)
        }

        return result
    }


    func processCodeTags(_ base: String) -> String {

        // FROM 1.1.0
        // Look for markdown code blocks top'n'tailed with three ticks ```
        // Processed here because SwiftyMarkdown doesn't handle this markup

        var isBlock = false
        var index = 0
        var lines = base.components(separatedBy: CharacterSet.newlines)

        // Run through the lines looking for initial ```
        // Remove any found and inset the lines in between (for SwiftyMarkdown to format)
        for line in lines {
            if line.hasPrefix("```") {
                // Found a code block marker: remove the line and set
                // the marker to the opposite what it was, off or on
                lines.remove(at: index)
                isBlock = !isBlock
                continue
            }

            if isBlock {
                // Pad each line with an initial four spaces - this is what SwiftyMarkdown
                // looks for in a code block
                lines[index] = "    " + lines[index]
            }

            index += 1
        }

        // Re-assemble the string from the lines, spacing them with a newline
        // (except for the final line, of course)
        index = 0
        var result = ""
        for line in lines {
            result += line + (index < lines.count - 1 ? "\n" : "")
            index += 1
        }

        return result
    }


    func convertSpaces(_ base: String) -> String {

        // FROM 1.1.1
        // Convert space-formatted lists to tab-formatte lists
        // Required because SwiftyMarkdown doesn't indent on spaces

        // Find (multiline) x spaces followed by *, - or 1-9,
        // where x >= 1
        let pattern = #"(?m)^[ ]+([1-9]|\*|-)"#
        var result = base as NSString
        var nrange: NSRange = result.range(of: pattern, options: .regularExpression)

        // Use NSRange and NSString because it's easier to modify the
        // range to exclude the character *after* the spaces
        while nrange.location != NSNotFound {
            var tabs = ""

            // Get the range of the spaces minus the detected list character
            let crange: NSRange = NSMakeRange(nrange.location, nrange.length - 1)

            // Get the number of tabs characters we need to insert
            let tabCount = (nrange.length - 1) / BUFFOON_CONSTANTS.SPACES_FOR_A_TAB

            // Assemble the required number of tabs
            for _ in 0..<tabCount {
                tabs += "\t"
            }

            // Swap out the spaces for the string of one or more tabs
            result = result.replacingCharacters(in: crange, with: tabs) as NSString

            // Get the next occurence of the pattern ready for the 'while...' check
            nrange = result.range(of: pattern, options: .regularExpression)
        }

        return result as String
    }


    // MARK:- Front Matter Functions

    /**
     Extract and return initial front matter.

     FROM 1.3.0

     - Parameters:
        - markdown:      The markdown file content.
        - markerPattern: A string literal specifying the front matter boundary marker Reg Ex, eg. #"^(-)+"# for ---.

     - Returns: The parsed string, or an empty string (`""`) on error.
     */
    func getFrontMatter(_ markdown: String, _ markerPattern: String) -> String {
        
        let lines = markdown.components(separatedBy: CharacterSet.newlines)
        var fm: [String] = []
        var doAdd: Bool = false
        
        for line in lines {
            // Look for the pattern on the current line
            let dashRange: NSRange = (line as NSString).range(of: markerPattern, options: .regularExpression)
            
            if !doAdd && line.count > 0 {
                if dashRange.location == 0 {
                    // Front matter start
                    doAdd = true
                    continue
                } else {
                    // Some other text than front matter at the start
                    // so break
                    break
                }
            }
            
            if doAdd && dashRange.location == 0 {
                // End of front matter
                var rs: String = ""
                for item in fm {
                    rs += item + "\n"
                }
                
                return rs
            }
            
            if doAdd && line.count > 0 {
                // Add the line of front matter to the store
                fm.append(line)
            }
        }
        
        return ""
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


    // MARK:- Formatting Functions

    /**
     Set common style values for the markdown render.

     - Parameters:
        - sm:          The SwiftyMarkdown instance used for rendering
        - isThumbnail: Are we rendering a thumbnail (`true`) or a preview (`false`).
     */
    func setSwiftStyles(_ sm: SwiftyMarkdown, _ isThumbnail: Bool) {

        sm.setFontColorForAllStyles(with: (isThumbnail || self.doShowLightBackground) ? NSColor.black : NSColor.labelColor)
        sm.setFontSizeForAllStyles(with: self.fontSize)

        // FROM 1.4.0 -- add colour settings for headings too
        sm.h4.fontSize = self.fontSize * 1.2
        sm.h4.color = NSColor.hexToColour(self.headColourHex)
        sm.h3.fontSize = self.fontSize * 1.4
        sm.h3.color = sm.h4.color
        sm.h2.fontSize = self.fontSize * 1.6
        sm.h2.color = sm.h4.color
        sm.h1.fontSize = self.fontSize * 2.0
        sm.h1.color = sm.h4.color
        
        sm.setFontNameForAllStyles(with: self.bodyFontName)
        sm.code.fontName = self.codeFontName
        
        // Set the code colour
        sm.code.color = NSColor.hexToColour(self.codeColourHex) // getColour(codeColourIndex)

        // NOTE The following do not set link colour - this is
        //      a bug or issue with SwiftyMarkdown 1.2.3
        sm.link.color = NSColor.hexToColour(self.linkColourHex) // getColour(linkColourIndex)
        sm.link.underlineColor = sm.link.color
    }
    
}
