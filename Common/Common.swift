/*
 *  Common.swift
 *  Code common to Markdown Previewer and Markdown Thumbnailer
 *
 *  Created by Tony Smith on 23/09/2020.
 *  Copyright © 2025 Tony Smith. All rights reserved.
 */


import Foundation
import AppKit
import Yaml


// FROM 2.0.0
// Simple class to hold indices (start and end) of the key elements
// within a string of markdown-formatted text
class MarkdownComponents {
    // TO-DO Replace with ranges??
    var frontMatterStart: String.Index? = nil
    var frontMatterEnd: String.Index?   = nil
    var markdownStart: String.Index?    = nil
    var markdownEnd: String.Index?      = nil
}


// FROM 1.4.0
// Implement common code as a class
class Common {

    // MARK: - Public Properties

    var doShowLightBackground: Bool                                 = true
    // FROM 2.0.0
    var fontSize: CGFloat                                           = 0.0
    var lineSpacing: CGFloat                                        = 1.0
    var workingDirectory: String                                    = ""
    var linkColor: NSColor                                          = .linkColor    // Used to pass the user's
    // preferred link colour up to
    // the main text view
    // FROM 2.1.0
    var doShowMargin: Bool                                          = true


    // MARK: - Private Properties

    private var doShowFrontMatter: Bool                             = false
    private var isThumbnail: Bool                                   = false
    // FROM 1.3.0
    // Front Matter string attributes...
    private var yamlKeyAttributes: [NSAttributedString.Key:Any]     = [:]
    private var yamlValueAttributes: [NSAttributedString.Key:Any]   = [:]
    // Front Matter rendering artefacts...
    private var hr: NSAttributedString                              = NSAttributedString(string: "")
    private var newLine: NSAttributedString                         = NSAttributedString(string: "")
    // FROM 2.0.0
    private var markdowner: PMMarkdowner?                           = nil
    private var styler: PMStyler?                                   = nil

    /*
     Replace the following string with your own team ID. This is used to
     identify the app suite and so share preferences set by the main app with
     the previewer and thumbnailer extensions.
     */
    private var appSuiteName: String = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME


    // MARK: - Lifecycle Functions

