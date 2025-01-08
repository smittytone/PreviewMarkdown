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
    
    func isMacInLightMode() -> Bool {
        
        return (self.effectiveAppearance.name.rawValue == "NSAppearanceNameAqua")
    }
}
