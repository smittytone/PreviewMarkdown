# Swifty Markdown

SwiftyMarkdown is a Swift-based *Markdown* parser that converts *Markdown* files or strings into **NSAttributedStrings**. It uses sensible defaults and supports dynamic type, even with custom fonts.

Show Images From Your App Bundle!
---
![Image](bubble)

Customise fonts and colors easily in a Swift-like way: 

    md.code.fontName = "CourierNewPSMT"

    md.h2.fontName = "AvenirNextCondensed-Medium"
    md.h2.color = UIColor.redColor()
    md.h2.alignment = .center

It supports the standard Markdown syntax, like *italics*, _underline italics_, **bold**, `backticks for code`, ~~strikethrough~~, and headings.

It ignores random * and correctly handles escaped \*asterisks\* and \_underlines\_ and \`backticks\`. It also supports inline Markdown [Links](http://voyagetravelapps.com/).

> It also now supports blockquotes
> and it supports whole-line italic and bold styles so you can go completely wild with styling! Wow! Such styles! Much fun!

**Lists**

- It Supports
- Unordered
- Lists
	- Indented item with a longer string to make sure indentation is consistent
		- Second level indent with a longer string to make sure indentation is consistent
- List item with a longer string to make sure indentation is consistent

1. And
1. Ordered
1. Lists
	1. Indented item
		1. Second level indent
1. (Use `1.` as the list item identifier)
1. List item
1. List item
	- Mix
		- List styles
1. List item with a longer string to make sure indentation is consistent
1. List item
1. List item
1. List item
1. List item