    init?(_ isThumbnail: Bool = false) {

        self.isThumbnail = isThumbnail

        // Instantiate styler
        self.styler = PMStyler()
        guard let styler = self.styler else {
            return nil
        }

        // Load in the user's preferred values, or set defaults
        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            // Locally relevant settings values
            self.doShowFrontMatter = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_YAML)
            self.doShowLightBackground = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_USE_LIGHT)
            // FROM 2.1.0
            self.doShowMargin = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_MARGIN)

            // The remaining settings values are passed directly to the styler
            styler.fontSize = CGFloat(isThumbnail
                                      ? BUFFOON_CONSTANTS.THUMBNAIL_SIZE.FONT_SIZE
                                      : defaults.float(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_SIZE))

            styler.colourValues.code  = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_COLOUR)  ?? BUFFOON_CONSTANTS.HEX_COLOUR.CODE
            styler.colourValues.head  = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_HEAD_COLOUR)  ?? BUFFOON_CONSTANTS.HEX_COLOUR.HEAD
            styler.colourValues.link  = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINK_COLOUR)  ?? BUFFOON_CONSTANTS.HEX_COLOUR.LINK
            styler.colourValues.quote = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_QUOTE_COLOUR) ?? BUFFOON_CONSTANTS.HEX_COLOUR.QUOTE

            styler.codeFontName = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_FONT_NAME) ?? BUFFOON_CONSTANTS.FONT_NAME.CODE
            styler.bodyFontName = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_NAME) ?? BUFFOON_CONSTANTS.FONT_NAME.BODY

            styler.lineSpacing = CGFloat(defaults.float(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINE_SPACE))

            // FROM 2.1.0
            styler.colourValues.yamlkey = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_YAML_KEY_COLOUR) ?? BUFFOON_CONSTANTS.HEX_COLOUR.YAML
        }

        // Just in case the above block reads in zero values
        // NOTE The other values CAN be zero
        if styler.fontSize < BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS[0] ||
            styler.fontSize > BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS[BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS.count - 1] {
            styler.fontSize = CGFloat(BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE)
        }

        // Set paragraph spacing
        styler.paraSpacing = styler.fontSize * 1.4

        // Retain these value for easy layouter access
        self.fontSize = styler.fontSize
        self.lineSpacing = styler.lineSpacing

        // FROM 1.3.0
        // Set the front matter key:value fonts and sizes
        var font: NSFont
        if let otherFont = NSFont(name: styler.codeFontName, size: styler.fontSize) {
            font = otherFont
        } else {
            // This should not be hit, but just in case...
            font = NSFont.systemFont(ofSize: styler.fontSize)
        }

        // YAML front matter styling attributes
        self.yamlKeyAttributes = [
            .foregroundColor: NSColor.hexToColour(styler.colourValues.yamlkey),
            .font: font
        ]

        self.yamlValueAttributes = [
            .foregroundColor: NSColor.labelColor,
            .font: font
        ]

        // NOTE This hack for an HR Requires NSTextView to use TextKit 1 for it to work
        self.hr = NSAttributedString(string: "\n\u{00A0}\u{0009}\u{00A0}\n\n",
                                     attributes: [.strikethroughStyle: NSUnderlineStyle.thick.rawValue,
                                                  .strikethroughColor: NSColor.labelColor])

        self.newLine = NSAttributedString(string: "\n", attributes: self.yamlValueAttributes)

        // FROM 2.0.0
        self.linkColor = NSColor.hexToColour(styler.colourValues.link)
    }


    // MARK: - The Primary Function

    /**
     Render the provided markdown.

     - Parameters
     - rawText - The loaded file's contents.

     - Returns The rendered markdown as an NSAttributedString.
     */
    func getAttributedString(_ rawText: Substring) -> NSAttributedString {

        // Process the markdown string
        var output: NSMutableAttributedString = NSMutableAttributedString(string: "")

        // Look for YAML front matter
        var frontMatter: Substring = ""
        let components: MarkdownComponents = getFrontMatter(rawText)
        if components.frontMatterStart != nil && !self.isThumbnail {
            frontMatter = rawText[components.frontMatterStart!...components.frontMatterEnd!]
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
                if lineCount >= BUFFOON_CONSTANTS.THUMBNAIL_SIZE.LINE_COUNT {
                    components.markdownEnd = index
                    break
                }
            }
        }

        // Get the markdown content that comes after the front matter (if there is any)
        var markdownToRender: Substring = rawText[components.markdownStart!..<components.markdownEnd!]
        if markdownToRender.count == 0 {
            markdownToRender = "*Empty File*"
        }

        // Load in the Markdown converter
        let markdowner: PMMarkdowner? = PMMarkdowner()
        if markdowner == nil {
            // Missing JS code file or other init error
            output = NSMutableAttributedString(string: "Could not instantiate MDJS",
                                               attributes: self.yamlValueAttributes)
        }

        // Render the Markdown
        if output.length == 0 && self.styler != nil {
            // No error encountered getting the JavaScript so proceed to render the string
            // First set up the styler with the chosen settings
            self.styler?.workingDirectory = self.workingDirectory

            if let attStr: NSAttributedString = styler?.render(markdowner!.tokenise(markdownToRender), self.isThumbnail, self.doShowLightBackground) {
                output = NSMutableAttributedString(attributedString: attStr)

                // Render YAML front matter if requested by the user, and we're not
                // rendering a thumbnail image (this is for previews only)
                if !self.isThumbnail && self.doShowFrontMatter && frontMatter.count > 0 {
                    do {
                        let yaml: Yaml = try Yaml.load(String(frontMatter))

                        var ys = ""
                        if let rs = processYaml(yaml, self.styler!.colourValues.yamlkey) { // renderYaml2(yaml, 0, false) {
                            let size = String(format:"%f", self.styler!.fontSize)
                            let font: String = "Avenir"
                            ys = "<TABLE style=\"width:300%;border:0px solid;border-collapse:collapse;font-family:\(font);color:#ffffff;font-size: " + size + "px;\">" + rs +  "</TABLE>"
                        }

                        if let tableString: NSMutableAttributedString = NSMutableAttributedString(html: ys.data(using: .utf8)!, options: [:], documentAttributes: nil) {
                            tableString.append(NSAttributedString(string: BUFFOON_CONSTANTS.LINE_END.FEED + BUFFOON_CONSTANTS.LINE_END.FEED))
                            tableString.append(output)
                            output = tableString
                        }

                        // Assemble the front matter string
                        //let renderedString: NSMutableAttributedString = NSMutableAttributedString(string: ys + "\n", attributes: self.yamlValueAttributes)

                        // Initial line
                        //renderedString.append(self.hr)

                        // Render the YAML to NSAttributedString
                        //if let yamlString = renderYaml(yaml, 0, false) {
                        //    renderedString.append(yamlString)
                        //}

                        // Add a line after the front matter
                        // renderedString.append(self.hr)

                        // Add in the orignal rendered markdown and then set the
                        // output string to the combined string
                        //renderedString.append(output)
                        //output = renderedString
                    } catch {
                        // No YAML to render, or the YAML was mis-formatted
                        // Get the error as reported by YamlSwift
                        let yamlErr: Yaml.ResultError = error as! Yaml.ResultError
                        var yamlErrString: String
                        switch(yamlErr) {
                            case .message(let s):
                                yamlErrString = s ?? "unknown"
                        }

                        // Assemble the error string
                        let errorString: NSMutableAttributedString = NSMutableAttributedString(string: "Could not render the front matter. Error: " + yamlErrString, attributes: self.yamlKeyAttributes)

#if DEBUG
                        errorString.append(self.hr)
                        errorString.append(NSMutableAttributedString(string: String(frontMatter),
                                                                     attributes: self.yamlValueAttributes))
#endif

                        errorString.append(self.hr)
                        errorString.append(output)
                        output = errorString
                    }
                }
            } else {
                output = NSMutableAttributedString(string: "Could not render markdown string",
                                                   attributes: self.yamlKeyAttributes)
            }
        }

        // FROM 1.3.0
        // Guard against non-trapped errors
        if output.length == 0 {
            return NSAttributedString(string: "No valid Markdown to render.",
                                      attributes: self.yamlKeyAttributes)
        }

        // Return the rendered NSAttributedString to Previewer or Thumbnailer
        return output as NSAttributedString
    }


    // MARK: - Front Matter Functions


    /**
     Extract and return initial front matter.

     FROM 1.3.0, updated 1.5.1, 2.0.0

     - Parameters
     - markdown:     The markdown file content.

     - Returns A data structure indicating front matter, markdown ranges.
     */
    func getFrontMatter(_ rawText: Substring) -> MarkdownComponents {

        // Assume the data is ALL markdown to begin with
        let components: MarkdownComponents = MarkdownComponents()
        components.markdownStart = rawText.startIndex
        components.markdownEnd = rawText.endIndex

        // Look for YAML symbol code:
        // Front matter delimited by --- and ---, or --- and ...
        let lineFindRegex = #"(?s)(?<=---\n).*(?=\n---)"#
        let dotFindRegex  = #"(?s)(?<=---\n).*(?=\n\.\.\.)"#

        // First look for either of the two delimiter patterns, lines first
        if let range = rawText.range(of: dotFindRegex, options: .regularExpression) {
            components.frontMatterStart = range.lowerBound
            components.frontMatterEnd = range.upperBound
        } else if let range = rawText.range(of: lineFindRegex, options: .regularExpression) {
            components.frontMatterStart = range.lowerBound
            components.frontMatterEnd = range.upperBound
        }

        // Make sure the front matter, if any, is no preceded by any text
        if components.frontMatterStart != nil {
            let endIndex: String.Index = rawText.index(components.frontMatterStart!, offsetBy: -4)
            let start: String = String(rawText[rawText.startIndex..<endIndex])
            if !start.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Front matter comes after text, ie. it is NOT front matter
                components.frontMatterStart = nil
                components.frontMatterEnd = nil
            }
        }

        // Set the start of the markdown content (after the front matter, if any)
        if let end = components.frontMatterEnd {
            components.markdownStart = rawText.index(end, offsetBy: 4)
        }

        return components
    }


    /**
     Render a supplied YAML sub-component ('part') to an NSAttributedString.
     Indents the value as required.
     Should NOT be called for thumbnails.

     FROM 1.3.0

     - Parameters
     - part:   A partial Yaml object.
     - indent: The number of indent spaces to add.
     - isKey:  Is the Yaml part a key?

     - Returns The rendered string as an NSAttributedString, or nil on error.
     */
    func renderYaml(_ part: Yaml, _ indent: Int, _ isKey: Bool) -> NSAttributedString? {

        let returnString: NSMutableAttributedString = NSMutableAttributedString(string: "",
                                                                                attributes: yamlKeyAttributes)

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
                        let valueIndent: Int = indent + BUFFOON_CONSTANTS.INSET.YAML
                        returnString.append(self.newLine)

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

                    returnString.setAttributes((isKey ? self.yamlKeyAttributes : self.yamlValueAttributes),
                                               range: NSMakeRange(0, returnString.length))
                    returnString.append(isKey ? NSAttributedString(string: " ", attributes: self.yamlValueAttributes) : self.newLine)
                    return returnString
                }
            case .null:
                returnString.append(getIndentedString(isKey ? "NULL KEY/n" : "NULL VALUE/n", indent))
                returnString.setAttributes((isKey ? self.yamlKeyAttributes : self.yamlValueAttributes),
                                           range: NSMakeRange(0, returnString.length))
                returnString.append(isKey ? NSAttributedString(string: " ") : self.newLine)
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

                returnString.setAttributes(self.yamlValueAttributes,
                                           range: NSMakeRange(0, returnString.length))
                return returnString
        }

        // Error condition
        return nil
    }


    /**
     Return a space-prefix NSAttributedString.

     FROM 1.3.0

     - Parameters
     - baseString: The string to be indented.
     - indent:     The number of indent spaces to add.

     - Returns The indented string as an NSAttributedString.
     */
    func getIndentedString(_ baseString: String, _ indent: Int) -> NSAttributedString {

        let trimmedString = baseString.trimmingCharacters(in: .whitespaces)
        let spaceString = String(repeating: " ", count: indent)
        let indentedString: NSMutableAttributedString = NSMutableAttributedString()
        indentedString.append(NSAttributedString(string: spaceString))
        indentedString.append(NSAttributedString(string: trimmedString))
        return indentedString.attributedSubstring(from: NSMakeRange(0, indentedString.length))
    }


    var SPACE_CHAR = "~"

    func renderCollection(_ leadKey: Yaml?, _ collection: Yaml, _ rows: [Row], _ indent: Int, _ flag: Bool = false) -> [Row] {

        var nuRows = rows

        switch collection {
            case .dictionary:
                if let dict = collection.dictionary {
                    // Pad value of outer key
                    // TODO May not have one if within an array...
                    let keys: [Yaml] = Array(dict.keys)
                    for key in keys {
                        let value = dict[key] ?? ""

                        if key == keys.first, let leadKey = leadKey {
                            // Value is a collection so make a row with the lead key and an empty value
                            let row = Row(key: String(repeating: SPACE_CHAR, count: (indent - 1) * 4) + processScalar(leadKey), val: SPACE_CHAR, rule: 0.0)
                            nuRows.append(row)
                        }

                        if value.array != nil || value.dictionary != nil {
                            nuRows = renderCollection(key, value, nuRows, indent + 1)
                        } else {
                            // Inset the key and add the scalar value
                            let row = Row(key: String(repeating: SPACE_CHAR, count: indent * 4) + processScalar(key), val: processScalar(value))
                            nuRows.append(row)
                        }
                    }
                }
            case .array:
                if let list = collection.array {
                    for value in list {
                        if (value.dictionary != nil || value.array != nil) {
                            // Value is a collection, so drop and indent
                            if value == list.first, let leadKey = leadKey {
                                // Value is a collection so make a row with the lead key and an empty value
                                let row = Row(key: String(repeating: SPACE_CHAR, count: (indent - 1) * 4) + processScalar(leadKey), val: SPACE_CHAR, rule: 0.0)
                                nuRows.append(row)
                            }

                            nuRows = renderCollection(nil, value, nuRows, indent)
                            if var row = nuRows.popLast() {
                                row.rule = 1.0
                                nuRows.append(row)
                            }
                        } else {
                            // Value is a scalar so follow ion
                            var subKey: String
                            if value == list.first, let leadKey = leadKey {
                                subKey = String(repeating: SPACE_CHAR, count: (indent - 1) * 4) + processScalar(leadKey)
                            } else {
                                subKey = SPACE_CHAR
                            }

                            // Add the row
                            let row = Row(key: subKey, val: processScalar(value))
                            nuRows.append(row)
                        }
                    }
                }
            default:
                break
        }

        return nuRows
    }


    struct Row {
        var key: String = "~"
        var val: String = "~"
        var rule: Double = 0.5
    }

    var rows: [Row] = []

    func processYaml(_ yaml: Yaml, _ keyColour: String) -> String? {

        //var table = "" //addHeaders(["Field", "Value"])

        // Proceed on assumption `yaml` is a dictionary, which
        // is reasonable for front matter
        if let dict = yaml.dictionary {
            var keys: [Yaml] = Array(dict.keys)
            // Sort keys - assume strings for front matter
            keys = keys.sorted(by: { (a, b) -> Bool in
                if let a_s: String = a.string {
                    if let b_s: String = b.string {
                        return (a_s.lowercased() < b_s.lowercased())
                    }
                }

                return false
            })

            // Iterate over the front matter dictionary's keys
            for key in keys {
                let value = dict[key] ?? ""
                if value.dictionary != nil || value.array != nil {
                    // Collection type so process its elements
                    rows = renderCollection(key, value, rows, 1)
                    if var row = rows.popLast() {
                        row.rule = 2.0
                        rows.append(row)
                    }
                } else {
                    // Row comprises key and single scalar value, always with a baseline
                    var row = Row()
                    row.key = processScalar(key)
                    row.val = processScalar(value)
                    row.rule = 2.0
                    rows.append(row)
                }
            }
        }

        // Replace space markers with actual spaces
        var table = addHeaders()
        for row in rows {
            table += addRow(row, keyColour)
        }

        table = table.replacingOccurrences(of: SPACE_CHAR, with: "&nbsp;")
        return table
    }

    func listify(_ list: [String]) -> String {

        var r = ""
        for i in 0..<list.count {
            r += list[i] + (i < list.count - 1 ? "<br />" : "")
        }

        return r
    }

    func processScalar(_ part: Yaml) -> String {

        var returnable = ""

        switch part {
            case .string:
                if let value = part.string {
                    let parts: [String] = value.components(separatedBy: "\n")
                    if parts.count > 1 {
                        for i in 0..<parts.count {
                            let part: String = parts[i]
                            returnable += part + " "
                        }
                    } else {
                        returnable = parts[0]
                    }
                }
            case .null:
                returnable = "<code>NULL</code>"
            default:
                if let val = part.int {
                    returnable = "\(val)"
                } else if let val = part.bool {
                    returnable = val ? "<code>TRUE</code>" : "<code>FALSE</code>"
                } else if let val = part.double {
                    returnable = "\(val)"
                } else {
                    returnable = "<code>ERROR, NON-SCALAR</code>"
                }
        }

        return returnable
    }


    func addHeaders() -> String {

        return "<tr colspan=\"2\"><td style=\"border:0px solid;font-size:\(1.4 * self.styler!.fontSize)px;color: #\(self.styler!.colourValues.head)\"><b>Front Matter</b></td></tr>"
    }


    func addRow(_ row: Row, _ keyColour: String) -> String {

        let borderColor = row.rule >= 2.0 ? "ffffffaa" : "999999aa"

        var nuRow = "<tr>"
        nuRow += "<td style=\"width:30%;border:1px solid #\(borderColor);border-width: 0 0 \(row.rule)px 0;padding: 8px 0 8px 0;color:#\(keyColour)\">\(row.key)</td>"
        nuRow += "<td style=\"width:70%;border:1px solid #\(borderColor);border-width: 0 0 \(row.rule)px 0;padding: 8px 0 8px 0;color: #ffffff\">\(row.val)</td>"
        return nuRow + "</tr>"
    }

}
