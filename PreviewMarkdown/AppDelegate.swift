/*
 *  AppDelegate.swift
 *  PreviewMarkdown
 *
 *  Created by Tony Smith on 31/10/2019.
 *  Copyright © 2021 Tony Smith. All rights reserved.
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
    @IBOutlet var creditMenuPM: NSMenuItem!
    @IBOutlet var creditMenuDiscount: NSMenuItem!
    @IBOutlet var creditMenuQLMarkdown: NSMenuItem!
    @IBOutlet var creditMenuSwiftyMarkdown: NSMenuItem!
    @IBOutlet var creditMenuAcknowlegdments: NSMenuItem!
    @IBOutlet var creditAppStoreRating: NSMenuItem!
    // FROM 1.3.0
    @IBOutlet var creditMenuYamlSwift: NSMenuItem!
    // FROM 1.3.1
    @IBOutlet var creditMenuOthersPreviewYaml: NSMenuItem!
    // FROM 1.3.2
    @IBOutlet var creditMenuOthersPreviewCode: NSMenuItem!
    
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
    
    // FROM 1.2.0
    // What's New Sheet
    @IBOutlet weak var whatsNewWindow: NSWindow!
    @IBOutlet weak var whatsNewWebView: WKWebView!
    
    // FROM 1.4.0
    @IBOutlet weak var bodyStylePopup: NSPopUpButton!
    @IBOutlet weak var codeStylePopup: NSPopUpButton!

    // MARK:- Private Properies
    // FROM 1.1.1
    private var feedbackTask: URLSessionTask? = nil

    // FROM 1.2.0 -- stores for preferences
    //private var previewCodeColour: Int = BUFFOON_CONSTANTS.CODE_COLOUR_INDEX
    //private var previewLinkColour: Int = BUFFOON_CONSTANTS.LINK_COLOUR_INDEX
    //private var previewCodeFont: Int = BUFFOON_CONSTANTS.CODE_FONT_INDEX
    //private var previewBodyFont: Int = BUFFOON_CONSTANTS.BODY_FONT_INDEX
    internal var whatsNewNav: WKNavigation? = nil
    private  var previewFontSize: CGFloat = CGFloat(BUFFOON_CONSTANTS.PREVIEW_FONT_SIZE)
    private  var doShowLightBackground: Bool = false
    private  var doShowTag: Bool = false
    private  var localMarkdownUTI: String = "NONE"
    
    // FROM 1.3.0
    private var doShowFrontMatter: Bool = false

    // FROM 1.3.1
    private var appSuiteName: String = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME
    private var feedbackPath: String = MNU_SECRETS.ADDRESS.A
    
    // FROM 1.4.0
    private  var codeColourHex: String = BUFFOON_CONSTANTS.CODE_COLOUR_HEX
    private  var headColourHex: String = BUFFOON_CONSTANTS.HEAD_COLOUR_HEX
    private  var bodyFontName: String = BUFFOON_CONSTANTS.BODY_FONT_NAME
    private  var codeFontName: String = BUFFOON_CONSTANTS.CODE_FONT_NAME
    internal var bodyFonts: [PMFont] = []
    internal var codeFonts: [PMFont] = []

    
    // MARK:- Class Lifecycle Functions

    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // FROM 1.4.0
        let q: DispatchQueue = DispatchQueue.init(label: "com.bps.previewmarkdown.async-queue")
        q.async {
            self.asyncGetFonts()
        }

        // FROM 1.2.0
        // Set application group-level defaults
        registerPreferences()
        
        // FROM 1.2.0
        // Get the local UTI for markdown files
        self.localMarkdownUTI = getLocalFileUTI(getLocalFileUTI(BUFFOON_CONSTANTS.SAMPLE_UTI_FILE))

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
        
        // Close the window... which will trigger an app closure
        self.window.close()
    }
    
    
    @IBAction @objc private func doShowSites(sender: Any) {
        
        // Open the websites for contributors
        let item: NSMenuItem = sender as! NSMenuItem
        var path: String = BUFFOON_CONSTANTS.URL_MAIN

        // FROM 1.1.0 -- bypass unused items
        if item == self.creditMenuDiscount {
            path += "#acknowledgements"
        } else if item == self.creditMenuQLMarkdown {
            path += "#acknowledgements"
        } else if item == self.creditMenuSwiftyMarkdown {
            path = "https://github.com/SimonFairbairn/SwiftyMarkdown"
        } else if item == self.creditMenuAcknowlegdments {
            path += "#acknowledgements"
        } else if item == self.creditAppStoreRating {
            path = BUFFOON_CONSTANTS.APP_STORE + "?action=write-review"
        } else if item == self.creditMenuYamlSwift {
            // FROM 1.3.0
            path = "https://github.com/behrang/YamlSwift"
        } else if item == self.creditMenuPM {
            // FROM 1.3.0
            path += "#how-to-use-previewmarkdown"
        } else if item == self.creditMenuOthersPreviewYaml {
            // FROM 1.3.1
            path = "https://apps.apple.com/us/app/previewyaml/id1564574724?ls=1"
        } else if item == self.creditMenuOthersPreviewCode {
            path = "https://apps.apple.com/us/app/previewcode/id1571797683?ls=1"
        }
        
        // Open the selected website
        NSWorkspace.shared.open(URL.init(string:path)!)
    }


    @IBAction private func openSysPrefs(sender: Any) {

        // FROM 1.1.0
        // Open the System Preferences app at the Extensions pane
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Extensions.prefPane"))
    }

    
    // MARK: Reporting Functions
    
    @IBAction @objc private func showFeedbackWindow(sender: Any?) {

        // FROM 1.1.1
        // Display a window in which the user can submit feedback

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
            } else {
                // Report the error
                sendFeedbackError()
            }
        } else {
            // No feedback, so close the sheet
            self.window.endSheet(self.reportWindow)
        }
        
        // NOTE sheet closes asynchronously unless there was no feedback to send
    }
    
    
    private func sendFeedback(_ feedback: String) -> URLSessionTask? {
        
        // FROM 1.2.0
        // Break out into separate function
        
        // Send the string etc.
        // First get the data we need to build the user agent string
        let userAgent: String = getUserAgentForFeedback()
        let endPoint: String = MNU_SECRETS.ADDRESS.B
        
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

    
    // MARK: Preferences Functions
    
    /**
     Initialise and display the **Preferences** sheet.
     
     FROM 1.2.0

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction private func doShowPreferences(sender: Any) {

        // The suite name is the app group name, set in each extension's entitlements, and the host app's
        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            //self.previewCodeColour = defaults.integer(forKey: "com-bps-previewmarkdown-code-colour-index")
            //self.previewLinkColour = defaults.integer(forKey: "com-bps-previewmarkdown-link-colour-index")
            //self.previewCodeFont = defaults.integer(forKey: "com-bps-previewmarkdown-code-font-index")
            //self.previewBodyFont = defaults.integer(forKey: "com-bps-previewmarkdown-body-font-index")
            
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
        }

        // Get the menu item index from the stored value
        // NOTE The other values are currently stored as indexes -- should this be the same?
        //self.codeColourPopup.selectItem(at: self.previewCodeColour)
        //self.codeFontPopup.selectItem(at: self.previewCodeFont)
        //self.bodyFontPopup.selectItem(at: self.previewBodyFont)
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
        let b = NSDate.timeIntervalSinceReferenceDate

        self.codeFontPopup.removeAllItems()
        self.bodyFontPopup.removeAllItems()
        //var selectedItem: NSMenuItem? = nil

        //var bodyFonts: [String] = []

        /*
        let bodyFonts: [String] = fm.availableFonts
        var codeFonts: [String] = []
        if let fonts: [String] = fm.availableFontNames(with: .fixedPitchFontMask) {
            codeFonts = fonts
        }
        
        // Set the code font list of monospace fonts
        for font in codeFonts {
            if font.hasPrefix(".") || font == "AppleColorEmoji" || font.hasPrefix("AppleBraille") {
                continue
            }
            
            // Set the font's display name...
            var fontDisplayName: String? = nil
            if let namedFont: NSFont = NSFont.init(name: font, size: 0) {
                fontDisplayName = namedFont.displayName
            } else {
                fontDisplayName = font.replacingOccurrences(of: "-", with: " ")
            }
            
            // ...and add it to the popup
            self.codeFontPopup.addItem(withTitle: fontDisplayName!)
            
            // Retain the font's PostScript name for use later
            if let addedMenuItem: NSMenuItem = self.codeFontPopup.lastItem {
                addedMenuItem.representedObject = font
                
                if font == self.codeFontName {
                    selectedFont = addedMenuItem
                }
            }
        }
        
        if selectedFont != nil {
            self.codeFontPopup.select(selectedFont!)
        }
        
        // Set the code font list of regular (and light/medium) fonts
        for font in bodyFonts {
            // Reject fonts by name -- where are these?!?
            if font.hasPrefix(".") {
                continue
            }
            
            // Reject fonts by type
            // Apparently these look-ups are expensive
            let fd: NSFontDescriptor = NSFontDescriptor.init(name: font, size: 10.0)
            if fd.symbolicTraits.contains(.italic) ||
                fd.symbolicTraits.contains(.bold) ||
                fd.symbolicTraits.contains(.monoSpace) ||
                fd.symbolicTraits.contains(.classSymbolic) //||
                //fd.symbolicTraits.contains(.vertical) ||
                //fd.symbolicTraits.contains(.classScripts)
                {
                continue
            }
            
            // Set the font's display name...
            var fontDisplayName: String? = nil //font.replacingOccurrences(of: "-", with: " ")
            
            if let namedFont: NSFont = NSFont.init(descriptor: fd, size: 10.0) {
                fontDisplayName = namedFont.displayName
            } else {
                fontDisplayName = font.replacingOccurrences(of: "-", with: " ")
            }
            
            // ...make sure it still doesn't start with a period...
            if fontDisplayName!.hasPrefix(".") {
                continue
            }
            
            // ...and add it to the popup
            self.bodyFontPopup.addItem(withTitle: fontDisplayName!)
            
            // Retain the font's PostScript name for use later
            if let addedMenuItem: NSMenuItem = self.bodyFontPopup.lastItem {
                addedMenuItem.representedObject = font
                
                if font == self.bodyFontName {
                    selectedFont = addedMenuItem
                }
            }
        }

        if selectedFont != nil {
            self.bodyFontPopup.select(selectedFont!)
        }

        let families: [String] = fm.availableFontFamilies
        print("fm.availableFontFamilies: \((NSDate.timeIntervalSinceReferenceDate - b) * 1000)ms")
        for family in families {
            if !family.hasPrefix(".") {
                if let fonts: [[Any]] = fm.availableMembers(ofFontFamily: family) {
                    for font in fonts {
                        let pname: String = font[0] as! String
                        let traits: UInt = font[3] as! UInt

                        if mono & traits != 0 {
                            if pname.hasPrefix("AppleBra") || pname == "AppleColorEmoji" {
                                break
                            }

                            codeFonts.append(pname)
                            let aFont: NSFont? = NSFont.init(name: pname, size: 0)
                            codeFonts.append(aFont!.displayName ?? pname)
                            continue
                        }

                        if traits & bold == 0 && traits & ital == 0 && traits & symb == 0 {
                            bodyFonts.append(pname)
                            let aFont: NSFont? = NSFont.init(name: pname, size: 0)
                            bodyFonts.append(aFont!.displayName ?? pname)
                        }
                    }
                }
            }
        }

        print(" fm.availableMembers: \((NSDate.timeIntervalSinceReferenceDate - b) * 1000)ms")
         */

        for i: Int in 0..<self.bodyFonts.count {
            let font: PMFont = self.bodyFonts[i]
            self.bodyFontPopup.addItem(withTitle: font.displayName)
        }

        self.bodyStylePopup.isEnabled = false
        selectFontByPostScriptName(self.bodyFontName, true)


        for i: Int in 0..<self.codeFonts.count {
            let font: PMFont = self.codeFonts[i]
            self.codeFontPopup.addItem(withTitle: font.displayName)
        }

        self.codeStylePopup.isEnabled = false
        selectFontByPostScriptName(self.codeFontName, false)

        print("\((NSDate.timeIntervalSinceReferenceDate - b) * 1000)ms")
        
        // Display the sheet
        self.window.beginSheet(self.preferencesWindow, completionHandler: nil)
    }


    private func setStylePopup(_ isBody: Bool = true) {

        let selectedFamily: String = isBody ? self.bodyFontPopup.titleOfSelectedItem! : self.codeFontPopup.titleOfSelectedItem!
        let familyList: [PMFont] = isBody ? self.bodyFonts : self.codeFonts
        let targetPopup: NSPopUpButton = isBody ? self.bodyStylePopup : self.codeStylePopup
        targetPopup.removeAllItems()

        for family: PMFont in familyList {
            if selectedFamily == family.displayName {
                if let styles: [PMFont] = family.styles {
                    targetPopup.isEnabled = true
                    for style: PMFont in styles {
                        targetPopup.addItem(withTitle: style.styleName)
                    }
                }
            }
        }
    }

    
    private func selectFontByPostScriptName(_ psname: String, _ isBody: Bool) {

        let familyList: [PMFont] = isBody ? self.bodyFonts : self.codeFonts
        let targetPopup: NSPopUpButton = isBody ? self.bodyFontPopup : self.codeFontPopup

        for family: PMFont in familyList {
            if let styles: [PMFont] = family.styles {
                for style: PMFont in styles {
                    if style.postScriptName == psname {
                        targetPopup.selectItem(withTitle: family.displayName)
                        setStylePopup(isBody)
                    }
                }
            }
        }
    }


    private func getPostScriptName(_ isBody: Bool) -> String? {

        let familyList: [PMFont] = isBody ? self.bodyFonts : self.codeFonts
        let fontPopup: NSPopUpButton = isBody ? self.bodyFontPopup : self.codeFontPopup
        let stylePopup: NSPopUpButton = isBody ? self.bodyStylePopup : self.codeStylePopup

        if let selectedFont: String = fontPopup.titleOfSelectedItem {
            let selectedStyle: Int = stylePopup.indexOfSelectedItem

            for family: PMFont in familyList {
                if family.displayName == selectedFont {
                    if let styles: [PMFont] = family.styles {
                        let font: PMFont = styles[selectedStyle]
                        return font.postScriptName
                    }
                }
            }
        }

        return nil
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
    }


    /**
     Close the **Preferences** sheet and save any settings that have changed.
     
     FROM 1.2.0
     
     - Parameters:
        - sender: The source of the action.
     */
    @IBAction private func doSavePreferences(sender: Any) {

        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            /* REMOVE IN 1.4.0
            if self.codeColourPopup.indexOfSelectedItem != self.previewCodeColour {
                defaults.setValue(self.codeColourPopup.indexOfSelectedItem,
                                  forKey: "com-bps-previewmarkdown-code-colour-index")
            }
            
            if self.codeFontPopup.indexOfSelectedItem != self.previewCodeFont {
                defaults.setValue(self.codeFontPopup.indexOfSelectedItem,
                                  forKey: "com-bps-previewmarkdown-code-font-index")
            }

            if self.bodyFontPopup.indexOfSelectedItem != self.previewBodyFont {
                defaults.setValue(self.bodyFontPopup.indexOfSelectedItem,
                                  forKey: "com-bps-previewmarkdown-body-font-index")
            }
             */
            
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

            // Sync any changes
            defaults.synchronize()
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
    }

    
    // MARK: What's New Functions
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
                let key: String = "com-bps-previewmarkdown-do-show-whats-new-" + getVersion()
                doShowSheet = defaults.bool(forKey: key)
            }
        }
      
        // Configure and show the sheet: first, get the folder path
        if doShowSheet {
            let htmlFolderPath = Bundle.main.resourcePath! + "/new"
            
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

            defaults.synchronize()
        }
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
            
            /* REMOVED IN 1.4.0
            // Colour of links in the preview, stored as in integer array index, not currently used
            // Reason: see Common.swift
            let linkColourDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-link-colour-index")
            if linkColourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.LINK_COLOUR_INDEX,
                                  forKey: "com-bps-previewmarkdown-link-colour-index")
            }
            
            // REMOVED IN 1.4.0
            // Colour of code blocks in the preview, stored as in integer array index
            // Default: 0 (purple)
            let codeColourDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-code-colour-index")
            if codeColourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.CODE_COLOUR_INDEX,
                                  forKey: "com-bps-previewmarkdown-code-colour-index")
            }
            
            // REMOVED IN 1.4.0
            // Font for body blocks in the preview, stored as in integer array index
            // Default: 0 (System)
            let bodyFontDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-body-font-index")
            if bodyFontDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.BODY_FONT_INDEX,
                                  forKey: "com-bps-previewmarkdown-body-font-index")
            }
            
            // REMOVED IN 1.4.0
            // Font for code blocks in the preview, stored as in integer array index
            // Default: 0 (Andale Mono)
            let codeFontDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-code-font-index")
            if codeFontDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.CODE_FONT_INDEX,
                                  forKey: "com-bps-previewmarkdown-code-font-index")
            }
            */
            
            // Use light background even in dark mode, stored as a bool
            // Default: false
            let useLightDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-do-use-light")
            if useLightDefault == nil {
                defaults.setValue(false,
                                  forKey: "com-bps-previewmarkdown-do-use-light")
            }

            // Show the file identity ('tag') on Finder thumbnails
            // Default: true
            let showTagDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-do-show-tag")
            if showTagDefault == nil {
                defaults.setValue(true,
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

            // Sync any additions
            defaults.synchronize()
        }

    }

}

