//
//  PreviewMarkdownTests.swift
//  PreviewMarkdownTests
//
//  Created by Tony Smith on 18/09/2020.
//  Copyright © 2021 Tony Smith. All rights reserved.
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


    func testProcessCode() throws {

        let markdownString = """
            This is some text.

            ```
            This is some code.
            ```
            More text.
            """

        let expectedString = """
            This is some text.

                This is some code.
            More text.
            """

        //print(processCodeTags(markdownString))
        XCTAssert(processCodeTags(markdownString) == expectedString)

    }


    func testConvertSpaces() throws {

        var markdownString = """
            This is some text.
            1. Tab
                * Tab
                    - Tab
            \t* Tab2
            Done
            """

        var expectedString = """
            This is some text.
            1. Tab
            \t* Tab
            \t\t- Tab
            \t* Tab2
            Done
            """

        //print(convertSpaces(markdownString))
        XCTAssert(convertSpaces(markdownString) == expectedString)

        markdownString = "    11. Something"
        expectedString = "\t11. Something"
        XCTAssert(convertSpaces(markdownString) == expectedString)
    }


}
