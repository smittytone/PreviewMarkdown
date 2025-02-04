/*
 *  Extensions.swift
 *  Code common to Previewer and Thumbnailer: Swift Extensions
 *
 *  Created by Tony Smith on 17/09/2024.
 *  Copyright © 2025 Tony Smith. All rights reserved.
 */

import Foundation
import AppKit


extension Data {
    
    /**
     Get the encoding of the string formed from data.

     - Returns The string's encoding or nil.
    */
    var stringEncoding: String.Encoding? {
        var nss: NSString? = nil
        guard case let rawValue = NSString.stringEncoding(for: self,
                                                          encodingOptions: nil,
                                                          convertedString: &nss,
                                                          usedLossyConversion: nil), rawValue != 0 else { return nil }
        return .init(rawValue: rawValue)
    }
}


extension NSMutableAttributedString {
    
    /**
     Swap the paragraph style in all of the attributes of an NSMutableAttributedString
     with the supplied new paragraph style.
     
     - Parameters:
        - paraStyle: The injected NSParagraphStyle.
     */
    func addParaStyle(with paraStyle: NSParagraphStyle) {

        beginEditing()
        self.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: self.length)) { (value, range, stop) in
            if let _ = value as? NSParagraphStyle {
                addAttribute(.paragraphStyle, value: paraStyle, range: range)
            }
        }
        endEditing()
    }
}


extension Scanner {
    
    /**
     Look ahead and return the next character in the sequence without
     altering the current location of the scanner.
     
     - Parameters
        - in: The string being scanned.
     
     - Returns The next character as a string.
     */
    func getNextCharacter(in outer: String) -> String {
        
        let string: NSString = self.string as NSString
        let idx: Int = self.currentIndex.utf16Offset(in: outer)
        let nextChar: String = string.substring(with: NSMakeRange(idx, 1))
        return nextChar
    }
    
    
    func skipNextCharacter() {
        
        /**
         Step over the next character.
         */
        self.currentIndex = self.string.index(after: self.currentIndex)
    }
}


extension CGFloat {
    
    /**
     Determine if the instance is near enough the specified value as makes no odds.
     
     - Parameters
        - value: The float value we're comparing the instance to.
     
     - Returns `true` if the values are proximate, otherwise `false`.
     */
    func isClose(to value: CGFloat) -> Bool {

        let absA: CGFloat = abs(self)
        let absB: CGFloat = abs(value)
        let diff: CGFloat = abs(self - value)
        
        if self == value {
            return true
        } else if self == .zero || value == .zero || (absA + absB) < Self.leastNormalMagnitude {
            return diff < Self.ulpOfOne * Self.leastNormalMagnitude
        } else {
            return (diff / Self.minimum(CGFloat(absA + absB), Self.greatestFiniteMagnitude)) < .ulpOfOne
        }
    }
}


extension NSColor {
    
    /**
     Class function to return an NSColor object that matches the colour supplied as a RGBA hex value.
     
     - Paramaters:
        - colourValue: The colour as a hex string `RRGGBBAA`, eg `FF00AA88`.
     */
    static func colourFromHexString(_ colourValue: String) -> NSColor {
        
        var colourString: String = colourValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if (colourString.hasPrefix("#")) {
            // The colour is defined by a hex value
            colourString = (colourString as NSString).substring(from: 1)
        }
        
        // Colours in hex strings have 3, 6 or 8 (6 + alpha) values
        if colourString.count != 8 && colourString.count != 6 && colourString.count != 3 {
            return NSColor.gray
        }

        var r: UInt64 = 0, g: UInt64 = 0, b: UInt64 = 0, a: UInt64 = 0
        var divisor: CGFloat
        var alpha: CGFloat = 1.0

        if colourString.count == 6 || colourString.count == 8 {
            // Decode a six-character hex string
            let rString: String = (colourString as NSString).substring(to: 2)
            let gString: String = ((colourString as NSString).substring(from: 2) as NSString).substring(to: 2)
            let bString: String = ((colourString as NSString).substring(from: 4) as NSString).substring(to: 2)

            Scanner(string: rString).scanHexInt64(&r)
            Scanner(string: gString).scanHexInt64(&g)
            Scanner(string: bString).scanHexInt64(&b)

            divisor = 255.0
            
            if colourString.count == 8 {
                // Decode the eight-character hex string's alpha value
                let aString: String = ((colourString as NSString).substring(from: 6) as NSString).substring(to: 2)
                Scanner(string: aString).scanHexInt64(&a)
                alpha = CGFloat(a) / divisor
            }
        } else {
            // Decode a three-character hex string
            let rString: String = (colourString as NSString).substring(to: 1)
            let gString: String = ((colourString as NSString).substring(from: 1) as NSString).substring(to: 1)
            let bString: String = ((colourString as NSString).substring(from: 2) as NSString).substring(to: 1)

            Scanner(string: rString).scanHexInt64(&r)
            Scanner(string: gString).scanHexInt64(&g)
            Scanner(string: bString).scanHexInt64(&b)
            divisor = 15.0
        }

        return NSColor(red: CGFloat(r) / divisor, green: CGFloat(g) / divisor, blue: CGFloat(b) / divisor, alpha: alpha)
    }
}


extension URL {
    
    func unixpath() -> String {
        
        return self.absoluteString.replacingOccurrences(of: "file://", with: "")
    }
}
