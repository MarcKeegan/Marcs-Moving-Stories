/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI

extension Font {
    // MARK: - Google Sans Font Family
    
    /// Google Sans Regular font
    static func googleSans(size: CGFloat) -> Font {
        return .custom("GoogleSans-Regular", size: size)
    }
    
    /// Google Sans Italic font
    static func googleSansItalic(size: CGFloat) -> Font {
        return .custom("GoogleSans-Italic", size: size)
    }
    
    // MARK: - Semantic Font Styles
    
    /// Large title using Google Sans
    static var googleSansLargeTitle: Font {
        return googleSans(size: 34)
    }
    
    /// Title using Google Sans
    static var googleSansTitle: Font {
        return googleSans(size: 28)
    }
    
    /// Title 2 using Google Sans
    static var googleSansTitle2: Font {
        return googleSans(size: 22)
    }
    
    /// Title 3 using Google Sans
    static var googleSansTitle3: Font {
        return googleSans(size: 20)
    }
    
    /// Headline using Google Sans
    static var googleSansHeadline: Font {
        return googleSans(size: 17)
    }
    
    /// Body using Google Sans
    static var googleSansBody: Font {
        return googleSans(size: 17)
    }
    
    /// Callout using Google Sans
    static var googleSansCallout: Font {
        return googleSans(size: 16)
    }
    
    /// Subheadline using Google Sans
    static var googleSansSubheadline: Font {
        return googleSans(size: 15)
    }
    
    /// Footnote using Google Sans
    static var googleSansFootnote: Font {
        return googleSans(size: 13)
    }
    
    /// Caption using Google Sans
    static var googleSansCaption: Font {
        return googleSans(size: 12)
    }
    
    /// Caption 2 using Google Sans
    static var googleSansCaption2: Font {
        return googleSans(size: 11)
    }
}
