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
    
    override func drawUnderline(forGlyphRange glyphRange: NSRange,
        underlineType underlineVal: NSUnderlineStyle,
        baselineOffset: CGFloat,
        lineFragmentRect lineRect: CGRect,
        lineFragmentGlyphRange lineGlyphRange: NSRange,
        containerOrigin: CGPoint
    ) {
        
        if underlineVal != .double {
            super.drawUnderline(forGlyphRange: glyphRange, 
                                underlineType: underlineVal,
                                baselineOffset: baselineOffset,
                                lineFragmentRect: lineRect,
                                lineFragmentGlyphRange: lineGlyphRange,
                                containerOrigin: containerOrigin)
            return
        }
        
        let firstPosition  = location(forGlyphAt: glyphRange.location).x
        let lastPosition: CGFloat

        if NSMaxRange(glyphRange) < NSMaxRange(lineGlyphRange) {
            lastPosition = location(forGlyphAt: NSMaxRange(glyphRange)).x
        } else {
            lastPosition = lineFragmentUsedRect(
                forGlyphAt: NSMaxRange(glyphRange) - 1,
                effectiveRange: nil).size.width
        }

        var lineRect = lineRect
        let height = lineRect.size.height * 3.5 / 4.0 // replace your under line height
        lineRect.origin.x += firstPosition
        lineRect.size.width = lastPosition - firstPosition
        lineRect.size.height = height
        lineRect.origin.x += containerOrigin.x
        lineRect.origin.y += containerOrigin.y
        lineRect = lineRect.integral.insetBy(dx: 0.5, dy: 0.5)
        
        let path = NSBezierPath.init(roundedRect: lineRect, xRadius: 4.0, yRadius: 4.0)
        path.fill()
    }
}
