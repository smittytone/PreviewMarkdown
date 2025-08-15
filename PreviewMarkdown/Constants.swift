/*
 *  Constants.swift
 *  PreviewMarkdown
 *
 *  Created by Tony Smith on 12/08/2020.
 *  Copyright © 2025 Tony Smith. All rights reserved.
 */


// Combine the app's various constants into a struct
import Foundation


struct BUFFOON_CONSTANTS {

    // FROM 1.0.0
    struct ERRORS {

        struct CODES {
            static let NONE                     = 0
            static let FILE_INACCESSIBLE        = 400
            static let FILE_WONT_OPEN           = 401
            static let BAD_MD_STRING            = 402
            static let BAD_TS_STRING            = 403
        }

        struct MESSAGES {
            static let NO_ERROR                 = "No error"
            static let FILE_INACCESSIBLE        = "Can't access file"
            static let FILE_WONT_OPEN           = "Can't open file"
            static let BAD_MD_STRING            = "Can't get markdown data"
            static let BAD_TS_STRING            = "Can't access NSTextView's TextStorage"
        }
    }

    // FROM 1.3.1
    static let URL_MAIN                         = "https://smittytone.net/previewmarkdown/index.html"
    static let SUITE_NAME                       = ".suite.previewmarkdown"
    static let SAMPLE_UTI_FILE                  = "sample.md"

    // FROM 1.4.3
    static let APP_CODE_PREVIEWER               = "com.bps.PreviewMarkdown.Previewer"
    
    // FROM 1.4.6
    struct APP_STORE_URLS {
        
        static let PM                           = "https://apps.apple.com/us/app/previewmarkdown/id1492280469"
        static let PC                           = "https://apps.apple.com/us/app/previewcode/id1571797683"
        static let PY                           = "https://apps.apple.com/us/app/previewyaml/id1564574724"
        static let PJ                           = "https://apps.apple.com/us/app/previewjson/id6443584377"
        static let PT                           = "https://apps.apple.com/us/app/previewtext/id1660037028"
    }
    
    // FROM 1.5.0
    static let SYS_LAUNCH_SERVICES              = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

    struct PREFS_IDS {
        
        static let MAIN_WHATS_NEW               = "com-bps-previewmarkdown-do-show-whats-new-"
        static let PREVIEW_BODY_FONT_SIZE       = "com-bps-previewmarkdown-base-font-size"
        static let PREVIEW_BODY_FONT_NAME       = "com-bps-previewmarkdown-body-font-name"
        static let PREVIEW_CODE_FONT_NAME       = "com-bps-previewmarkdown-code-font-name"
        static let PREVIEW_USE_LIGHT            = "com-bps-previewmarkdown-do-use-light"
        static let PREVIEW_SHOW_YAML            = "com-bps-previewmarkdown-do-show-front-matter"
        static let PREVIEW_LINK_COLOUR          = "com-bps-previewmarkdown-link-colour-hex"
        static let PREVIEW_CODE_COLOUR          = "com-bps-previewmarkdown-code-colour-hex"
        static let PREVIEW_HEAD_COLOUR          = "com-bps-previewmarkdown-head-colour-hex"
        static let PREVIEW_QUOTE_COLOUR         = "com-bps-previewmarkdown-quote-colour-hex"
        static let PREVIEW_YAML_KEY_COLOUR      = "com-bps-previewmarkdown-yaml-key-colour-hex"
        static let PREVIEW_LINE_SPACE           = "com-bps-previewmarkdown-line-spacing"
        static let THUMB_FONT_SIZE              = "com-bps-previewmarkdown-thumb-font-size"
        static let THUMB_SHOW_TAG               = "com-bps-previewmarkdown-do-show-tag"
        static let PREVIEW_SHOW_MARGIN          = "com-bps-previewmarkdown-do-show-margin"
    }
    
    // FROM 2.0.0
    static let MISSING_IMG                      = "missing-img"
    static let LOCKED_IMG                       = "locked-img"
    static let MAX_FEEDBACK_SIZE                = 512
    
    struct COLOUR_IDS {
        
        static let HEADS                        = "heads"
        static let CODE                         = "code"
        static let LINKS                        = "links"
        static let QUOTES                       = "quote"
        static let YAML_KEYS                    = "yamlkeys"
        static let NEW_HEADS                    = "new_heads"
        static let NEW_CODE                     = "new_code"
        static let NEW_LINKS                    = "new_links"
        static let NEW_QUOTES                   = "new_quote"
        static let NEW_YAML_KEYS                = "new_yamlkeys"
    }

    // FROM 2.1.0
    static let COLOUR_OPTIONS                   = [BUFFOON_CONSTANTS.COLOUR_IDS.HEADS,
                                                   BUFFOON_CONSTANTS.COLOUR_IDS.CODE,
                                                   BUFFOON_CONSTANTS.COLOUR_IDS.LINKS,
                                                   BUFFOON_CONSTANTS.COLOUR_IDS.QUOTES,
                                                   BUFFOON_CONSTANTS.COLOUR_IDS.YAML_KEYS]

