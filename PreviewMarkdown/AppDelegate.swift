/*
 *  AppDelegate.swift
 *  PreviewMarkdown
 *
 *  Created by Tony Smith on 31/10/2019.
 *  Copyright © 2024 Tony Smith. All rights reserved.
 */


import Cocoa
import CoreServices
import WebKit


@NSApplicationMain
final class AppDelegate: NSObject,
                         NSApplicationDelegate,
                         URLSessionDelegate,
                         URLSessionDataDelegate,
                         WKNavigationDelegate {

    // MARK: - Class UI Properies

    // Menu Items Tab
    @IBOutlet var helpMenu: NSMenuItem!
    @IBOutlet var helpMenuSwiftyMarkdown: NSMenuItem!
    @IBOutlet var helpMenuAppStoreRating: NSMenuItem!
    // FROM 1.3.0
    @IBOutlet var helpMenuYamlSwift: NSMenuItem!
    // FROM 1.3.1
    @IBOutlet var helpMenuOthersPreviewYaml: NSMenuItem!
    // FROM 1.4.0
    @IBOutlet var helpMenuOthersPreviewCode: NSMenuItem!
    // FROM 1.4.4
    @IBOutlet var helpMenuOthersPreviewJson: NSMenuItem!
    // FROM 1.4.5
    @IBOutlet var helpMenuOthersPreviewText: NSMenuItem!
    @IBOutlet var helpMenuOnlineHelp: NSMenuItem!
    @IBOutlet var helpMenuReportBug: NSMenuItem!
    @IBOutlet var helpMenuWhatsNew: NSMenuItem!
    @IBOutlet var mainMenuSettings: NSMenuItem!
    // FROM 1.5.0
    @IBOutlet var mainMenuResetFinder: NSMenuItem!
    
    // Panel Items
    @IBOutlet var versionLabel: NSTextField!
    
    // Windows
    @IBOutlet weak var window: NSWindow!

    // FROM 1.1.1
    // Report Sheet
    @IBOutlet weak var reportWindow: NSWindow!
    @IBOutlet weak var feedbackText: NSTextField!
    @IBOutlet weak var connectionProgress: NSProgressIndicator!

    // FROM 1.2.0
    // Preferences Sheet
    @IBOutlet weak var preferencesWindow: NSWindow!
    @IBOutlet weak var fontSizeSlider: NSSlider!
    @IBOutlet weak var fontSizeLabel: NSTextField!
    @IBOutlet weak var useLightCheckbox: NSButton!
    @IBOutlet weak var bodyFontPopup: NSPopUpButton!
    @IBOutlet weak var codeFontPopup: NSPopUpButton!
    // FROM 1.3.0
    @IBOutlet weak var showFrontMatterCheckbox: NSButton!
    // FROM 1.4.0
    //@IBOutlet weak var codeColourWell: NSColorWell!
    @IBOutlet weak var headColourWell: NSColorWell!
    @IBOutlet weak var bodyStylePopup: NSPopUpButton!
    @IBOutlet weak var codeStylePopup: NSPopUpButton!
    // FROM 1.5.0
    @IBOutlet weak var lineSpacingPopup: NSPopUpButton!
    @IBOutlet weak var colourSelectionPopup: NSPopUpButton!

    // FROM 1.2.0
    // What's New Sheet
    @IBOutlet weak var whatsNewWindow: NSWindow!
    @IBOutlet weak var whatsNewWebView: WKWebView!


    // MARK: - Private Properies

    // FROM 1.1.1
    private var feedbackTask: URLSessionTask? = nil
    // FROM 1.2.0 -- stores for preferences
    internal var whatsNewNav: WKNavigation? = nil
    private  var previewFontSize: CGFloat = CGFloat(BUFFOON_CONSTANTS.PREVIEW_FONT_SIZE)
    private  var doShowLightBackground: Bool = false
    private  var doShowTag: Bool = false
             var localMarkdownUTI: String = "NONE"
    // FROM 1.3.0
    private  var doShowFrontMatter: Bool = false
    // FROM 1.4.0
    private  var codeColourHex: String = BUFFOON_CONSTANTS.CODE_COLOUR_HEX
    private  var headColourHex: String = BUFFOON_CONSTANTS.HEAD_COLOUR_HEX
    private  var bodyFontName: String = BUFFOON_CONSTANTS.BODY_FONT_NAME
    private  var codeFontName: String = BUFFOON_CONSTANTS.CODE_FONT_NAME
    internal var bodyFonts: [PMFont] = []
    internal var codeFonts: [PMFont] = []
    // FROM 1.4.6
    //private  var havePrefsChanged: Bool = false
    // FROM 1.5.0
    private var lineSpacing: CGFloat = BUFFOON_CONSTANTS.BASE_LINE_SPACING
    private var linkColourHex: String = BUFFOON_CONSTANTS.LINK_COLOUR_HEX
    private var displayColours: [String:String] = [:]

    /*
     Replace the following string with your own team ID. This is used to
     identify the app suite and so share preferences set by the main app with
     the previewer and thumbnailer extensions.
     */
    private  var appSuiteName: String = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME

    
    // MARK: - Class Lifecycle Functions

    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // FROM 1.4.0
        // Pre-load fonts in a separate thread
        let q: DispatchQueue = DispatchQueue.init(label: "com.bps.previewmarkdown.async-queue")
        q.async {
            self.asyncGetFonts()
        }

        // FROM 1.2.0
        // Set application group-level defaults
        registerPreferences()
        
        // FROM 1.2.0
        // Get the local UTI for markdown files
        self.localMarkdownUTI = getLocalFileUTI(BUFFOON_CONSTANTS.SAMPLE_UTI_FILE)

        // FROM 1.0.3
        // Add the version number to the panel
        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        versionLabel.stringValue = "Version \(version) (\(build))"

        // From 1.0.4
        // Disable the Help menu Spotlight features
        let dummyHelpMenu: NSMenu = NSMenu.init(title: "Dummy")
        let theApp = NSApplication.shared
        theApp.helpMenu = dummyHelpMenu
        
        // FROM 1.0.2
        // Centre window and display
        self.window.center()
        self.window.makeKeyAndOrderFront(self)

        // FROM 1.2.0
        // Show 'What's New' if we need to
        // (and set up the WKWebBiew: no elasticity, horizontal scroller)
        // NOTE Has to take place at the end of the function
        doShowWhatsNew(self)
    }


    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {

        // When the main window closed, shut down the app
        return true
    }


    // MARK: - Action Functions

    @IBAction private func doClose(_ sender: Any) {
        
        // FROM 1.3.0
        // Reset the QL thumbnail cache... just in case
        _ = runProcess(app: "/usr/bin/qlmanage", with: ["-r", "cache"])
        
        // FROM 1.4.6
        // Check for open panels
        if self.preferencesWindow.isVisible {
            if checkPrefs() {
                let alert: NSAlert = showAlert("You have unsaved settings",
                                               "Do you wish to cancel and save them, or quit the app anyway?",
                                               false)
                alert.addButton(withTitle: "Quit")
                alert.addButton(withTitle: "Cancel")
                alert.beginSheetModal(for: self.preferencesWindow) { (response: NSApplication.ModalResponse) in
                    if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                        // The user clicked 'Quit'
                        self.preferencesWindow.close()
                        self.window.close()
                    }
                }
                
                return
            }
            
            self.preferencesWindow.close()
        }
        
        if self.whatsNewWindow.isVisible {
            self.whatsNewWindow.close()
        }
        
        if self.reportWindow.isVisible {
            if self.feedbackText.stringValue.count > 0 {
                let alert: NSAlert = showAlert("You have unsent feedback",
                                               "Do you wish to cancel and send it, or quit the app anyway?",
                                               false)
                alert.addButton(withTitle: "Quit")
                alert.addButton(withTitle: "Cancel")
                alert.beginSheetModal(for: self.reportWindow) { (response: NSApplication.ModalResponse) in
                    if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                        // The user clicked 'Quit'
                        self.reportWindow.close()
                        self.window.close()
                    }
                }
                
                return
            }
            
            self.reportWindow.close()
        }

        // Close the window... which will trigger an app closure
        self.window.close()
    }
    
    
    @IBAction @objc private func doShowSites(sender: Any) {
        
        // Open the websites for contributors
        let item: NSMenuItem = sender as! NSMenuItem
        var path: String = BUFFOON_CONSTANTS.URL_MAIN

        // FROM 1.1.0 -- bypass unused items
        if item == self.helpMenuSwiftyMarkdown {
            path = "https://github.com/SimonFairbairn/SwiftyMarkdown"
        } else if item == self.helpMenuAppStoreRating {
            path = BUFFOON_CONSTANTS.APP_STORE + "?action=write-review"
        } else if item == self.helpMenuYamlSwift {
            // FROM 1.3.0
            path = "https://github.com/behrang/YamlSwift"
        } else if item == self.helpMenuOnlineHelp {
            // FROM 1.3.0
            path += "#how-to-use-previewmarkdown"
        } else if item == self.helpMenuOthersPreviewYaml {
            // FROM 1.3.1
            path = BUFFOON_CONSTANTS.APP_URLS.PY
        } else if item == self.helpMenuOthersPreviewCode {
            // FROM 1.4.0
            path = BUFFOON_CONSTANTS.APP_URLS.PC
        } else if item == self.helpMenuOthersPreviewJson {
            // FROM 1.4.4
            path = BUFFOON_CONSTANTS.APP_URLS.PJ
        } else if item == self.helpMenuOthersPreviewText {
            // FROM 1.4.6
            path = BUFFOON_CONSTANTS.APP_URLS.PT
        }
        
        // Open the selected website
        NSWorkspace.shared.open(URL.init(string:path)!)
    }
    
    
    @IBAction private func doShowPrefsHelp(sender: Any) {
        
        // FROM 1.5.0
        // Alternative route to help
        let path: String = BUFFOON_CONSTANTS.URL_MAIN + "#customise-the-preview"
        NSWorkspace.shared.open(URL.init(string:path)!)

    }


    @IBAction private func doOpenSysPrefs(sender: Any) {

        // FROM 1.1.0
        // Open the System Preferences app at the Extensions pane
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Extensions.prefPane"))
    }
    
    
    @IBAction private func doInitiateFinderReset(sender: Any) {
        
        // FROM 1.5.0
        warnUserAboutReset()
    }

    
    // MARK: - Report Functions
    
    @IBAction @objc private func showFeedbackWindow(sender: Any?) {

        // FROM 1.1.1
        // Display a window in which the user can submit feedback
        
        // FROM 1.4.6
        // Disable menus we don't want used when the panel is open
        hidePanelGenerators()

        // Reset the UI
        self.connectionProgress.stopAnimation(self)
        self.feedbackText.stringValue = ""

        // Present the window
        self.window.beginSheet(self.reportWindow, completionHandler: nil)
    }


    @IBAction @objc private func doCancelReportWindow(sender: Any) {

        // FROM 1.1.1
        // User has clicked 'Cancel', so just close the sheet

        self.connectionProgress.stopAnimation(self)
        self.window.endSheet(self.reportWindow)
        
        // FROM 1.4.6
        // Restore menus
        showPanelGenerators()
    }


    @IBAction @objc private func doSendFeedback(sender: Any) {

        // FROM 1.1.1
        // User clicked 'Send' so get the message (if there is one) from the text field and send it
        
        let feedback: String = self.feedbackText.stringValue

        if feedback.count > 0 {
            // Start the connection indicator if it's not already visible
            self.connectionProgress.startAnimation(self)

            /*
             Add your own `func sendFeedback(_ feedback: String) -> URLSessionTask?` function
             */
            self.feedbackTask = sendFeedback(feedback)
            
            if self.feedbackTask != nil {
                // We have a valid URL Session Task, so start it to send
                self.feedbackTask!.resume()
            } else {
                // Report the error
                sendFeedbackError()
            }

            return
        }
        
        // No feedback, so close the sheet
        self.window.endSheet(self.reportWindow)
        
        // FROM 1.4.6
        // Restore menus
        showPanelGenerators()
        
        // NOTE sheet closes asynchronously unless there was no feedback to send
    }
    
    
    // MARK: - Preferences Functions
    
    /**
     Initialise and display the **Preferences** sheet.
     
     FROM 1.2.0

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction private func doShowPreferences(sender: Any) {
        
        // FROM 1.4.6
        // Reset changed prefs flag
        //self.havePrefsChanged = false
        
        // FROM 1.4.6
        // Disable menus we don't want used when the panel is open
        hidePanelGenerators()
        
        // The suite name is the app group name, set in each extension's entitlements, and the host app's
        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            self.previewFontSize = CGFloat(defaults.float(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_SIZE))
            self.doShowLightBackground = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_USE_LIGHT)
            
            // FROM 1.3.0
            self.doShowFrontMatter = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_YAML)
            
            // FROM 1.4.0
            self.codeFontName = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_FONT_NAME) ?? BUFFOON_CONSTANTS.CODE_FONT_NAME
            self.bodyFontName = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_NAME) ?? BUFFOON_CONSTANTS.BODY_FONT_NAME
            
            // FROM 1.5.0
            self.lineSpacing = CGFloat(defaults.float(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINE_SPACE))
            self.displayColours["heads"] = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_HEAD_COLOUR) ?? BUFFOON_CONSTANTS.HEAD_COLOUR_HEX
            self.displayColours["code"]  = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_COLOUR) ?? BUFFOON_CONSTANTS.CODE_COLOUR_HEX
            self.displayColours["links"] = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINK_COLOUR) ?? BUFFOON_CONSTANTS.LINK_COLOUR_HEX
            self.displayColours["quote"] = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_QUOTE_COLOUR) ??
                BUFFOON_CONSTANTS.QUOTE_COLOUR_HEX
        }

        // Get the menu item index from the stored value
        // NOTE The other values are currently stored as indexes -- should this be the same?
        let index: Int = BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS.lastIndex(of: self.previewFontSize) ?? 3
        self.fontSizeSlider.floatValue = Float(index)
        self.fontSizeLabel.stringValue = "\(Int(BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[index]))pt"
        self.useLightCheckbox.state = self.doShowLightBackground ? .on : .off
        
        // FROM 1.3.0
        self.showFrontMatterCheckbox.state = self.doShowFrontMatter ? .on : .off
        
        // FROM 1.4.0
        // Set the two colour wells
        //self.codeColourWell.color = NSColor.hexToColour(self.codeColourHex)
        self.headColourWell.color = NSColor.hexToColour(self.displayColours["heads"] ?? BUFFOON_CONSTANTS.HEAD_COLOUR_HEX)
        
        // FROM 1.4.0
        // Extend font selection to all available fonts
        // First, the body text font...
        self.bodyFontPopup.removeAllItems()
        self.bodyStylePopup.isEnabled = false
        
        for i: Int in 0..<self.bodyFonts.count {
            let font: PMFont = self.bodyFonts[i]
            self.bodyFontPopup.addItem(withTitle: font.displayName)
        }

        selectFontByPostScriptName(self.bodyFontName, true)

        // ...and the code font
        self.codeFontPopup.removeAllItems()
        self.codeStylePopup.isEnabled = false

        for i: Int in 0..<self.codeFonts.count {
            let font: PMFont = self.codeFonts[i]
            self.codeFontPopup.addItem(withTitle: font.displayName)
        }

        selectFontByPostScriptName(self.codeFontName, false)

        // FROM 1.5.0
        // Set the line spacing selector
        switch(round(self.lineSpacing * 100) / 100.0) {
            case 1.15:
                self.lineSpacingPopup.selectItem(at: 1)
            case 1.5:
                self.lineSpacingPopup.selectItem(at: 2)
            case 2.0:
                self.lineSpacingPopup.selectItem(at: 3)
            default:
                self.lineSpacingPopup.selectItem(at: 0)
        }

        self.colourSelectionPopup.selectItem(at: 0)
        self.clearNewColours()

        // Display the sheet
        self.window.beginSheet(self.preferencesWindow, completionHandler: nil)
    }


    /**
     Close the **Preferences** sheet without saving.
     
     FROM 1.2.0

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction private func doClosePreferences(sender: Any) {

        // FROM 1.4.0
        /* REMOVED 1.5.0
        // Close the colour selection panel if it's open
        if self.codeColourWell.isActive {
            NSColorPanel.shared.close()
            self.codeColourWell.deactivate()
        }
         */
        
        if checkPrefs() {
            let alert: NSAlert = showAlert("You have made changes",
                                           "Do you wish to go back and save them, or ignore them? ",
                                           false)
            alert.addButton(withTitle: "Go Back")
            alert.addButton(withTitle: "Ignore Changes")
            alert.beginSheetModal(for: self.preferencesWindow) { (response: NSApplication.ModalResponse) in
                if response != NSApplication.ModalResponse.alertFirstButtonReturn {
                    // The user clicked 'Cancel'
                    self.clearNewColours()
                    self.closePrefsWindow()
                }
            }
        } else {
            self.clearNewColours()
            closePrefsWindow()
        }
    }
    
    
    /**
        Follow-on function to close the **Preferences** sheet without saving.
        FROM 1.5.3

        - Parameters:
            - sender: The source of the action.
     */
    private func closePrefsWindow() {
        
        if self.headColourWell.isActive {
            NSColorPanel.shared.close()
            self.headColourWell.deactivate()
        }

        // Remove the sheet now we have the data
        self.window.endSheet(self.preferencesWindow)
        
        // FROM 1.4.6
        // Restore menus
        showPanelGenerators()
    }
    
    
    /**
        Check prefs for differences from the initial state.
        Used when the **Preferences** sheet is closed with the Cancel button.
        FROM 1.5.3
     */
    private func checkPrefs() -> Bool {
        
        var haveChanged: Bool = false
        
        // Check for a use light background change
        var state: Bool = self.useLightCheckbox.state == .on
        haveChanged = (self.doShowLightBackground != state)
        
        // Check for a show frontmatter change
        if !haveChanged {
            state = self.showFrontMatterCheckbox.state == .on
            haveChanged = (self.doShowFrontMatter != state)
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
        
        if !haveChanged {
            haveChanged = (self.lineSpacing != lineSpacing)
        }
        
        // Check for and record font and style changes
        if let fontName: String = getPostScriptName(false) {
            if !haveChanged {
                haveChanged = (fontName != self.codeFontName)
            }
        }
        
        if let fontName: String = getPostScriptName(true) {
            if !haveChanged {
                haveChanged = (fontName != self.bodyFontName)
            }
        }
        
        // Check for and record a font size change
        if !haveChanged {
            haveChanged = (self.previewFontSize != BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[Int(self.fontSizeSlider.floatValue)])
        }
        
        // Check for colour changes
        if let _ = self.displayColours["new_heads"] {
            haveChanged = true
        }

        if let _ = self.displayColours["new_code"] {
            haveChanged = true
        }

        if let _ = self.displayColours["new_links"] {
            haveChanged = true
        }

        if let _ = self.displayColours["new_quote"] {
            haveChanged = true
        }
        
        return haveChanged
    }


    /**
     Close the **Preferences** sheet and save any settings that have changed.
     
     FROM 1.2.0
     
     - Parameters:
        - sender: The source of the action.
     */
    @IBAction private func doSavePreferences(sender: Any) {

        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            let newValue: CGFloat = BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[Int(self.fontSizeSlider.floatValue)]
            if newValue != self.previewFontSize {
                defaults.setValue(newValue,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_SIZE)
            }
            
            var state: Bool = self.useLightCheckbox.state == .on
            if self.doShowLightBackground != state {
                defaults.setValue(state,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_USE_LIGHT)
            }

            // FROM 1.3.0
            // Get the YAML checkbox value and update
            state = self.showFrontMatterCheckbox.state == .on
            if self.doShowFrontMatter != state {
                defaults.setValue(state,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_YAML)
            }

            // FROM 1.4.0
            // Get any font changes
            if let psname: String = getPostScriptName(false) {
                if psname != self.codeFontName {
                    self.codeFontName = psname
                    defaults.setValue(psname, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_FONT_NAME)
                }
            }

            if let psname = getPostScriptName(true) {
                if psname != self.bodyFontName {
                    self.bodyFontName = psname
                    defaults.setValue(psname, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_NAME)
                }
            }
            
            // FROM 1.5.0
            // Save the selected line spacing
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
            
            if (self.lineSpacing != lineSpacing) {
                self.lineSpacing = lineSpacing
                defaults.setValue(lineSpacing, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINE_SPACE)
            }

            if let newColour: String = self.displayColours["new_heads"] {
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_HEAD_COLOUR)
            }

            if let newColour: String = self.displayColours["new_code"] {
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_CODE_COLOUR)
            }

            if let newColour: String = self.displayColours["new_links"] {
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_LINK_COLOUR)
            }

            if let newColour: String = self.displayColours["new_quote"] {
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_QUOTE_COLOUR)
            }
        }
        
        closePrefsWindow()
    }
    
    
    /**
     Called when the user selects a font from either list.

     FROM 1.4.0

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction private func doUpdateFonts(sender: Any) {

        let item: NSPopUpButton = sender as! NSPopUpButton
        setStylePopup(item == self.bodyFontPopup)
        //self.havePrefsChanged = true
    }

    
    /**
     When the font size slider is moved and released, this function updates the font size readout.
 
     FROM 1.2.0

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction private func doMoveSlider(sender: Any) {

        let index: Int = Int(self.fontSizeSlider.floatValue)
        self.fontSizeLabel.stringValue = "\(Int(BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[index]))pt"
        //self.havePrefsChanged = true
    }


    /**
        Generic IBAction for any Prefs control to register it has been used.
     
        - Parameters:
            - sender: The source of the action.
     */
    @IBAction private func controlClicked(sender: Any) {
        
        //self.havePrefsChanged = true
    }


    /**
        Update the colour preferences dictionary with a value from the
        colour well when a colour is chosen.
        FROM 1.5.0

        - Parameters:
            - sender: The source of the action.
     */
    @objc @IBAction private func colourSelected(sender: Any) {

        let keys: [String] = ["heads", "code", "links", "quote"]
        let key: String = "new_" + keys[self.colourSelectionPopup.indexOfSelectedItem]
        self.displayColours[key] = self.headColourWell.color.hexString
        //self.havePrefsChanged = true
    }


    /**
        Update the colour well with the stored colour: either a new one, previously
        chosen, or the loaded preference.
        FROM 1.5.0

        - Parameters:
            - sender: The source of the action.
     */
    @IBAction private func doChooseColourType(sender: Any) {

        let keys: [String] = ["heads", "code", "links", "quote"]
        let key: String = keys[self.colourSelectionPopup.indexOfSelectedItem]

        // If there's no `new_xxx` key, the next line will evaluate to false
        if let colour: String = self.displayColours["new_" + key] {
            if colour.count != 0 {
                // Set the colourwell with the updated colour and exit
                self.headColourWell.color = NSColor.hexToColour(colour)
                return
            }
        }

        // Set the colourwell with the stored colour
        if let colour: String = self.displayColours[key] {
            self.headColourWell.color = NSColor.hexToColour(colour)
        }
    }


    /**
        Zap any temporary colour values.
        FROM 1.5.0

     */
    private func clearNewColours() {

        let keys: [String] = ["heads", "code", "links", "quote"]
        for key in keys {
            if let _: String = self.displayColours["new_" + key] {
                self.displayColours["new_" + key] = nil
            }
        }
    }



    
    // MARK: - What's New Functions
    /**
     Show the **What's New** sheet.

     If we're on a new, non-patch version, of the user has explicitly
     asked to see it with a menu click See if we're coming from a menu click
     (`sender != self`) or directly in code from *appDidFinishLoading()*
     (`sender == self`)

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction private func doShowWhatsNew(_ sender: Any) {

        // See if we're coming from a menu click (sender != self) or
        // directly in code from 'appDidFinishLoading()' (sender == self)
        var doShowSheet: Bool = type(of: self) != type(of: sender)
        
        if !doShowSheet {
            // We are coming from the 'appDidFinishLoading()' so check
            // if we need to show the sheet by the checking the prefs
            if let defaults = UserDefaults(suiteName: self.appSuiteName) {
                // Get the version-specific preference key
                let key: String = BUFFOON_CONSTANTS.PREFS_IDS.MAIN_WHATS_NEW + getVersion()
                doShowSheet = defaults.bool(forKey: key)
            }
        }
      
        // Configure and show the sheet
        if doShowSheet {
            // FROM 1.4.6
            // Disable menus we don't want used when the panel is open
            hidePanelGenerators()
            
            // First, get the folder path
            let htmlFolderPath = Bundle.main.resourcePath! + "/new"

            // Set WebView properties: limit scrollers and elasticity
            self.whatsNewWebView.enclosingScrollView?.hasHorizontalScroller = false
            self.whatsNewWebView.enclosingScrollView?.horizontalScrollElasticity = .none
            self.whatsNewWebView.enclosingScrollView?.verticalScrollElasticity = .none
            self.whatsNewWebView.configuration.suppressesIncrementalRendering = true

            // Just in case, make sure we can load the file
            if FileManager.default.fileExists(atPath: htmlFolderPath) {
                let htmlFileURL = URL.init(fileURLWithPath: htmlFolderPath + "/new.html")
                let htmlFolderURL = URL.init(fileURLWithPath: htmlFolderPath)
                self.whatsNewNav = self.whatsNewWebView.loadFileURL(htmlFileURL, allowingReadAccessTo: htmlFolderURL)
            }
        }
    }


    @IBAction private func doCloseWhatsNew(_ sender: Any) {

        // FROM 1.2.0
        // Close the 'What's New' sheet, making sure we clear the preference flag for this minor version,
        // so that the sheet is not displayed next time the app is run (unless the version changes)

        // Close the sheet
        self.window.endSheet(self.whatsNewWindow)
        
        // Scroll the web view back to the top
        self.whatsNewWebView.evaluateJavaScript("window.scrollTo(0,0)", completionHandler: nil)

        // Set this version's preference
        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            let key: String = BUFFOON_CONSTANTS.PREFS_IDS.MAIN_WHATS_NEW + getVersion()
            defaults.setValue(false, forKey: key)

            #if DEBUG
            print("\(key) reset back to true")
            defaults.setValue(true, forKey: key)
            #endif
        }
        
        // FROM 1.4.6
        // Restore menus
        showPanelGenerators()
    }


    // MARK: - Misc Functions
    
    /**
     Configure the app's preferences with default values.
     
     FROM 1.2.0
     */
    private func registerPreferences() {

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

}

