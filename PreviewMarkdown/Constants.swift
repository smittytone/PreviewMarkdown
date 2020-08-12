
//  Constants.swift
//  PreviewMarkdown
//
//  Created by Tony Smith on 12/08/2020.
//  Copyright © 2020 Tony Smith. All rights reserved.


// Combine the app's various constants into a struct

struct BUFFOON_CONSTANTS {

    struct ERRORS {

        struct CODES {
            static let NONE                 = 0
            static let FILE_INACCESSIBLE    = 400
            static let FILE_WONT_OPEN       = 401
            static let BAD_MD_STRING        = 402
        }

        struct MESSAGES {
            static let NO_ERROR             = "No error"
            static let FILE_INACCESSIBLE    = "Can't access file"
            static let FILE_WONT_OPEN       = "Can't open file"
            static let BAD_MD_STRING        = "Can't get markdown data"
        }
    }


    struct THUMBNAIL_SIZE {
        static let ORIGIN_X             = 0
        static let ORIGIN_Y             = 0
        static let WIDTH                = 768
        static let HEIGHT               = 1024
        static let ASPECT               = 0.75
    }


    static let BASE_PREVIEW_FONT_SIZE       = 16.0
    static let BASE_THUMB_FONT_SIZE         = 14.0
}