    static let BULLET_STYLES                    = ["\u{25CF}",
                                                   "\u{25CB}",
                                                   "\u{25A0}",
                                                   "\u{25A1}",
                                                   "\u{25C6}",
                                                   "\u{25C7}"]

    static let SUPPORTED_TAGS                   = ["p", "a",
                                                   "h1", "h2", "h3", "h4", "h5", "h6",
                                                   "pre", "code", "kbd", "img",
                                                   "li", "blockquote",
                                                   "em", "strong", "s",
                                                   "sub", "sup"]

    static let CHARACTER_STYLES                 = ["strong", "em", "a", "s", "img", "sub", "sup", "code", "kbd"]

    static let PREVIEW_MARGIN_WIDTH             = 16.0
    static let PREVIEW_MARGIN_SIZE              = NSSize(width: PREVIEW_MARGIN_WIDTH, height: PREVIEW_MARGIN_WIDTH)
    static let HTML_ESCAPE_REGEX                = try! NSRegularExpression(pattern: "&#?[a-zA-Z0-9]+?;", options: .caseInsensitive)

    struct MULTIPLIER {

        static let H1                           = 2.6
        static let H2                           = 2.2
        static let H3                           = 1.8
        static let H4                           = 1.4
        static let H5                           = 1.2
        static let H6                           = 1.2
        static let BLOCK                        = 1.6
        static let BASELINE_SHIFT               = 0.67
        static let SUB_OFFSET                   = -5.0
        static let SUPER_OFFSET                 = 10.0
    }

    struct INSET {

        static let LIST                         = 50.0
        static let BLOCK                        = 50.0
        static let YAML                         = 2
    }

    struct HEX_COLOUR {

        static let HEAD                         = "941751FF"
        static let CODE                         = "00FF00FF"
        static let LINK                         = "0096FFFF"
        static let QUOTE                        = "22528EFF"
        static let YAML                         = "00FF00FF"
    }

    struct PREVIEW_SIZE {

        static let FONT_SIZE                    = 16.0
        static let FONT_SIZE_OPTIONS: [CGFloat] = [10.0, 12.0, 14.0, 16.0, 18.0, 24.0, 28.0]
        static let LINE_SPACING                 = 1.0
    }

    struct THUMBNAIL_SIZE {

        static let ORIGIN_X                     = 0
        static let ORIGIN_Y                     = 0
        static let WIDTH                        = 768
        static let HEIGHT                       = 1024
        static let ASPECT                       = 0.75
        static let TAG_HEIGHT                   = 204.8
        static let FONT_SIZE: Float             = 18.0
        static let LINE_COUNT                   = 40
    }

    struct FONT_NAME {

        static let BODY                         = "SFPro-Regular"
        static let CODE                         = "AndaleMono"
    }

    struct FONT_WEIGHT {

        static let BOLD                         = 10
        static let ITALIC                       = 5
    }

    struct DELIMITERS {

        static let HTML_START                   = "<"
        static let HTML_END                     = ">"
    }

    struct LINE_END {

        static let LF                           = "\n"
        static let WINDOWS                      = "\n\r"
#if PARASYM
        static let BREAK                        = "†\u{2028}"
        static let FEED                         = "¶\u{2029}"
#else
        static let BREAK                        = "\u{2028}"
        static let FEED                         = "\u{2029}"
#endif
    }
}


// MARK: - Legacy Constants

// FROM 1.0.0
//static let PREVIEW_FONT_SIZE                = 16.0
//static let THUMBNAIL_FONT_SIZE: Float       = 18.0
//static let SPACES_FOR_A_TAB                 = 4
//static let TAG_TEXT_SIZE                    = 180 //124
//static let TAG_TEXT_MIN_SIZE                = 118

// FROM 1.2.0
//static let CODE_COLOUR_INDEX                = 0
//static let LINK_COLOUR_INDEX                = 2
//static let CODE_FONT_INDEX                  = 0
//static let BODY_FONT_INDEX                  = 0
//static let FONT_SIZE_OPTIONS: [CGFloat]     = [10.0, 12.0, 14.0, 16.0, 18.0, 24.0, 28.0]

// FROM 1.3.0
//static let YAML_INDENT                      = 2

// FROM 1.3.1
//static let APP_STORE                      = "https://apps.apple.com/us/app/previewmarkdown/id1492280469"

// FROM 1.4.1
//static let THUMBNAIL_LINE_COUNT             = 40

// FROM 1.4.0
//static let BODY_FONT_NAME                   = "SFPro-Regular"
//static let CODE_FONT_NAME                   = "AndaleMono"
//static let HEAD_COLOUR_HEX                  = "941751FF"
//static let CODE_COLOUR_HEX                  = "00FF00FF"
//static let LINK_COLOUR_HEX                  = "0096FFFF"
//static let QUOTE_COLOUR_HEX                 = "22528EFF"
//static let YAML_KEY_COLOUR_HEX              = "00FF00FF"

// FROM 1.5.0
//static let BASE_LINE_SPACING                = 1.0
