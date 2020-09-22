//: [Previous](@previous)

import UIKit


enum CharacterStyle : CharacterStyling {
	case none
	case bold
	case italic
	case code
	case link
	case image
}

enum MarkdownLineStyle : LineStyling {
    var shouldTokeniseLine: Bool {
        switch self {
        case .codeblock:
            return false
        default:
            return true
        }
        
    }
    
    case h1
    case h2
    case h3
    case h4
    case h5
    case h6
    case previousH1
    case previousH2
    case body
    case blockquote
    case codeblock
    case unorderedList
    func styleIfFoundStyleAffectsPreviousLine() -> LineStyling? {
        switch self {
        case .previousH1:
            return MarkdownLineStyle.h1
        case .previousH2:
            return MarkdownLineStyle.h2
        default :
            return nil
        }
    }
}


@objc public protocol FontProperties {
	var fontName : String? { get set }
	var color : UIColor { get set }
	var fontSize : CGFloat { get set }
}


/**
A struct defining the styles that can be applied to the parsed Markdown. The `fontName` property is optional, and if it's not set then the `fontName` property of the Body style will be applied.

If that is not set, then the system default will be used.
*/
@objc open class BasicStyles : NSObject, FontProperties {
	public var fontName : String?
	public var color = UIColor.black
	public var fontSize : CGFloat = 0.0
}

/// A class that takes a [Markdown](https://daringfireball.net/projects/markdown/) string or file and returns an NSAttributedString with the applied styles. Supports Dynamic Type.
@objc open class SwiftyMarkdown: NSObject {
	static let lineRules = [
		LineRule(token: "=", type: MarkdownLineStyle.previousH1, removeFrom: .entireLine, changeAppliesTo: .previous),
		LineRule(token: "-", type: MarkdownLineStyle.previousH2, removeFrom: .entireLine, changeAppliesTo: .previous),
		LineRule(token: "    ", type: MarkdownLineStyle.codeblock, removeFrom: .leading, shouldTrim: false),
		LineRule(token: "\t", type: MarkdownLineStyle.codeblock, removeFrom: .leading, shouldTrim: false),
		LineRule(token: ">",type : MarkdownLineStyle.blockquote, removeFrom: .leading),
		LineRule(token: "- ",type : MarkdownLineStyle.unorderedList, removeFrom: .leading),
		LineRule(token: "###### ",type : MarkdownLineStyle.h6, removeFrom: .both),
		LineRule(token: "##### ",type : MarkdownLineStyle.h5, removeFrom: .both),
		LineRule(token: "#### ",type : MarkdownLineStyle.h4, removeFrom: .both),
		LineRule(token: "### ",type : MarkdownLineStyle.h3, removeFrom: .both),
		LineRule(token: "## ",type : MarkdownLineStyle.h2, removeFrom: .both),
		LineRule(token: "# ",type : MarkdownLineStyle.h1, removeFrom: .both)
	]
	
	static let characterRules = [
		CharacterRule(openTag: "![", intermediateTag: "](", closingTag: ")", escapeCharacter: "\\", styles: [1 : [CharacterStyle.image]], maxTags: 1),
		CharacterRule(openTag: "[", intermediateTag: "](", closingTag: ")", escapeCharacter: "\\", styles: [1 : [CharacterStyle.link]], maxTags: 1),
		CharacterRule(openTag: "`", intermediateTag: nil, closingTag: nil, escapeCharacter: "\\", styles: [1 : [CharacterStyle.code]], maxTags: 1, cancels: .allRemaining),
		CharacterRule(openTag: "*", intermediateTag: nil, closingTag: nil, escapeCharacter: "\\", styles: [1 : [CharacterStyle.italic], 2 : [CharacterStyle.bold], 3 : [CharacterStyle.bold, CharacterStyle.italic]], maxTags: 3),
		CharacterRule(openTag: "_", intermediateTag: nil, closingTag: nil, escapeCharacter: "\\", styles: [1 : [CharacterStyle.italic], 2 : [CharacterStyle.bold], 3 : [CharacterStyle.bold, CharacterStyle.italic]], maxTags: 3)
	]
	
	let lineProcessor = SwiftyLineProcessor(rules: SwiftyMarkdown.lineRules, defaultRule: MarkdownLineStyle.body)
	let tokeniser = SwiftyTokeniser(with: SwiftyMarkdown.characterRules)
	
	/// The styles to apply to any H1 headers found in the Markdown
	open var h1 = BasicStyles()
	
	/// The styles to apply to any H2 headers found in the Markdown
	open var h2 = BasicStyles()
	
