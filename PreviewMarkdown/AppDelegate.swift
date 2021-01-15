
//  AppDelegate.swift
//  PreviewMarkdown
//
//  Created by Tony Smith on 31/10/2019.
//  Copyright © 2021 Tony Smith. All rights reserved.


import Cocoa
import CoreServices


@NSApplicationMain
class AppDelegate: NSObject,
                   NSApplicationDelegate,
                   URLSessionDelegate,
                   URLSessionDataDelegate {

    // MARK:- Class UI Properies
    // Menu Items Tab
    @IBOutlet var creditMenuPM: NSMenuItem!
    @IBOutlet var creditMenuDiscount: NSMenuItem!
    @IBOutlet var creditMenuQLMarkdown: NSMenuItem!
    @IBOutlet var creditMenuSwiftyMarkdown: NSMenuItem!
    @IBOutlet var creditMenuAcknowlegdments: NSMenuItem!
    @IBOutlet var creditAppStoreRating: NSMenuItem!
    
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
    @IBOutlet weak var codeColourPopup: NSPopUpButton!
    @IBOutlet weak var fontSizeSlider: NSSlider!
    @IBOutlet weak var fontSizeLabel: NSTextField!
    @IBOutlet weak var useLightCheckbox: NSButton!


    // MARK:- Private Properies
    // FROM 1.1.1
    private var feedbackTask: URLSessionTask? = nil

    // FROM 1.2.0 -- stores for preferences
    private var previewFontSize: CGFloat = 16.0
    private var previewCodeColour: Int = 1
    private var previewLinkColour: Int = 2
    private var doShowLightBackground: Bool = false


    // MARK:- Class Lifecycle Functions

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {

        // When the main window closed, shut down the app
        return true
    }


    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // FROM 1.2.0
        // Set application group-level defaults
        registerPreferences()

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
    }


    // MARK:- Action Functions

    @IBAction func doClose(_ sender: Any) {

        // Close the window... which will trigger an app closure
        self.window.close()
    }
    
    
    @IBAction @objc func doShowSites(sender: Any) {
        
        // Open the websites for contributors
        let item: NSMenuItem = sender as! NSMenuItem
        var path: String = "https://smittytone.net/previewmarkdown/index.html"

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
            path = "https://apps.apple.com/gb/app/previewmarkdown/id1492280469?action=write-review"
        }
        
        // Open the selected website
        NSWorkspace.shared.open(URL.init(string:path)!)
    }


    @IBAction func openSysPrefs(sender: Any) {

        // FROM 1.1.0
        // Open the System Preferences app at the Extensions pane
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Extensions.prefPane"))
    }


    @IBAction @objc func showFeedbackWindow(sender: Any?) {

        // FROM 1.1.1
        // Display a window in which the user can submit feedback

        // Reset the UI
        self.connectionProgress.stopAnimation(self)
        self.feedbackText.stringValue = ""

        // Present the window
        if let window = self.window {
            window.beginSheet(self.reportWindow,
                              completionHandler: nil)
        }
    }


    @IBAction @objc func doCancelReportWindow(sender: Any?) {

        // FROM 1.1.1
        // User has clicked 'Cancel', so just close the sheet

        self.connectionProgress.stopAnimation(self)
        self.window!.endSheet(self.reportWindow)
    }


    @IBAction @objc func doSendFeedback(sender: Any?) {

        // FROM 1.1.1
        // User clicked 'Send' so get the message (if there is one) from the text field and send it
        let feedback: String = self.feedbackText.stringValue

        if feedback.count > 0 {
            // Start the connection indicator if it's not already visible
            self.connectionProgress.startAnimation(self)

            // Send the string etc.
            let sysVer: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
            let bundle: Bundle = Bundle.main
            let app: String = bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as! String
            let version: String = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
            let build: String = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as! String
            let userAgent: String = "\(app) \(version) (build \(build)) (macOS \(sysVer.majorVersion).\(sysVer.minorVersion).\(sysVer.patchVersion))"

            let date: Date = Date()
            var dateString = "Unknown"

            let def: DateFormatter = DateFormatter()
            def.locale = Locale(identifier: "en_US_POSIX")
            def.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            def.timeZone = TimeZone(secondsFromGMT: 0)
            dateString = def.string(from: date)

            let dict: NSMutableDictionary = NSMutableDictionary()
            dict.setObject("*FEEDBACK REPORT*\n*DATE* \(dateString))\n*USER AGENT* \(userAgent)\n*FEEDBACK* \(feedback)",
                            forKey: NSString.init(string: "text"))
            dict.setObject(true, forKey: NSString.init(string: "mrkdown"))

            if let url: URL = URL.init(string: MNU_SECRETS.ADDRESS.A + MNU_SECRETS.ADDRESS.B) {
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
                    self.feedbackTask = session.dataTask(with: request)
                    self.feedbackTask?.resume()
                } catch {
                    sendFeedbackError()
                }
            }
        } else {
            self.window!.endSheet(self.reportWindow)
        }
    }

    @IBAction func doShowPreferences(sender: Any?) {

        // FROM 1.2.0
        // Display the Preferences... sheet

        // The suite name is the app group name, set in each extension's entitlements, and the host app's
        if let defaults = UserDefaults(suiteName: MNU_SECRETS.PID + ".suite.previewmarkdown") {
            self.previewFontSize = CGFloat(defaults.float(forKey: "com-bps-previewmarkdown-base-font-size"))
            self.previewCodeColour = defaults.integer(forKey: "com-bps-previewmarkdown-code-colour-index")
            self.previewLinkColour = defaults.integer(forKey: "com-bps-previewmarkdown-link-colour-index")
            self.doShowLightBackground = defaults.bool(forKey: "com-bps-previewmarkdown-do-use-light")
        }

        // Get the menu item index from the stored value
        // NOTE The other values are currently stored as indexes -- should this be the same?
        let options: [CGFloat] = [10.0, 12.0, 14.0, 16.0, 18.0, 24.0, 28.0]
        let index: Int = options.lastIndex(of: self.previewFontSize) ?? 3
        self.fontSizeSlider.floatValue = Float(index)
        self.fontSizeLabel.stringValue = "\(Int(options[index]))pt"
        self.codeColourPopup.selectItem(at: self.previewCodeColour)
        self.useLightCheckbox.state = self.doShowLightBackground ? .on : .off

        // Display the sheet
        if let window = self.window {
            window.beginSheet(self.preferencesWindow,
                              completionHandler: nil)
        }
    }


    @IBAction func doMoveSlider(sender: Any?) {

        // FROM 1.2.0
        let options: [CGFloat] = [10.0, 12.0, 14.0, 16.0, 18.0, 24.0, 28.0]
        let index: Int = Int(self.fontSizeSlider.floatValue)
        self.fontSizeLabel.stringValue = "\(Int(options[index]))pt"
    }


    @IBAction func doClosePreferences(sender: Any?) {

        // FROM 1.2.0
        // Close the Preferences... sheet

        self.window.endSheet(self.preferencesWindow)
    }


    @IBAction func doSavePreferences(sender: Any?) {

        // FROM 1.2.0
        // Close the Preferences... sheet and save the prefs, if they have changed

        if let defaults = UserDefaults(suiteName: MNU_SECRETS.PID + ".suite.previewmarkdown") {
            if self.codeColourPopup.indexOfSelectedItem != self.previewCodeColour {
                defaults.setValue(self.codeColourPopup.indexOfSelectedItem,
                                  forKey: "com-bps-previewmarkdown-code-colour-index")
            }

            let state: Bool = self.useLightCheckbox.state == .on
            if self.doShowLightBackground != state {
                defaults.setValue(state,
                                  forKey: "com-bps-previewmarkdown-do-use-light")
            }

            let options: [CGFloat] = [10.0, 12.0, 14.0, 16.0, 18.0, 24.0, 28.0]
            let newValue: CGFloat = options[Int(self.fontSizeSlider.floatValue)]
            if newValue != self.previewFontSize {
                defaults.setValue(newValue,
                                  forKey: "com-bps-previewmarkdown-base-font-size")
            }

            // Sync any changes
            defaults.synchronize()
        }

        // Remove the sheet now we have the data
        self.window.endSheet(self.preferencesWindow)
    }


    // MARK: - URLSession Delegate Functions

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {

        // Some sort of connection error - report it
        self.connectionProgress.stopAnimation(self)
        sendFeedbackError()
    }


    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {

        // The operation to send the comment completed
        self.connectionProgress.stopAnimation(self)
        if let _ = error {
            // An error took place - report it
            sendFeedbackError()
        } else {
            // The comment was submitted successfully
            let alert: NSAlert = showAlert("Thanks For Your Feedback!",
                                           "Your comments have been received and we’ll take a look at them shortly.")
            alert.beginSheetModal(for: self.reportWindow) { (resp) in
                // Close the feedback window when the modal alert returns
                self.window!.endSheet(self.reportWindow)
            }
        }
    }


    // MARK: - Misc Functions

    func sendFeedbackError() {

        // Present an error message specific to sending feedback
        // This is called from multiple locations: if the initial request can't be created,
        // there was a send failure, or a server error
        let alert: NSAlert = showAlert("Feedback Could Not Be Sent",
                                       "Unfortunately, your comments could not be send at this time. Please try again later.")
        alert.beginSheetModal(for: self.reportWindow,
                              completionHandler: nil)
        
    }


    func showAlert(_ head: String, _ message: String) -> NSAlert {

        // FROM 1.1.1
        // Generic alert presentation
        let alert: NSAlert = NSAlert()
        alert.messageText = head
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        return alert
    }


    func registerPreferences() {

        // FROM 1.2.0
        // Called by the app at launch to register its initial defaults

        if let defaults = UserDefaults(suiteName: MNU_SECRETS.PID + ".suite.previewmarkdown") {
            // Check if each preference value exists -- set if it doesn't
            // Preview base font size
            let previewFontSizeDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-base-font-size")
            if previewFontSizeDefault == nil {
                defaults.setValue(CGFloat(BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE),
                                  forKey: "com-bps-previewmarkdown-base-font-size")
            }

            // Thumbnail view base font size
            let thumbFontSizeDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-thumb-font-size")
            if thumbFontSizeDefault == nil {
                defaults.setValue(CGFloat(BUFFOON_CONSTANTS.BASE_THUMB_FONT_SIZE),
                                  forKey: "com-bps-previewmarkdown-thumb-font-size")
            }

            // Colour of links in the preview
            let linkColourDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-link-colour-index")
            if linkColourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.LINK_COLOUR_INDEX,
                                  forKey: "com-bps-previewmarkdown-link-colour-index")
            }

            // Colour of code blocks in the preview
            let codeColourDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-code-colour-index")
            if codeColourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.CODE_COLOUR_INDEX,
                                  forKey: "com-bps-previewmarkdown-code-colour-index")
            }

            // Use light background even in dark mode
            let useLightDefault: Any? = defaults.object(forKey: "com-bps-previewmarkdown-do-use-light")
            if useLightDefault == nil {
                defaults.setValue(false,
                                  forKey: "com-bps-previewmarkdown-do-use-light")
            }

            // Sync any additions
            defaults.synchronize()
        }

    }

}

