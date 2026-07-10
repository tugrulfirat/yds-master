import SwiftUI
import SpriteKit
#if canImport(UIKit)
import UIKit
#endif

/// Central lookup for user-provided artwork.
///
/// Drop PNGs into Assets.xcassets using the names documented in ASSETS.md
/// (e.g. "cannon_barrel", "shield", "golem", "arena_wordCannon") and they
/// automatically replace the code-drawn placeholder graphics — no code
/// changes needed. Missing assets fall back to the vector placeholders.
enum GameAssets {

    static func has(_ name: String) -> Bool {
        #if canImport(UIKit)
        return UIImage(named: name) != nil
        #else
        return false
        #endif
    }

    /// SwiftUI image, or nil if the asset hasn't been added yet.
    static func image(_ name: String) -> Image? {
        has(name) ? Image(name) : nil
    }

    /// SpriteKit texture, or nil if the asset hasn't been added yet.
    static func texture(_ name: String) -> SKTexture? {
        #if canImport(UIKit)
        guard let ui = UIImage(named: name) else { return nil }
        return SKTexture(image: ui)
        #else
        return nil
        #endif
    }
}
