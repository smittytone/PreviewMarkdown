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
class AppDelegate:  NSObject,
                    NSApplicationDelegate,
                    NSOpenSavePanelDelegate {

    // MARK: - Class UI Properies
    
    @IBOutlet var window: NSWindow!
    @IBOutlet var mainView: NSView!
    @IBOutlet var previewTextView: NSTextView!
    @IBOutlet var previewScrollView: NSScrollView!
    @IBOutlet var modeButton: NSButton!
    @IBOutlet var modeIndicator: NSImageView!


    // MARK: - Private Properies

    private var openDialog: NSOpenPanel? = nil
    private var currentURL: URL? = nil
    private var renderAsDark: Bool = true
    private var renderIndents: Bool = false

    
    // MARK: - Class Lifecycle Functions
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // Set the mode button
        self.modeButton.state = self.renderAsDark ? .on : .off

        // Centre the main window and display
        self.window.center()
        self.window.makeKeyAndOrderFront(self)
        
        var currentlyInLightMode: Bool = true
        if #available(macOS 11.0, *) {
            let appearance: NSAppearance = NSAppearance.currentDrawing()
            currentlyInLightMode = appearance.name == NSAppearance.Name.aqua
        } else {
            let appearance: NSAppearance = NSAppearance.current
            currentlyInLightMode = appearance.name == NSAppearance.Name.aqua
        }

        self.modeIndicator.contentTintColor = currentlyInLightMode ? .systemGreen : .systemPurple
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
        
        if let uti = UTType.init("net.daringfireball.markdown") {
            self.openDialog!.allowedContentTypes = [uti]
        }

        if let uti = UTType.init("net.ia.markdown") {
            self.openDialog!.allowedContentTypes.append(uti)
        }

        if self.openDialog!.runModal() == .OK {
            self.currentURL = self.openDialog!.url
        } else {
            self.currentURL = nil
        }

        self.openDialog!.close()
        self.openDialog = nil
        
        if let openURL = self.currentURL {
            if let possibleError = renderContent(openURL) {
                let errorAlert: NSAlert = NSAlert.init(error: possibleError)
                errorAlert.beginSheetModal(for: self.window)
            }
        }
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
                    guard let common = Common.init(false) else {
                        let errDesc: String = "No file selected to render"
                        reportError = NSError(domain: BUFFOON_CONSTANTS.APP_CODE_PREVIEWER,
                                              code: BUFFOON_CONSTANTS.ERRORS.CODES.BAD_MD_STRING,
                                              userInfo: [NSLocalizedDescriptionKey: errDesc])
                        return reportError
                    }
                    
                    //common.viewWidth = self.previewTextView.frame.width
                    common.settings.doShowLightBackground = !self.renderAsDark
                    common.workingDirectory = (mdUrl.unixpath() as NSString).deletingLastPathComponent

                    if common.settings.doShowMargin {
                        // Add an inset margin to the main text view
                        // TODO What are the best sizes? Want to add a little whitespace to increase
                        //      clarity, but not to make an obvious blank space
                        self.previewTextView.textContainerInset = BUFFOON_CONSTANTS.PREVIEW_MARGIN_SIZE
                    }

                    // Get the key string first
                    let mdAttString: NSAttributedString = common.getAttributedString(mdString[...])

                    if let renderTextStorage: NSTextStorage = self.previewTextView.textStorage {
                        safeMainSync {
                            self.previewTextView.backgroundColor = common.settings.doShowLightBackground ? NSColor.init(white: 1.0, alpha: 0.9) : NSColor.textBackgroundColor
                            self.previewScrollView.scrollerKnobStyle = common.settings.doShowLightBackground ? .dark : .light

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
                                layouter.marginDelta = common.settings.doShowMargin ? BUFFOON_CONSTANTS.PREVIEW_MARGIN_WIDTH : 0.0
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
