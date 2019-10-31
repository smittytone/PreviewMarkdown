//
//  AppDelegate.swift
//  PreviewMarkdown
//
//  Created by Tony Smith on 31/10/2019.
//  Copyright © 2019 Tony Smith. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    
    @IBOutlet weak var window: NSWindow!


    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {

        // When the main window closed, shut down the app
        return true
    }


    @IBAction func doClose(_ sender: Any) {

        // Close the window... which will trigger an app closure
        self.window.close()
    }
}

