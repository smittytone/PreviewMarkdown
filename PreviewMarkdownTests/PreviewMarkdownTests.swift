//
//  PreviewMarkdownTests.swift
//  PreviewMarkdownTests
//
//  Created by Tony Smith on 18/09/2020.
//  Copyright © 2020 Tony Smith. All rights reserved.
//

import XCTest
import AppKit

@testable import PreviewMarkdown
@testable import Previewer


class PreviewMarkdownTests: XCTestCase {

    let appDelegate = NSApplication.shared.delegate as! AppDelegate
    let pvc: PreviewViewController = PreviewViewController()


    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    
    func testProcessSymbols() throws {

        var markdownString = "**&trade; &plusmn; &nbsp;"
        var expectedString = "**™ ±  "
        XCTAssert(processSymbols(markdownString) == expectedString)

        markdownString = "&reg; &copy;"
        expectedString = "® ©"
        XCTAssert(processSymbols(markdownString) == expectedString)

        markdownString = "&sup2; &gt; &trad."
        expectedString = "² > &trad."
        XCTAssert(processSymbols(markdownString) == expectedString)
    }



}
