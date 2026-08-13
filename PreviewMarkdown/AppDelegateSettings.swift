/*
 *  AppDelegateSettings.swift
 *  PreviewMarkdown
 *  Extension for AppDelegate providing settings handling functionality.
 *
 *  Created by Tony Smith on 07/10/2024.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */


import AppKit


extension AppDelegate {

    // MARK: - User Action Functions
    
    /**
     Update UI when we are about to switch to it
     */
    internal func willShowSettingsPage() {

        // FROM 2.4.6
        // Fix track colour on macOS 26
        if #available(macOS 26.0, *) {
            self.fontSizeSlider.tintProminence = .secondary
        }

        // FROM 2.3.0
        // Disable this switch below 26.1
        if #available(macOS 26.1, *) {
            self.tintThumbnailsAdvancedLabel.isEnabled = true
            self.tintThumbnailsAdvancedSwitch.isEnabled = true
        } else {
            self.tintThumbnailsAdvancedLabel.isEnabled = false
            self.tintThumbnailsAdvancedSwitch.isEnabled = false
        }

        // Disable the Settings > Apply button if no settings have changed.
        self.applyButton.isEnabled = checkSettingsOnQuit()

        // FROM 2.2.4
        self.window.makeFirstResponder(self)
    }


    /**
     When the font size slider is moved and released, this function updates the font size readout.
  
     FROM 1.2.0

     - Parameters:
        - sender: The source of the action.
      */
    @IBAction
    internal func doMoveSlider(sender: Any) {

        let index = Int(self.fontSizeSlider.floatValue)
        self.fontSizeLabel.stringValue = "\(Int(BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS[index]))pt"
        willShowSettingsPage()
     }


    override func keyDown(with event: NSEvent) {

        if (event.keyCode == 126 || event.keyCode == 124) && self.fontSizeSlider.floatValue < 6.0 {
            self.fontSizeSlider.floatValue += 1
            if self.fontSizeSlider.floatValue > 6.0 {
                self.fontSizeSlider.floatValue = 6.0
            }

            doMoveSlider(sender: self)
        }

        if (event.keyCode == 125 || event.keyCode == 123) && self.fontSizeSlider.floatValue > 0.0 {
            self.fontSizeSlider.floatValue -= 1
            if self.fontSizeSlider.floatValue < 0.0 {
                self.fontSizeSlider.floatValue = 0.0
            }

            doMoveSlider(sender: self)
        }
    }


     /**
      Called when the user selects a font from either list.

      FROM 1.4.0

      - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    internal func doUpdateFonts(sender: Any) {

        let item = sender as! NSPopUpButton
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
        let key = "new_" + keys[self.colourSelectionPopup.indexOfSelectedItem]
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
        let key = keys[self.colourSelectionPopup.indexOfSelectedItem]

        // If there's no `new_xxx` key, the next line will evaluate to false
        // NOTE We add `new_xxx` keys when a colour is changed
        if let colour = self.currentSettings.displayColours["new_" + key] {
            if colour.count != 0 {
                // Set the colourwell with the updated colour and exit
                self.headColourWell.color = NSColor.hexToColour(colour)
                return
            }
        }

        // Set the colourwell with the initial colour
        if let colour = self.currentSettings.displayColours[key] {
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


    // MARK: - Advanced Settings
    
    @IBAction
    internal func doShowAdvancedSettings(sender: Any) {

        self.window.beginSheet(self.advancedSettingsSheet)
    }


    @IBAction
    internal func doCloseAdvancedSettings(sender: Any) {

        self.window.endSheet(self.advancedSettingsSheet)
        willShowSettingsPage()
    }

    
    // MARK: - General Functions

    /**
     Update the UI with the supplied settings.
     
     FROM 2.0.0
     
     - Parameters:
        - settings: An instance holding the settings to show in the UI.
     */
    internal func displaySettings(_ settings: PMSettings) {
        
        // Get the menu item index from the stored value
        // NOTE The other values are currently stored as indexes -- should this be the same?
        let index = BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS.lastIndex(of: settings.fontSize) ?? 3
        self.fontSizeSlider.floatValue = Float(index)
        self.fontSizeLabel.stringValue = "\(Int(BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS[index]))pt"

        // Set the colour well
        // NOTE This has only one colour, so we always reset to "heads" on changes
        self.headColourWell.color = NSColor.hexToColour(settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.HEADS] ?? BUFFOON_CONSTANTS.HEX_COLOUR.HEAD)
        self.colourSelectionPopup.selectItem(at: 0)
        self.clearNewColours()
        
        // Extend font selection to all available fonts
        // First, the body text font...
        self.bodyFontPopup.removeAllItems()
        self.bodyStylePopup.isEnabled = false
        
        for i in 0..<self.bodyFonts.count {
            let font: PMFont = self.bodyFonts[i]
            self.bodyFontPopup.addItem(withTitle: font.displayName)
        }
        
        self.bodyFontPopup.selectItem(withTitle: "")
        selectFontByPostScriptName(settings.bodyFontName, true)

        // ...and the code font
        self.codeFontPopup.removeAllItems()
        self.codeStylePopup.isEnabled = false

        for i in 0..<self.codeFonts.count {
            let font = self.codeFonts[i]
            self.codeFontPopup.addItem(withTitle: font.displayName)
        }
        
        self.codeFontPopup.selectItem(withTitle: "")
        selectFontByPostScriptName(settings.codeFontName, false)

        // Set the line spacing selector
        let linespacingValues: [CGFloat] = [1.0, 1.15, 1.5, 2.0]
        self.lineSpacingPopup.selectItem(at: linespacingValues.firstIndex(of: round(settings.lineSpacing * 100) / 100.0) ?? 0)

        // FROM 2.3.0
        self.showMarginSwitch.state = settings.doShowMargin ? .on : .off
        self.showFrontMatterSwitch.state = settings.doShowFrontMatter ? .on : .off
        self.useLightSwitch.state = settings.doReverseMode ? .on : .off

        self.tintThumbnailsAdvancedSwitch.state = settings.thumbnailMatchFinderMode ? .on : .off
        var idx = 2
        if settings.previewWindowScale == BUFFOON_CONSTANTS.SCALERS.WINDOW_SIZE_S {
            idx = 0
        } else if settings.previewWindowScale == BUFFOON_CONSTANTS.SCALERS.WINDOW_SIZE_M {
            idx = 1
        }

        self.previewSizeAdvancedPopup.selectItem(at: idx)

        self.previewMarginSizeText.stringValue = String(format:"%.1f", settings.previewMarginWidth)
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
        displayedSettings.codeFontName = getPostScriptName(false) ?? BUFFOON_CONSTANTS.FONT_NAME.CODE
        displayedSettings.bodyFontName = getPostScriptName(true) ?? BUFFOON_CONSTANTS.FONT_NAME.BODY
        // FROM 2.3.0
        displayedSettings.doShowMargin = self.showMarginSwitch.state == .on
        displayedSettings.doShowFrontMatter = self.showFrontMatterSwitch.state == .on
        displayedSettings.doReverseMode = self.useLightSwitch.state == .on

        // Set the actual linespacing according to the index of the menu
        let linespacingValues: [CGFloat] = [1.0, 1.15, 1.5, 2.0]
        if self.lineSpacingPopup.indexOfSelectedItem >= 0 && self.lineSpacingPopup.indexOfSelectedItem < linespacingValues.count {
            displayedSettings.lineSpacing = linespacingValues[self.lineSpacingPopup.indexOfSelectedItem]
        } else {
            displayedSettings.lineSpacing = linespacingValues[0]
        }

        displayedSettings.thumbnailMatchFinderMode = self.tintThumbnailsAdvancedSwitch.state == .on
        let idx = self.previewSizeAdvancedPopup.indexOfSelectedItem
        switch idx {
            case 1:
                displayedSettings.previewWindowScale = BUFFOON_CONSTANTS.SCALERS.WINDOW_SIZE_M
            case 2:
                displayedSettings.previewWindowScale = BUFFOON_CONSTANTS.SCALERS.WINDOW_SIZE_L
            default:
                displayedSettings.previewWindowScale = BUFFOON_CONSTANTS.SCALERS.WINDOW_SIZE_S
        }

        displayedSettings.previewMarginWidth = Double(self.previewMarginSizeText.stringValue) ?? BUFFOON_CONSTANTS.PREVIEW_SIZE.PREVIEW_MARGIN_WIDTH

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
        var settingsHaveChanged = self.currentSettings.doReverseMode != displayedSettings.doReverseMode
        
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

        // FROM 2.3.0
        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.thumbnailMatchFinderMode != displayedSettings.thumbnailMatchFinderMode
        }

        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.previewWindowScale != displayedSettings.previewWindowScale
        }

        if !settingsHaveChanged {
            settingsHaveChanged = !displayedSettings.previewMarginWidth.isClose(to: self.currentSettings.previewMarginWidth)
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


    // MARK: - NSTextFieldDelegate Functions

    /**
     Verify input values.

     FROM 2.3.0
    */
    func controlTextDidEndEditing(_ obj: Notification) {

        if let doubleValue = Double(self.previewMarginSizeText.stringValue) {
            let min = Double(BUFFOON_CONSTANTS.PREVIEW_SIZE.PREVIEW_MARGIN_WIDTH_MIN).rounded(.towardZero)
            let max = Double(BUFFOON_CONSTANTS.PREVIEW_SIZE.PREVIEW_MARGIN_WIDTH_MAX).rounded(.towardZero)

            if doubleValue > min && doubleValue <= max {
                // Value within supported range, so write the formatted value back from where it will later be read
                self.previewMarginSizeText.stringValue = String(format:"%.1f", doubleValue)
                return
            }

            // Erroneous value: numeric but out of range
            // Set value to either end
            if doubleValue < min {
                self.previewMarginSizeText.stringValue = String(format:"%.1f", min)
            } else if doubleValue > max {
                self.previewMarginSizeText.stringValue = String(format:"%.1f", max)
            }
        } else {
            // Erroneous value: not numeric
            self.previewMarginSizeText.stringValue = String(format:"%.1f", self.currentSettings.previewMarginWidth)
        }

        // Warn the user
        NSSound.beep()
    }
}
