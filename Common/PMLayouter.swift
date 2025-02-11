//
//  PMLayouter.swift
//  PreviewMarkdown
//
//  Created by Tony Smith on 05/09/2024.
//  Copyright © 2025 Tony Smith. All rights reserved.
//

import Foundation
import AppKit



class PMLayouter: NSLayoutManager {
    
    // The background of KDB lozenges
    var lozengeColour: NSColor?     = nil
    var fontSize: CGFloat           = 13.0
    var lineSpacing: CGFloat        = 1.0
    
    
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
        
        // Get the bounding rect of the glyphs themselves and pad left and right
        // with the pad being font size dependent
        var lozengeRect = lineRect
        lozengeRect = self.boundingRect(forGlyphRange: glyphRange, in: self.textContainers[0])
        lozengeRect.origin.x -= (self.fontSize > 18 ? 4.0 : 2.0)
        lozengeRect.size.width += (self.fontSize > 18 ? 8.0 : 4.0)
        
        // Allow for larger line spacing values 'stretching' the rect
        lozengeRect.size.height = lozengeRect.size.height / self.lineSpacing
        
        // Draw and fill rounded path over lozenge
        let path = NSBezierPath.init(roundedRect: lozengeRect, xRadius: 4.0, yRadius: 4.0)
        if let colour: NSColor = self.lozengeColour {
            colour.setFill()
        } else {
            // Default to dark grey CHANGE
            NSColor.green.setFill()
        }
        
        path.fill()
    }
}
