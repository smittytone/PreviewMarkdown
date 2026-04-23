//
//  AppDelegate.swift
//  RenderDemo
//
//  Created by Tony Smith on 10/07/2023.
//  Copyright © 2024 Tony Smith. All rights reserved.
//

import AppKit
import UniformTypeIdentifiers


@main
@MainActor
class AppDelegate:  NSObject,
                    NSApplicationDelegate,
                    NSOpenSavePanelDelegate {

    // MARK: - Class UI Properies
    
    @IBOutlet var window: NSWindow!
    @IBOutlet var mainView: NSView!
    @IBOutlet var previewTextView: NSTextView!
    @IBOutlet var previewScrollView: NSScrollView!
    @IBOutlet var modeButton: NSButton!
    //@IBOutlet var modeIndicator: NSImageView!
    @IBOutlet weak var reloadButton: NSButton!
    @IBOutlet weak var reloadMenuItem: NSMenuItem!
    @IBOutlet weak var progress: NSProgressIndicator!
    @IBOutlet weak var thumbButton: NSButton!


    // MARK: - Private Properies

    private var _currentURL: URL? = nil
    private var currentDirURL: URL? = nil
    private var renderAsDark: Bool = true
    private var renderIndents: Bool = false

    private var currentURL: URL? {
        get {
            return self._currentURL
        }
        set(new) {
            self._currentURL = new
            self.reloadButton.isEnabled = new != nil
            self.reloadMenuItem.isEnabled = new != nil
        }
    }


    // MARK: - Class Lifecycle Functions
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // Set the mode button
        self.modeButton.state = self.renderAsDark ? .on : .off
        self.reloadButton.isEnabled = false
        self.reloadMenuItem.isEnabled = false
        self.progress.isHidden = true

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.doRender),
                                               name: NSNotification.Name(rawValue: "com.bps.rd.load"),
                                               object: nil)

        // Centre the main window and display
        self.window.center()
        self.window.makeKeyAndOrderFront(self)
    }
    
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {

        // When the main window closed, shut down the app
        return true
    }


    // MARK: - Action Functions
    
    @IBAction private func doLoadFile(_ sender: Any) {

        let openPanel = NSOpenPanel()
        openPanel.delegate = self
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        if self.currentDirURL != nil {
            openPanel.directoryURL = self.currentDirURL!
        } else {
            openPanel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        }

        openPanel.beginSheetModal(for: self.window) { (response) in
            if response == .OK {
                self.currentURL = openPanel.url
                self.currentDirURL = openPanel.directoryURL
                NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "com.bps.rd.load")))
            }
        }
    }
    

    @IBAction
    private func doReloadFile(_ sender: Any) {

        doRender(Notification(name: Notification.Name(rawValue: "")))
    }


    @IBAction private func doSwitchMode(_ sender: Any) {

        self.renderAsDark = self.modeButton.state == .on
        doReRenderFile(self)
    }


    @IBAction
    private func doReRenderFile(_ sender: Any) {

        wenderFile()
    }


    @objc
    func wenderFile() {

        Task { @MainActor in
            self.progress.isHidden = false
            self.progress.startAnimation(self)

            let possibleError: NSError? = await renderContent(self.currentURL)
            self.progress.stopAnimation(self)

            if possibleError != nil {
                // Pop up an alert
                let errorAlert: NSAlert = NSAlert(error: possibleError!)
                await errorAlert.beginSheetModal(for: self.window)
            }
        }
    }


    // MARK: - Rendering Functions

    @objc
    private func doRender(_ note: Notification) {

        self.progress.isHidden = false
        self.progress.startAnimation(self)
        let _ = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.wenderFile), userInfo: nil, repeats: false)

    }


    @MainActor
    func renderContent(_ fileToRender: URL?) async -> NSError? {

        var reportError: NSError? = nil
        
        do {
            if let mdUrl: URL = fileToRender {
                self.window.title = mdUrl.absoluteString

                // Get the file contents as a string
                let data = try Data.init(contentsOf: mdUrl, options: [.uncached])

                // Get the string's encoding, or fail back to .utf8
                let encoding: String.Encoding = data.stringEncoding ?? .utf8

                if let mdString: String = String.init(data: data, encoding: encoding) {
                    guard let common = Common.init(forThumbnail: false) else {
                        let errDesc: String = "No file selected to render"
                        reportError = NSError(domain: BUFFOON_CONSTANTS.APP_CODE_PREVIEWER,
                                              code: BUFFOON_CONSTANTS.ERRORS.CODES.BAD_MD_STRING,
                                              userInfo: [NSLocalizedDescriptionKey: errDesc])
                        return reportError
                    }
                    
                    //common.viewWidth = self.previewTextView.frame.width
                    common.settings.doReverseMode = !self.renderAsDark
                    common.workingDirectory = (mdUrl.unixpath() as NSString).deletingLastPathComponent

                    if common.settings.doShowMargin {
                        // Add an inset margin to the main text view
                        // TODO What are the best sizes? Want to add a little whitespace to increase
                        //      clarity, but not to make an obvious blank space
                        self.previewTextView.textContainerInset = BUFFOON_CONSTANTS.PREVIEW_SIZE.PREVIEW_MARGIN_SIZE
                    }

                    // Get the key string first
                    let mdAttString: NSAttributedString = common.getAttributedString(mdString[...])

                    if let renderTextStorage: NSTextStorage = self.previewTextView.textStorage {
                        self.previewTextView.backgroundColor = common.settings.doReverseMode ? NSColor.init(white: 1.0, alpha: 0.9) : NSColor.textBackgroundColor
                        self.previewScrollView.scrollerKnobStyle = common.settings.doReverseMode ? .dark : .light

                        // Correct way to set a text view's link colouring, etc. - and have it stick
                        self.previewTextView.linkTextAttributes = [NSAttributedString.Key.foregroundColor: common.linkColor,
                                                                  NSAttributedString.Key.cursor: NSCursor.pointingHand ]

                        // Auto-scroll to top of preview
                        self.previewScrollView.contentView.scroll(to: NSMakePoint(0, 0))
                        self.previewScrollView.reflectScrolledClipView(self.previewScrollView.contentView)

                        // We need to access the NSTextView's containter to apply the custom NSLayoutManager
                        if let renderTextContainer: NSTextContainer = self.previewTextView.textContainer {
                            let layouter = PMLayouter()
                            layouter.fontSize = common.settings.fontSize
                            layouter.marginDelta = common.settings.doShowMargin ? BUFFOON_CONSTANTS.PREVIEW_SIZE.PREVIEW_MARGIN_WIDTH : 0.0
                            renderTextContainer.replaceLayoutManager(layouter)
                        }

                        renderTextStorage.beginEditing()
                        renderTextStorage.setAttributedString(mdAttString)
                        renderTextStorage.endEditing()
                        self.previewTextView.display()
                        return nil
                    }

                    // We can't access the preview NSTextView's NSTextStorage
                    reportError = makeError(BUFFOON_CONSTANTS.ERRORS.CODES.BAD_TS_STRING)
                } else {
                    // We couldn't convert to data to a valid encoding
                    let errDesc: String = "\(BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_TS_STRING) \(encoding)"
                    reportError = NSError(domain: BUFFOON_CONSTANTS.APP_CODE_PREVIEWER,
                                          code: BUFFOON_CONSTANTS.ERRORS.CODES.BAD_MD_STRING,
                                          userInfo: [NSLocalizedDescriptionKey: errDesc])
                }
            } else {
                // No file selected
                let errDesc: String = "No file selected to render"
                reportError = NSError(domain: BUFFOON_CONSTANTS.APP_CODE_PREVIEWER,
                                      code: BUFFOON_CONSTANTS.ERRORS.CODES.BAD_MD_STRING,
                                      userInfo: [NSLocalizedDescriptionKey: errDesc])
            }
        } catch {
            // We couldn't read the file so set an appropriate error to report back
            reportError = makeError(BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN)
        }
        
        return reportError
    }
    
    
    /**
     Generate an NSError for an internal error, specified by its code.

     Codes are listed in `Constants.swift`

     - Parameters:
        - code: The internal error code.

     - Returns: The described error as an NSError.
     */
    func makeError(_ code: Int) -> NSError {

        var errDesc: String

        switch(code) {
        case BUFFOON_CONSTANTS.ERRORS.CODES.FILE_INACCESSIBLE:
            errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.FILE_INACCESSIBLE
        case BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN:
            errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.FILE_WONT_OPEN
        case BUFFOON_CONSTANTS.ERRORS.CODES.BAD_TS_STRING:
            errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_TS_STRING
        case BUFFOON_CONSTANTS.ERRORS.CODES.BAD_MD_STRING:
            errDesc = BUFFOON_CONSTANTS.ERRORS.MESSAGES.BAD_MD_STRING
        default:
            errDesc = "UNKNOWN ERROR"
        }

        return NSError(domain: BUFFOON_CONSTANTS.APP_CODE_PREVIEWER,
                       code: code,
                       userInfo: [NSLocalizedDescriptionKey: errDesc])
    }

}
