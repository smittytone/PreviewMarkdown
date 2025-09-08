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


// FROM 2.2.0
// Structure to hold front matter row components.
struct Row {
    var key: String     = BUFFOON_CONSTANTS.HARDTAB
    var val: String     = BUFFOON_CONSTANTS.HARDTAB
    var rule: Double    = BUFFOON_CONSTANTS.RULES.FINE
    var style: String   = ""
    var indent: Int     = 0
}


// FROM 1.4.0
// Implement common code as a class
class Common {

    // MARK: - Public Properties

    var doShowLightBackground: Bool                                 = true          // Pass to caller
    // FROM 2.0.0
    var fontSize: CGFloat                                           = 0.0           // Pass to the lozenge layouter
    var lineSpacing: CGFloat                                        = 1.0           // Pass to the lozenge layouter
    var workingDirectory: String                                    = ""            // Pass in the file's directory
    var linkColor: NSColor                                          = .linkColor    // Pass to main text view
    // FROM 2.1.0
    var doShowMargin: Bool                                          = true          // Pass to main text view


    // MARK: - Private Properties

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
    // FROM 2.1.0
    private var settings: PMSettings                                = PMSettings()

    /*
     Replace the following string with your own team ID. This is used to
     identify the app suite and so share preferences set by the main app with
     the previewer and thumbnailer extensions.
     */
    private let appSuiteName: String = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME


    // MARK: - Lifecycle Functions

    init?(_ isThumbnail: Bool = false) {

        self.isThumbnail = isThumbnail

        // Instantiate styler
        self.styler = PMStyler()
        guard let styler = self.styler else {
            return nil
        }

        // FROM 2.1.0
        // Load the saved settings
        self.settings.loadSettings(self.appSuiteName)

        // Just in case the above block reads in zero values
        // NOTE The other values CAN be zero
        if self.settings.fontSize < BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS[0] ||
            self.settings.fontSize > BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS[BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS.count - 1] {
            self.settings.fontSize = CGFloat(BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE)
        }

        // Set paragraph spacing
        styler.paraSpacing = self.settings.fontSize * 1.4

        // FROM 1.3.0
        // Set the front matter key:value fonts and sizes
        var font: NSFont
        if let otherFont = NSFont(name: self.settings.codeFontName, size: self.settings.fontSize) {
            font = otherFont
        } else {
            // This should not be hit, but just in case...
            font = NSFont.systemFont(ofSize: self.settings.fontSize)
        }

        // FROM 2.1.0
        styler.settings = self.settings

        // YAML front matter styling attributes
        self.yamlKeyAttributes = [
            .foregroundColor: NSColor.hexToColour(self.settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.YAML_KEYS]!),
            .font: font
        ]

        self.yamlValueAttributes = [
            .foregroundColor: NSColor.labelColor,
            .font: font
        ]

        self.newLine = NSAttributedString(string: "\n", attributes: self.yamlValueAttributes)

        // FROM 2.2.0
        // New, TextKit 2-friendly horizontal rule
        let hrTable = NSTextTable()
        hrTable.numberOfColumns = 1
        let hrBlock = NSTextTableBlock(table: hrTable, startingRow: 0, rowSpan: 1, startingColumn: 0, columnSpan: 1)
        hrBlock.setWidth(2.0, type: .absoluteValueType, for: .border, edge: .maxY)
        hrBlock.setBorderColor(NSColor.labelColor)
        let hrParaStyle = NSMutableParagraphStyle()
        hrParaStyle.alignment = .center
        hrParaStyle.textBlocks = [hrBlock]
        let hrFont = styler.makeFont("plain", 8.0)
        self.hr = NSMutableAttributedString(string: "\n",
                                            attributes: [.foregroundColor: NSColor.labelColor,
                                                         .paragraphStyle: hrParaStyle,
                                                         .font: hrFont])

