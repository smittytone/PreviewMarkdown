//
//  SwiftyMarkdownAttributedStringTests.swift
//  SwiftyMarkdownTests
//
//  Created by Simon Fairbairn on 17/12/2019.
//  Copyright © 2019 Voyage Travel Apps. All rights reserved.
//

import XCTest
@testable import SwiftyMarkdown

class SwiftyMarkdownPerformanceTests: XCTestCase {
	
	func testThatFilesAreProcessedQuickly() {
		
		let url = self.resourceURL(for: "test.md")
		
		measure {
			guard let md = SwiftyMarkdown(url: url) else {
				XCTFail("Failed to load file")
				return
			}
			_ = md.attributedString()
		}
		
	}
	
	func testThatStringsAreProcessedQuickly() {
		let string = "SwiftyMarkdown converts Markdown files and strings into `NSAttributedString`s using sensible defaults and a *Swift*-style syntax. It uses **dynamic type** to set the font size correctly with [whatever](https://www.neverendingvoyage.com/) font you'd like to use."
		let md = SwiftyMarkdown(string: string)
		measure {
			_ = md.attributedString(from: string)
		}
	}
	
 	func testThatVeryLongStringsAreProcessedQuickly() {
		let string = "SwiftyMarkdown converts Markdown files and strings into `NSAttributedString`s using sensible defaults and a *Swift*-style syntax. It uses **dynamic type** to set the font size correctly with [whatever](https://www.neverendingvoyage.com/) font you'd like to use. SwiftyMarkdown converts Markdown files and strings into `NSAttributedString`s using sensible defaults and a *Swift*-style syntax. It uses **dynamic type** to set the font size correctly with [whatever](https://www.neverendingvoyage.com/) font you'd like to use. SwiftyMarkdown converts Markdown files and strings into `NSAttributedString`s using sensible defaults and a *Swift*-style syntax. It uses **dynamic type** to set the font size correctly with [whatever](https://www.neverendingvoyage.com/) font you'd like to use. SwiftyMarkdown converts Markdown files and strings into `NSAttributedString`s using sensible defaults and a *Swift*-style syntax. It uses **dynamic type** to set the font size correctly with [whatever](https://www.neverendingvoyage.com/) font you'd like to use. SwiftyMarkdown converts Markdown files and strings into `NSAttributedString`s using sensible defaults and a *Swift*-style syntax. It uses **dynamic type** to set the font size correctly with [whatever](https://www.neverendingvoyage.com/) font you'd like to use. SwiftyMarkdown converts Markdown files and strings into `NSAttributedString`s using sensible defaults and a *Swift*-style syntax. It uses **dynamic type** to set the font size correctly with [whatever](https://www.neverendingvoyage.com/) font you'd like to use."
		let md = SwiftyMarkdown(string: string)
		measure {
			_ = md.attributedString(from: string)
		}
	}
	
}
