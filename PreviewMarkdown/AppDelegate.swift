/*
 *  AppDelegate.swift
 *  PreviewMarkdown
 *
 *  Created by Tony Smith on 31/10/2019.
 *  Copyright © 2025 Tony Smith. All rights reserved.
 */


import Cocoa
import CoreServices
import WebKit


@NSApplicationMain
final class AppDelegate: NSResponder,
                         NSApplicationDelegate,
                         URLSessionDelegate,
                         URLSessionDataDelegate,
                         WKNavigationDelegate,
                         NSControlTextEditingDelegate,
                         NSTextFieldDelegate,
                         NSWindowDelegate,
                         NSMenuDelegate {

    // MARK: - Class UI Properies

    // Menu Items
    @IBOutlet var helpMenu: NSMenuItem!
    @IBOutlet var helpMenuMarkdownIt: NSMenuItem!
    @IBOutlet var helpMenuHighlightjs: NSMenuItem!
    @IBOutlet var helpMenuYamlSwift: NSMenuItem!
    @IBOutlet var helpMenuOthersPreviewCode: NSMenuItem!
    @IBOutlet var helpMenuOthersPreviewJson: NSMenuItem!

    @IBOutlet var helpMenuOnlineHelp: NSMenuItem!
    @IBOutlet var helpMenuReportBug: NSMenuItem!
    @IBOutlet var helpMenuAppStoreRating: NSMenuItem!
    @IBOutlet var helpMenuWhatsNew: NSMenuItem!

    @IBOutlet var mainMenu: NSMenu!
    @IBOutlet var mainMenuSettings: NSMenuItem!
    @IBOutlet var mainMenuResetFinder: NSMenuItem!
    
    // Window
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var infoButton: NSButton!
    @IBOutlet weak var settingsButton: NSButton!
    @IBOutlet weak var feedbackButton: NSButton!
    @IBOutlet weak var mainTabView: NSTabView!

    // Window > Info Tab Items
    @IBOutlet var versionLabel: NSTextField!
    @IBOutlet var infoLabel: NSTextField!
    
    // Window > Settings Tab Items
    @IBOutlet weak var fontSizeSlider: NSSlider!
    @IBOutlet weak var fontSizeLabel: NSTextField!
    @IBOutlet weak var useLightCheckbox: NSButton!
    @IBOutlet weak var showFrontMatterCheckbox: NSButton!
    @IBOutlet weak var headColourWell: NSColorWell!
    @IBOutlet weak var bodyFontPopup: NSPopUpButton!
    @IBOutlet weak var bodyStylePopup: NSPopUpButton!
    @IBOutlet weak var codeFontPopup: NSPopUpButton!
    @IBOutlet weak var codeStylePopup: NSPopUpButton!
    @IBOutlet weak var lineSpacingPopup: NSPopUpButton!
    @IBOutlet weak var colourSelectionPopup: NSPopUpButton!
    @IBOutlet weak var applyButton: NSButton!
    // FROM 2.1.0
    @IBOutlet weak var showMarginCheckbox: NSButton!
    // FROM 2.3.0
    @IBOutlet weak var useLightSwitch: NSSwitch!
    @IBOutlet weak var showFrontMatterSwitch: NSSwitch!
    @IBOutlet weak var showMarginSwitch: NSSwitch!

    // Window > Feedback Tab Items
    @IBOutlet weak var feedbackText: NSTextField!
    @IBOutlet weak var connectionProgress: NSProgressIndicator!
    @IBOutlet weak var messageSizeLabel: NSTextField!
    @IBOutlet weak var messageSendButton: NSButton!

    // What's New Sheet
    @IBOutlet weak var whatsNewWindow: NSWindow!
    @IBOutlet weak var whatsNewWebView: WKWebView!

    // FROM 2.3.0
    // Advanced Settings Sheet
    @IBOutlet weak var advancedSettingsSheet: NSWindow!
    @IBOutlet weak var applyAdvancedButton: NSButton!
    @IBOutlet weak var previewSizeAdvancedPopup: NSPopUpButton!
    @IBOutlet weak var tintTumbnailsAdvancedSwitch: NSSwitch!
    @IBOutlet weak var tintTumbnailsAdvancedLabel: NSTextField!
    @IBOutlet weak var previewMarginSizeText: NSTextField!
    @IBOutlet weak var previewMarginRangeText: NSTextField!


    // MARK: - Public Properties

    var localMarkdownUTI: String = "NONE"


    // MARK: - Private Properies

    internal var feedbackTask: URLSessionTask? = nil
    internal var whatsNewNav: WKNavigation? = nil
    internal var bodyFonts: [PMFont] = []
    internal var codeFonts: [PMFont] = []

    /*
     Replace the following string with your own team ID. This is used to
     identify the app suite and so share preferences set by the main app with
     the previewer and thumbnailer extensions.
     */
    internal var appSuiteName: String = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME
    
    // FROM 2.0.0
    private  var tabManager: PMTabManager = PMTabManager()
    internal var hasSentFeedback: Bool = false
    internal var initialLoadDone: Bool = false
    internal let defaultSettings: PMSettings = PMSettings()
    internal var currentSettings: PMSettings = PMSettings()


    // MARK: - Class Lifecycle Functions

    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // FROM 1.4.0
        // Pre-load fonts in a separate thread
        // NOTE This ultimately calls `loadSettings()` which we delay until after the fonts
        //      have loaded asynchronously because they reference loaded fonts.
        let dq: DispatchQueue = DispatchQueue(label: "com.bps.previewmarkdown.async-queue")
        dq.async {
            self.asyncGetFonts()
        }
        
        // FROM 1.2.0
        // Set application group-level defaults
        defaultSettings.registerSettings(self.appSuiteName, getVersion())

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
        let dummyHelpMenu: NSMenu = NSMenu(title: "Dummy")
        let theApp = NSApplication.shared
        theApp.helpMenu = dummyHelpMenu
        
        // FROM 2.0.0
        // Configure the tab manager
        self.tabManager.parent = self
        self.tabManager.buttons.append(self.infoButton)
        self.tabManager.buttons.append(self.settingsButton)
        self.tabManager.buttons.append(self.feedbackButton)
        self.infoButton.toolTip = "About PreviewMarkdown 2"
        self.settingsButton.toolTip = "Set preview styles and content"
        self.feedbackButton.toolTip = "Send feedback to the developer"
        self.infoButton.alphaValue = 1.0
        self.settingsButton.alphaValue = 1.0
        self.feedbackButton.alphaValue = 1.0
        
        // Add callback closures, one per tab, to the tab manager
        self.tabManager.callbacks.append(nil)   // Info tab
        self.tabManager.callbacks.append {      // Settings tab
            self.willShowSettingsPage()
        }
        self.tabManager.callbacks.append {
            self.willShowFeedbackPage()         // Feedback tab
        }
        
        // Clear the Feedback tab
        // NOTE Don't initialise the Settings tab here too:
        //      It must happen after we've got a list of fonts
        initialiseFeedback()
        
        // FROM 2.0.0
        // Register our Markdown to HTML service
        NSApplication.shared.servicesProvider = HTMLServiceProvider()
        NSUpdateDynamicServices()
        
        // FROM 1.2.0
        // Show 'What's New' if we need to
        // (and set up the WKWebView: no elasticity, horizontal scroller)
        // NOTE Has to take place at the end of the function
        doShowWhatsNew(self)

        // FROM 2.0.0
        self.mainMenuResetFinder.isHidden = true

        // FROM 2.3.0
        self.previewMarginSizeText.delegate = self
        self.previewMarginRangeText.stringValue = "Valid range \(BUFFOON_CONSTANTS.PREVIEW_SIZE.PREVIEW_MARGIN_WIDTH_MIN)-\(BUFFOON_CONSTANTS.PREVIEW_SIZE.PREVIEW_MARGIN_WIDTH_MAX)" 

        // Show the main window
        setInfoText()
        self.window.delegate = self
        self.window.center()
        self.window.makeKeyAndOrderFront(self)

        self.showMarginCheckbox.isHidden = true
        self.showFrontMatterCheckbox.isHidden = true
        self.useLightCheckbox.isHidden = true
    }


    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {

        // When the main window closed, shut down the app
        return true
    }


    // MARK: - Action Functions

    @IBAction
    private func doClose(_ sender: Any) {

        //FROM 2.0.0
        closeBasics()
        closeSettings()
    }


    /**
     Close sheets and perform other general close-related tasks.
     
     FROM 2.0.0
     */
    internal func closeBasics() {
        
        // FROM 1.3.0
        // Reset the QL thumbnail cache... just in case (don't think this does anything)
        _ = runProcess(app: "/usr/bin/qlmanage", with: ["-r", "cache"])
        
        // Close the What's New sheet if it's open
        if self.whatsNewWindow.isVisible {
            self.whatsNewWindow.close()
        }
    }


    /**
     Handle a settings-change call to action, if there is one, and either bail (to allow the user
     to save the settings) or move on to the feedback check.
     
     FROM 2.0.0
     */
    internal func closeSettings() {
        
        // Are there any unsaved changes to the settings?
        if checkSettingsOnQuit() {
            let alert: NSAlert = showAlert("You have unsaved settings",
                                           "Do you wish to cancel and save or change them, or quit the app anyway?",
                                           false)
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Cancel")
            alert.beginSheetModal(for: self.window) { (response: NSApplication.ModalResponse) in
                if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                    // The user clicked 'Quit': now check for feedback changes
                    self.closeFeedback()
                }
            }
            
            // Exit the close process to allow the user to save their changed settings
            return
        }
        
        // Move on to the next phase: the feedback check
        closeFeedback()
    }


    /**
     Handle a feedback-unsent call to action, if one is needed, and either bail (to all the user
     to send the feedback) or close the main window.
     
     FROM 2.0.0
     */
    internal func closeFeedback() {
        
        // Does the feeback page contain text? If so let the user know
        if self.feedbackText.stringValue.count > 0 && !self.hasSentFeedback {
            let alert: NSAlert = showAlert("You have unsent feedback",
                                           "Do you wish to cancel and send it, or quit the app anyway?",
                                           false)
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Cancel")
            alert.beginSheetModal(for: self.window) { (response: NSApplication.ModalResponse) in
                if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                    // The user clicked 'Quit'
                    self.window.close()
                }
            }
            
            // Exit the close process to allow the user to send their entered feedback
            return
        }

        // No feedback text to send/ignore so close the window which will trigger an app closure
        self.window.close()
    }


    /**
     Open the websites for contributors, etc.
     */
    @IBAction @objc private func doShowSites(sender: Any) {
        
        let item: NSMenuItem = sender as! NSMenuItem
        var path: String = BUFFOON_CONSTANTS.URL_MAIN
        
        if item == self.helpMenuMarkdownIt {
            path = "https://github.com/markdown-it/markdown-it"
        } else if item == self.helpMenuHighlightjs {
            // FROM 2.0.0
            path = "https://github.com/highlightjs/highlight.js"
        } else if item == self.helpMenuYamlSwift {
            path = "https://github.com/behrang/YamlSwift"
        } else if item == self.helpMenuAppStoreRating {
            path = BUFFOON_CONSTANTS.APP_STORE_URLS.PM + "?action=write-review"
        } else if item == self.helpMenuOnlineHelp {
            path += "#how-to-use-previewmarkdown"
        } else if item == self.helpMenuOthersPreviewCode {
            path = BUFFOON_CONSTANTS.APP_STORE_URLS.PC
        } else if item == self.helpMenuOthersPreviewJson {
            path = BUFFOON_CONSTANTS.APP_STORE_URLS.PJ
        }
        
        // Open the selected website
        NSWorkspace.shared.open(URL(string:path)!)
    }


    /**
     Alternative route to help.
     
     FROM 1.5.0
     */
    @IBAction
    private func doShowPrefsHelp(sender: Any) {

        let path: String = BUFFOON_CONSTANTS.URL_MAIN + "#customize-the-preview"
        NSWorkspace.shared.open(URL(string:path)!)
    }


    /**
     Open the System Preferences app at the Extensions pane.
     FROM 1.1.0
     */
    @IBAction
    @objc
    private func doOpenSysPrefs(sender: Any) {

       NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Extensions.prefPane"))
    }


    @IBAction
    private func doInitiateFinderReset(sender: Any) {

        // FROM 1.5.0
        warnUserAboutReset()
    }


    @IBAction
    private func doSwitchTab(sender: NSButton) {

        // FROM 2.0.0
        self.tabManager.buttonClicked(sender)
    }


    @IBAction
    private func doShowSettings(sender: Any) {

        // FROM 2.0.0
        self.tabManager.programmaticallyClickButton(at: 1)
    }


    @IBAction
    private func doShowFeedback(sender: Any) {

        // FROM 2.0.0
        self.tabManager.programmaticallyClickButton(at: 2)
    }


    // MARK: - Window Set Up Functions

    /**
     Create and display the information text label. This is done programmatically
     because we're using an NSAttributedString rather than a plain string.
     */
    private func setInfoText() {
        
        // Set the attributes
        let bodyAtts: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13.0),
            .foregroundColor: NSColor.labelColor
        ]
        
        let boldAtts : [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13.0, weight: .bold),
            .foregroundColor: NSColor.labelColor
        ]
        
        let infoText: NSMutableAttributedString = NSMutableAttributedString(string: "You need only run this app once, to register its Markdown Previewer and Markdown Thumbnailer application extensions with macOS. You can then manage these extensions in ", attributes: bodyAtts)
        let boldText: NSAttributedString = NSAttributedString(string: "System Settings > Extensions > Quick Look", attributes: boldAtts)
        infoText.append(boldText)
        infoText.append(NSAttributedString(string: ".\n\nCases where previews cannot be rendered can usually be resolved by logging out of your Mac, logging in again and running this app once more.", attributes: bodyAtts))
        self.infoLabel.attributedStringValue = infoText
    }
}