        // Retain these value for easy layouter access
        // FROM 2.0.0
        self.linkColor = NSColor.hexToColour(settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.LINKS]!)
        self.fontSize = self.settings.fontSize
        self.lineSpacing = self.settings.lineSpacing
        self.doShowLightBackground = self.settings.doShowLightBackground
        // FROM 2.1.0
        self.doShowMargin = self.settings.doShowMargin
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
                if !self.isThumbnail && self.settings.doShowFrontMatter && frontMatter.count > 0 {
                    do {
                        let yaml: Yaml = try Yaml.load(String(frontMatter))

                        // FROM 2.2.0
                        let yamlString: NSMutableAttributedString = processYaml(yaml, self.styler!)
                        yamlString.addAttributedStrings([self.newLine, self.hr, self.newLine, output])
                        output = yamlString
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
                        errorString.addAttributedStrings([self.newLine, self.hr])
                        errorString.append(NSMutableAttributedString(string: String(frontMatter),
                                                                     attributes: self.yamlValueAttributes))
#endif
                        errorString.addAttributedStrings([self.hr, self.newLine, output])
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
    private func getFrontMatter(_ rawText: Substring) -> MarkdownComponents {

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
     Process front matter into a rendered table

     UPDATED 2.2.0

     - Parameters:
        - yaml:   The decoded front matter.
        - styler: A PMStyler instance (taken from the global).

     - Returns An attributed string comprising the table.
     */

    private func processYaml(_ yaml: Yaml, _ styler: PMStyler) -> NSMutableAttributedString {

        var rows: [Row] = []

        // Proceed on assumption `yaml` is a dictionary,
        // which is reasonable for front matter...
        if let dict = yaml.dictionary {
            let keys: [Yaml] = sortKeys(Array(dict.keys))
            for key in keys {
                let value = dict[key] ?? ""
                if value.dictionary != nil || value.array != nil {
                    // Value is a collection type so process its elements
                    rows.append(contentsOf: processCollection(key, value, 1))

                    // Add an thick rule after each primary item
                    if var row = rows.popLast() {
                        row.rule = BUFFOON_CONSTANTS.RULES.THICK
                        rows.append(row)
                    }
                } else {
                    // Row comprises key and single scalar value, always with a baseline
                    let (_, rkey) = processScalar(key)
                    let (style, rval) = processScalar(value)
                    let row = Row(key: rkey,
                                  val: rval,
                                  rule: BUFFOON_CONSTANTS.RULES.THICK,
                                  style: style)

                    rows.append(row)
                }
            }
        }

        // Zap the last row rule
        if var row = rows.popLast() {
            row.rule = BUFFOON_CONSTANTS.RULES.NONE
            rows.append(row)
        }

        // Assemble and return the table
        return makeTable(rows, styler)
    }


    /**
     Process a particular YAML collection.

     FROM 2.2.0

     - Parameters:
        - leadKey    The key for which the collection is a value, or `nil` if there is no key.
        - collection The collection itself.
        - indent     The level of indentation.

     - Returns An array of rows to be used to extend the parent.
     */
    private func processCollection(_ leadKey: Yaml?, _ collection: Yaml, _ indent: Int) -> [Row] {

        var newRows: [Row] = []

        switch collection {
            case .dictionary:
                if let map = collection.dictionary {
                    let keys: [Yaml] = sortKeys(Array(map.keys))
                    for key in keys {
                        let value = map[key] ?? ""

                        if key == keys.first, let leadKey = leadKey {
                            // Value is a collection so make a row with the lead key and an empty value
                            let (_, rkey) = processScalar(leadKey)
                            let row = Row(key: String(repeating: BUFFOON_CONSTANTS.HARDTAB, count: (indent - 1)) + rkey,
                                          val: BUFFOON_CONSTANTS.HARDTAB,
                                          rule: BUFFOON_CONSTANTS.RULES.NONE,
                                          indent: indent - 1)
                            newRows.append(row)
                        }

                        if value.array != nil || value.dictionary != nil {
                            // Recurse over the collection value
                            newRows.append(contentsOf: processCollection(key, value, indent + 1))
                        } else {
                            // Inset the key and add the scalar value
                            let (_, rkey) = processScalar(key)
                            let (style, rval) = processScalar(value)
                            let row = Row(key: String(repeating: BUFFOON_CONSTANTS.HARDTAB, count: indent) + rkey,
                                          val: rval,
                                          style: style,
                                          indent: indent)
                            newRows.append(row)
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
                                let (_, rkey) = processScalar(leadKey)
                                var inset = indent - 1
                                if inset < 0 {
                                    inset = 0
                                }
                                let row = Row(key: String(repeating: BUFFOON_CONSTANTS.HARDTAB, count: inset) + rkey,
                                              val: BUFFOON_CONSTANTS.HARDTAB,
                                              rule: BUFFOON_CONSTANTS.RULES.NONE,
                                              indent: inset)
                                newRows.append(row)
                            }

                            newRows.append(contentsOf: processCollection(nil, value, indent))

                            // After rendering the collection, increase the rule of the last item
                            if var row = newRows.popLast() {
                                row.rule = BUFFOON_CONSTANTS.RULES.MEDIUM
                                newRows.append(row)
                            }
                        } else {
                            // Value is a scalar so follow on from the last
                            var subKey: String = BUFFOON_CONSTANTS.HARDTAB
                            var inset = indent
                            if value == list.first, let leadKey = leadKey {
                                inset = indent - 1
                                if inset < 0 {
                                    inset = 0
                                }
                                let (_, rkey) = processScalar(leadKey)
                                subKey = String(repeating: BUFFOON_CONSTANTS.HARDTAB, count: inset) + rkey
                            }

                            // Add the row
                            let (style, rval) = processScalar(value)
                            let row = Row(key: subKey,
                                          val: rval,
                                          style: style,
                                          indent: inset)
                            newRows.append(row)
                        }
                    }
                }
            default:
                break
        }

        return newRows
    }


    private func sortKeys(_ keys: [Yaml]) -> [Yaml] {

        let newKeys = keys.sorted(by: { (a, b) -> Bool in
            if let a_s: String = a.string {
                if let b_s: String = b.string {
                    return (a_s.lowercased() < b_s.lowercased())
                }
            }

            return false
        })

        return newKeys
    }

    /**
     Handle any scalar value. Most are simple interpolations (int, double), others return strings
     based on the value (bool, null, unknown). Strings are assembled out of parts.

     FROM 2.2.0

     - Parameters:
        - part The YAML scalar value to process.

     - Returns The value to add to the table.
     */
    func processScalar(_ part: Yaml) -> (String, String) {

        switch part {
            case .string:
                if let value = part.string {
                    let parts: [String] = value.components(separatedBy: "\n")
                    var returnString = ""
                    if parts.count > 1 {
                        for i in 0..<parts.count {
                            let part: String = parts[i]
                            returnString += part + " "
                        }
                    } else {
                        returnString = parts[0]
                    }

                    return ("", returnString)
                }
            case .null:
                return ("code", "NULL")
            default:
                if let val = part.int {
                    return ("", "\(val)")
                } else if let val = part.double {
                    return ("", "\(val)")
                } else if let val = part.bool {
                    return ("code", val ? "TRUE" : "FALSE")
                } else {
                    return ("code", "UNKNOWN")
                }
        }

        return ("", "")
    }


    /**
     Hand back an NSAttributedString comprising the parsed front matter as a table.

     FROM 2.2.0

     - Parameters:
        - rows    The array of Row instances.
        - styler: A PMStyler (taken from the global).

     - Returns The table header HTML.
     */
    private func makeTable(_ rows: [Row], _ styler: PMStyler) -> NSMutableAttributedString {

        // Set the header
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineSpacing = styler.setFontSize("h6")
        let tableString = NSMutableAttributedString(string: "Front Matter\n",
                                                    attributes: [.foregroundColor: styler.colours.head ?? NSColor.hexToColour(BUFFOON_CONSTANTS.HEX_COLOUR.YAML),
                                                                 .font: styler.makeFont("strong", styler.setFontSize("h4")),
                                                                 .paragraphStyle: paraStyle])

        autoreleasepool {
            // Prepare the table
            let table: NSTextTable = NSTextTable()
            table.numberOfColumns = 2
            table.collapsesBorders = false

            // Assemble the table's rows (each with two cells: one for the key, one for the value)
            for (i, row) in rows.enumerated() {
                tableString.append(makeCell(row, i, table, styler, true))   // Key
                tableString.append(makeCell(row, i, table, styler, false))  // Value
            }
        }

        return tableString
    }


    /**
     Create a front matter table cell.

     FROM 2.2.0

     - Parameters:
        - row:         A row instance.
        - rowNumber:   The index of the row in table sequence.
        - parentTable: The table to hold the cell.
        - styler:      A PMStyler (taken from the global).
        - isKey:       Are we assembling a key cell, or a value cell?

     - Returns An attributed string comprising the cell.
     */
    private func makeCell(_ row: Row, _ rowNumber: Int, _ parentTable: NSTextTable, _ styler: PMStyler, _ isKey: Bool) -> NSMutableAttributedString {

        // Assemble the containing block with 8pt padding and a bottom rule only
        let cellBlock = NSTextTableBlock(table: parentTable, startingRow: rowNumber, rowSpan: 1, startingColumn: isKey ? 0 : 1, columnSpan: 1)
        cellBlock.setWidth(BUFFOON_CONSTANTS.PREVIEW_FRONT_MATTER.CELL_PADDING, type: .absoluteValueType, for: .padding)
        cellBlock.setValue(isKey
                           ? BUFFOON_CONSTANTS.PREVIEW_FRONT_MATTER.KEY_WIDTH_PCT
                           : BUFFOON_CONSTANTS.PREVIEW_FRONT_MATTER.VALUE_WIDTH_PCT,
                           type: .percentageValueType, for: .width)
        cellBlock.setValue(styler.settings!.fontSize * BUFFOON_CONSTANTS.SCALERS.FRONT_MATTER_ROW_HEIGHT, type: .absoluteValueType, for: .height)
        // NOTE Following two lines set the underline
        cellBlock.setBorderColor(NSColor.hexToColour((isMacInLightMode() || self.doShowLightBackground) ? "EBEBEBFF" : "5E5E5EFF"), for: .maxY)
        cellBlock.setWidth(row.rule, type: .absoluteValueType, for: .border, edge: .maxY)

        // Create the cell's paragraph style
        let cellParaStyle = NSMutableParagraphStyle()
        cellParaStyle.alignment = .left
        cellParaStyle.defaultTabInterval = BUFFOON_CONSTANTS.PREVIEW_FRONT_MATTER.TAB_INTERVAL
        cellParaStyle.textBlocks = [cellBlock]  // Is this quicker than `.append(cellBlock)`?

        // Build and return the cell itself
        let cellTextStyle = isKey ? (row.indent == 0 ? "strong" : "plain") : (row.style.isEmpty ? "plain" : row.style)
        var cellTextColour: NSColor
        if isKey {
            cellTextColour = styler.colours.yamlkey ?? NSColor.hexToColour(self.settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.YAML_KEYS]!)
        } else if row.style == "code" {
            cellTextColour = styler.colours.code ?? NSColor.hexToColour(self.settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.CODE]!)
        } else {
            cellTextColour = NSColor.labelColor
        }

        let cellText = isKey ? row.key : row.val
        let cellFont = styler.makeFont(cellTextStyle, styler.settings!.fontSize * BUFFOON_CONSTANTS.SCALERS.FRONT_MATTER_TEXT)
        return NSMutableAttributedString(string: cellText + "\n",
                                         attributes: [.foregroundColor: cellTextColour,
                                                      .paragraphStyle: cellParaStyle,
                                                      .font: cellFont])
    }


    /**
     Determine whether the host Mac is in light mode.

     - Returns: `true` if the Mac is in light mode, otherwise `false`.
     */
    private func isMacInLightMode() -> Bool {

        return NSApp.effectiveAppearance.name.rawValue == "NSAppearanceNameAqua"
    }


    /*
     LEGACY CODE
     */

    /**
     Render a supplied YAML sub-component ('part') to an NSAttributedString.
     Indents the value as required.
     Should NOT be called for thumbnails.

     FROM 1.3.0-2.1.0

     - Parameters
     - part:   A partial Yaml object.
     - indent: The number of indent spaces to add.
     - isKey:  Is the Yaml part a key?

     - Returns The rendered string as an NSAttributedString, or nil on error.

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
     */


    /**
     Return a space-prefix NSAttributedString.

     FROM 1.3.0-2.1.0

     - Parameters
     - baseString: The string to be indented.
     - indent:     The number of indent spaces to add.

     - Returns The indented string as an NSAttributedString.

    func getIndentedString(_ baseString: String, _ indent: Int) -> NSAttributedString {

        let trimmedString = baseString.trimmingCharacters(in: .whitespaces)
        let spaceString = String(repeating: " ", count: indent)
        let indentedString: NSMutableAttributedString = NSMutableAttributedString()
        indentedString.append(NSAttributedString(string: spaceString))
        indentedString.append(NSAttributedString(string: trimmedString))
        return indentedString.attributedSubstring(from: NSMakeRange(0, indentedString.length))
    }
     */
}
