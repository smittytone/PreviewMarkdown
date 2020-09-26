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


func processSymbols(_ base: String) -> String {

    // FROM 1.1.0
    // FInd and and replace any HTML symbol markup
    // Processed here because SwiftyMarkdown doesn't handle this markup

    let finds = ["&quot;", "&amp;", "&frasl;", "&lt;", "&gt;", "&lsquo;", "&rsquo;", "&ldquo;", "&rdquo;", "&bull;", "&ndash;", "&mdash;", "&trade;", "&nbsp;",  "&iexcl;", "&cent;", "&pound;", "&yen;", "&sect;", "&copy;", "&ordf;", "&reg;", "&deg;", "&ordm;", "&plusmn;", "&sup2;", "&sup3;", "&micro;", "&para;", "&middot;", "&iquest;", "&divide;", "&euro;", "&dagger;", "&Dagger;"]
    let reps = ["\"", "&", "/", "<", ">", "‘", "’", "“", "”", "•", "-", "—", "™", " ", "¡", "¢", "£", "¥", "§", "©", "ª", "®", "º", "º", "±", "²", "³", "µ", "¶", "·", "¿", "÷", "€", "†", "‡"]

    var result = base
    let pattern = #"&[a-zA-Z]+[1-9]*;"#
    var range = base.range(of: pattern, options: .regularExpression)

    while range != nil {
        var repText = ""
        let find = String(result[range!])
        if finds.contains(find) {
            repText = reps[finds.firstIndex(of: find)!]
        }

        result = result.replacingCharacters(in: range!, with: repText)
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
    var result = ""
    index = 0
    for line in lines {
        result += line + (index < lines.count - 1 ? "\n" : "")
        index += 1
    }

    return result
}


func getAttributedString(_ markdownString: String, _ size: CGFloat, _ isThumbnail: Bool) -> NSAttributedString {

    // FROM 1.1.0
    // Use SwiftyMarkdown to render the input markdown as an NSAttributedString, which is returned
    // NOTE Set the font colour according to whether we're rendering a thumbail or a preview
    //      (thumbnails always rendered black on white; previews may be the opposite [dark mode])

    let swiftyMarkdown: SwiftyMarkdown = SwiftyMarkdown.init(string: "")
    setBaseValues(swiftyMarkdown, size, isThumbnail)
    let processed = processCodeTags(markdownString)
    return swiftyMarkdown.attributedString(from: processSymbols(processed))
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


func convertSpaces(_ base: String) -> String {

    // FROM 1.1.1
    // Convert space-formatted lists to tab-formatte lists
    let pattern = #"[ ]+([1-9]|\*|-)"#
    let tab = "\t"
    var result = base as NSString
    var nrange: NSRange = result.range(of: pattern, options: .regularExpression)

    while nrange.location != NSNotFound {
        var tabs = ""
        let crange: NSRange = NSMakeRange(nrange.location, nrange.length - 1)
        let tabCount = (nrange.length - 1) / 4

        for _ in 0..<tabCount {
            tabs += tab
        }

        result = result.replacingCharacters(in: crange, with: tabs) as NSString
        nrange = result.range(of: pattern, options: .regularExpression)
    }

    return result as String
}
