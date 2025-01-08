//
//  AppDelegateSettings.swift
//  PreviewMarkdown
//  Extension for AppDelegate providing settings handling functionality.
//
//  Created by Tony Smith on 07/10/2024.
//  Copyright © 2025 Tony Smith. All rights reserved.
//

import Foundation
import AppKit


extension AppDelegate {
    
    
    // MARK: - User Action Functions
    
    /**
     When the font size slider is moved and released, this function updates the font size readout.
  
     FROM 1.2.0

     - Parameters:
        - sender: The source of the action.
      */
     @IBAction internal func doMoveSlider(sender: Any) {

         let index: Int = Int(self.fontSizeSlider.floatValue)
         self.fontSizeLabel.stringValue = "\(Int(BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[index]))pt"
     }


     /**
      Called when the user selects a font from either list.

      FROM 1.4.0

      - Parameters:
        - sender: The source of the action.
     */
    @IBAction internal func doUpdateFonts(sender: Any) {

        let item: NSPopUpButton = sender as! NSPopUpButton
        setStylePopup(item == self.bodyFontPopup)
    }
    
    
    /**
     Update the colour preferences dictionary with a value from the
     colour well when a colour is chosen.

     FROM 1.5.0

     - Parameters:
        - sender: The source of the action.
     */
    @objc @IBAction internal func colourSelected(sender: Any) {

        let keys: [String] = ["heads", "code", "links", "quote"]
        let key: String = "new_" + keys[self.colourSelectionPopup.indexOfSelectedItem]
        self.currentSettings.displayColours[key] = self.headColourWell.color.hexString
    }


    /**
     Update the colour well with the stored colour: either a new one, previously
     chosen, or the loaded preference.
     
     FROM 1.5.0

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction internal func doChooseColourType(sender: Any) {

        let keys: [String] = ["heads", "code", "links", "quote"]
        let key: String = keys[self.colourSelectionPopup.indexOfSelectedItem]

        // If there's no `new_xxx` key, the next line will evaluate to false
        // NOTE We add `new_xxx` keys when a colour is changed
        if let colour: String = self.currentSettings.displayColours["new_" + key] {
            if colour.count != 0 {
                // Set the colourwell with the updated colour and exit
                self.headColourWell.color = NSColor.hexToColour(colour)
                return
            }
        }

        // Set the colourwell with the stored colour
        if let colour: String = self.currentSettings.displayColours[key] {
            self.headColourWell.color = NSColor.hexToColour(colour)
        }
    }


    /**
     The user has clicked on the Settings > Apply button.
     
     FROM 2.0.0

     - Parameters:
        - sender: The source of the action.
     */
     @IBAction internal func doApplyCurrentSettings(sender: Any) {
         
         // First, make sure changes have been made
         if checkSettingsOnQuit() {
             // Changes are present, so save them.
             // NOTE This call updates the current settings values from the Settings tab UI.
             saveSettings()
         }
     }


     /**
      The user has clicked on the Settings > Defaults button.
      
      NOTE This does not save the settings, it only updates Settings tab UI state.
      
      FROM 2.0.0

      - Parameters:
         - sender: The source of the action.     
      */
     @IBAction internal func doApplyDefaultSettings(sender: Any) {
         
         displaySettings(self.defaultSettings)
     }


    // MARK: - General Functions


    /**
     Configure the app's preferences with default values.
     
     FROM 1.2.0
     RENAMED 2.0.0
     */
    internal func registerSettings() {

        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            // Check if each preference value exists -- set if it doesn't
            // Preview body font size, stored as a CGFloat
            // Default: 16.0
            let bodyFontSizeDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_SIZE)
            if bodyFontSizeDefault == nil {
                defaults.setValue(CGFloat(BUFFOON_CONSTANTS.PREVIEW_FONT_SIZE),
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_SIZE)
            }

