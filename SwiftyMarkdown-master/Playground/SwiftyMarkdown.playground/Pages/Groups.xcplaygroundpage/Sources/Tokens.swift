import Foundation



public protocol Rule {
	var escapeCharacter : Character? { get }
	var openTag : String { get }
	var intermediateTag : String? { get }
	var closingTag : String? { get }
	var maxTags : Int { get }
	var minTags : Int { get }
}

public struct LinkRule : Rule {
	public let escapeCharacter : Character? = "\\"
	public let openTag : String = "["
	public let intermediateTag : String? = "]("
	public let closingTag : String? = ")"
	public let maxTags : Int = 1
	public let minTags : Int = 1
	public init() { }
}

public struct AsteriskRule : Rule {
	public let escapeCharacter : Character? = "\\"
	public let openTag : String = "*"
	public let intermediateTag : String? = nil
	public let closingTag : String? = nil
	public let maxTags : Int = 3
	public let minTags : Int = 1
	public init() { }
}
