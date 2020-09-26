//
//  Common.swift
//  Code common to Previewer and Thumbnailer
//
//  Created by Tony Smith on 23/09/2020.
//  Copyright © 2020 Tony Smith. All rights reserved.
//

import Foundation
import SwiftyMarkdown
import AppKit


func getAttributedString(_ markdownString: String, _ size: CGFloat, _ isThumbnail: Bool) -> NSAttributedString {

    // FROM 1.1.0
    // Use SwiftyMarkdown to render the input markdown as an NSAttributedString, which is returned
    // NOTE Set the font colour according to whether we're rendering a thumbail or a preview
    //      (thumbnails always rendered black on white; previews may be the opposite [dark mode])

    let swiftyMarkdown: SwiftyMarkdown = SwiftyMarkdown.init(string: "")
    setBaseValues(swiftyMarkdown, size, isThumbnail)
    var processed = processCodeTags(markdownString)
    processed = convertSpaces(processed)
    return swiftyMarkdown.attributedString(from: processSymbols(processed))
}


func processSymbols(_ base: String) -> String {

    // FROM 1.1.0
    // FInd and and replace any HTML symbol markup
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


func setBaseValues(_ sm: SwiftyMarkdown, _ baseFontSize: CGFloat, _ isThumbnail: Bool) {

    // Set common base style values for the markdown render

    sm.setFontColorForAllStyles(with: isThumbnail ? NSColor.black : NSColor.labelColor)
    sm.setFontSizeForAllStyles(with: baseFontSize)
    sm.setFontNameForAllStyles(with: "HelveticaNeue")

    sm.h4.fontSize = baseFontSize * 1.2
    sm.h3.fontSize = baseFontSize * 1.4
    sm.h2.fontSize = baseFontSize * 1.6
    sm.h1.fontSize = baseFontSize * 2.0

    sm.code.fontName = "AndaleMono"
    sm.code.color = NSColor.systemPurple

    sm.link.color = NSColor.systemBlue
}



