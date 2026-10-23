/*
 *  PMAppDelegateSettings.swift
 *  PreviewMarkdown
 *  Extension for AppDelegate providing settings handling functionality.
 *
 *  Created by Tony Smith on 07/10/2024.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */


import AppKit


extension AppDelegate {

    // MARK: - User Action Functions

    internal func initialiseSettings() {

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

        self.advancedYamlFontSizeText.delegate = self
        self.advancedMaxFileSizeText.delegate = self
    }

    
    /**
     Update UI when we are about to switch to it
     */
    internal func willShowSettingsPage() {

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

        guard let item = sender as? NSPopUpButton else { return }
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

        let keys = BUFFOON_CONSTANTS.COLOUR_OPTIONS
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

        let keys = BUFFOON_CONSTANTS.COLOUR_OPTIONS
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

     NOTE This is only possible if the button is enabled.

     FROM 2.0.0

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    internal func doApplyCurrentSettings(sender: Any) {
         
         // Changes are present, so save them.
         // NOTE This call updates the current settings values from the Settings tab UI.
         saveSettings()
         willShowSettingsPage()
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

        if advancedValuesGood() {
            self.window.endSheet(self.advancedSettingsSheet)

            var note = Notification(name: .NSAppleEventManagerWillProcessFirstEvent, object: self.advancedYamlFontSizeText)
            controlTextDidEndEditing(note)
            note.object = self.advancedMaxFileSizeText
            controlTextDidEndEditing(note)

            willShowSettingsPage()
        }
    }


    internal func advancedValuesGood() -> Bool {

        let yamlSize = self.advancedYamlFontSizeText.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let ys = yamlSize.first {
            if ys.isWholeNumber {
                // The first digit is a number
                let value = Float(self.advancedYamlFontSizeText.stringValue)
                guard value != nil else {
                    showWarning("The YAML front matter font size is not a number or M(atch)")
                    return false
                }

                guard value! >= 6.0 && value! <= 28.0 else {
                    showWarning("The YAML front matter font size is not in the range 0-28")
                    return false
                }
            } else {
                // Text
                if ys != "M" || !["M", "MATCH"].contains(yamlSize) {
                    // Not Match or M
                    showWarning("The YAML front matter font size must be a number or M(atch)")
                    return false
                }
            }
        } else {
            // Box is empty
            showWarning("The YAML front matter font size must be a number or M(atch)")
            return false
        }

        // Preview Margin Size
        if let previewMargin = Float(self.previewMarginSizeText.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
            if previewMargin < 0.0 || previewMargin > 256.0 {
                showWarning("The preview margin size is outside the range \(BUFFOON_CONSTANTS.PREVIEW_SIZE.PREVIEW_MARGIN_WIDTH_MIN)-\(BUFFOON_CONSTANTS.PREVIEW_SIZE.PREVIEW_MARGIN_WIDTH_MAX)")
                return false
            }
        } else {
            showWarning("The preview margin size must be a number in the range \(BUFFOON_CONSTANTS.PREVIEW_SIZE.PREVIEW_MARGIN_WIDTH_MIN)-\(BUFFOON_CONSTANTS.PREVIEW_SIZE.PREVIEW_MARGIN_WIDTH_MAX)")
            return false
        }

        // File Size
        let possibleSize = calculateSize(self.advancedMaxFileSizeText.stringValue.uppercased())
        if possibleSize == -1 {
            showWarning("The maximum file size value is not a valid size, eg. 1MB, 100MB, 2GB, or A(ny size)")
            return false
        }

        return true
    }


    internal func showWarning(_ message: String) {

        Task { @MainActor in
            let alert = makeAlert("Something‘s not right!", message, true, true)
            _ = await alert.beginSheetModal(for: self.advancedSettingsSheet)
        }
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
            let font: PAFont = self.bodyFonts[i]
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

        // FROM 2.5.0
        let displayText = settings.yamlFontSize == 0.0 ? "Match" : String(format:"%.1f", settings.yamlFontSize)
        self.advancedYamlFontSizeText.stringValue = displayText
        self.advancedMaxFileSizeText.stringValue = unifySize(settings.maxFileSize)
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

        // FROM 2.5.0
        if self.advancedYamlFontSizeText.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().hasPrefix("M") {
            displayedSettings.yamlFontSize = 0.0
        } else {
            displayedSettings.yamlFontSize = CGFloat(Float(self.advancedYamlFontSizeText.stringValue) ?? 6.0)
        }

        let fieldValue = self.advancedMaxFileSizeText.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if self.infinities.contains(fieldValue) {
            displayedSettings.maxFileSize = 0
        } else {
            displayedSettings.maxFileSize = calculateSize(fieldValue)
        }

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

        // FROM 2.5.0
        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.yamlFontSize != displayedSettings.yamlFontSize
        }

        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.maxFileSize != displayedSettings.maxFileSize
        }


