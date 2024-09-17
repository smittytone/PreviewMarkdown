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
    var lozengeColour: NSColor? = nil
    
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
        let firstPosition = location(forGlyphAt: glyphRange.location).x
        
        // Watch out for line-spanning
        let lastPosition: CGFloat
        if NSMaxRange(glyphRange) < NSMaxRange(lineGlyphRange) {
            lastPosition = location(forGlyphAt: NSMaxRange(glyphRange)).x
        } else {
            lastPosition = lineFragmentUsedRect(forGlyphAt: NSMaxRange(glyphRange) - 1, effectiveRange: nil).size.width
        }

        var lozengeRect = lineRect
        let height = lozengeRect.size.height * 0.6
        // Pad with 1.0 pixels either side
        lozengeRect.origin.x += firstPosition - 1.0
        lozengeRect.size.width = lastPosition - firstPosition + 2.0
        lozengeRect.size.height = height
        lozengeRect.origin.x += containerOrigin.x
        lozengeRect.origin.y += containerOrigin.y - 4.0 // + baselineOffset
        lozengeRect = lozengeRect.integral //.insetBy(dx: 0.5, dy: 0.5)
        
        // Draw and fill rounded path over lozenge
        let path = NSBezierPath.init(roundedRect: lozengeRect, xRadius: 4.0, yRadius: 4.0)
        if let colour: NSColor = self.lozengeColour {
            colour.setFill()
        } else {
            // Default to dark grey CHANGE
            NSColor.darkGray.setFill()
        }
        
        path.fill()
    }
}