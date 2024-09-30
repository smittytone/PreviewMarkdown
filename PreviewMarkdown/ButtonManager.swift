//
//  ButtonManager.swift
//  PreviewMarkdown
//
//  Created by Tony Smith on 30/09/2024.
//  Copyright © 2024 Tony Smith. All rights reserved.
//

import Foundation
import AppKit


class ButtonManager {
    
    var buttons: [NSButton] = []
    var tabIndices: [Int] = [0, 1, 2]
    var tabView: NSTabView? = nil
    var window: NSWindow? = nil
    var currentIndex: Int = 0
    
    
    func currentButton() -> NSButton {
        
        return self.buttons[self.currentIndex]
    }
    
    
    func buttonClicked(_ button: NSButton) {
        
        if button == self.buttons[currentIndex] {
            self.buttons[currentIndex].state = .on
            return
        }
        
        guard let tv: NSTabView = self.tabView else {
            return
        }
        
        guard let wd: NSWindow = self.window else {
            return
        }
        
        if let nextIndex: Int = self.buttons.firstIndex(of: button) {
            // Select the required tab
            tv.selectTabViewItem(at: nextIndex)
            self.currentIndex = nextIndex
            
            // Update the window title if we need to
           switch nextIndex {
                case 1:
                    wd.title = "Settings"
                case 2:
                    wd.title = "Feedback"
                default:
                   wd.title = "PreviewMarkdown 2"
            }
            
            // Enable the current tab's button and disable the rest
            for i in 0..<self.buttons.count {
                if i != nextIndex {
                    self.buttons[i].state = .off
                } else {
                    self.buttons[i].state = .on
                }
            }
        }
    }
    
    
    func programmaticallyClickButton(_ button: NSButton) {
        
        buttonClicked(button)
    }
    
    
    func programmaticallyClickButton(at index: Int) {
        
        if index < 0 || index >= self.buttons.count {
            return
        }
        
        buttonClicked(self.buttons[index])
    }
}


