//
//  PreviewMarkdown2Tests.swift
//  PreviewMarkdownTests
//
//  Created by Tony Smith on 16/01/2025.
//  Copyright © 2025 Tony Smith. All rights reserved.
//

import XCTest
import AppKit

@testable import PreviewMarkdown


final class PreviewMarkdown2Tests: XCTestCase {
    
    let appDelegate = NSApplication.shared.delegate as! AppDelegate
    let pvc: PreviewViewController = PreviewViewController()
    let cwm = Common.init()
    let pms: PMStyler = PMStyler()
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testProcessCheckboxes() throws {
        
        // Negative cases
        var markdownString = "[p]"
        _ = pms.render(markdownString)
        XCTAssert(pms.tokenString == "[p]")
        
        markdownString = "[x]()"
        _ = pms.render(markdownString)
        XCTAssert(pms.tokenString == "[x]()")
        
        // Positive cases
        markdownString = "[X]"
        _ = pms.render(markdownString)
        XCTAssert(pms.tokenString == "✅")
        
        markdownString = "[x]"
        _ = pms.render(markdownString)
        XCTAssert(pms.tokenString == "✅")
        
        markdownString = "[]"
        _ = pms.render(markdownString)
        XCTAssert(pms.tokenString == "❎")
        
        markdownString = "[ ]"
        _ = pms.render(markdownString)
        XCTAssert(pms.tokenString == "❎")
    }

}
