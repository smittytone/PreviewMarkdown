/*
 *  PMSettings.swift
 *  PreviewApps
 *
 *  Created by Tony Smith on 08/10/2024.
 *  Copyright © 2025 Tony Smith. All rights reserved.
 */

import Foundation


/**
 Internal settings record structure.
 Values are pre-set to the app defaults.
 */

struct PMSettings {
    
    var doShowLightBackground: Bool         = false
    var doShowFrontMatter: Bool             = false
    
    var displayColours: [String:String]     = [
        "heads": BUFFOON_CONSTANTS.HEAD_COLOUR_HEX,
        "code": BUFFOON_CONSTANTS.CODE_COLOUR_HEX,
        "link": BUFFOON_CONSTANTS.LINK_COLOUR_HEX,
        "quote": BUFFOON_CONSTANTS.QUOTE_COLOUR_HEX
    ]
    
    var bodyFontName: String                = BUFFOON_CONSTANTS.BODY_FONT_NAME
    var codeFontName: String                = BUFFOON_CONSTANTS.CODE_FONT_NAME
    
    var fontSize: CGFloat                   = CGFloat(BUFFOON_CONSTANTS.PREVIEW_FONT_SIZE)
    var lineSpacing: CGFloat                = BUFFOON_CONSTANTS.BASE_LINE_SPACING
    
}