	/// The styles to apply to any H3 headers found in the Markdown
	open var h3 = BasicStyles()
	
	/// The styles to apply to any H4 headers found in the Markdown
	open var h4 = BasicStyles()
	
	/// The styles to apply to any H5 headers found in the Markdown
	open var h5 = BasicStyles()
	
	/// The styles to apply to any H6 headers found in the Markdown
	open var h6 = BasicStyles()
	
	/// The default body styles. These are the base styles and will be used for e.g. headers if no other styles override them.
	open var body = BasicStyles()
	
	/// The styles to apply to any links found in the Markdown
	open var link = BasicStyles()
	
	/// The styles to apply to any bold text found in the Markdown
	open var bold = BasicStyles()
	
	/// The styles to apply to any italic text found in the Markdown
	open var italic = BasicStyles()
	
	/// The styles to apply to any code blocks or inline code text found in the Markdown
	open var code = BasicStyles()
	
	
	var currentType : MarkdownLineStyle = .body
	
	
	let string : String
	
	let tagList = "!\\_*`[]()"
	let validMarkdownTags = CharacterSet(charactersIn: "!\\_*`[]()")

	
	/**
	
	- parameter string: A string containing [Markdown](https://daringfireball.net/projects/markdown/) syntax to be converted to an NSAttributedString
	
	- returns: An initialized SwiftyMarkdown object
	*/
	public init(string : String ) {
		self.string = string
	}
	
	/**
	A failable initializer that takes a URL and attempts to read it as a UTF-8 string
	
	- parameter url: The location of the file to read
	
	- returns: An initialized SwiftyMarkdown object, or nil if the string couldn't be read
	*/
	public init?(url : URL ) {
		
		do {
			self.string = try NSString(contentsOf: url, encoding: String.Encoding.utf8.rawValue) as String
			
		} catch {
			self.string = ""
			return nil
		}
	}
	
	/**
	Set font size for all styles
	
	- parameter size: size of font
	*/
	open func setFontSizeForAllStyles(with size: CGFloat) {
		h1.fontSize = size
		h2.fontSize = size
		h3.fontSize = size
		h4.fontSize = size
		h5.fontSize = size
		h6.fontSize = size
		body.fontSize = size
		italic.fontSize = size
		code.fontSize = size
		link.fontSize = size
	}
	
	open func setFontColorForAllStyles(with color: UIColor) {
		h1.color = color
		h2.color = color
		h3.color = color
		h4.color = color
		h5.color = color
		h6.color = color
		body.color = color
		italic.color = color
		code.color = color
		link.color = color
	}
	
	open func setFontNameForAllStyles(with name: String) {
		h1.fontName = name
		h2.fontName = name
		h3.fontName = name
		h4.fontName = name
		h5.fontName = name
		h6.fontName = name
		body.fontName = name
		italic.fontName = name
		code.fontName = name
		link.fontName = name
	}
	
	
	
	/**
	Generates an NSAttributedString from the string or URL passed at initialisation. Custom fonts or styles are applied to the appropriate elements when this method is called.
	
	- returns: An NSAttributedString with the styles applied
	*/
	open func attributedString() -> NSAttributedString {
		let attributedString = NSMutableAttributedString(string: "")
		let foundAttributes : [SwiftyLine] = lineProcessor.process(self.string)
		
		var strings : [String] = []
		for line in foundAttributes {
			let finalTokens = self.tokeniser.process(line.line)
			attributedString.append(attributedStringFor(tokens: finalTokens, in: line))
		}
		
		return attributedString
	}
	
	
}

extension SwiftyMarkdown {
	
