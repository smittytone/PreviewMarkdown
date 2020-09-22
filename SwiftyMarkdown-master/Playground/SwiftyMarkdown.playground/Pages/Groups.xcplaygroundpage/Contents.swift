//: [Previous](@previous)

import Foundation

extension String {
	func repeating( _ max : Int ) -> String {
		var output = self
		for _ in 1..<max {
			output += self
		}
		return output
	}
}

enum TagState {
	case none
	case open
	case intermediate
	case closed
}

struct TagString {
	var state : TagState = .none
	var preOpenString = ""
	var openTagString = ""
	var intermediateString = ""
	var intermediateTagString = ""
	var metadataString = ""
	var closedTagString = ""
	var postClosedString = ""

	let rule : Rule
	
	init( with rule : Rule ) {
		self.rule = rule
	}
	
	mutating func append( _ string : String? ) {
		guard let existentString = string else {
			return
		}
		switch self.state {
		case .none:
			self.preOpenString += existentString
		case .open:
			self.intermediateString += existentString
		case .intermediate:
			self.metadataString += existentString
		case .closed:
			self.postClosedString += existentString
		}
	}
	
	mutating func append( contentsOf tokenGroup: [TokenGroup] ) {
		print(tokenGroup)
		for token in tokenGroup {
			switch token.state {
			case .none:
				self.append(token.string)
			case .open:
				if self.state != .none {
					self.preOpenString += token.string
				} else {
					self.openTagString += token.string
				}
			case .intermediate:
				if self.state != .open {
					self.intermediateString += token.string
				} else {
					self.intermediateTagString += token.string
				}
			case .closed:
				if self.rule.intermediateTag != nil && self.state != .intermediate {
					self.metadataString += token.string
				} else {
					self.closedTagString += token.string
				}
			}
			self.state = token.state
		}
	}
	
	mutating func tokens() -> [Token] {
		print(self)
		var tokens : [Token] = []

		if !self.preOpenString.isEmpty {
			tokens.append(Token(type: .string, inputString: self.preOpenString))
		}
		if !self.openTagString.isEmpty {
			tokens.append(Token(type: .openTag, inputString: self.openTagString))
		}
		if !self.intermediateString.isEmpty {
			var token = Token(type: .string, inputString: self.intermediateString)
			token.metadataString = self.metadataString
			tokens.append(token)
		}
		if !self.intermediateTagString.isEmpty {
			tokens.append(Token(type: .intermediateTag, inputString: self.intermediateTagString))
		}
		if !self.metadataString.isEmpty {
			tokens.append(Token(type: .metadata, inputString: self.metadataString))
		}
		if !self.closedTagString.isEmpty {
			tokens.append(Token(type: .closeTag, inputString: self.closedTagString))
		}
		
		self.preOpenString = ""
		self.openTagString = ""
		self.intermediateString = ""
		self.intermediateTagString = ""
		self.metadataString = ""
		self.closedTagString = ""
		self.postClosedString = ""
		
		self.state = .none
		
		return tokens
	}
}

struct TokenGroup {
	enum TokenGroupType {
		case string
		case tag
		case escape
	}

	let string : String
	let isEscaped : Bool
	let type : TokenGroupType
	var state : TagState = .none
}



func getTokenGroups( for string : inout String, with rule : Rule, shouldEmpty : Bool = false ) -> [TokenGroup] {
	if string.isEmpty {
		return []
	}
	let maxCount = rule.openTag.count * rule.maxTags
	var groups : [TokenGroup] = []
	
	let maxTag = rule.openTag.repeating(rule.maxTags)
	
	if maxTag.contains(string) {
		if string.count == maxCount || shouldEmpty {
			var token = TokenGroup(string: string, isEscaped: false, type: .tag)
			token.state = .open
			groups.append(token)
			string.removeAll()
		}
	
	} else if string == rule.intermediateTag {
		var token = TokenGroup(string: string, isEscaped: false, type: .tag)
		token.state = .intermediate
		groups.append(token)
		string.removeAll()
	} else if string == rule.closingTag {
		var token = TokenGroup(string: string, isEscaped: false, type: .tag)
		token.state = .closed
		groups.append(token)
		string.removeAll()
	}
	
	if shouldEmpty && !string.isEmpty {
		let token = TokenGroup(string: string, isEscaped: false, type: .tag)
		groups.append(token)
		string.removeAll()
	}
	return groups
}

