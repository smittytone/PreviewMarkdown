# PreviewMarkdown 1.4.2 #

This app provides [Markdown](https://daringfireball.net/projects/markdown/syntax) file preview and thumbnailing extensions for Catalina and later versions of macOS.

![PreviewMarkdown App Store QR code](qr-code.jpg)

## Installation and Usage ##

Just run the host app once to register the extensions &mdash; you can quit the app as soon as it has launched. We recommend logging out of your Mac and back in again at this point. Now you can preview markdown documents using QuickLook (select an icon and hit Space), and Finder’s preview pane and **Info** panels.

You can disable and re-enable the Previewer and Thumbnailer extensions at any time in **System Preferences > Extensions > Quick Look**.

### Adjusting the Preview ###

You can alter some of the key elements of the preview by using the **Preferences** panel:

* The colour of code blocks.
* Code blocks’ monospaced font.
* The base body text size.
* The body text font.
* Whether preview should be display white-on-black even in Dark Mode.

Changing these settings will affect previews immediately, but may not affect thumbnail until you open a folder that has not been previously opened in the current login session.

For more information on the background to this app, please see this [blog post](https://smittytone.wordpress.com/2019/11/07/create_previews_macos_catalina/).

### YAML Front Matter ###

Version 1.3.0 adds optional support for rendering YAML front matter in Markdown files. To enable it, go to **Preview Markdown > Preferences...** and check the **Show YAML front matter** checkbox. YAML will appear in QuickLook previews only.

## Source Code ##

This repository contains the primary source code for PreviewMarkdown. Certain graphical assets, code components and data files are not included. To build PreviewMarkdown from scratch, you will need to add these files yourself or remove them from your fork.

## Acknowledgements ##

PreviewMarkdown’s app extensions contain [SwiftyMarkdown](https://github.com/SimonFairbairn/SwiftyMarkdown) by Simon Fairbairn and other contributors, and [YamlSwift](https://github.com/behrang/YamlSwift) by Behrang Noruzi Niya and other contributors.

## Release Notes ##

* 1.4.2 *Unreleased*
    * Upgrade to SwiftyMarkdown 1.2.4.

* 1.4.1 *20 November 2021*
    * Disable selection of thumbnail tags under macOS 12 Monterey to avoid clash with system-added tags.
* 1.4.0 *28 July 2021*
    * Allow any installed font to be selected.
    * Allow the heading colour to be selected.
    * Allow any colour to be chosen using macOS’ colour picker.
    * Tighten the thumbnailer code.
    * Fixed a rare bug in the previewer error reporting code.
* 1.3.1 *18 June 2021*
    * Add links to other PreviewApps.
    * Support macOS 11 Big Sur’s UTType API.
    * Stability improvements.
* 1.3.0 *9 May 2021*
    * Add optional presentation of YAML front matter to previews.
    * Recode Thumbnailer to make it thread safe: this should prevent crashes leading to generic or editor-specific thumbnail icons being seen.
    * Update user-agent string.
    * Minor code and UI improvements.
* 1.2.0 *4 February 2021*
    * Add preview display preferences (requested by various anonymous feedback senders)
    * Add file type ident tag to thumbnails (requested by @chamiu).
    * Add **What’s New** sheet to be shown with new major/minor versions.
    * Include local markdown UTI with user-submitted feedback.
    * Add link for app reviews.
* 1.1.4 *16 January 2021*
    * Add UTI `net.ia.markdown`.
* 1.1.3 *14 January 2021*
    * Add UTI `pro.writer.markdown`.
* 1.1.2 *18 November 2020*
    * Apple Silicon version included.
* 1.1.1 *1 October 2020*
    * Add report bugs/send feedback mechanism.
    * Add usage advice to main window.
    * Handle markdown formatting not yet rendered by SwiftyMarkdown: three-tick code blocks, HTML symbols, space-inset lists.
* 1.1.0 *25 September 2020*
    * Add macOS Big Sur support.
    * Better macOS dark/light mode support.
    * Migrate engine to [SwiftyMarkdown 1.2.3](https://github.com/SimonFairbairn/SwiftyMarkdown).
* 1.0.5 *9 April 2020*
    * App Store release version.
* 1.0.4 *Unreleased*
    * Minor cosmetic changes to app menus.
* 1.0.3 *10 December 2019*
    * Add version number to app’s info panel.
* 1.0.2 *4 December 2019*
    * Fix random crash (`string index out of range` in SwiftyMarkdown).
* 1.0.1 *20 November 2019*
    * Correct thumbnailer styles.
* 1.0.0 *8 November 2019*
    * Initial public release.

## Copyright and Credits ##

Primary app code and UI design &copy; 2022, Tony Smith.

Code portions &copy; 2022 Simon Fairbairn. Code portions &copy;2021 Behrang Noruzi Niya.
