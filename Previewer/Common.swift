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

    let finds = ["&quot;", "&amp;", "&frasl;", "&lt;", "&gt;", "&lsquo;", "&rsquo;", "&ldquo;", "&rdquo;", "&bull;", "&ndash;", "&mdash;", "&trade;", "&nbsp;",  "&iexcl;", "&cent;", "&pound;", "&yen;", "&sect;", "&copy;", "&ordf;", "&reg;", "&deg;", "&ordm;", "&plusmn;", "&sup2;", "&sup3;", "&micro;", "&para;", "&middot;", "&iquest;", "&divide;", "&euro;", "&dagger;", "&Dagger;"]
    let reps = ["\"", "&", "/", "<", ">", "‘", "’", "“", "”", "•", "-", "—", "™", " ", "¡", "¢", "£", "¥", "§", "©", "ª", "®", "º", "º", "±", "²", "³", "µ", "¶", "·", "¿", "÷", "€", "†", "‡"]

    var result = base
    let pattern = #"&[a-zA-Z]+[1-9]*;"#
    var range = result.range(of: pattern, options: .regularExpression)

    while range != nil {
        var repText = ""
        let find = String(result[range!])
        if finds.contains(find) {
            repText = reps[finds.firstIndex(of: find)!]
        }

        result = result.replacingCharacters(in: range!, with: repText)
        range = result.range(of: pattern, options: .regularExpression)
    }

    return result;
}


func getAttributedString(_ markdownString: String, _ size: CGFloat, _ isThumbnail: Bool) -> NSAttributedString {

    // FROM 1.1.0
    // Use SwiftyMarkdown to render the input markdown as an NSAttributedString, which is returned
    // NOTE Set the font colour according to whether we're rendering a thumbail or a preview
    //      (thumbnails always rendered black on white; previews may be the opposite [dark mode])

    let swiftyMarkdown: SwiftyMarkdown = SwiftyMarkdown.init(string: "")
    setBaseValues(swiftyMarkdown, size)
    swiftyMarkdown.setFontColorForAllStyles(with: isThumbnail ? NSColor.black : NSColor.labelColor)
    let processString = processSymbols(markdownString)
    return swiftyMarkdown.attributedString(from: processString)
}


func setBaseValues(_ sm: SwiftyMarkdown, _ baseFontSize: CGFloat) {

    // Set common base style values for the markdown render

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


