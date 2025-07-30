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
    var doShowFrontMatter: Bool             = false
    
    var displayColours: [String: String]    = [
        "heads": BUFFOON_CONSTANTS.HEAD_COLOUR_HEX,
        "code": BUFFOON_CONSTANTS.CODE_COLOUR_HEX,
        "link": BUFFOON_CONSTANTS.LINK_COLOUR_HEX,
        "quote": BUFFOON_CONSTANTS.QUOTE_COLOUR_HEX
    ]
    
    var bodyFontName: String                = BUFFOON_CONSTANTS.BODY_FONT_NAME
    var codeFontName: String                = BUFFOON_CONSTANTS.CODE_FONT_NAME
    
    var fontSize: CGFloat                   = CGFloat(BUFFOON_CONSTANTS.PREVIEW_FONT_SIZE)
    var lineSpacing: CGFloat                = BUFFOON_CONSTANTS.BASE_LINE_SPACING


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
            self.codeFontName = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_FONT_NAME) ?? BUFFOON_CONSTANTS.CODE_FONT_NAME
            self.bodyFontName = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_NAME) ?? BUFFOON_CONSTANTS.BODY_FONT_NAME
            self.displayColours["heads"] = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_HEAD_COLOUR) ?? BUFFOON_CONSTANTS.HEAD_COLOUR_HEX
            self.displayColours["code"]  = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_COLOUR) ?? BUFFOON_CONSTANTS.CODE_COLOUR_HEX
            self.displayColours["links"] = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINK_COLOUR) ?? BUFFOON_CONSTANTS.LINK_COLOUR_HEX
            self.displayColours["quote"] = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_QUOTE_COLOUR) ?? BUFFOON_CONSTANTS.QUOTE_COLOUR_HEX
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
        }
    }
}
