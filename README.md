# PreviewMarkdown 2.3.0

This app provides [Markdown](https://daringfireball.net/projects/markdown/syntax) file preview and thumbnailing extensions for versions of macOS 10.15 or above.

Version 2.0.0 features a brand new rendering engine which adds support for tables, source code highlighting, nested blockquotes and more. It adds preliminary img support

[![PreviewMarkdown App Store QR code](qr-code.jpg)](https://apps.apple.com/gb/app/previewmarkdown/id1492280469)

## Installation and Usage

Just run the host app once to register the extensions &mdash; you can quit the app as soon as it has launched. We recommend logging out of your Mac and back in again at this point. Now you can preview markdown documents using QuickLook (select an icon and hit Space), and Finder’s preview pane and **Info** panels.

You can disable and re-enable the Previewer and Thumbnailer extensions at any time in **System Preferences > Extensions > Quick Look**.

### Adjusting the Preview

You can alter some of the key elements of the preview by using the **Preferences** panel:

- The base body font and text size.
- The monospaced code font.
- The colour of headlines, code, blockquotes and link text.
- Whether YAML front matter should be displayed too. This is handy if you are a [Hugo](https://gohugo.io) or [Jekyll](https://jekyllrb.com) user — [see below for more details](#yaml-front-matter).
- Whether preview should be display white-on-black even in macOS’ Dark Mode.

Changing these settings will affect previews immediately, but may not affect thumbnails until you open a folder that has not been previously opened in the current login session, or you log out of your macOS user account. This is because Finder caches thumbnails generated in a given session.

### YAML Front Matter

*PreviewMarkdown* supports rendering YAML front matter in Markdown files. To enable it, go to **Preview Markdown > Preferences...** and check the **Show YAML front matter** checkbox. YAML will appear in QuickLook previews only, not thumbnails.

YAML front matter can be delimited with both `---` and `---`, and `---` and `...` start and end markers, as per [the YAML 1.2 specification](https://yaml.org).

## Known Issues

1. Tables containing nested remote images may take an extended time to render while `NSAttributedString`’s WebKit-based HTML parser attempts to request the image, which ultimately fails. We are exploring mitigations.
1. Tables are intermittently rendered with horizontal blanks in place of borders. Resizing the preview window fixes them (though may cause other horizontal lines to disappear). We are exploring mitigations but believe this is an issue with macOS’ TextKit.
1. Users of Markdown editing tools like OneMarkdown and Marked may not see PreviewMarkdown-produced previews. This is because those apps claim ownership of key Markdown file UTIs which may cause Finder to pre-empt PreviewMarkdown. There is no workaround at this time.

## Source Code

This repository contains the primary source code for *PreviewMarkdown*. Certain graphical assets, code components and data files are not included. To build *PreviewMarkdown* from scratch, you will need to add these files yourself or remove them from your fork’s Xcode project.

The files `REPLACE_WITH_YOUR_FUNCTIONS` and `REPLACE_WITH_YOUR_CODES` must be replaced with your own files. The former will contain your `sendFeedback(_ feedback: String) -> URLSessionTask?` function. The latter your Developer Team ID, used as the App Suite identifier prefix.

You will need to generate your own `Assets.xcassets` file containing the app icon.

You will need to create your own `new` directory containing your own `new.html` file.

## Acknowledgements

PreviewMarkdown’s app extensions contains [YamlSwift](https://github.com/behrang/YamlSwift) by Behrang Noruzi Niya and other contributors, and [Markdown-It](https://github.com/markdown-it/markdown-it) by Vitaly Puzrin and Alex Kocharin.

## Release Notes

See [CHANGELOG.md](CHANGELOG.md)

## Copyright and Credits ##

Primary app code and UI design &copy; 2026, Tony Smith.

Code portions &copy; 2014-2026 Vitaly Puzrin, Alex Kocharin; &copy; 2006-2026, Josh Goebel and Other Contributors; &copy; 2015 Behrang Noruzi Niya. 
