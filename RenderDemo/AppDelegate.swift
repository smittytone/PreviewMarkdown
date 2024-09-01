//
//  AppDelegate.swift
//  RenderDemo
//
//  Created by Tony Smith on 13/08/2023.
//  Copyright © 2023 Tony Smith. All rights reserved.
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
    @IBOutlet var indentButton: NSButton!


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
        self.indentButton.state = self.renderIndents ? .on : .off

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

        self.common = Common.init(false)
        let possibleError: NSError? = renderContent(self.currentURL)
        if possibleError != nil {
            // Pop up an alert
            let errorAlert: NSAlert = NSAlert.init(error: possibleError!)
            errorAlert.beginSheetModal(for: self.window)
        }
    }


    @IBAction private func doSetIndentCharacter(_ sender: Any) {

        self.renderIndents = self.indentButton.state == .on
        doReRenderFile(self)
    }


    // MARK: - Rendering Functions

    func renderContent(_ fileToRender: URL?) -> NSError? {

        var reportError: NSError? = nil

        do {
            if let yamlUrl: URL = fileToRender {
                self.window.title = yamlUrl.absoluteString

                // Get the file contents as a string
                let data: Data = try Data.init(contentsOf: yamlUrl, options: [.uncached])

                // Get the string's encoding, or fail back to .utf8
                let encoding: String.Encoding = data.stringEncoding ?? .utf8

                if let markdownString: String = String.init(data: data, encoding: encoding) {
                    common.doShowLightBackground = !self.renderAsDark
                    //common.doUseSpecialIndentChar = self.renderIndents
                    common.resetStylesOnModeChange()

                    // Get the key string first
                    let markdownAttString: NSAttributedString = common.getAttributedString(markdownString, false)

                    self.previewTextView.backgroundColor = common.doShowLightBackground ? NSColor.init(white: 1.0, alpha: 0.9) : NSColor.textBackgroundColor
                    self.previewScrollView.scrollerKnobStyle = common.doShowLightBackground ? .dark : .light

                    if let renderTextStorage: NSTextStorage = self.previewTextView.textStorage {
                        renderTextStorage.beginEditing()
                        renderTextStorage.setAttributedString(markdownAttString)
                        renderTextStorage.endEditing()
                        self.previewTextView.needsDisplay = true
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

}

