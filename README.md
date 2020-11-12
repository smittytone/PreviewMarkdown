# PreviewMarkdown 1.1.2 #

A simple app that provides [Markdown](https://daringfireball.net/projects/markdown/syntax) file preview and thumbnailing extensions for Catalina and later versions of macOS.

![PreviewMarkdown App Store QR code](qr-code.jpg)

## Installation and Usage ##

Just run the host app once to register the extensions &mdash; you can quit the app as soon as it has launched. We recommend logging out of your Mac and back in again at this point. Now you can preview markdown documents using QuickLook (select an icon and hit Space), and Finder’s preview pane and **Info** panels.

You can disable and re-enable the Previewer and Thumbnailer extensions at any time in **System Preferences > Extensions > Quick Look**.

For more information on the background to this app, please see this [blog post](https://smittytone.wordpress.com/2019/11/07/create_previews_macos_catalina/).

## Release Notes ##

- 1.1.2 *Unreleased*
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

Primary app code and UI design &copy; 2020, Tony Smith.

Code portions &copy; 2020 Simon Fairbairn.
