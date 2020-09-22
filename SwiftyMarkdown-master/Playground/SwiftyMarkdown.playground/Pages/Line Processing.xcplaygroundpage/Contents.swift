import Foundation

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

let rules = [
	LineRule(token: "=", type: MarkdownLineStyle.previousH1, removeFrom: .entireLine, changeAppliesTo: .previous),
	LineRule(token: "-", type: MarkdownLineStyle.previousH2, removeFrom: .entireLine, changeAppliesTo: .previous),
	LineRule(token: "    ", type: MarkdownLineStyle.codeblock, removeFrom: .leading),
	LineRule(token: "\t", type: MarkdownLineStyle.codeblock, removeFrom: .leading),
	LineRule(token: ">",type : MarkdownLineStyle.blockquote, removeFrom: .leading),
	LineRule(token: "- ",type : MarkdownLineStyle.unorderedList, removeFrom: .leading),
	LineRule(token: "###### ",type : MarkdownLineStyle.h6, removeFrom: .both),
	LineRule(token: "##### ",type : MarkdownLineStyle.h5, removeFrom: .both),
	LineRule(token: "#### ",type : MarkdownLineStyle.h4, removeFrom: .both),
	LineRule(token: "### ",type : MarkdownLineStyle.h3, removeFrom: .both),
	LineRule(token: "## ",type : MarkdownLineStyle.h2, removeFrom: .both),
	LineRule(token: "# ",type : MarkdownLineStyle.h1, removeFrom: .both)
]

let lineProcesser = SwiftyLineProcessor(rules: rules, defaultRule: MarkdownLineStyle.body)
print(lineProcesser.process("#### Heading 4 ###").first?.line ?? "")

