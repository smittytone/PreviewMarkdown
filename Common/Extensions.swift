/*
 *  Extensions.swift
 *  Code common to Previewer and Thumbnailer: Swift Extensions
 *
 *  Created by Tony Smith on 17/09/2024.
 *  Copyright © 2024 Tony Smith. All rights reserved.
 */

import Foundation
import AppKit


/**
Get the encoding of the string formed from data.

- Returns: The string's encoding or nil.
*/

extension Data {
    
    var stringEncoding: String.Encoding? {
        var nss: NSString? = nil
        guard case let rawValue = NSString.stringEncoding(for: self,
                                                          encodingOptions: nil,
                                                          convertedString: &nss,
                                                          usedLossyConversion: nil), rawValue != 0 else { return nil }
        return .init(rawValue: rawValue)
    }
}


/**
Swap the paragraph style in all of the attributes of
 an NSMutableAttributedString.

- Parameters:
 - paraStyle: The injected NSParagraphStyle.
*/
extension NSMutableAttributedString {
    
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