	func font( for line : SwiftyLine, characterOverride : CharacterStyle? = nil ) -> UIFont {
		let textStyle : UIFont.TextStyle
		var fontName : String?
		var fontSize : CGFloat?
		
		// What type are we and is there a font name set?
		switch line.lineStyle as! MarkdownLineStyle {
		case .h1:
			fontName = h1.fontName
			fontSize = h1.fontSize
			if #available(iOS 9, *) {
				textStyle = UIFont.TextStyle.title1
			} else {
				textStyle = UIFont.TextStyle.headline
			}
		case .h2:
			fontName = h2.fontName
			fontSize = h2.fontSize
			if #available(iOS 9, *) {
				textStyle = UIFont.TextStyle.title2
			} else {
				textStyle = UIFont.TextStyle.headline
			}
		case .h3:
			fontName = h3.fontName
			fontSize = h3.fontSize
			if #available(iOS 9, *) {
				textStyle = UIFont.TextStyle.title2
			} else {
				textStyle = UIFont.TextStyle.subheadline
			}
		case .h4:
			fontName = h4.fontName
			fontSize = h4.fontSize
			textStyle = UIFont.TextStyle.headline
		case .h5:
			fontName = h5.fontName
			fontSize = h5.fontSize
			textStyle = UIFont.TextStyle.subheadline
		case .h6:
			fontName = h6.fontName
			fontSize = h6.fontSize
			textStyle = UIFont.TextStyle.footnote
		default:
			fontName = body.fontName
			fontSize = body.fontSize
			textStyle = UIFont.TextStyle.body
		}

		if fontName == nil {
			fontName = body.fontName
		}
		
		if let characterOverride = characterOverride {
			switch characterOverride {
			case .code:
				fontName = code.fontName ?? fontName
			case .link:
				fontName = link.fontName ?? fontName
			default:
				break
			}
		}
		
		fontSize = fontSize == 0.0 ? nil : fontSize
		var font : UIFont
		if let existentFontName = fontName {
			font = UIFont.preferredFont(forTextStyle: textStyle)
			let finalSize : CGFloat
			if let existentFontSize = fontSize {
				finalSize = existentFontSize
			} else {
				let styleDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: textStyle)
				finalSize = styleDescriptor.fontAttributes[.size] as? CGFloat ?? CGFloat(14)
			}
			
			if let customFont = UIFont(name: existentFontName, size: finalSize)  {
				let fontMetrics = UIFontMetrics(forTextStyle: textStyle)
				font = fontMetrics.scaledFont(for: customFont)
			} else {
				font = UIFont.preferredFont(forTextStyle: textStyle)
			}
		} else {
			font = UIFont.preferredFont(forTextStyle: textStyle)
		}
		
		return font
		
	}
	
	func color( for line : SwiftyLine ) -> UIColor {
		// What type are we and is there a font name set?
		switch line.lineStyle as! MarkdownLineStyle {
		case .h1, .previousH1:
			return h1.color
		case .h2, .previousH2:
			return h2.color
		case .h3:
			return h3.color
		case .h4:
			return h4.color
		case .h5:
			return h5.color
		case .h6:
			return h6.color
		case .body:
			return body.color
		case .codeblock:
			return code.color
		case .blockquote:
			return body.color
		case .unorderedList:
			return body.color
		}
	}
	
	func attributedStringFor( tokens : [Token], in line : SwiftyLine ) -> NSAttributedString {
		var outputLine = line.line
		if let style = line.lineStyle as? MarkdownLineStyle, style == .codeblock {
			outputLine = "\t\(outputLine)"
		}
		
		var attributes : [NSAttributedString.Key : AnyObject] = [:]
		let finalAttributedString = NSMutableAttributedString()
		for token in tokens {
			var font = self.font(for: line)
			attributes[.foregroundColor] = self.color(for: line)
			guard let styles = token.characterStyles as? [CharacterStyle] else {
				continue
			}
			if styles.contains(.italic) {
				if let italicDescriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) {
					font = UIFont(descriptor: italicDescriptor, size: 0)
				}
			}
			if styles.contains(.bold) {
				if let boldDescriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) {
					font = UIFont(descriptor: boldDescriptor, size: 0)
				}
			}
			attributes[.font] = font
			if styles.contains(.link), let url = token.metadataString {
				attributes[.foregroundColor] = self.link.color
				attributes[.font] = self.font(for: line, characterOverride: .link)
				attributes[.link] = url as AnyObject
			}
			
			if styles.contains(.image), let imageName = token.metadataString {
				let image1Attachment = NSTextAttachment()
				image1Attachment.image = UIImage(named: imageName)
				let str = NSAttributedString(attachment: image1Attachment)
				finalAttributedString.append(str)
				continue
			}
			
			if styles.contains(.code) {
				attributes[.foregroundColor] = self.code.color
				attributes[.font] = self.font(for: line, characterOverride: .code)
			} else {
				// Switch back to previous font
			}
			let str = NSAttributedString(string: token.outputString, attributes: attributes)
			finalAttributedString.append(str)
		}
		
		
		return finalAttributedString
	}
}


let image = UIImage(named: "bubble")
let image1Attachment = NSTextAttachment()
image1Attachment.image = image
let att = NSAttributedString(attachment: image1Attachment)



var str = "# Hello, *playground* `code` **bold** ![Image](bubble)"

let md = SwiftyMarkdown(string: str)
md.body.color = .red
md.h1.color = .white
md.h1.fontName = "Noteworthy-Light"

md.link.color = .red

md.code.fontName = "CourierNewPSMT"
	
md.attributedString()

//: [Next](@next)
