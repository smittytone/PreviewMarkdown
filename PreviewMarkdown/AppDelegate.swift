/*
 *  AppDelegate.swift
 *  PreviewMarkdown
 *
 *  Created by Tony Smith on 31/10/2019.
 *  Copyright © 2023 Tony Smith. All rights reserved.
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


    // MARK:- Class UI Properies
    // Menu Items Tab
    @IBOutlet var helpMenu: NSMenuItem!
    //@IBOutlet var creditMenuDiscount: NSMenuItem!
    //@IBOutlet var creditMenuQLMarkdown: NSMenuItem!
    @IBOutlet var helpMenuSwiftyMarkdown: NSMenuItem!
    //@IBOutlet var helpMenuAcknowlegdments: NSMenuItem!
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
    @IBOutlet weak var doShowTagCheckbox: NSButton!
    @IBOutlet weak var bodyFontPopup: NSPopUpButton!
    @IBOutlet weak var codeFontPopup: NSPopUpButton!
    //@IBOutlet weak var codeColourPopup: NSPopUpButton!
    // FROM 1.3.0
    @IBOutlet weak var showFrontMatterCheckbox: NSButton!
    // FROM 1.4.0
    @IBOutlet weak var codeColourWell: NSColorWell!
    @IBOutlet weak var headColourWell: NSColorWell!
    @IBOutlet weak var bodyStylePopup: NSPopUpButton!
    @IBOutlet weak var codeStylePopup: NSPopUpButton!
    // FROM 1.4.1
    @IBOutlet weak var tagInfoTextField: NSTextField!
    // FROM 1.5.0
    @IBOutlet weak var lineSpacingPopup: NSPopUpButton!

    // FROM 1.2.0
    // What's New Sheet
    @IBOutlet weak var whatsNewWindow: NSWindow!
    @IBOutlet weak var whatsNewWebView: WKWebView!
    
    // MARK:- Private Properies

    // FROM 1.1.1
    private var feedbackTask: URLSessionTask? = nil
    // FROM 1.2.0 -- stores for preferences
    internal var whatsNewNav: WKNavigation? = nil
    private  var previewFontSize: CGFloat = CGFloat(BUFFOON_CONSTANTS.PREVIEW_FONT_SIZE)
    private  var doShowLightBackground: Bool = false
    private  var doShowTag: Bool = false
    private  var localMarkdownUTI: String = "NONE"
    // FROM 1.3.0
    private  var doShowFrontMatter: Bool = false
    // FROM 1.3.1
    private  var appSuiteName: String = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME
    private  var feedbackPath: String = MNU_SECRETS.ADDRESS.B
    // FROM 1.4.0
    private  var codeColourHex: String = BUFFOON_CONSTANTS.CODE_COLOUR_HEX
    private  var headColourHex: String = BUFFOON_CONSTANTS.HEAD_COLOUR_HEX
    private  var bodyFontName: String = BUFFOON_CONSTANTS.BODY_FONT_NAME
    private  var codeFontName: String = BUFFOON_CONSTANTS.CODE_FONT_NAME
    internal var bodyFonts: [PMFont] = []
    internal var codeFonts: [PMFont] = []
    // FROM 1.4.1
    internal var isMontereyPlus: Bool = false
    // FROM 1.4.6
    private  var havePrefsChanged: Bool = false
    // FROM 1.5.0
    private var lineSpacing: CGFloat = BUFFOON_CONSTANTS.BASE_LINE_SPACING

    
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
        
        // FROM 1.4.1
        recordSystemState()
        
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


    // MARK:- Action Functions

    @IBAction private func doClose(_ sender: Any) {
        
        // FROM 1.3.0
        // Reset the QL thumbnail cache... just in case
        _ = runProcess(app: "/usr/bin/qlmanage", with: ["-r", "cache"])
        
        // FROM 1.4.6
        // Check for open panels
        if self.preferencesWindow.isVisible {
            if self.havePrefsChanged {
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
            
            self.feedbackTask = sendFeedback(feedback)
            
            if self.feedbackTask != nil {
                // We have a valid URL Session Task, so start it to send
                self.feedbackTask!.resume()
                return
            } else {
                // Report the error
                sendFeedbackError()
            }
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
        self.havePrefsChanged = false
        
        // FROM 1.4.6
        // Disable menus we don't want used when the panel is open
        hidePanelGenerators()
        
        // The suite name is the app group name, set in each extension's entitlements, and the host app's
        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            self.previewFontSize = CGFloat(defaults.float(forKey: "com-bps-previewmarkdown-base-font-size"))
            self.doShowLightBackground = defaults.bool(forKey: "com-bps-previewmarkdown-do-use-light")
            self.doShowTag = defaults.bool(forKey: "com-bps-previewmarkdown-do-show-tag")
            
            // FROM 1.3.0
            self.doShowFrontMatter = defaults.bool(forKey: "com-bps-previewmarkdown-do-show-front-matter")
            
            // FROM 1.4.0
            self.codeColourHex = defaults.string(forKey: "com-bps-previewmarkdown-code-colour-hex") ?? BUFFOON_CONSTANTS.CODE_COLOUR_HEX
            self.headColourHex = defaults.string(forKey: "com-bps-previewmarkdown-head-colour-hex") ?? BUFFOON_CONSTANTS.HEAD_COLOUR_HEX
            self.codeFontName = defaults.string(forKey: "com-bps-previewmarkdown-code-font-name") ?? BUFFOON_CONSTANTS.CODE_FONT_NAME
            self.bodyFontName = defaults.string(forKey: "com-bps-previewmarkdown-body-font-name") ?? BUFFOON_CONSTANTS.BODY_FONT_NAME
            
            // FROM 1.5.0
            self.lineSpacing = CGFloat(defaults.float(forKey: "com-bps-previewmarkdown-line-spacing"))
        }

        // Get the menu item index from the stored value
        // NOTE The other values are currently stored as indexes -- should this be the same?
        let index: Int = BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS.lastIndex(of: self.previewFontSize) ?? 3
        self.fontSizeSlider.floatValue = Float(index)
        self.fontSizeLabel.stringValue = "\(Int(BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[index]))pt"
        self.useLightCheckbox.state = self.doShowLightBackground ? .on : .off
        self.doShowTagCheckbox.state = self.doShowTag ? .on : .off
        
        // FROM 1.3.0
        self.showFrontMatterCheckbox.state = self.doShowFrontMatter ? .on : .off
        
        // FROM 1.4.0
        // Set the two colour wells
        self.codeColourWell.color = NSColor.hexToColour(self.codeColourHex)
        self.headColourWell.color = NSColor.hexToColour(self.headColourHex)
        
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
        
        // FROM 1.4.1
        // Hide tag selection on Monterey
        self.doShowTagCheckbox.isEnabled = !self.isMontereyPlus
        if (isMontereyPlus) {
            // FROM 1.4.2
            // Hide the unneeded options
            self.tagInfoTextField.isHidden = true
            self.doShowTagCheckbox.isHidden = true
            
            //self.doShowTagCheckbox.toolTip = "Not available in macOS 12 and up"
            //self.tagInfoTextField.stringValue = "macOS 12 adds its own thumbnail file extension tags, so this option is no longer available."
        }
        
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


        // Display the sheet
        self.window.beginSheet(self.preferencesWindow, completionHandler: nil)
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
        self.havePrefsChanged = true
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
        self.havePrefsChanged = true
    }


    /**
     Close the **Preferences** sheet without saving.
     
     FROM 1.2.0

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction private func doClosePreferences(sender: Any) {

        // FROM 1.4.0
        // Close the colour selection panel if it's open
        if self.codeColourWell.isActive {
            NSColorPanel.shared.close()
            self.codeColourWell.deactivate()
        }
                
        if self.headColourWell.isActive {
            NSColorPanel.shared.close()
            self.headColourWell.deactivate()
        }

        self.window.endSheet(self.preferencesWindow)
        
        // FROM 1.4.6
        // Restore menus
        showPanelGenerators()
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
                                  forKey: "com-bps-previewmarkdown-base-font-size")
            }
            
            var state: Bool = self.useLightCheckbox.state == .on
            if self.doShowLightBackground != state {
                defaults.setValue(state,
                                  forKey: "com-bps-previewmarkdown-do-use-light")
            }

            state = self.doShowTagCheckbox.state == .on
            if self.doShowTag != state {
                defaults.setValue(state,
                                  forKey: "com-bps-previewmarkdown-do-show-tag")
            }

            // FROM 1.3.0
            // Get the YAML checkbox value and update
            state = self.showFrontMatterCheckbox.state == .on
            if self.doShowFrontMatter != state {
                defaults.setValue(state,
                                  forKey: "com-bps-previewmarkdown-do-show-front-matter")
            }
            
            // FROM 1.4.0
            // Get any colour changes
            let newCodeColour: String = self.codeColourWell.color.hexString
            if newCodeColour != self.codeColourHex {
                self.codeColourHex = newCodeColour
                defaults.setValue(newCodeColour,
                                  forKey: "com-bps-previewmarkdown-code-colour-hex")
            }
            
            let newHeadColour: String = self.headColourWell.color.hexString
            if newHeadColour != self.headColourHex {
                self.headColourHex = newHeadColour
                defaults.setValue(newHeadColour,
                                  forKey: "com-bps-previewmarkdown-head-colour-hex")
            }
            
            // FROM 1.4.0
            // Get any font changes
            if let psname: String = getPostScriptName(false) {
                if psname != self.codeFontName {
                    self.codeFontName = psname
                    defaults.setValue(psname, forKey: "com-bps-previewmarkdown-code-font-name")
                }
            }

            if let psname = getPostScriptName(true) {
                if psname != self.bodyFontName {
                    self.bodyFontName = psname
                    defaults.setValue(psname, forKey: "com-bps-previewmarkdown-body-font-name")
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
                defaults.setValue(lineSpacing, forKey: "com-bps-previewmarkdown-line-spacing")
            }
        }

        // FROM 1.4.0
        // Close the colour selection panel if it's open
        if self.codeColourWell.isActive {
            NSColorPanel.shared.close()
            self.codeColourWell.deactivate()
        }
                
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
        Generic IBAction for any Prefs control to register it has been used.
     
        - Parameters:
            - sender: The source of the action.
     */
    @IBAction private func controlClicked(sender: Any) {
        
        self.havePrefsChanged = true
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
                let key: String = BUFFOON_CONSTANTS.WHATS_NEW_PREF + getVersion()
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
            let key: String = "com-bps-previewmarkdown-do-show-whats-new-" + getVersion()
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
            let bodyFontSizeDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-base-font-size")
            if bodyFontSizeDefault == nil {
                defaults.setValue(CGFloat(BUFFOON_CONSTANTS.PREVIEW_FONT_SIZE),
                                  forKey: "com-bps-previewmarkdown-base-font-size")
            }

            // Thumbnail view base font size, stored as a CGFloat, not currently used
            // Default: 14.0
            let thumbFontSizeDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-thumb-font-size")
            if thumbFontSizeDefault == nil {
                defaults.setValue(CGFloat(BUFFOON_CONSTANTS.THUMBNAIL_FONT_SIZE),
                                  forKey: "com-bps-previewmarkdown-thumb-font-size")
            }
            
            // Use light background even in dark mode, stored as a bool
            // Default: false
            let useLightDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-do-use-light")
            if useLightDefault == nil {
                defaults.setValue(false,
                                  forKey: "com-bps-previewmarkdown-do-use-light")
            }

            // Show the file identity ('tag') on Finder thumbnails
            // Default: false (from 1.4.1)
            let showTagDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-do-show-tag")
            if showTagDefault == nil {
                defaults.setValue(false,
                                  forKey: "com-bps-previewmarkdown-do-show-tag")
            }

            // Show the What's New sheet
            // Default: true
            // This is a version-specific preference suffixed with, eg, '-2-3'. Once created
            // this will persist, but with each new major and/or minor version, we make a
            // new preference that will be read by 'doShowWhatsNew()' to see if the sheet
            // should be shown this run
            let key: String = "com-bps-previewmarkdown-do-show-whats-new-" + getVersion()
            let showNewDefault: Any? = defaults.object(forKey: key)
            if showNewDefault == nil {
                defaults.setValue(true, forKey: key)
            }
            
            // FROM 1.3.0
            // Show any YAML front matter, if present
            // Default: true
            let showFrontMatterDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-do-show-front-matter")
            if showFrontMatterDefault == nil {
                defaults.setValue(true, forKey: "com-bps-previewmarkdown-do-show-front-matter")
            }
            
            // FROM 1.4.0
            // Colour of links in the preview, stored as hex string
            let linkColourDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-link-colour-hex")
            if linkColourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.LINK_COLOUR_HEX,
                                  forKey: "com-bps-previewmarkdown-link-colour-hex")
            }
            
            // FROM 1.4.0
            // Colour of code blocks in the preview, stored as hex string
            let codeColourDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-code-colour-hex")
            if codeColourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.CODE_COLOUR_HEX,
                                  forKey: "com-bps-previewmarkdown-code-colour-hex")
            }
            
            // FROM 1.4.0
            // Colour of headings in the preview, stored as hex string
            let headColourDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-head-colour-hex")
            if headColourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.HEAD_COLOUR_HEX,
                                  forKey: "com-bps-previewmarkdown-head-colour-hex")
            }
            
            // FROM 1.4.0
            // Font for body test in the preview, stored as a PostScript name
            let bodyFontDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-body-font-name")
            if bodyFontDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.BODY_FONT_NAME,
                                  forKey: "com-bps-previewmarkdown-body-font-name")
            }

            // FROM 1.4.0
            // Font for code blocks in the preview, stored as a PostScript name
            let codeFontDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-code-font-name")
            if codeFontDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.CODE_FONT_NAME,
                                  forKey: "com-bps-previewmarkdown-code-font-name")
            }
            
            // FROM 1.5.0
            // Store the preview line spacing value
            let lineSpacingDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-line-spacing")
            if lineSpacingDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.BASE_LINE_SPACING,
                                  forKey: "com-bps-previewmarkdown-line-spacing")
            }
        }
    }
    
    
    private func sendFeedback(_ feedback: String) -> URLSessionTask? {
        
        // FROM 1.2.0
        // Break out into separate function
        
        // Send the string etc.
        // First get the data we need to build the user agent string
        let userAgent: String = getUserAgentForFeedback()
        let endPoint: String = MNU_SECRETS.ADDRESS.A
        
        // Get the date as a string
        let dateString: String = getDateForFeedback()

        // Assemble the message string
        let dataString: String = """
         *FEEDBACK REPORT*
         *Date:* \(dateString)
         *User Agent:* \(userAgent)
         *UTI:* \(self.localMarkdownUTI)
         *FEEDBACK:*
         \(feedback)
         """

        // Build the data we will POST:
        let dict: NSMutableDictionary = NSMutableDictionary()
        dict.setObject(dataString,
                        forKey: NSString.init(string: "text"))
        dict.setObject(true, forKey: NSString.init(string: "mrkdwn"))
        
        // Make and return the HTTPS request for sending
        if let url: URL = URL.init(string: self.feedbackPath + endPoint) {
            var request: URLRequest = URLRequest.init(url: url)
            request.httpMethod = "POST"

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: dict,
                                                              options:JSONSerialization.WritingOptions.init(rawValue: 0))

                request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
                request.addValue("application/json", forHTTPHeaderField: "Content-type")

                let config: URLSessionConfiguration = URLSessionConfiguration.ephemeral
                let session: URLSession = URLSession.init(configuration: config,
                                                          delegate: self,
                                                          delegateQueue: OperationQueue.main)
                return session.dataTask(with: request)
            } catch {
                // Fall through to error condition
            }
        }
        
        return nil
    }

}

