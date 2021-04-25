//
//  Common.swift
//  Code common to Previewer and Thumbnailer
//
//  Created by Tony Smith on 23/09/2020.
//  Copyright © 2021 Tony Smith. All rights reserved.
//

import Foundation
import SwiftyMarkdown
import Yaml
import AppKit


// FROM 1.2.0
// Set defaults for the user-selectable values
private var codeColourIndex: Int = BUFFOON_CONSTANTS.CODE_COLOUR_INDEX
private var codeFontIndex: Int = BUFFOON_CONSTANTS.CODE_FONT_INDEX
private var bodyFontIndex: Int = BUFFOON_CONSTANTS.BODY_FONT_INDEX
private var fontSizeBase: CGFloat = CGFloat(BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE)
private var linkColourIndex: Int = BUFFOON_CONSTANTS.LINK_COLOUR_INDEX
private var doShowLightBackground: Bool = false
private let codeFonts: [String] = ["AndaleMono", "Courier", "Menlo-Regular", "Monaco"]
private let bodyFonts: [String] = ["system", "ArialMT", "Helvetica", "HelveticaNeue", "LucidaGrande", "Times-Roman", "Verdana"]
// FROM 1.3.0
// Front Matter string attributes...
private var keyAtts: [NSAttributedString.Key:Any] = [
    NSAttributedString.Key.foregroundColor: getColour(codeColourIndex),
    NSAttributedString.Key.font: NSFont.init(name: codeFonts[codeFontIndex], size: fontSizeBase) as Any
]
private var valAtts: [NSAttributedString.Key:Any] = [
    NSAttributedString.Key.foregroundColor: (doShowLightBackground ? NSColor.black : NSColor.labelColor),
    NSAttributedString.Key.font: NSFont.init(name: codeFonts[codeFontIndex], size: fontSizeBase) as Any
]
// Front Matter rendering artefacts...
private var hr = NSAttributedString(string: "\n\u{00A0}\u{0009}\u{00A0}\n\n", attributes: [.strikethroughStyle: NSUnderlineStyle.patternDot.rawValue, .strikethroughColor: NSColor.labelColor])
private let newLine: NSAttributedString = NSAttributedString.init(string: "\n")

    

// MARK: Primary Function

