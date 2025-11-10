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

class PMSettings {

    var doShowLightBackground: Bool         = false
    var doShowFrontMatter: Bool             = true
    var bodyFontName: String                = BUFFOON_CONSTANTS.FONT_NAME.BODY
    var codeFontName: String                = BUFFOON_CONSTANTS.FONT_NAME.CODE
    var fontSize: CGFloat                   = CGFloat(BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE)
    var lineSpacing: CGFloat                = BUFFOON_CONSTANTS.PREVIEW_SIZE.LINE_SPACING
    // FROM 2.1.0
    var doShowMargin: Bool                  = false
    var displayColours: [String: String]    = [
        BUFFOON_CONSTANTS.COLOUR_IDS.HEADS:     BUFFOON_CONSTANTS.HEX_COLOUR.HEAD,
        BUFFOON_CONSTANTS.COLOUR_IDS.CODE:      BUFFOON_CONSTANTS.HEX_COLOUR.CODE,
        BUFFOON_CONSTANTS.COLOUR_IDS.LINKS:     BUFFOON_CONSTANTS.HEX_COLOUR.LINK,
        BUFFOON_CONSTANTS.COLOUR_IDS.QUOTES:    BUFFOON_CONSTANTS.HEX_COLOUR.QUOTE,
        BUFFOON_CONSTANTS.COLOUR_IDS.YAML_KEYS: BUFFOON_CONSTANTS.HEX_COLOUR.YAML,
        BUFFOON_CONSTANTS.COLOUR_IDS.LOZENGE:   BUFFOON_CONSTANTS.HEX_COLOUR.LOZENGE        // Advanced
    ]
    // FROM 2.3.0
    var previewWindowScale: CGFloat         = BUFFOON_CONSTANTS.SCALERS.WINDOW_SIZE_L       // Advanced
    var previewMarginWidth: CGFloat         = BUFFOON_CONSTANTS.PREVIEW_MARGIN_WIDTH        // Advanced
    var thumbnailMatchFinderMode: Bool      = false                                         // Advanced


