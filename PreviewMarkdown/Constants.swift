/*
 *  Constants.swift
 *  PreviewMarkdown
 *
 *  Created by Tony Smith on 12/08/2020.
 *  Copyright © 2023 Tony Smith. All rights reserved.
 */


// Combine the app's various constants into a struct
import Foundation


struct BUFFOON_CONSTANTS {

    struct ERRORS {

        struct CODES {
            static let NONE                 = 0
            static let FILE_INACCESSIBLE    = 400
            static let FILE_WONT_OPEN       = 401
            static let BAD_MD_STRING        = 402
            static let BAD_TS_STRING        = 403
        }

        struct MESSAGES {
            static let NO_ERROR             = "No error"
            static let FILE_INACCESSIBLE    = "Can't access file"
            static let FILE_WONT_OPEN       = "Can't open file"
            static let BAD_MD_STRING        = "Can't get markdown data"
            static let BAD_TS_STRING        = "Can't access NSTextView's TextStorage"
        }
    }

    struct THUMBNAIL_SIZE {

        static let ORIGIN_X                 = 0
        static let ORIGIN_Y                 = 0
        static let WIDTH                    = 768
        static let HEIGHT                   = 1024
        static let ASPECT                   = 0.75
        static let TAG_HEIGHT               = 204.8
        static let FONT_SIZE                = 130.0
    }

    static let PREVIEW_FONT_SIZE            = 16.0
    static let THUMBNAIL_FONT_SIZE: Float   = 18.0
    static let SPACES_FOR_A_TAB             = 4

    // FROM 1.2.0
    static let CODE_COLOUR_INDEX            = 0
    static let LINK_COLOUR_INDEX            = 2
    static let CODE_FONT_INDEX              = 0
    static let BODY_FONT_INDEX              = 0
    static let FONT_SIZE_OPTIONS: [CGFloat] = [10.0, 12.0, 14.0, 16.0, 18.0, 24.0, 28.0]

    // FROM 1.3.0
    static let YAML_INDENT                  = 2

    // FROM 1.3.1
    static let URL_MAIN                     = "https://smittytone.net/previewmarkdown/index.html"
    static let APP_STORE                    = "https://apps.apple.com/us/app/previewmarkdown/id1492280469"
    static let SUITE_NAME                   = ".suite.previewmarkdown"

    static let TAG_TEXT_SIZE                = 180 //124
    static let TAG_TEXT_MIN_SIZE            = 118
    
    // FROM 1.4.0
    static let LINK_COLOUR_HEX              = "0096FFFF"
    static let HEAD_COLOUR_HEX              = "941751FF"
    static let CODE_COLOUR_HEX              = "00FF00FF"
    static let BODY_FONT_NAME               = "System"
    static let CODE_FONT_NAME               = "Courier"
    
    static let SAMPLE_UTI_FILE              = "sample.md"

    // FROM 1.4.1
    static let THUMBNAIL_LINE_COUNT         = 40
    
    // FROM 1.4.3
    static let APP_CODE_PREVIEWER           = "com.bps.PreviewMarkdown.Previewer"
    
    // FROM 1.4.6
    struct APP_URLS {
        
        static let PM                           = "https://apps.apple.com/us/app/previewmarkdown/id1492280469?ls=1"
        static let PC                           = "https://apps.apple.com/us/app/previewcode/id1571797683?ls=1"
        static let PY                           = "https://apps.apple.com/us/app/previewyaml/id1564574724?ls=1"
        static let PJ                           = "https://apps.apple.com/us/app/previewjson/id6443584377?ls=1"
        static let PT                           = "https://apps.apple.com/us/app/previewtext/id1660037028?ls=1"
    }
    
    static let WHATS_NEW_PREF                   = "com-bps-previewmarkdown-do-show-whats-new-"
    
    // FROM 1.4.7
    static let SYS_LAUNCH_SERVICES              = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
}
