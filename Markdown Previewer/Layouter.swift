//
//  Layouter.swift
//  PreviewMarkdown
//
//  Created by Tony Smith on 05/09/2024.
//  Copyright © 2024 Tony Smith. All rights reserved.
//

import Foundation
import AppKit



class Layouter: NSLayoutManager {
    
    // The background of KDB lozenges
    var keyboardColour: NSColor? = nil
    
    // Override this function to hijack double-line drawing and replace it with
    // a lozenge. We use this for <kdb>...</kdb> tags in PreviewMarkdown.
    override func drawUnderline(forGlyphRange glyphRange: NSRange,
                                underlineType underlineVal: NSUnderlineStyle,
                                baselineOffset: CGFloat,
                                lineFragmentRect lineRect: CGRect,
                                lineFragmentGlyphRange lineGlyphRange: NSRange,
                                containerOrigin: CGPoint) {
        
        // If the text is underlined in any way other than `.double`, fall back
        // to the parent class' underline drawing method and exit.
        if underlineVal != .double {
            super.drawUnderline(forGlyphRange: glyphRange,
                                underlineType: underlineVal,
                                baselineOffset: baselineOffset,
                                lineFragmentRect: lineRect,
                                lineFragmentGlyphRange: lineGlyphRange,
                                containerOrigin: containerOrigin)
            return
        }
        
        // Calculate the rect we will draw in place of the double underline
        let firstPosition  = location(forGlyphAt: glyphRange.location).x
        
        let lastPosition: CGFloat
        if NSMaxRange(glyphRange) < NSMaxRange(lineGlyphRange) {
            lastPosition = location(forGlyphAt: NSMaxRange(glyphRange)).x
        } else {
            lastPosition = lineFragmentUsedRect(forGlyphAt: NSMaxRange(glyphRange) - 1, effectiveRange: nil).size.width
        }

        var lineRect = lineRect
        let height = lineRect.size.height * 0.45
        // Pad with 1.0 pixels either side
        lineRect.origin.x += firstPosition - 1.0
        lineRect.size.width = lastPosition - firstPosition + 2.0
        lineRect.size.height = height
        lineRect.origin.x += containerOrigin.x
        lineRect.origin.y += containerOrigin.y
        //lineRect = lineRect.integral.insetBy(dx: 0.5, dy: 0.5)
        
        let path = NSBezierPath.init(roundedRect: lineRect, xRadius: 4.0, yRadius: 4.0)
        if let colour: NSColor = self.keyboardColour {
            colour.setFill()
        }
        
        // Fill the rounded rectangle
        path.fill()
    }
}