    /**
     Populate the current settings value with those read from disk.
     */
    func loadSettings(_ suite: String) {
        
        // The suite name is the app group name, set in each extension's entitlements, and the host app's
        if let defaults = UserDefaults(suiteName: suite) {
            self.fontSize = CGFloat(defaults.float(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_SIZE))
            self.lineSpacing = CGFloat(defaults.float(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINE_SPACE))
            self.doShowLightBackground = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_USE_LIGHT)
            self.doShowFrontMatter = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_YAML)
            self.codeFontName = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_FONT_NAME) ?? BUFFOON_CONSTANTS.FONT_NAME.CODE
            self.bodyFontName = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_NAME) ?? BUFFOON_CONSTANTS.FONT_NAME.BODY
            self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.HEADS]  = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_HEAD_COLOUR)
            ?? BUFFOON_CONSTANTS.HEX_COLOUR.HEAD
            self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.CODE]   = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_COLOUR)
            ?? BUFFOON_CONSTANTS.HEX_COLOUR.CODE
            self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.LINKS]  = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINK_COLOUR)
            ?? BUFFOON_CONSTANTS.HEX_COLOUR.LINK
            self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.QUOTES] = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_QUOTE_COLOUR)
            ?? BUFFOON_CONSTANTS.HEX_COLOUR.QUOTE
            // FROM 2.1.0
            self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.YAML_KEYS] = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_YAML_KEY_COLOUR)
            ?? BUFFOON_CONSTANTS.HEX_COLOUR.YAML
            self.doShowMargin = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_MARGIN)
            // FROM 2.3.0
            self.previewWindowScale = CGFloat(defaults.double(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_WINDOW_SCALE))
            self.previewMarginWidth = CGFloat(defaults.double(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_MARGIN))
            self.thumbnailMatchFinderMode = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_IDS.THUMB_MATCH_MODE)
            self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.LOZENGE] = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LOZENGE_COLOUR)
            ?? BUFFOON_CONSTANTS.HEX_COLOUR.LOZENGE
        }
    }


    /**
     Write Settings page state values to disk, but only those that have been changed.
     If this happens, also update the current settings store
     */
    func saveSettings(_ suite: String) {
        
        if let defaults = UserDefaults(suiteName: suite) {
            // TO-DO Test each on to see if the setting needs to be saved
            defaults.setValue(self.fontSize, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_SIZE)
            defaults.setValue(self.doShowLightBackground, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_USE_LIGHT)
            defaults.setValue(self.doShowFrontMatter, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_YAML)
            defaults.setValue(self.codeFontName, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_FONT_NAME)
            defaults.setValue(self.bodyFontName, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_NAME)
            defaults.setValue(self.lineSpacing, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINE_SPACE)

            // For colours, the UI sets the keys prefixed `new_xxx` when the colour of category xxx
            // has changed. If there's no `new_xxx`, then category xxx's colour has not been changed
            if let newColour: String = self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_HEADS] {
                self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.HEADS] = newColour
                self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_HEADS] = nil
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_HEAD_COLOUR)
            }

            if let newColour: String = self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_CODE] {
                self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.CODE] = newColour
                self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_CODE] = nil
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_COLOUR)
            }

            if let newColour: String = self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_LINKS] {
                self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.LINKS] = newColour
                self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_LINKS] = nil
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINK_COLOUR)
            }

            if let newColour: String = self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_QUOTES] {
                self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.QUOTES] = newColour
                self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_QUOTES] = nil
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_QUOTE_COLOUR)
            }

            // FROM 2.1.0
            if let newColour: String = self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_YAML_KEYS] {
                self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.YAML_KEYS] = newColour
                self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_YAML_KEYS] = nil
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_YAML_KEY_COLOUR)
            }

            defaults.setValue(self.doShowMargin, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_MARGIN)

            // FROM 2.3.0
            if let newColour: String = self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_LOZENGE] {
                self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.LOZENGE] = newColour
                self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_LOZENGE] = nil
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LOZENGE_COLOUR)
            }

            defaults.setValue(self.previewWindowScale, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_WINDOW_SCALE)
            defaults.setValue(self.previewMarginWidth, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_MARGIN)
            defaults.setValue(self.thumbnailMatchFinderMode, forKey: BUFFOON_CONSTANTS.PREFS_IDS.THUMB_MATCH_MODE)
        }
    }


    /**
     Configure the app's preferences with default values.

     FROM 1.2.0
     RENAMED 2.0.0
     MOVED HERE 2.3.0
     */
    internal func registerSettings(_ suite: String, _ version: String) {

        if let defaults = UserDefaults(suiteName: suite) {
            // Check if each preference value exists -- set if it doesn't
            // Preview body font size, stored as a CGFloat
            // Default: 16.0
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_SIZE) == nil {
                defaults.setValue(CGFloat(BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE),
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_SIZE)
            }

            // Thumbnail view base font size, stored as a CGFloat, NOT CURRENTLY USED
            // Default: 14.0
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.THUMB_FONT_SIZE) == nil {
                defaults.setValue(CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_SIZE.FONT_SIZE),
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.THUMB_FONT_SIZE)
            }

            // Use light background even in dark mode, stored as a bool
            // Default: false
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_USE_LIGHT) == nil {
                defaults.setValue(false,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_USE_LIGHT)
            }

            // Show the What's New sheet
            // Default: true
            // This is a version-specific preference suffixed with, eg, '-2-3'. Once created
            // this will persist, but with each new major and/or minor version, we make a
            // new preference that will be read by 'doShowWhatsNew()' to see if the sheet
            // should be shown this run
            let key: String = BUFFOON_CONSTANTS.PREFS_IDS.MAIN_WHATS_NEW + version
            if defaults.object(forKey: key) == nil {
                defaults.setValue(true, forKey: key)
            }

            // Show any YAML front matter, if present
            // Default: true
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_YAML) == nil {
                defaults.setValue(true, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_YAML)
            }

            // Colour of links in the preview, stored as hex string
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINK_COLOUR) == nil {
                defaults.setValue(BUFFOON_CONSTANTS.HEX_COLOUR.LINK,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINK_COLOUR)
            }

            // Colour of code blocks in the preview, stored as hex string
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_COLOUR) == nil {
                defaults.setValue(BUFFOON_CONSTANTS.HEX_COLOUR.CODE,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_COLOUR)
            }

            // Colour of headings in the preview, stored as hex string
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_HEAD_COLOUR) == nil {
                defaults.setValue(BUFFOON_CONSTANTS.HEX_COLOUR.HEAD,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_HEAD_COLOUR)
            }

            // Font for body test in the preview, stored as a PostScript name
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_NAME) == nil {
                defaults.setValue(BUFFOON_CONSTANTS.FONT_NAME.BODY,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_NAME)
            }

            // Font for code blocks in the preview, stored as a PostScript name
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_FONT_NAME) == nil {
                defaults.setValue(BUFFOON_CONSTANTS.FONT_NAME.CODE,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_FONT_NAME)
            }

            // Store the preview line spacing value
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINE_SPACE) == nil {
                defaults.setValue(BUFFOON_CONSTANTS.PREVIEW_SIZE.LINE_SPACING,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINE_SPACE)
            }

            // The blockquote colour, stored as hex string
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_QUOTE_COLOUR) == nil {
                defaults.setValue(BUFFOON_CONSTANTS.HEX_COLOUR.QUOTE,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_QUOTE_COLOUR)
            }

            // FROM 2.1.0
            // The YAML key colour, stored as hex string
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_YAML_KEY_COLOUR) == nil {
                defaults.setValue(BUFFOON_CONSTANTS.HEX_COLOUR.YAML,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_YAML_KEY_COLOUR)
            }

            // Show a margin or not
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_MARGIN) == nil {
                defaults.setValue(true, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_MARGIN)
            }

            // FROM 2.3.0
            // The KEYB HTML tag lozenge colour, stored as hex string
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LOZENGE_COLOUR) == nil {
                defaults.setValue(BUFFOON_CONSTANTS.HEX_COLOUR.LOZENGE,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LOZENGE_COLOUR)
            }

            // Thumbnail should match macOS mode
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.THUMB_MATCH_MODE) == nil {
                defaults.setValue(false, forKey: BUFFOON_CONSTANTS.PREFS_IDS.THUMB_MATCH_MODE)
            }

            // Preview window scale factor (fraction of main screen size)
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_WINDOW_SCALE) == nil {
                defaults.setValue(BUFFOON_CONSTANTS.SCALERS.WINDOW_SIZE_L, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_WINDOW_SCALE)
            }

            // Preview inset margin width
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_MARGIN) == nil {
                defaults.setValue(BUFFOON_CONSTANTS.PREVIEW_MARGIN_WIDTH, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_MARGIN)
            }
        }
    }
}
