//
//  Forest.swift
//  SwiftUIApps
//

import SwiftUI
import UIKit

/// Design tokens from DESIGN.md. Change values there first, then mirror them here.
enum Forest {
    static let canvas = Color(light: 0xF1EFE3, dark: 0x141813)
    static let surface = Color(light: 0xFDFCF8, dark: 0x1D231C)
    static let sunken = Color(light: 0xE4E8D8, dark: 0x263025)
    static let ink = Color(light: 0x22281F, dark: 0xECEEE4)
    static let inkMuted = Color(light: 0x5B6356, dark: 0xA6AE9E)
    static let line = Color(light: 0xDAD8C6, dark: 0x2F382D)
    static let moss = Color(light: 0x45694D, dark: 0x8DB592)
    static let onMoss = Color(light: 0xFFFFFF, dark: 0x10170F)
    static let danger = Color(light: 0xA8402F, dark: 0xE0806E)

    enum Radius {
        static let card: CGFloat = 12
        static let tile: CGFloat = 10
    }

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 40
    }
}

extension Font {
    static let headwordFace = "HiraMinProN-W6"

    /// Hiragino Mincho for Japanese headwords; scales with Dynamic Type.
    static func headword(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom(headwordFace, size: size, relativeTo: style)
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
