/*
 *  Common.swift
 *  Code common to Markdown Previewer and Markdown Thumbnailer
 *
 *  Created by Tony Smith on 23/09/2020.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */


import Foundation


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


