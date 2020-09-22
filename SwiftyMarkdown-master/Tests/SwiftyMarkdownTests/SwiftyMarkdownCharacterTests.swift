//
//  SwiftyMarkdownCharacterTests.swift
//  SwiftyMarkdownTests
//
//  Created by Simon Fairbairn on 17/12/2019.
//  Copyright © 2019 Voyage Travel Apps. All rights reserved.
//

@testable import SwiftyMarkdown
import XCTest

class SwiftyMarkdownStylingTests: SwiftyMarkdownCharacterTests {
	
	func off_testIsolatedCase() {
		
		challenge = TokenTest(input: "*\\***\\****b*\\***\\****\\", output: "***b***\\", tokens : [
			Token(type: .string, inputString: "*", characterStyles: [CharacterStyle.italic]),
			Token(type: .string, inputString: "*b**", characterStyles: [CharacterStyle.bold, CharacterStyle.italic]),
			Token(type: .string, inputString: "\\", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		return
		
		challenge = TokenTest(input: """
		An asterisk: *
		Line break
		""", output: """
		An asterisk: *
		Line break
		""", tokens: [
			Token(type: .string, inputString: "An asterisk: *", characterStyles: []),
			Token(type: .string, inputString: "Line break", characterStyles: [])
		])
		results = self.attempt(challenge)
		XCTAssertEqual(results.stringTokens.count, challenge.tokens.count )
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		return
			
			challenge = TokenTest(input: "A [referenced link][link]\n[link]: https://www.neverendingvoyage.com/", output: "A referenced link", tokens: [
				Token(type: .string, inputString: "A ", characterStyles: []),
				Token(type: .string, inputString: "referenced link", characterStyles: [CharacterStyle.link])
			])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		if results.links.count == 1 {
			XCTAssertEqual(results.links[0].metadataStrings.first, "https://www.neverendingvoyage.com/")
		} else {
			XCTFail("Incorrect link count. Expecting 1, found \(results.links.count)")
		}
		
		
		
		challenge = TokenTest(input: "A [referenced link][link]\n[notLink]: https://www.neverendingvoyage.com/", output: "A [referenced link][link]", tokens: [
			Token(type: .string, inputString: "A [referenced link][link]", characterStyles: [])
		])
		results = self.attempt(challenge, rules: [.links, .images, .referencedLinks])
		XCTAssertEqual(results.attributedString.string, challenge.output)
		XCTAssertEqual(results.links.count, 0)
		
	}
	
	func testThatBoldTraitsAreRecognised() {
		challenge = TokenTest(input: "**A bold string**", output: "A bold string",  tokens: [
			Token(type: .string, inputString: "A bold string", characterStyles: [CharacterStyle.bold])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "A string with a **bold** word", output: "A string with a bold word",  tokens: [
			Token(type: .string, inputString: "A string with a ", characterStyles: []),
			Token(type: .string, inputString: "bold", characterStyles: [CharacterStyle.bold]),
			Token(type: .string, inputString: " word", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "\\*\\*A normal string\\*\\*", output: "**A normal string**", tokens: [
			Token(type: .string, inputString: "**A normal string**", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "\\\\*\\*A normal \\\\ string\\*\\*", output: "\\**A normal \\\\ string**", tokens: [
			Token(type: .string, inputString: "\\**A normal \\\\ string**", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "A string with double \\*\\*escaped\\*\\* asterisks", output: "A string with double **escaped** asterisks", tokens: [
			Token(type: .string, inputString: "A string with double **escaped** asterisks", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "\\**One escaped, one not at either end\\**", output: "*One escaped, one not at either end*", tokens: [
			Token(type: .string, inputString: "*", characterStyles: []),
			Token(type: .string, inputString: "One escaped, one not at either end*", characterStyles: [CharacterStyle.italic]),
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "A string with one \\**escaped\\** asterisk, one not at either end", output: "A string with one *escaped* asterisk, one not at either end", tokens: [
			Token(type: .string, inputString: "A string with one *", characterStyles: []),
			Token(type: .string, inputString: "escaped*", characterStyles: [CharacterStyle.italic]),
			Token(type: .string, inputString: " asterisk, one not at either end", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
	}
	
	func testThatCodeTraitsAreRecognised() {
		challenge = TokenTest(input: "`Code (**should** not process internal tags)`", output: "Code (**should** not process internal tags)",  tokens: [
			Token(type: .string, inputString: "Code (**should** not process internal tags)", characterStyles: [CharacterStyle.code])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "A string with `code` (should not be indented)", output: "A string with code (should not be indented)", tokens : [
			Token(type: .string, inputString: "A string with ", characterStyles: []),
			Token(type: .string, inputString: "code", characterStyles: [CharacterStyle.code]),
			Token(type: .string, inputString: " (should not be indented)", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "`A code string` with multiple `code` `instances`", output: "A code string with multiple code instances", tokens : [
			Token(type: .string, inputString: "A code string", characterStyles: [CharacterStyle.code]),
			Token(type: .string, inputString: " with multiple ", characterStyles: []),
			Token(type: .string, inputString: "code", characterStyles: [CharacterStyle.code]),
			Token(type: .string, inputString: " ", characterStyles: []),
			Token(type: .string, inputString: "instances", characterStyles: [CharacterStyle.code])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "\\`A normal string\\`", output: "`A normal string`", tokens: [
			Token(type: .string, inputString: "`A normal string`", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "A string with \\`escaped\\` backticks", output: "A string with `escaped` backticks", tokens: [
			Token(type: .string, inputString: "A string with `escaped` backticks", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "A lonely backtick: `", output: "A lonely backtick: `", tokens: [
			Token(type: .string, inputString: "A lonely backtick: `", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "Two backticks followed by a full stop ``.", output: "Two backticks followed by a full stop ``.", tokens: [
			Token(type: .string, inputString: "Two backticks followed by a full stop ``.", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
	}
	
	func testThatItalicTraitsAreParsedCorrectly() {
		
		challenge = TokenTest(input: "*An italicised string*", output: "An italicised string", tokens : [
			Token(type: .string, inputString: "An italicised string", characterStyles: [CharacterStyle.italic])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "A string with *italicised* text", output: "A string with italicised text", tokens : [
			Token(type: .string, inputString: "A string with ", characterStyles: []),
			Token(type: .string, inputString: "italicised", characterStyles: [CharacterStyle.italic]),
			Token(type: .string, inputString: " text", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		
		challenge = TokenTest(input: "_An italic string_ with a *mix* _of_ italic *styles*", output: "An italic string with a mix of italic styles", tokens : [
			Token(type: .string, inputString: "An italic string", characterStyles: [CharacterStyle.italic]),
			Token(type: .string, inputString: " with a ", characterStyles: []),
			Token(type: .string, inputString: "mix", characterStyles: [CharacterStyle.italic]),
			Token(type: .string, inputString: " ", characterStyles: []),
			Token(type: .string, inputString: "of", characterStyles: [CharacterStyle.italic]),
			Token(type: .string, inputString: " italic ", characterStyles: []),
			Token(type: .string, inputString: "styles", characterStyles: [CharacterStyle.italic])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		
		challenge = TokenTest(input: "\\_A normal string\\_", output: "_A normal string_", tokens: [
			Token(type: .string, inputString: "_A normal string_", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "A string with \\_escaped\\_ underscores", output: "A string with _escaped_ underscores", tokens: [
			Token(type: .string, inputString: "A string with _escaped_ underscores", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: """
		An asterisk: *
		Line break
		""", output: """
		An asterisk: *
		Line break
		""", tokens: [
			Token(type: .string, inputString: "An asterisk: *", characterStyles: []),
			Token(type: .string, inputString: "Line break", characterStyles: [])
		])
		results = self.attempt(challenge)
		XCTAssertEqual(results.stringTokens.count, challenge.tokens.count )
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
	}
	
	func testThatStrikethroughTraitsAreRecognised() {
		challenge = TokenTest(input: "~~An~~A crossed-out string", output: "AnA crossed-out string", tokens: [
			Token(type: .string, inputString: "An", characterStyles: [CharacterStyle.strikethrough]),
			Token(type: .string, inputString: "A crossed-out string", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		
		challenge = TokenTest(input: "A **Bold** string and a ~~removed~~crossed-out string", output: "A Bold string and a removedcrossed-out string", tokens: [
			Token(type: .string, inputString: "A ", characterStyles: []),
			Token(type: .string, inputString: "Bold", characterStyles: [CharacterStyle.bold]),
			Token(type: .string, inputString: " string and a ", characterStyles: []),
			Token(type: .string, inputString: "removed", characterStyles: [CharacterStyle.strikethrough]),
			Token(type: .string, inputString: "crossed-out string", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		
		challenge = TokenTest(input: "\\~\\~removed\\~\\~crossed-out string. ~This should be ignored~", output: "~~removed~~crossed-out string. ~This should be ignored~", tokens: [
			Token(type: .string, inputString: "~~removed~~crossed-out string. ~This should be ignored~", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		
	}
	
	func testThatMixedTraitsAreRecognised() {
		
		challenge = TokenTest(input: "__A bold string__ with a **mix** **of** bold __styles__", output: "A bold string with a mix of bold styles", tokens : [
			Token(type: .string, inputString: "A bold string", characterStyles: [CharacterStyle.bold]),
			Token(type: .string, inputString: " with a ", characterStyles: []),
			Token(type: .string, inputString: "mix", characterStyles: [CharacterStyle.bold]),
			Token(type: .string, inputString: " ", characterStyles: []),
			Token(type: .string, inputString: "of", characterStyles: [CharacterStyle.bold]),
			Token(type: .string, inputString: " bold ", characterStyles: []),
			Token(type: .string, inputString: "styles", characterStyles: [CharacterStyle.bold])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "_An italic string_, **followed by a bold one**, `with some code`, \\*\\*and some\\*\\* \\_escaped\\_ \\`characters\\`, `ending` *with* __more__ variety.", output: "An italic string, followed by a bold one, with some code, **and some** _escaped_ `characters`, ending with more variety.", tokens : [
			Token(type: .string, inputString: "An italic string", characterStyles: [CharacterStyle.italic]),
			Token(type: .string, inputString: ", ", characterStyles: []),
			Token(type: .string, inputString: "followed by a bold one", characterStyles: [CharacterStyle.bold]),
			Token(type: .string, inputString: ", ", characterStyles: []),
			Token(type: .string, inputString: "with some code", characterStyles: [CharacterStyle.code]),
			Token(type: .string, inputString: ", **and some** _escaped_ `characters`, ", characterStyles: []),
			Token(type: .string, inputString: "ending", characterStyles: [CharacterStyle.code]),
			Token(type: .string, inputString: " ", characterStyles: []),
			Token(type: .string, inputString: "with", characterStyles: [CharacterStyle.italic]),
			Token(type: .string, inputString: " ", characterStyles: []),
			Token(type: .string, inputString: "more", characterStyles: [CharacterStyle.bold]),
			Token(type: .string, inputString: " variety.", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
	}
	
	func testForExtremeEscapeCombinations() {
		
		challenge = TokenTest(input: "\\****b\\****", output: "*b*", tokens : [
			Token(type: .string, inputString: "*", characterStyles: []),
			Token(type: .string, inputString: "b*", characterStyles: [CharacterStyle.bold, CharacterStyle.italic])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "**\\**b*\\***", output: "*b*", tokens : [
			Token(type: .string, inputString: "*", characterStyles: [CharacterStyle.bold]),
			Token(type: .string, inputString: "b", characterStyles: [CharacterStyle.italic, CharacterStyle.bold]),
			Token(type: .string, inputString: "*", characterStyles: [CharacterStyle.bold]),
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
//		challenge = TokenTest(input: "Before *\\***\\****A bold string*\\***\\****\\ After", output: "Before ***A bold string***\\ After", tokens : [
//			Token(type: .string, inputString: "Before ", characterStyles: []),
//			Token(type: .string, inputString: "*", characterStyles: [CharacterStyle.italic]),
//			Token(type: .string, inputString: "**", characterStyles: [CharacterStyle.bold]),
//			Token(type: .string, inputString: "A bold string**", characterStyles: [CharacterStyle.bold, CharacterStyle.italic]),
//			Token(type: .string, inputString: "\\ After", characterStyles: [])
//		])
//		results = self.attempt(challenge)
//		if results.stringTokens.count == challenge.tokens.count {
//			for (idx, token) in results.stringTokens.enumerated() {
//				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
//				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
//			}
//		} else {
//			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
//		}
//		XCTAssertEqual(results.foundStyles, results.expectedStyles)
//		XCTAssertEqual(results.attributedString.string, challenge.output)
	}
	
	func testThatExtraCharactersAreHandles() {
		challenge = TokenTest(input: "***A bold italic string***", output: "A bold italic string",  tokens: [
			Token(type: .string, inputString: "A bold italic string", characterStyles: [CharacterStyle.bold, CharacterStyle.italic])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "A string with a ****bold**** word", output: "A string with a bold word",  tokens: [
			Token(type: .string, inputString: "A string with a ", characterStyles: []),
			Token(type: .string, inputString: "bold", characterStyles: [CharacterStyle.bold]),
			Token(type: .string, inputString: " word", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "A string with a ****bold italic*** word", output: "A string with a *bold italic word",  tokens: [
			Token(type: .string, inputString: "A string with a ", characterStyles: []),
			Token(type: .string, inputString: "*bold italic", characterStyles: [CharacterStyle.bold, CharacterStyle.italic]),
			Token(type: .string, inputString: " word", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "A string with a ***bold** italic* word", output: "A string with a bold italic word",  tokens: [
			Token(type: .string, inputString: "A string with a ", characterStyles: []),
			Token(type: .string, inputString: "bold", characterStyles: [CharacterStyle.bold, CharacterStyle.italic]),
			Token(type: .string, inputString: " italic", characterStyles: [CharacterStyle.italic]),
			Token(type: .string, inputString: " word", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "A string with a **bold*italic*bold** word", output: "A string with a bolditalicbold word",  tokens: [
			Token(type: .string, inputString: "A string with a ", characterStyles: []),
			Token(type: .string, inputString: "bold", characterStyles: [CharacterStyle.bold]),
			Token(type: .string, inputString: "italic", characterStyles: [CharacterStyle.italic, CharacterStyle.bold]),
			Token(type: .string, inputString: "bold", characterStyles: [CharacterStyle.bold]),
			Token(type: .string, inputString: " word", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "A string with ```code`", output: "A string with ```code`", tokens : [
			Token(type: .string, inputString: "A string with ```code`", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "A string with ```code```", output: "A string with code", tokens : [
			Token(type: .string, inputString: "A string with ", characterStyles: []),
			Token(type: .string, inputString: "code", characterStyles: [CharacterStyle.code])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
	}
	
	
	// The new version of SwiftyMarkdown is a lot more strict than the old version, although this may change in future
	func offtestThatMarkdownMistakesAreHandledAppropriately() {
		let mismatchedBoldCharactersAtStart = "**This should be bold*"
		let mismatchedBoldCharactersWithin = "A string *that should be italic**"
		
		var md = SwiftyMarkdown(string: mismatchedBoldCharactersAtStart)
		XCTAssertEqual(md.attributedString().string, "This should be bold")
		
		md = SwiftyMarkdown(string: mismatchedBoldCharactersWithin)
		XCTAssertEqual(md.attributedString().string, "A string that should be italic")
		
	}
	
	func offtestAdvancedEscaping() {
		
		challenge = TokenTest(input: "\\***A normal string*\\**", output: "**A normal string*", tokens: [
			Token(type: .string, inputString: "**", characterStyles: []),
			Token(type: .string, inputString: "A normal string", characterStyles: [CharacterStyle.italic]),
			Token(type: .string, inputString: "**", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
		challenge = TokenTest(input: "A string with randomly *\\**escaped**\\* asterisks", output: "A string with randomly **escaped** asterisks", tokens: [
			Token(type: .string, inputString: "A string with randomly **", characterStyles: []),
			Token(type: .string, inputString: "escaped", characterStyles: [CharacterStyle.italic]),
			Token(type: .string, inputString: "** asterisks", characterStyles: [])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
	}
	
	func testThatAsterisksAndUnderscoresNotAttachedToWordsAreNotRemoved() {
		
		let asteriskFullStop = "Two asterisks followed by a full stop: **."
		let asteriskWithBold = "A **bold** word followed by an asterisk * "
		let underscoreFullStop = "Two underscores followed by a full stop: __."
		let asteriskComma = "An asterisk followed by a full stop: *, *"
		
		let backtickSpace = "A backtick followed by a space: `"
		
		let underscoreSpace = "An underscore followed by a space: _"
		
		let backtickComma = "A backtick followed by a space: `, `"
		let underscoreComma = "An underscore followed by a space: _, _"
		
		let backtickWithCode = "A `code` word followed by a backtick ` "
		let underscoreWithItalic = "An _italic_ word followed by an underscore _ "
		
		var md = SwiftyMarkdown(string: backtickSpace)
		SwiftyMarkdown.characterRules = self.defaultRules
		XCTAssertEqual(md.attributedString().string, backtickSpace)
		
		md = SwiftyMarkdown(string: underscoreSpace)
		XCTAssertEqual(md.attributedString().string, underscoreSpace)
		
		md = SwiftyMarkdown(string: asteriskFullStop)
		XCTAssertEqual(md.attributedString().string, asteriskFullStop)
		
		md = SwiftyMarkdown(string: underscoreFullStop)
		XCTAssertEqual(md.attributedString().string, underscoreFullStop)
		
		md = SwiftyMarkdown(string: asteriskComma)
		XCTAssertEqual(md.attributedString().string, asteriskComma)
		
		md = SwiftyMarkdown(string: backtickComma)
		XCTAssertEqual(md.attributedString().string, backtickComma)
		
		md = SwiftyMarkdown(string: underscoreComma)
		XCTAssertEqual(md.attributedString().string, underscoreComma)
		
		md = SwiftyMarkdown(string: asteriskWithBold)
		XCTAssertEqual(md.attributedString().string, "A bold word followed by an asterisk *")
		
		md = SwiftyMarkdown(string: backtickWithCode)
		XCTAssertEqual(md.attributedString().string, "A code word followed by a backtick `")
		
		md = SwiftyMarkdown(string: underscoreWithItalic)
		XCTAssertEqual(md.attributedString().string, "An italic word followed by an underscore _")
		
	}
	
	func testReportedCrashingStrings() {
		challenge = TokenTest(input: "[**\\!bang**](https://duckduckgo.com/bang)", output: "\\!bang", tokens: [
			Token(type: .string, inputString: "\\!bang", characterStyles: [CharacterStyle.link, CharacterStyle.bold])
		])
		results = self.attempt(challenge)
		if results.stringTokens.count == challenge.tokens.count {
			for (idx, token) in results.stringTokens.enumerated() {
				XCTAssertEqual(token.inputString, challenge.tokens[idx].inputString)
				XCTAssertEqual(token.characterStyles as? [CharacterStyle], challenge.tokens[idx].characterStyles as?  [CharacterStyle])
			}
		} else {
			XCTAssertEqual(results.stringTokens.count, challenge.tokens.count)
		}
		XCTAssertEqual(results.foundStyles, results.expectedStyles)
		XCTAssertEqual(results.attributedString.string, challenge.output)
		
	}
	
}
