
//  AppDelegate.swift
//  PreviewMarkdown
//
//  Created by Tony Smith on 31/10/2019.
//  Copyright © 2019-20 Tony Smith. All rights reserved.


import Cocoa
import CoreServices


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK:- Class Properies
    // Menu Items Tab
    @IBOutlet var creditMenuPM: NSMenuItem!
    @IBOutlet var creditMenuDiscount: NSMenuItem!
    @IBOutlet var creditMenuQLMarkdown: NSMenuItem!
    @IBOutlet var creditMenuSwiftyMarkdown: NSMenuItem!
    @IBOutlet var creditMenuAcknowlegdments: NSMenuItem!
    
    // Panel Items
    @IBOutlet var versionLabel: NSTextField!
    
    // Windows
    @IBOutlet weak var window: NSWindow!


    // MARK:- Class Lifecycle Functions

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {

        // When the main window closed, shut down the app
        return true
    }


    func applicationDidFinishLaunching(_ notification: Notification) {
        
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
        var path: String = "https://smittytone.github.io/previewmarkdown/index.html"

        // FROM 1.1.0 -- bypass unused items
        if item == self.creditMenuDiscount {
            path = "https://smittytone.github.io/previewmarkdown/index.html#acknowledgements"
        } else if item == self.creditMenuQLMarkdown {
            path = "https://smittytone.github.io/previewmarkdown/index.html#acknowledgements"
        } else if item == self.creditMenuSwiftyMarkdown {
            path = "https://github.com/SimonFairbairn/SwiftyMarkdown"
        } else if item == self.creditMenuAcknowlegdments {
            path = "https://smittytone.github.io/previewmarkdown/index.html#acknowledgements"
        }
        
        // Open the selected website
        NSWorkspace.shared.open(URL.init(string:path)!)
    }


    @IBAction func openSysPrefs(sender: Any) {

        // FROM 1.1.0
        // Open the System Preferences app at the Extensions pane
        //let script = "tell application \"System Preferences\"\nactivate\nreveal pane \"Extensions\"\nend tell"
        let task: Process = Process()
        task.executableURL = URL.init(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", "tell application \"System Preferences\"", "-e", "activate",  "-e", "reveal pane id \"com.apple.preferences.extensions\"", "-e", "set test to id of pane \"com.apple.preferences.extensions\"", "-e", "end tell"]

        // Pipe out the output to avoid putting it in the log
        //let outputPipe = Pipe()
        //task.standardOutput = outputPipe
        //task.standardError = outputPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            // The script exited with an error -- fall through
            print("** \(error)")
        }

        //print(task.terminationStatus)
    }

}

