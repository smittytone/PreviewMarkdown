/*
 *  AppDelegateSettings.swift
 *  PreviewMarkdown
 *  Extension for AppDelegate providing settings handling functionality.
 *
 *  Created by Tony Smith on 07/10/2024.
 *  Copyright © 2025 Tony Smith. All rights reserved.
 */


import AppKit


extension AppDelegate {

    // MARK: - User Action Functions
    
    /**
     Update UI when we are about to switch to it
     */
    internal func willShowSettingsPage() {

        // FROM 2.2.1
        // Fix track colour on macOS 26
        if #available(macOS 26.0, *) {
            self.fontSizeSlider.tintProminence = .none
        }

        // Disable the Feedback > Send button if we have sent a message.
        // It will be re-enabled by typing something
        self.applyButton.isEnabled = checkSettingsOnQuit()
    }


    /**
     When the font size slider is moved and released, this function updates the font size readout.
  
     FROM 1.2.0

     - Parameters:
        - sender: The source of the action.
      */
    @IBAction
    internal func doMoveSlider(sender: Any) {

        let index: Int = Int(self.fontSizeSlider.floatValue)
        self.fontSizeLabel.stringValue = "\(Int(BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS[index]))pt"
        willShowSettingsPage()
     }


     /**
      Called when the user selects a font from either list.

      FROM 1.4.0

      - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    internal func doUpdateFonts(sender: Any) {

        let item: NSPopUpButton = sender as! NSPopUpButton
        setStylePopup(item == self.bodyFontPopup)
        willShowSettingsPage()
    }


    /**
     Update the colour preferences dictionary with a value from the
     colour well when a colour is chosen.

     FROM 1.5.0

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    @objc
    internal func colourSelected(sender: Any) {

        let keys: [String] = BUFFOON_CONSTANTS.COLOUR_OPTIONS
        let key: String = "new_" + keys[self.colourSelectionPopup.indexOfSelectedItem]
        self.currentSettings.displayColours[key] = self.headColourWell.color.hexString
        willShowSettingsPage()
    }


    /**
     Update the colour well with the stored colour: either a new one, previously
     chosen, or the loaded preference.
     
     FROM 1.5.0

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    internal func doChooseColourType(sender: Any) {

        let keys: [String] = BUFFOON_CONSTANTS.COLOUR_OPTIONS
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

        // Set the colourwell with the initial colour
        if let colour: String = self.currentSettings.displayColours[key] {
            self.headColourWell.color = NSColor.hexToColour(colour)
        }
    }


    /**
     Handler for controls whose values are read.
     
     FROM 2.0.0

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    internal func doChangeValue(sender: Any) {

        willShowSettingsPage()
    }


    /**
     The user has clicked on the Settings > Apply button.
     
     FROM 2.0.0

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    internal func doApplyCurrentSettings(sender: Any) {
         
         // First, make sure changes have been made
         if checkSettingsOnQuit() {
             // Changes are present, so save them.
             // NOTE This call updates the current settings values from the Settings tab UI.
             saveSettings()
             willShowSettingsPage()
         }
    }


     /**
      The user has clicked on the Settings > Defaults button.
      
      NOTE This does not save the settings, it only updates Settings tab UI state.
      
      FROM 2.0.0

      - Parameters:
         - sender: The source of the action.     
      */
    @IBAction
    internal func doApplyDefaultSettings(sender: Any) {
         
        displaySettings(self.defaultSettings)
        applyDefaultColours()
        willShowSettingsPage()
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
            let key: String = BUFFOON_CONSTANTS.PREFS_IDS.MAIN_WHATS_NEW + getVersion()
            if defaults.object(forKey: key) == nil {
                defaults.setValue(true, forKey: key)
            }
            
            // FROM 1.3.0
            // Show any YAML front matter, if present
            // Default: true
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_YAML) == nil {
                defaults.setValue(true, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_YAML)
            }
            
            // FROM 1.4.0
            // Colour of links in the preview, stored as hex string
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINK_COLOUR) == nil {
                defaults.setValue(BUFFOON_CONSTANTS.HEX_COLOUR.LINK,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINK_COLOUR)
            }
            
            // FROM 1.4.0
            // Colour of code blocks in the preview, stored as hex string
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_COLOUR) == nil {
                defaults.setValue(BUFFOON_CONSTANTS.HEX_COLOUR.CODE,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_COLOUR)
            }
            
            // FROM 1.4.0
            // Colour of headings in the preview, stored as hex string
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_HEAD_COLOUR) == nil {
                defaults.setValue(BUFFOON_CONSTANTS.HEX_COLOUR.HEAD,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_HEAD_COLOUR)
            }
            
            // FROM 1.4.0
            // Font for body test in the preview, stored as a PostScript name
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_NAME) == nil {
                defaults.setValue(BUFFOON_CONSTANTS.FONT_NAME.BODY,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_NAME)
            }

            // FROM 1.4.0
            // Font for code blocks in the preview, stored as a PostScript name
            if defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_FONT_NAME) == nil {
                defaults.setValue(BUFFOON_CONSTANTS.FONT_NAME.CODE,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_FONT_NAME)
            }
            
            // FROM 1.5.0
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
        }
    }


    /**
     Update the UI with the supplied settings.
     
     FROM 2.0.0
     
     - Parameters:
        - settings: An instance holding the settings to show in the UI.
     */
    internal func displaySettings(_ settings: PMSettings) {
        
        // Get the menu item index from the stored value
        // NOTE The other values are currently stored as indexes -- should this be the same?
        let index: Int = BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS.lastIndex(of: settings.fontSize) ?? 3
        self.fontSizeSlider.floatValue = Float(index)
        self.fontSizeLabel.stringValue = "\(Int(BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS[index]))pt"

        // Set the checkboxes
        self.useLightCheckbox.state = settings.doShowLightBackground ? .on : .off
        self.showFrontMatterCheckbox.state = settings.doShowFrontMatter ? .on : .off
        // FROM 2.1.0
        self.showMarginCheckbox.state = settings.doShowMargin ? .on : .off

        // Set the colour well
        // NOTE This has only one colour, so we always reset to "heads" on changes
        self.headColourWell.color = NSColor.hexToColour(settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.HEADS] ?? BUFFOON_CONSTANTS.HEX_COLOUR.HEAD)
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
        let linespacingValues: [CGFloat] = [1.0, 1.15, 1.5, 2.0]
        self.lineSpacingPopup.selectItem(at: linespacingValues.firstIndex(of: round(settings.lineSpacing * 100) / 100.0) ?? 0)
    }


    /**
     Generate a set of settings derived from the state of the UI - except for the colour values,
     as these are stored directly in the current settings store. THIS WILL CHANGE
     
     FROM 2.0.0
     
     - Returns A settings instance.
     */
    internal func settingsFromDisplay() -> PMSettings {
        
        let displayedSettings = PMSettings()
        displayedSettings.fontSize = BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS[Int(self.fontSizeSlider.floatValue)]
        displayedSettings.doShowFrontMatter = self.showFrontMatterCheckbox.state == .on
        displayedSettings.doShowLightBackground = self.useLightCheckbox.state == .on
        displayedSettings.codeFontName = getPostScriptName(false) ?? BUFFOON_CONSTANTS.FONT_NAME.CODE
        displayedSettings.bodyFontName = getPostScriptName(true) ?? BUFFOON_CONSTANTS.FONT_NAME.BODY
        // FROM 2.1.0
        displayedSettings.doShowMargin = self.showMarginCheckbox.state == .on

        // Set the actual linespacing according to the index of the menu
        let linespacingValues: [CGFloat] = [1.0, 1.15, 1.5, 2.0]
        assert(self.lineSpacingPopup.indexOfSelectedItem < linespacingValues.count)
        displayedSettings.lineSpacing = linespacingValues[self.lineSpacingPopup.indexOfSelectedItem]
        
        return displayedSettings
    }


    /**
     Populate the current settings value with those read from disk.
     */
    internal func loadSettings() {
        
        // Get the settings
        self.currentSettings.loadSettings(self.appSuiteName)

        // Use the loaded settings to update the Settings tab UI
        displaySettings(self.currentSettings)

        if !self.initialLoadDone {
            // Settings page elements have been set to reflect the current settings,
            // either default values at the start, or custom values subsequently.
            self.initialLoadDone = true
        }
    }


    /**
     Write Settings page state values to disk, but only those that have been changed.
     If this happens, also update the current settings store
     */
    internal func saveSettings() {
        
        // Update the current settings store with values from the UI
        // NOTE We need to preserve the `displayColours` values, so copy them to
        //      the temporary store first.
        let displayedSettings = settingsFromDisplay()
        displayedSettings.displayColours = self.currentSettings.displayColours
        self.currentSettings = displayedSettings
        self.currentSettings.saveSettings(self.appSuiteName)
    }


    /**
     Compare the current Settings page values to those we have stored in `currentSettings`.
     If any are different, we need to warn the user.
     
     - Returns:
        `true` if one or more settings has changed, otherwise `false`.
     */
    internal func checkSettingsOnQuit() -> Bool {
        
        let displayedSettings = settingsFromDisplay()
        var settingsHaveChanged = self.currentSettings.doShowLightBackground != displayedSettings.doShowLightBackground
        
        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.doShowFrontMatter != displayedSettings.doShowFrontMatter
        }
        
        if !settingsHaveChanged {
            settingsHaveChanged = !self.currentSettings.lineSpacing.isClose(to: displayedSettings.lineSpacing)
        }
        
        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.codeFontName != displayedSettings.codeFontName
        }
        
        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.bodyFontName != displayedSettings.bodyFontName
        }
        
        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.fontSize != displayedSettings.fontSize
        }
        
        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_HEADS] != nil
        }
        
        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_CODE] != nil
        }
        
        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_LINKS] != nil
        }
        
        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_QUOTES] != nil
        }

        // FROM 2.1.0
        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_YAML_KEYS] != nil
        }

        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.doShowMargin != displayedSettings.doShowMargin
        }

        return settingsHaveChanged
    }


    /**
     Zap any temporary colour values.
     
     FROM 1.5.0
     */
    internal func clearNewColours() {

        let keys: [String] = BUFFOON_CONSTANTS.COLOUR_OPTIONS
        for key in keys {
            if let _: String = self.currentSettings.displayColours["new_" + key] {
                self.currentSettings.displayColours["new_" + key] = nil
            }
        }
    }


    /**
     Set colours to defaults any temporary colour values.
     
     FROM 2.0.0
     */
    internal func applyDefaultColours() {

        let keys: [String] = BUFFOON_CONSTANTS.COLOUR_OPTIONS
        for key in keys {
            self.currentSettings.displayColours["new_" + key] = self.defaultSettings.displayColours[key]
        }
    }
}