        return settingsHaveChanged
    }


    /**
     Zap any temporary colour values.
     
     FROM 1.5.0
     */
    internal func clearNewColours() {

        let keys = BUFFOON_CONSTANTS.COLOUR_OPTIONS
        for key in keys {
            if let _ = self.currentSettings.displayColours["new_" + key] {
                self.currentSettings.displayColours["new_" + key] = nil
            }
        }
    }


    /**
     Set colours to defaults any temporary colour values.
     
     FROM 2.0.0
     */
    internal func applyDefaultColours() {

        let keys = BUFFOON_CONSTANTS.COLOUR_OPTIONS
        for key in keys {
            self.currentSettings.displayColours["new_" + key] = self.defaultSettings.displayColours[key]
        }
    }


    /**
     Receive a string like `Any`, `12B`, `8KB`, `10MB` or `0.5GB` and
     convert it into `0` or a larger integer.

     `0` has special meaning: any size.

     FROM 2.5.0
     */
    internal func calculateSize(_ sizeText: String) -> Int {

        if sizeText.isEmpty {
            return  -1
        }

        let testText = sizeText.trimmingCharacters(in: .whitespaces).uppercased().replacingOccurrences(of: ",", with: "")
        if self.infinities.contains(testText) {
            return 0
        }

        let units = ["B", "KB", "MB", "GB", "TB"]
        let (valueText, unit) = parseFileSize(testText)
        let valueBase = Double(valueText) ?? 1.0
        var value = 0
        if !unit.isEmpty {
            if units.contains(unit) {
                let index = Double(units.firstIndex(of: String(unit)) ?? 0)
                value = Int(valueBase * pow(1024, index))
            } else {
                // Bad unit
                return -1
            }
        } else {
            value = Int(valueBase)
        }

        // Apply the 1MB smallest max. value
        if value < 1048576 {
            return -1
        }

        return value
    }


    /**
     Take a filesize string, with or without a byte marker (eg. `B`, `KB`, `MB`) and
     separate the value from the units. If no units are provided, `B` is returned.

     FROM 2.5.0

     - Parameters:
        - input: The source string.

     - Returns A tuple comprising the size compoent as a string and the unit marker
               (default: `B`)
     */
    internal func parseFileSize(_ input: String) -> (value: String, unit: String) {

        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // Take the leading run of digits and decimal points as the value
        let value = String(trimmed.prefix {
            ("0"..."9").contains($0) || $0 == "."
        })

        // Whatever follows is the byte marker, eg. "KB", "MB", "GB"
        let unit = String(trimmed.dropFirst(value.count)).trimmingCharacters(in: .whitespaces)
        return (value, unit.isEmpty ? "B" : unit)
    }


    /**
     Convert an byte value into a units string,
     eg. `536,870,912` to `512MB`.

     - Parameters:
        - numberInBytes: The byte value.

     - Returns: The string containing a order of magnitude merker.
     */
    internal func unifySize(_ numberInBytes: Int) -> String {

        // Special case: handle a zero value, which is used
        // to represent any size (ie. user has set no limit)
        if numberInBytes == 0 {
            return "♾️"
        }

        let units = ["B", "KB", "MB", "GB", "TB"]
        var displayText = ""
        let base: Double = 1024
        var power: Double = 0

        while true {
            let max = Int(pow(base, power))
            if numberInBytes < max {
                displayText = "\(numberInBytes / Int(pow(base, power - 1)))\(units[Int(power - 1)])"
                break
            }

            power += 1
            if power > Double(units.count) {
                return "ERROR"
            }
        }

        return displayText
    }


    // MARK: - NSTextFieldDelegate Functions

    /**
     Verify input values.

     FROM 2.3.0
    */
    func controlTextDidEndEditing(_ obj: Notification) {

        let textField = obj.object as? NSTextField ?? nil
        if textField == self.previewMarginSizeText {
            if let doubleValue = Double(textField!.stringValue) {
                if let update = check(double: doubleValue, min: Float(BUFFOON_CONSTANTS.PREVIEW_SIZE.PREVIEW_MARGIN_WIDTH_MIN), max: Float(BUFFOON_CONSTANTS.PREVIEW_SIZE.PREVIEW_MARGIN_WIDTH_MAX)) {
                    textField!.stringValue = update
                    return
                }
            } else {
                // Bad value -- not numeric
                textField!.stringValue = String(format:"%.1f", self.currentSettings.previewMarginWidth)
            }
        } else if textField == self.advancedYamlFontSizeText {
            if let doubleValue = Double(textField!.stringValue) {
                // User has entered a number value
                if let update = check(double: doubleValue, min: 6.0, max: 28.0) {
                    textField!.stringValue = update
                    return
                }
            } else {
                // Text entered -- is it correct?
                let currentText = textField!.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                if currentText == "MATCH" || currentText == "M" {
                    textField!.stringValue = "Match"
                    return
                }

                // Bad text -- replace with the current numeric value
                textField!.stringValue = String(format:"%.1f", self.currentSettings.yamlFontSize)
            }
        } else if textField == self.advancedMaxFileSizeText {
            let possibleSize = calculateSize(textField!.stringValue.uppercased())
            if possibleSize != -1 {
                // Value OK
                if possibleSize == 0 {
                    // Variant on 'any'
                    textField!.stringValue = "♾️"
                } else {
                    textField!.stringValue = "\(unifySize(possibleSize))" //textField!.stringValue.uppercased()
                }

                return
            }

            // Invalid entry -- replace with the current value
            textField!.stringValue = "\(unifySize(self.currentSettings.maxFileSize))"
        }

        // Warn the user
        NSSound.beep()
    }


    internal func check(double: Double, min: Float, max: Float) -> String? {

        let mind = Double(min).rounded(.towardZero)
        let maxd = Double(max).rounded(.towardZero)

        if double >= mind && double <= maxd {
            // Value within supported range, so write the formatted value back from where it will later be read
            return String(format:"%.1f", double)
        }

        // Erroneous value: numeric but out of range, so set value to either end
        NSSound.beep()
        if double < mind {
            return String(format:"%.1f", mind)
        } else if double > maxd {
            return String(format:"%.1f", maxd)
        }

        // Error
        return nil
    }
}