            // Thumbnail view base font size, stored as a CGFloat, not currently used
            // Default: 14.0
            let thumbFontSizeDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.THUMB_FONT_SIZE)
            if thumbFontSizeDefault == nil {
                defaults.setValue(CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_FONT_SIZE),
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.THUMB_FONT_SIZE)
            }
            
            // Use light background even in dark mode, stored as a bool
            // Default: false
            let useLightDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_USE_LIGHT)
            if useLightDefault == nil {
                defaults.setValue(false,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_USE_LIGHT)
            }

            // Show the What's New sheet
            // Default: true
            // This is a version-specific preference suffixed with, eg, '-2-3'. Once created
            // this will persist, but with each new major and/or minor version, we make a
            // new preference that will be read by 'doShowWhatsNew()' to see if the sheet
            // should be shown this run
            let key: String = BUFFOON_CONSTANTS.PREFS_IDS.MAIN_WHATS_NEW + getVersion()
            let showNewDefault: Any? = defaults.object(forKey: key)
            if showNewDefault == nil {
                defaults.setValue(true, forKey: key)
            }
            
            // FROM 1.3.0
            // Show any YAML front matter, if present
            // Default: true
            let showFrontMatterDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_YAML)
            if showFrontMatterDefault == nil {
                defaults.setValue(true, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_YAML)
            }
            
            // FROM 1.4.0
            // Colour of links in the preview, stored as hex string
            let linkColourDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINK_COLOUR)
            if linkColourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.LINK_COLOUR_HEX,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINK_COLOUR)
            }
            
            // FROM 1.4.0
            // Colour of code blocks in the preview, stored as hex string
            let codeColourDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_COLOUR)
            if codeColourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.CODE_COLOUR_HEX,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_COLOUR)
            }
            
            // FROM 1.4.0
            // Colour of headings in the preview, stored as hex string
            let headColourDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_HEAD_COLOUR)
            if headColourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.HEAD_COLOUR_HEX,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_HEAD_COLOUR)
            }
            
            // FROM 1.4.0
            // Font for body test in the preview, stored as a PostScript name
            let bodyFontDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_NAME)
            if bodyFontDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.BODY_FONT_NAME,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_NAME)
            }

            // FROM 1.4.0
            // Font for code blocks in the preview, stored as a PostScript name
            let codeFontDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_FONT_NAME)
            if codeFontDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.CODE_FONT_NAME,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_FONT_NAME)
            }
            
            // FROM 1.5.0
            // Store the preview line spacing value
            let lineSpacingDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINE_SPACE)
            if lineSpacingDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.BASE_LINE_SPACING,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINE_SPACE)
            }

            // The blockquote colour, stored as hex string
            let quoteColourDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_QUOTE_COLOUR)
            if quoteColourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.QUOTE_COLOUR_HEX,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_QUOTE_COLOUR)
            }
        }
    }
    
    
    /**
     Update the UI with the supplied settings.
     
     - Parameters:
        - settings: The settings to show in the UI.
     */
    internal func displaySettings(_ settings: Settings) {
        
        // Get the menu item index from the stored value
        // NOTE The other values are currently stored as indexes -- should this be the same?
        let index: Int = BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS.lastIndex(of: settings.fontSize) ?? 3
        self.fontSizeSlider.floatValue = Float(index)
        self.fontSizeLabel.stringValue = "\(Int(BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[index]))pt"
        
        // Set the checkboxes
        self.useLightCheckbox.state = settings.doShowLightBackground ? .on : .off
        self.showFrontMatterCheckbox.state = settings.doShowFrontMatter ? .on : .off
        
        // Set the colour well
        // NOTE This has only one colour, so we always reset to "heads" on changes
        self.headColourWell.color = NSColor.hexToColour(settings.displayColours["heads"] ?? BUFFOON_CONSTANTS.HEAD_COLOUR_HEX)
        self.colourSelectionPopup.selectItem(at: 0)
        self.clearNewColours()
        
        // Extend font selection to all available fonts
        // First, the body text font...
        self.bodyFontPopup.removeAllItems()
        self.bodyStylePopup.isEnabled = false
        
        for i: Int in 0..<self.bodyFonts.count {
            let font: PMFont = self.bodyFonts[i]
            self.bodyFontPopup.addItem(withTitle: font.displayName)
        }
        
        self.bodyFontPopup.selectItem(withTitle: "")
        selectFontByPostScriptName(settings.bodyFontName, true)

        // ...and the code font
        self.codeFontPopup.removeAllItems()
        self.codeStylePopup.isEnabled = false

        for i: Int in 0..<self.codeFonts.count {
            let font: PMFont = self.codeFonts[i]
            self.codeFontPopup.addItem(withTitle: font.displayName)
        }
        
        self.codeFontPopup.selectItem(withTitle: "")
        selectFontByPostScriptName(settings.codeFontName, false)

        // Set the line spacing selector
        switch(round(settings.lineSpacing * 100) / 100.0) {
            case 1.15:
                self.lineSpacingPopup.selectItem(at: 1)
            case 1.5:
                self.lineSpacingPopup.selectItem(at: 2)
            case 2.0:
                self.lineSpacingPopup.selectItem(at: 3)
            default:
                self.lineSpacingPopup.selectItem(at: 0)
        }
    }
    
    
    /**
     Populate the current settings value with those read from disk.
     */
    internal func loadSettings() {
        
        // The suite name is the app group name, set in each extension's entitlements, and the host app's
        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            self.currentSettings.fontSize = CGFloat(defaults.float(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_SIZE))
            self.currentSettings.lineSpacing = CGFloat(defaults.float(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINE_SPACE))
            
            self.currentSettings.doShowLightBackground = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_USE_LIGHT)
            self.currentSettings.doShowFrontMatter = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_YAML)
            
            self.currentSettings.codeFontName = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_FONT_NAME) ?? BUFFOON_CONSTANTS.CODE_FONT_NAME
            self.currentSettings.bodyFontName = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_NAME) ?? BUFFOON_CONSTANTS.BODY_FONT_NAME
            
            self.currentSettings.displayColours["heads"] = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_HEAD_COLOUR) ?? BUFFOON_CONSTANTS.HEAD_COLOUR_HEX
            self.currentSettings.displayColours["code"]  = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_COLOUR) ?? BUFFOON_CONSTANTS.CODE_COLOUR_HEX
            self.currentSettings.displayColours["links"] = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINK_COLOUR) ?? BUFFOON_CONSTANTS.LINK_COLOUR_HEX
            self.currentSettings.displayColours["quote"] = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_QUOTE_COLOUR) ??
                BUFFOON_CONSTANTS.QUOTE_COLOUR_HEX
        }

        // Use the loaded settings to update the Settings tab UI
        displaySettings(self.currentSettings)

        if !self.initialLoadDone {
            // Settings page elements have been set to reflect the current settings,
            // either default values at the start, or custom values subsequently.
            self.initialLoadDone = true
        }
    }
    
    
    /**
     Compare the current Settings page values to those we have stored in `currentSettings`.
     If any are different, we need to warn the user.
     
     - Returns:
        `true` if one or more settings has changed, otherwise `false`.
     */
    internal func checkSettingsOnQuit() -> Bool {
        
        var settingsHaveChanged: Bool = false
        
        // Check for a use light background change
        var state: Bool = self.useLightCheckbox.state == .on
        settingsHaveChanged = (self.currentSettings.doShowLightBackground != state)
        
        // Check for a show frontmatter change
        if !settingsHaveChanged {
            state = self.showFrontMatterCheckbox.state == .on
            settingsHaveChanged = (self.currentSettings.doShowFrontMatter != state)
        }
        
        // Check for line spacing change
        let lineIndex: Int = self.lineSpacingPopup.indexOfSelectedItem
        var lineSpacing: CGFloat = 1.0
        switch(lineIndex) {
            case 1:
                lineSpacing = 1.15
            case 2:
                lineSpacing = 1.5
            case 3:
                lineSpacing = 2.0
            default:
                lineSpacing = 1.0
        }
        
        if !settingsHaveChanged {
            settingsHaveChanged = (self.currentSettings.lineSpacing != lineSpacing)
        }
        
        // Check for and record font and style changes
        if let fontName: String = getPostScriptName(false) {
            if !settingsHaveChanged {
                settingsHaveChanged = (self.currentSettings.codeFontName != fontName)
            }
        }
        
        if let fontName: String = getPostScriptName(true) {
            if !settingsHaveChanged {
                settingsHaveChanged = (self.currentSettings.bodyFontName != fontName)
            }
        }
        
        // Check for and record a font size change
        if !settingsHaveChanged {
            settingsHaveChanged = (self.currentSettings.fontSize != BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[Int(self.fontSizeSlider.floatValue)])
        }
        
        // Check for colour changes
        if let _ = self.currentSettings.displayColours["new_heads"] {
            settingsHaveChanged = true
        }

        if let _ = self.currentSettings.displayColours["new_code"] {
            settingsHaveChanged = true
        }

        if let _ = self.currentSettings.displayColours["new_links"] {
            settingsHaveChanged = true
        }

        if let _ = self.currentSettings.displayColours["new_quote"] {
            settingsHaveChanged = true
        }
        
        return settingsHaveChanged
    }
    
    
    /**
     Write Settings page state values to disk, but only those that have been changed.
     If this happens, also update the current settings store
     */
    internal func saveSettings() {
        
        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            let newValue: CGFloat = BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[Int(self.fontSizeSlider.floatValue)]
            if newValue != self.currentSettings.fontSize {
                self.currentSettings.fontSize = newValue
                defaults.setValue(newValue,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_SIZE)
            }
            
            var state: Bool = self.useLightCheckbox.state == .on
            if self.currentSettings.doShowLightBackground != state {
                self.currentSettings.doShowLightBackground = state
                defaults.setValue(state, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_USE_LIGHT)
            }

            state = self.showFrontMatterCheckbox.state == .on
            if self.currentSettings.doShowFrontMatter != state {
                self.currentSettings.doShowFrontMatter = state
                defaults.setValue(state, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_YAML)
            }

            if let psname: String = getPostScriptName(false) {
                if psname != self.currentSettings.codeFontName {
                    self.currentSettings.codeFontName = psname
                    defaults.setValue(psname, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_FONT_NAME)
                }
            }

            if let psname = getPostScriptName(true) {
                if psname != self.currentSettings.bodyFontName {
                    self.currentSettings.bodyFontName = psname
                    defaults.setValue(psname, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_NAME)
                }
            }
            
            let lineIndex: Int = self.lineSpacingPopup.indexOfSelectedItem
            var lineSpacing: CGFloat = 1.0
            switch lineIndex {
                case 1:
                    lineSpacing = 1.15
                case 2:
                    lineSpacing = 1.5
                case 3:
                    lineSpacing = 2.0
                default:
                    lineSpacing = 1.0
            }
            
            if self.currentSettings.lineSpacing != lineSpacing {
                self.currentSettings.lineSpacing = lineSpacing
                defaults.setValue(lineSpacing, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINE_SPACE)
            }

            if let newColour: String = self.currentSettings.displayColours["new_heads"] {
                self.currentSettings.displayColours["heads"] = newColour
                self.currentSettings.displayColours["new_heads"] = nil
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_HEAD_COLOUR)
            }

            if let newColour: String = self.currentSettings.displayColours["new_code"] {
                self.currentSettings.displayColours["code"] = newColour
                self.currentSettings.displayColours["new_code"] = nil
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_COLOUR)
            }

            if let newColour: String = self.currentSettings.displayColours["new_links"] {
                self.currentSettings.displayColours["links"] = newColour
                self.currentSettings.displayColours["new_links"] = nil
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINK_COLOUR)
            }

            if let newColour: String = self.currentSettings.displayColours["new_quote"] {
                self.currentSettings.displayColours["quote"] = newColour
                self.currentSettings.displayColours["new_quote"] = nil
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_QUOTE_COLOUR)
            }
        }
    }
    
    
    /**
     Zap any temporary colour values.
     
     FROM 1.5.0
     */
    internal func clearNewColours() {

        let keys: [String] = ["heads", "code", "links", "quote"]
        for key in keys {
            if let _: String = self.currentSettings.displayColours["new_" + key] {
                self.currentSettings.displayColours["new_" + key] = nil
            }
        }
    }
}
