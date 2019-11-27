
//  AppDelegate.swift
//  PreviewMarkdown
//
//  Created by Tony Smith on 31/10/2019.
//  Copyright © 2019 Tony Smith. All rights reserved.


import Cocoa


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    // Menu Items Tab
    @IBOutlet var creditMenuPM: NSMenuItem!
    @IBOutlet var creditMenuDiscount: NSMenuItem!
    @IBOutlet var creditMenuQLMarkdown: NSMenuItem!
    @IBOutlet var creditMenuSwiftyMarkdown: NSMenuItem!
    
    // Windows
    @IBOutlet weak var window: NSWindow!


    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {

        // When the main window closed, shut down the app
        return true
    }


    func applicationDidFinishLaunching(_ notification: Notification) {

        // FROM 1.0.2
        // Centre window and display
        window.center()
        window.makeKeyAndOrderFront(self)
    }

    
    @IBAction func doClose(_ sender: Any) {

        // Close the window... which will trigger an app closure
        self.window.close()
    }
    
    
    @IBAction @objc func doShowSites(sender: Any) {
        
        // Open the websites for contributors
        let item: NSMenuItem = sender as! NSMenuItem
        var path: String = "https://smittytone.github.io/index.html"
        
        if item == self.creditMenuDiscount {
            path = "https://github.com/Orc/discount"
        } else if item == self.creditMenuQLMarkdown {
            path = "https://github.com/toland/qlmarkdown"
        } else if item == self.creditMenuSwiftyMarkdown {
            path = "https://github.com/SimonFairbairn/SwiftyMarkdown"
        }
        
        // Open the selected website
        NSWorkspace.shared.open(URL.init(string:path)!)
    }
}

