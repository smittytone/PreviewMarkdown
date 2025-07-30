//
//  PMStylerEntities.swift
//  Structs and classes used by PMStyler
//
//  Created by Tony Smith on 29/01/2025.
//  Copyright © 2025 Tony Smith. All rights reserved.
//

import AppKit


typealias StyleAttributes = [String: [NSAttributedString.Key: AnyObject]]


enum ListType {
    case bullet
    case number
}


enum StyleType {
    case none
    case paragraph  // A paragraph-level style, eg. P, H1
    case character  // Applied to a parent style, eg. EM, STRONG
    case indent     // Indented block, eg. PRE or BLOCKQUOTE
}


class Style {
    var name: String = "p"
    var type: StyleType = .paragraph
}


struct FontRecord {
    var postScriptName: String = ""
    var style: String = "regular"
    var size: CGFloat = 12.0
    var font: NSFont? = nil
}


struct ColourValues {
    var head: String                  = "#FFFFFF"
    var code: String                  = "#00FF00"
    var link: String                  = "#64ACDD"
    var quote: String                 = "#FFFFFF"
}


struct Colours {
    var head: NSColor!
    var body: NSColor!
    var code: NSColor!
    var link: NSColor!
    var quote: NSColor!
}