func getAttributedString(_ markdownString: String, _ isThumbnail: Bool) -> NSAttributedString {

    // FROM 1.1.0
    // Use SwiftyMarkdown to render the input markdown as an NSAttributedString, which is returned
    // NOTE Set the font colour according to whether we're rendering a thumbail or a preview
    //      (thumbnails always rendered black on white; previews may be the opposite [dark mode])

    let swiftyMarkdown: SwiftyMarkdown = SwiftyMarkdown.init(string: "")
    setBaseValues(swiftyMarkdown, isThumbnail)
    var processed = processCodeTags(markdownString)
    processed = convertSpaces(processed)
    
    // Process the markdown string
    var output: NSMutableAttributedString = NSMutableAttributedString.init()
    output.append(swiftyMarkdown.attributedString(from: processSymbols(processed)))
    
    // FROM 1.3.0
    // Render YAML front matter if requested by the user, and we're not
    // rendering a thumbnail image (this is for previews only)
    if let defaults = UserDefaults(suiteName: MNU_SECRETS.PID + ".suite.previewmarkdown") {
        if !isThumbnail && defaults.bool(forKey: "com-bps-previewmarkdown-do-show-front-matter") {
            // Extract the front matter
            let frontMatter: String = getFrontMatter(markdownString, #"^(-)+"#)
            if frontMatter.count > 0 {
                // Only attempt to render the front matter if there is any
                do {
                    let yaml = try Yaml.load(frontMatter)
                    
                    // Assemble the front matter string
                    let renderedString: NSMutableAttributedString = NSMutableAttributedString()
                    
                    // Initial line
                    renderedString.append(hr)
                    
                    // Render the YAML to NSAttributedString
                    if let yamlString = renderYaml(yaml, 0, false) {
                        renderedString.append(yamlString)
                    }
                    
                    // Add a line after the front matter
                    renderedString.append(hr)

                    // Add in the orignal rendered markdown and then set the
                    // output string to the combined string
                    renderedString.append(output)
                    output = renderedString
                }
                catch {
                    // No YAML to render, or mis-formatted
                    let errorString: NSMutableAttributedString = NSMutableAttributedString.init(string: "Could not render the YAML. It may be mis-formed.\n", attributes: keyAtts)
#if DEBUG
                    errorString.append(NSMutableAttributedString.init(string: error.localizedDescription + "\n", attributes: keyAtts))
                    errorString.append(NSMutableAttributedString.init(string: frontMatter + "\n", attributes: valAtts))
#endif
                    errorString.append(output)
                    output = errorString
                }
            }
        }
    }
    
    // FROM 1.3.0
    // Guard against non-trapped errors
    if output.length == 0 {
        output.append(NSAttributedString.init(string: "No valid Markdown to render."))
    }
    
    // Return the rendered NSAttributedString to Previewer or Thumbnailer
    return output
}


// MARK: SwiftyMarkdown Rendering Support Functions

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


// MARK: Front Matter Functions

func getFrontMatter(_ markdown: String, _ markerPattern: String) -> String {
    
    // FROM 1.3.0
    // Extract and return initial front matter
    // 'markerPattern' is a string literal specifying the front matter boundary
    // marker Reg Ex, eg. #"^(-)+"# for ---.
    // Returns an empty string on error, or no front matter
    
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


func renderYaml(_ part: Yaml, _ indent: Int, _ isKey: Bool) -> NSAttributedString? {
    
    // Render a supplied YAML sub-component ('part') to an NSAttributedString,
    // indenting as required, and using a different text format for keys.
    // This is called recursively as it drills down through YAML values.
    // Returns nil on error
    
    let returnString: NSMutableAttributedString = NSMutableAttributedString.init()
    
    switch (part) {
    case .array:
        if let value = part.array {
            // Iterate through array elements
            // NOTE A given element can be of any YAML type
            for i in 0..<value.count {
                if let yamlString = renderYaml(value[i], indent, false) {
                    // Apply a prefix to separate array and dictionary elements
                    if i > 0 && (value[i].array != nil || value[i].dictionary != nil) {
                        returnString.append(newLine)
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
                    returnString.append(newLine)
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
                if value.array != nil || value.dictionary != nil {
                    valueIndent = indent + BUFFOON_CONSTANTS.YAML_INDENT
                    returnString.append(newLine)
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
            returnString.append(getIndentedString(keyOrValue, indent))
            returnString.addAttributes((isKey ? keyAtts : valAtts),
                                       range: NSMakeRange(0, returnString.length))
            returnString.append(isKey ? NSAttributedString.init(string: " ") : newLine)
            return returnString
        }
    case .null:
        returnString.append(getIndentedString("NULL/n", indent))
        returnString.addAttributes((isKey ? keyAtts : valAtts),
                                   range: NSMakeRange(0, returnString.length))
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
        
        returnString.addAttributes(valAtts,
                                   range: NSMakeRange(0, returnString.length))
        return returnString
    }
    
    // Error condition
    return nil
}


func getIndentedString(_ baseString: String, _ indent: Int) -> NSAttributedString {
    
    // Return a space-prefix NSAttributedString where 'indent' specifies
    // the number of spaces to add
    
    let trimmedString = baseString.trimmingCharacters(in: .whitespaces)
    let spaces = "                                                     "
    let spaceString = String(spaces.suffix(indent))
    let indentedString: NSMutableAttributedString = NSMutableAttributedString.init()
    indentedString.append(NSAttributedString.init(string: spaceString))
    indentedString.append(NSAttributedString.init(string: trimmedString))
    return indentedString.attributedSubstring(from: NSMakeRange(0, indentedString.length))
}


// MARK: Formatting Functions

func setBaseValues(_ sm: SwiftyMarkdown, _ isThumbnail: Bool) {

    // Set common base style values for the markdown render

    // FROM 1.2.0
    // The suite name is the app group name, set in each extension's entitlements, and the host app's
    if let defaults = UserDefaults(suiteName: MNU_SECRETS.PID + ".suite.previewmarkdown") {
        defaults.synchronize()
        fontSizeBase = CGFloat(isThumbnail
                                ? defaults.float(forKey: "com-bps-previewmarkdown-thumb-font-size")
                                : defaults.float(forKey: "com-bps-previewmarkdown-base-font-size"))
        codeColourIndex = defaults.integer(forKey: "com-bps-previewmarkdown-code-colour-index")
        linkColourIndex = defaults.integer(forKey: "com-bps-previewmarkdown-link-colour-index")
        codeFontIndex = defaults.integer(forKey: "com-bps-previewmarkdown-code-font-index")
        bodyFontIndex = defaults.integer(forKey: "com-bps-previewmarkdown-body-font-index")
        doShowLightBackground = defaults.bool(forKey: "com-bps-previewmarkdown-do-use-light")
    }

    // Just in case the above block reads in zero values
    // NOTE The other valyes CAN be zero
    if fontSizeBase < 1.0 || fontSizeBase > 28.0 {
        fontSizeBase = CGFloat(isThumbnail ? BUFFOON_CONSTANTS.BASE_THUMB_FONT_SIZE : BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE)
    }

    sm.setFontColorForAllStyles(with: (isThumbnail || doShowLightBackground) ? NSColor.black : NSColor.labelColor)
    sm.setFontSizeForAllStyles(with: fontSizeBase)

    sm.h4.fontSize = fontSizeBase * 1.2
    sm.h3.fontSize = fontSizeBase * 1.4
    sm.h2.fontSize = fontSizeBase * 1.6
    sm.h1.fontSize = fontSizeBase * 2.0

    if bodyFontIndex > 0 && bodyFontIndex < bodyFonts.count {
        // NOTE We ignore 0 because that indicates the System font,
        //      which is the default
        sm.setFontNameForAllStyles(with: bodyFonts[bodyFontIndex])
    }

    if codeFontIndex >= 0 && codeFontIndex < codeFonts.count {
        sm.code.fontName = codeFonts[codeFontIndex]
    }

    sm.code.color = getColour(codeColourIndex)

    // NOTE The following do not set link colour - this is
    //      a bug or issue with SwiftyMarkdown 1.2.3
    sm.link.color = getColour(linkColourIndex)
    sm.link.underlineColor = sm.link.color
    
    // FROM 1.3.0
    // Set the front matter key:value fonts and sizes
    // Front Matter string attributes...
    keyAtts = [
        NSAttributedString.Key.foregroundColor: getColour(codeColourIndex),
        NSAttributedString.Key.font: NSFont.init(name: codeFonts[codeFontIndex], size: fontSizeBase) as Any
    ]
    
    valAtts = [
        NSAttributedString.Key.foregroundColor: (doShowLightBackground ? NSColor.black : NSColor.labelColor),
        NSAttributedString.Key.font: NSFont.init(name: codeFonts[codeFontIndex], size: fontSizeBase) as Any
    ]
    
    hr = NSAttributedString(string: "\n\u{00A0}\u{0009}\u{00A0}\n\n",
                            attributes: [.strikethroughStyle: NSUnderlineStyle.thick.rawValue,
                                         .strikethroughColor: (doShowLightBackground ? NSColor.black : NSColor.white)])

}


func getColour(_ index: Int) -> NSColor {

    // FROM 1.2.0
    // Return the colour from the selection

    switch index {
        case 0:
            return NSColor.systemPurple
        case 1:
            return NSColor.systemBlue
        case 2:
            return NSColor.systemRed
        case 3:
            return NSColor.systemGreen
        case 4:
            return NSColor.systemOrange
        case 5:
            return NSColor.systemPink
        case 6:
            return NSColor.systemTeal
        case 7:
            return NSColor.systemBrown
        case 8:
            return NSColor.systemYellow
        case 9:
            return NSColor.systemIndigo
        default:
            return NSColor.systemGray
    }
}