func scan( _ string : String, with rule : Rule) -> [Token] {
		let scanner = Scanner(string: string)
		scanner.charactersToBeSkipped = nil
		var tokens : [Token] = []
		var set = CharacterSet(charactersIn: "\(rule.openTag)\(rule.intermediateTag ?? "")\(rule.closingTag ?? "")")
		if let existentEscape = rule.escapeCharacter {
			set.insert(charactersIn: String(existentEscape))
		}
		
		var openTag = rule.openTag.repeating(rule.maxTags)
		
		var tagString = TagString(with: rule)
		
		var openTagFound : TagState = .none
		var regularCharacters = ""
		var tagGroupCount = 0
		while !scanner.isAtEnd {
			tagGroupCount += 1
			
			if #available(iOS 13.0, OSX 10.15, watchOS 6.0, tvOS 13.0, *) {
				if let start = scanner.scanUpToCharacters(from: set) {
					tagString.append(start)
				}
			} else {
				var string : NSString?
				scanner.scanUpToCharacters(from: set, into: &string)
				if let existentString = string as String? {
					tagString.append(existentString)
				}
			}
			
			// The end of the string
			let maybeFoundChars = scanner.scanCharacters(from: set )
			guard let foundTag = maybeFoundChars else {
				continue
			}
			
			if foundTag == rule.openTag && foundTag.count < rule.minTags {
				tagString.append(foundTag)
				continue
			}
			
			//:--
			print(foundTag)
			var tokenGroups : [TokenGroup] = []
			var escapeCharacter : Character? = nil
			var cumulatedString = ""
			for char in foundTag {
				if let existentEscapeCharacter = escapeCharacter {
					
					// If any of the tags feature the current character
					let escape = String(existentEscapeCharacter)
					let nextTagCharacter = String(char)
					if rule.openTag.contains(nextTagCharacter) || rule.intermediateTag?.contains(nextTagCharacter) ?? false || rule.closingTag?.contains(nextTagCharacter) ?? false {
						tokenGroups.append(TokenGroup(string: nextTagCharacter, isEscaped: true, type: .tag))
						escapeCharacter = nil
					} else if nextTagCharacter == escape {
						// Doesn't apply to this rule
						tokenGroups.append(TokenGroup(string: nextTagCharacter, isEscaped: false, type: .escape))
					}
					
					continue
				}
				if let existentEscape = rule.escapeCharacter {
					if char == existentEscape {
						tokenGroups.append(contentsOf: getTokenGroups(for: &cumulatedString, with: rule, shouldEmpty: true))
						escapeCharacter = char
						continue
					}
				}
				cumulatedString.append(char)
				tokenGroups.append(contentsOf: getTokenGroups(for: &cumulatedString, with: rule))
				
			}
			if let remainingEscape = escapeCharacter {
				tokenGroups.append(TokenGroup(string: String(remainingEscape), isEscaped: false, type: .escape))
			}

			tokenGroups.append(contentsOf: getTokenGroups(for: &cumulatedString, with: rule, shouldEmpty: true))
			tagString.append(contentsOf: tokenGroups)
			
			if tagString.state == .closed {
				tokens.append(contentsOf: tagString.tokens())
			}
			
			
		}
		
		tokens.append(contentsOf: tagString.tokens())
		
		
		return tokens
	}

//: [Next](@next)



var string = "[]([[\\[Some Link]\\]](\\(\\(\\url) [Regular link](url)"
//string = "Text before [Regular link](url) Text after"
var output = "[]([[Some Link]] Regular link"

var tokens = scan(string, with: LinkRule())
print( tokens.filter( { $0.type == .string }).map({ $0.outputString }).joined())
//print( tokens )

//string = "**\\*\\Bold\\*\\***"
//output = "*\\Bold**"

//tokens = scan(string, with: AsteriskRule())
//print( tokens )

