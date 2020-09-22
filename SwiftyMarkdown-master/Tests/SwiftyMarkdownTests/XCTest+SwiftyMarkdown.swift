//
//  XCTest+SwiftyMarkdown.swift
//  SwiftyMarkdownTests
//
//  Created by Simon Fairbairn on 17/12/2019.
//  Copyright © 2019 Voyage Travel Apps. All rights reserved.
//

import XCTest
@testable import SwiftyMarkdown


struct ChallengeReturn {
	let tokens : [Token]
	let stringTokens : [Token]
	let links : [Token]
	let images : [Token]
	let attributedString : NSAttributedString
	let foundStyles : [[CharacterStyle]]
	let expectedStyles : [[CharacterStyle]]
}

enum Rule {
	case asterisks
	case backticks
	case underscores
	case images
	case links
	case referencedLinks
	case referencedImages
	case tildes
	
	func asCharacterRule() -> CharacterRule {
		switch self {
		case .images:
			return SwiftyMarkdown.characterRules.filter({ $0.primaryTag.tag == "![" && !$0.metadataLookup  }).first!
		case .links:
			return SwiftyMarkdown.characterRules.filter({ $0.primaryTag.tag == "[" && !$0.metadataLookup  }).first!
		case .backticks:
			return SwiftyMarkdown.characterRules.filter({ $0.primaryTag.tag == "`" }).first!
		case .tildes:
			return SwiftyMarkdown.characterRules.filter({ $0.primaryTag.tag == "~" }).first!
		case .asterisks:
			return SwiftyMarkdown.characterRules.filter({ $0.primaryTag.tag == "*" }).first!
		case .underscores:
			return SwiftyMarkdown.characterRules.filter({ $0.primaryTag.tag == "_" }).first!
		case .referencedLinks:
			return SwiftyMarkdown.characterRules.filter({ $0.primaryTag.tag == "[" && $0.metadataLookup  }).first!
		case .referencedImages:
			return SwiftyMarkdown.characterRules.filter({ $0.primaryTag.tag == "![" && $0.metadataLookup  }).first!
		}
	}
}

class SwiftyMarkdownCharacterTests : XCTestCase {
	let defaultRules = SwiftyMarkdown.characterRules
	
	var challenge : TokenTest!
	var results : ChallengeReturn!
	
	func attempt( _ challenge : TokenTest, rules : [Rule]? = nil ) -> ChallengeReturn {
		if let validRules = rules {
			SwiftyMarkdown.characterRules = validRules.map({ $0.asCharacterRule() })
		} else {
			SwiftyMarkdown.characterRules = self.defaultRules
		}
		
		let md = SwiftyMarkdown(string: challenge.input)
		md.applyAttachments = false
		let attributedString = md.attributedString()
		let tokens : [Token] = md.previouslyFoundTokens
		let stringTokens = tokens.filter({ $0.type == .string && !$0.isMetadata })
		
		let existentTokenStyles = stringTokens.compactMap({ $0.characterStyles as? [CharacterStyle] })
		let expectedStyles = challenge.tokens.compactMap({ $0.characterStyles as? [CharacterStyle] })
		
		let linkTokens = tokens.filter({ $0.type == .string && (($0.characterStyles as? [CharacterStyle])?.contains(.link) ?? false) })
		let imageTokens = tokens.filter({ $0.type == .string && (($0.characterStyles as? [CharacterStyle])?.contains(.image) ?? false) })
		
		return ChallengeReturn(tokens: tokens, stringTokens: stringTokens, links : linkTokens, images: imageTokens, attributedString:  attributedString, foundStyles: existentTokenStyles, expectedStyles : expectedStyles)
	}
}


extension XCTestCase {
	
	func resourceURL(for filename : String ) -> URL {
		let thisSourceFile = URL(fileURLWithPath: #file)
		let thisDirectory = thisSourceFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
		return thisDirectory.appendingPathComponent("Resources", isDirectory: true).appendingPathComponent(filename)
	}
	

}


