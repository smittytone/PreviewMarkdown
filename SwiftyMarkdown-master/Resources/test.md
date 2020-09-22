# SwiftyMarkdown 1.0

SwiftyMarkdown converts Markdown files and strings into `NSAttributedString`s using sensible defaults and a Swift-style syntax. It uses dynamic type to set the font size correctly with whatever font you'd like to use.

## Fully Rebuilt For 2020!

SwiftyMarkdown now features a more robust and reliable rules-based line processing and tokenisation engine. It has added support for images stored in the bundle (`![Image](<Name In bundle>)`), codeblocks, blockquotes, and unordered lists!

Line-level attributes can now have a paragraph alignment applied to them (e.g. `h2.aligment = .center`), and links can be underlined by setting underlineLinks to `true`. 

It also uses the system color `.label` as the default font color on iOS 13 and above for Dark Mode support out of the box. 

## Installation

### CocoaPods:

`pod 'SwiftyMarkdown'`

### SPM: 

In Xcode, `File -> Swift Packages -> Add Package Dependency` and add the GitHub URL. 

*italics* or _italics_
**bold** or __bold__
~~Linethrough~~Strikethroughs. 
`code`

# Header 1

or

Header 1
====

## Header 2

or

Header 2
---

### Header 3
#### Header 4
##### Header 5 #####
###### Header 6 ######

	Indented code blocks (spaces or tabs)

[Links](http://voyagetravelapps.com/)
![Images](<Name of asset in bundle>)

> Blockquotes

- Bulleted
- Lists
	- Including indented lists
		- Up to three levels
- Neat!

1. Ordered
1. Lists
	1. Including indented lists
		- Up to three levels
1. Neat! 

# SwiftyMarkdown 1.0

SwiftyMarkdown converts Markdown files and strings into `NSAttributedString`s using sensible defaults and a Swift-style syntax. It uses dynamic type to set the font size correctly with whatever font you'd like to use.

## Fully Rebuilt For 2020!

SwiftyMarkdown now features a more robust and reliable rules-based line processing and tokenisation engine. It has added support for images stored in the bundle (`![Image](<Name In bundle>)`), codeblocks, blockquotes, and unordered lists!

Line-level attributes can now have a paragraph alignment applied to them (e.g. `h2.aligment = .center`), and links can be underlined by setting underlineLinks to `true`. 

It also uses the system color `.label` as the default font color on iOS 13 and above for Dark Mode support out of the box. 

## Installation

### CocoaPods:

`pod 'SwiftyMarkdown'`

### SPM: 

In Xcode, `File -> Swift Packages -> Add Package Dependency` and add the GitHub URL. 

*italics* or _italics_
**bold** or __bold__
~~Linethrough~~Strikethroughs. 
`code`

# Header 1

or

Header 1
====

## Header 2

or

Header 2
---

### Header 3
#### Header 4
##### Header 5 #####
###### Header 6 ######

	Indented code blocks (spaces or tabs)

[Links](http://voyagetravelapps.com/)
![Images](<Name of asset in bundle>)

> Blockquotes

- Bulleted
- Lists
	- Including indented lists
		- Up to three levels
- Neat!

1. Ordered
1. Lists
	1. Including indented lists
		- Up to three levels
1. Neat! 
