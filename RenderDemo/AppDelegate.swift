//
//  AppDelegate.swift
//  RenderDemo
//
//  Created by Tony Smith on 10/07/2023.
//  Copyright © 2024 Tony Smith. All rights reserved.
//

import Cocoa

@main
class AppDelegate:  NSObject,
                    NSApplicationDelegate,
                    NSOpenSavePanelDelegate {

    // MARK: - Class UI Properies
    
    @IBOutlet var window: NSWindow!
    @IBOutlet var mainView: NSView!
    @IBOutlet var previewTextView: NSTextView!
    @IBOutlet var previewScrollView: NSScrollView!
    @IBOutlet var modeButton: NSButton!


    // MARK: - Private Properies

    private var openDialog: NSOpenPanel? = nil
    private var currentURL: URL? = nil
    private var renderAsDark: Bool = true
    private var renderIndents: Bool = false
    private var common: Common = Common.init(false)

    
    // MARK: - Class Lifecycle Functions
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // Set the mode button
        self.modeButton.state = self.renderAsDark ? .on : .off
        
        // Centre the main window and display
        self.window.center()
        self.window.makeKeyAndOrderFront(self)
        
        self.common.viewWidth = self.previewTextView.frame.width
    }
    
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {

        // When the main window closed, shut down the app
        return true
    }


    // MARK: - Action Functions
    
    @IBAction private func doLoadFile(_ sender: Any) {

        self.openDialog = NSOpenPanel.init()
        self.openDialog!.canChooseFiles = true
        self.openDialog!.canChooseDirectories = false
        self.openDialog!.allowsMultipleSelection = false
        self.openDialog!.delegate = self
        self.openDialog!.directoryURL = URL.init(fileURLWithPath: "")

        if self.openDialog!.runModal() == .OK {
            self.currentURL = self.openDialog!.url
            let possibleError: NSError? = renderContent(self.openDialog!.url)
            if possibleError != nil {
                let errorAlert: NSAlert = NSAlert.init(error: possibleError!)
                errorAlert.beginSheetModal(for: self.window)
            }
        }

        self.openDialog = nil
    }
    
    
    @IBAction private func doSwitchMode(_ sender: Any) {

        self.renderAsDark = self.modeButton.state == .on
        doReRenderFile(self)
    }


    @IBAction private func doReRenderFile(_ sender: Any) {

        let possibleError: NSError? = renderContent(self.currentURL)
        if possibleError != nil {
            // Pop up an alert
            let errorAlert: NSAlert = NSAlert.init(error: possibleError!)
            errorAlert.beginSheetModal(for: self.window)
        }
    }


    // MARK: - Rendering Functions
    
    func renderContent(_ fileToRender: URL?) -> NSError? {
        
        var reportError: NSError? = nil

        do {
            if let mdUrl: URL = fileToRender {
                self.window.title = mdUrl.absoluteString

                // Get the file contents as a string
                let data: Data = try Data.init(contentsOf: mdUrl, options: [.uncached])

                // Get the string's encoding, or fail back to .utf8
                let encoding: String.Encoding = data.stringEncoding ?? .utf8

                if let mdString: String = String.init(data: data, encoding: encoding) {
                    self.common.doShowLightBackground = !self.renderAsDark

                    // Get the key string first
                    let mdAttString: NSAttributedString = self.common.getAttributedString(mdString)

                    if let renderTextStorage: NSTextStorage = self.previewTextView.textStorage {
                        safeMainSync {
                            self.previewTextView.backgroundColor = self.common.doShowLightBackground ? NSColor.init(white: 1.0, alpha: 0.9) : NSColor.textBackgroundColor
                            self.previewScrollView.scrollerKnobStyle = self.common.doShowLightBackground ? .dark : .light
                            
                            // Auto-scroll to top of preview
                            self.previewScrollView.contentView.scroll(to: NSMakePoint(0, 0))
                            self.previewScrollView.reflectScrolledClipView(self.previewScrollView.contentView)
                            
                            // We need to access the NSTextView's containter to apply the custom NSLayoutManager
                            if let renderTextContainer: NSTextContainer = self.previewTextView.textContainer {
                                let layouter: Layouter = Layouter()
                                layouter.lozengeColour = NSColor.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
                                renderTextContainer.replaceLayoutManager(layouter)
                            }
                            
                            renderTextStorage.beginEditing()
                            renderTextStorage.setAttributedString(mdAttString)
                            renderTextStorage.endEditing()
                            self.previewTextView.display()
                        }
                        
                        return nil
                    }

                    // We can't access the preview NSTextView's NSTextStorage
                    reportError = setError(BUFFOON_CONSTANTS.ERRORS.CODES.BAD_TS_STRING)
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
            reportError = setError(BUFFOON_CONSTANTS.ERRORS.CODES.FILE_WONT_OPEN)
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
    func setError(_ code: Int) -> NSError {

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
    
    
    /**
     Execute the supplied block on the main thread.
    */
    private func safeMainSync(_ block: @escaping ()->()) {

        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.sync {
                block()
            }
        }
    }

}
