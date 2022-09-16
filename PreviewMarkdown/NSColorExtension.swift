/*
 *  NSColorExtension.swift
 *  PreviewApps
 *
 *  Created by Tony Smith on 18/06/2021.
 *  Copyright © 2022 Tony Smith. All rights reserved.
 */


import Foundation
import Cocoa


extension NSColor {

    /**
     Convert a colour's internal representation into an RGB+A hex string.
     */
    var hexString: String {
        
        guard let rgbColour = usingColorSpace(.sRGB) else {
            return BUFFOON_CONSTANTS.CODE_COLOUR_HEX
        }
        
        let red: Int = Int(round(rgbColour.redComponent * 0xFF))
        let green: Int = Int(round(rgbColour.greenComponent * 0xFF))
        let blue: Int = Int(round(rgbColour.blueComponent * 0xFF))
        let alpha: Int = Int(round(rgbColour.alphaComponent * 0xFF))
        
        let hexString: NSString = NSString(format: "%02X%02X%02X%02X", red, green, blue, alpha)
        return hexString as String
    }
    
    
    /**
     Generate a new NSColor from an RGB+A hex string..

     - Parameters:
        - hex: The RGB+A hex string, eg.`AABBCCFF`.

     - Returns: An NSColor instance.
     */
    static func hexToColour(_ hex: String) -> NSColor {
        
        if hex.count != 8 {
            return NSColor.red
        }
        
        func hexToFloat(_ hs: String) -> CGFloat {
            return CGFloat(UInt8(hs, radix: 16) ?? 0)
        }
        
        let hexns: NSString = hex as NSString
        let red: CGFloat = hexToFloat(hexns.substring(with: NSRange.init(location: 0, length: 2))) / 255
        let green: CGFloat = hexToFloat(hexns.substring(with: NSRange.init(location: 2, length: 2))) / 255
        let blue: CGFloat = hexToFloat(hexns.substring(with: NSRange.init(location: 4, length: 2))) / 255
        let alpha: CGFloat = hexToFloat(hexns.substring(with: NSRange.init(location: 6, length: 2))) / 255
        return NSColor.init(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}
