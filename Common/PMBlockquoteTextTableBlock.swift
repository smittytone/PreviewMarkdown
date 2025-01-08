//
//  BlockquoteTextBlock.swift
//  PreviewMarkdown
//
//  Created by Tony Smith on 15/10/2024.
//  Copyright © 2024 Tony Smith. All rights reserved.
//

import Foundation
import AppKit

class BlockquoteTextBlock: NSTextTableBlock {
    
    override func drawBackground(withFrame frameRect: NSRect, in controlView: NSView, characterRange charRange: NSRange, layoutManager: NSLayoutManager) {
        
        let backBezier: NSBezierPath = NSBezierPath.init(roundedRect: frameRect, xRadius: 16.0, yRadius: 16.0)
        NSColor.red.setFill()
        backBezier.fill()
    }
}
