# PreviewMarkdown 2.0.0

This app provides [Markdown](https://daringfireball.net/projects/markdown/syntax) file preview and thumbnailing extensions for versions of macOS 10.15 or above.

Version 2.0.0 features a brand new rendering engine which adds support for tables, source code highligting, nested blockquotes and more. It adds preliminary img support

![PreviewMarkdown App Store QR code](qr-code.jpg)

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

Users of Markdown editing tools like OneMarkdown and Marked may not see PreviewMarkdown-produced previews. This is because those apps claim ownership of key Markdown file UTIs which may cause Finder to pre-empt PreviewMarkdown. There is no workaround at this time.

## Source Code

This repository contains the primary source code for *PreviewMarkdown*. Certain graphical assets, code components and data files are not included. To build *PreviewMarkdown* from scratch, you will need to add these files yourself or remove them from your fork’s Xcode project.

The files `REPLACE_WITH_YOUR_FUNCTIONS` and `REPLACE_WITH_YOUR_CODES` must be replaced with your own files. The former will contain your `sendFeedback(_ feedback: String) -> URLSessionTask?` function. The latter your Developer Team ID, used as the App Suite identifier prefix.

You will need to generate your own `Assets.xcassets` file containing the app icon.

You will need to create your own `new` directory containing your own `new.html` file.

## Acknowledgements

PreviewMarkdown’s app extensions contains [YamlSwift](https://github.com/behrang/YamlSwift) by Behrang Noruzi Niya and other contributors and [Markdown-It](https://github.com/markdown-it/markdown-it) by Vitaly Puzrin and Alex Kocharin.

## Release Notes

- 2.0.0 *Unreleased*
    - Introduce a new rendering engine which leverages [Markdown-It](https://github.com/markdown-it/markdown-it).
- 1.5.3 *7 September 2024*
    - Improve settings change checking.
    - Correctly render the YAML frontmatter separator line: revert NSTextViews to TextKit 1 (previously bumped to TextKit 2 by Xcode).
- 1.5.2 *13 May 2024*
    - Revise thumbnailer to improve memory utilization and efficiency.
- 1.5.1 *2 November 2023*
    - Support the emerging `public.markdown` UTI.
    - Support YAML front matter that uses the `...` end marker (Thanks, anonymous).
    - Better **What’s New** dialog presentation in dark mode.
- 1.5.0 *1 October 2023*
    - Use *PreviewApps*’ new preview element colour selection UI.
    - Allow link colours to be changed.
    - Allow blockquote colours to be changed.
    - Add line-spacing setting for previews.
    - Add link to help on **Preferences** panel.
    - Add experimental Finder UTI database reset option.
    - Rename extensions `Markdown Previewer` and `Markdown Thumbnailer`.
    - Improve font edge-case handling.
    - Fix link text formatting.
    - Remove dynamic UTIs.
- 1.4.6 *21 January 2023*
    - Add link to [PreviewText](https://smittytone.net/previewtext/index.html).
    - Better menu handling when panels are visible.
    - Better app exit management.
- 1.4.5 *23 December 2022*
    - Add UTI `com.nutstore.down`.
- 1.4.4 *2 October 2022*
    - Fix UTI generation.
    - Add link to [PreviewJson](https://smittytone.net/previewjson/index.html).
- 1.4.3 *26 August 2022*
    - Initial support for non-utf8 source code file encodings.
- 1.4.2 *7 August 2022*
    - Upgrade to SwiftyMarkdown 1.2.4.
    - Support checkboxes (`[x]`, `[ ]`).
- 1.4.1 *20 November 2021*
    - Disable selection of thumbnail tags under macOS 12 Monterey to avoid clash with system-added tags.
- 1.4.0 *28 July 2021*
    - Allow any installed font to be selected.
    - Allow the heading colour to be selected.
    - Allow any colour to be chosen using macOS’ colour picker.
    - Tighten the thumbnailer code.
    - Fixed a rare bug in the previewer error reporting code.
- 1.3.1 *18 June 2021*
    - Add links to other PreviewApps.
    - Support macOS 11 Big Sur’s UTType API.
    - Stability improvements.
- 1.3.0 *9 May 2021*
    - Add optional presentation of YAML front matter to previews.
    - Recode Thumbnailer to make it thread safe: this should prevent crashes leading to generic or editor-specific thumbnail icons being seen.
    - Update user-agent string.
    - Minor code and UI improvements.
- 1.2.0 *4 February 2021*
    - Add preview display preferences (requested by various anonymous feedback senders)
    - Add file type ident tag to thumbnails (requested by @chamiu).
    - Add **What’s New** sheet to be shown with new major/minor versions.
    - Include local markdown UTI with user-submitted feedback.
    - Add link for app reviews.
- 1.1.4 *16 January 2021*
    - Add UTI `net.ia.markdown`.
- 1.1.3 *14 January 2021*
    - Add UTI `pro.writer.markdown`.
- 1.1.2 *18 November 2020*
    - Apple Silicon version included.
- 1.1.1 *1 October 2020*
    - Add report bugs/send feedback mechanism.
    - Add usage advice to main window.
    - Handle markdown formatting not yet rendered by SwiftyMarkdown: three-tick code blocks, HTML symbols, space-inset lists.
- 1.1.0 *25 September 2020*
    - Add macOS Big Sur support.
    - Better macOS dark/light mode support.
    - Migrate engine to [SwiftyMarkdown 1.2.3](https://github.com/SimonFairbairn/SwiftyMarkdown).
- 1.0.5 *9 April 2020*
    - App Store release version.
- 1.0.4 *Unreleased*
    - Minor cosmetic changes to app menus.
- 1.0.3 *10 December 2019*
    - Add version number to app’s info panel.
- 1.0.2 *4 December 2019*
    - Fix random crash (`string index out of range` in SwiftyMarkdown).
- 1.0.1 *20 November 2019*
    - Correct thumbnailer styles.
- 1.0.0 *8 November 2019*
    - Initial public release.

## Copyright and Credits ##

Primary app code and UI design &copy; 2024, Tony Smith.

Code portions &copy; 2022 Simon Fairbairn. Code portions &copy; 2021 Behrang Noruzi Niya.
