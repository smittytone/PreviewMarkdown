//
//  PreviewMarkdownTests.swift
//  PreviewMarkdownTests
//
//  Created by Tony Smith on 18/09/2020.
//  Copyright © 2024 Tony Smith. All rights reserved.
//

import XCTest
import AppKit

@testable import PreviewMarkdown
@testable import Previewer


class PreviewMarkdownTests: XCTestCase {

    let appDelegate = NSApplication.shared.delegate as! AppDelegate
    let pvc: PreviewViewController = PreviewViewController()
    let cmn: Common = Common(false)


    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }


    func testProcessSymbols() throws {

        var markdownString = "**&trade; &plusmn; &nbsp;"
        var expectedString = "**™ ±  "
        XCTAssert(cmn.processSymbols(markdownString) == expectedString)

        markdownString = "&reg; &copy;"
        expectedString = "® ©"
        XCTAssert(cmn.processSymbols(markdownString) == expectedString)

        markdownString = "&sup2; &gt; &trad."
        expectedString = "² > &trad."
        XCTAssert(cmn.processSymbols(markdownString) == expectedString)
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
        XCTAssert(cmn.processCodeTags(markdownString) == expectedString)
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
        XCTAssert(cmn.convertSpaces(markdownString) == expectedString)

        markdownString = "    11. Something"
        expectedString = "\t11. Something"
        XCTAssert(cmn.convertSpaces(markdownString) == expectedString)
    }

    
    func testProcessCheckboxes() throws {
        
        // Negative cases
        var markdownString = "[p]"
        XCTAssert(cmn.processCheckboxes(markdownString) == "[p]")
        
        markdownString = "[x]()"
        XCTAssert(cmn.processCheckboxes(markdownString) == "[x]()")
        
        // Positive cases
        markdownString = "[X]"
        XCTAssert(cmn.processCheckboxes(markdownString) == "✅")
        
        markdownString = "[x]"
        XCTAssert(cmn.processCheckboxes(markdownString) == "✅")
        
        markdownString = "[]"
        XCTAssert(cmn.processCheckboxes(markdownString) == "❎")
        
        markdownString = "[ ]"
        XCTAssert(cmn.processCheckboxes(markdownString) == "❎")
    }
    
    
    func testGetFrontMatter() throws {
        
        var markdownString = """
            ---
            title: ASCII
            description: A macOS tool to help you design glyphs for 8x8 LED matrix displays
            slug: ascii
            logo: true
            preview: images/ascii/preview.png
            ---
            # Next
            """

        var expectedString = """
            title: ASCII
            description: A macOS tool to help you design glyphs for 8x8 LED matrix displays
            slug: ascii
            logo: true
            preview: images/ascii/preview.png

            """
        XCTAssert(cmn.getFrontMatter(markdownString, #"^(-)+"#) == expectedString)
        
        markdownString = """
            ------------
            title: ASCII
            description: A macOS tool to help you design glyphs for 8x8 LED matrix displays
            slug: ascii
            logo: true
            preview: images/ascii/preview.png
            ------------
            # Next
            """
        
        XCTAssert(cmn.getFrontMatter(markdownString, #"^(-)+"#) == expectedString)
        
        markdownString = """
            +++
            title: ASCII
            description: A macOS tool to help you design glyphs for 8x8 LED matrix displays
            slug: ascii
            logo: true
            preview: images/ascii/preview.png
            +++
            # Next
            """
        
        XCTAssert(cmn.getFrontMatter(markdownString, #"^(\+)+"#) == expectedString)
        
        markdownString = """
            
            
            
            
            ------------
            title: ASCII
            description: A macOS tool to help you design glyphs for 8x8 LED matrix displays
            slug: ascii
            logo: true
            preview: images/ascii/preview.png
            ------------
            # Next
            """
        
        XCTAssert(cmn.getFrontMatter(markdownString, #"^(-)+"#) == expectedString)
        
        markdownString = """
            # Next
            """
        
        expectedString = ""
        
        XCTAssert(cmn.getFrontMatter(markdownString, #"^(-)+"#) == expectedString)
    }
}
