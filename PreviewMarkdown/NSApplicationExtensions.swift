//
//  NSApplicationExtensions.swift
//  PreviewApps
//
//  Created by Tony Smith on 11/10/2024.
//  Copyright © 2025 Tony Smith. All rights reserved.
//

import Foundation
import AppKit


extension NSApplication {
    
    /**
     Determine if the Mac is currently presenting in light mode.
     
     - Returns `true` if light mode is enabled, otherwise `false`.
     */
    func isMacInLightMode() -> Bool {
        
        return (self.effectiveAppearance.name.rawValue == "NSAppearanceNameAqua")
    }
}
