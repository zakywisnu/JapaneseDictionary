//
//  ViewPagerTabs.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 20/05/25.
//

import SwiftUI
import ZeroDesignKit

enum ViewPagerTabs: TabItem {
    case kotoba
    case kanji
    
    var title: String {
        switch self {
        case .kotoba:
            return "Kotoba"
        case .kanji:
            return "Kanji"
        }
    }
    
    var symbolImage: String {
        switch self {
        case .kotoba:
            return "character.textbox"
        case .kanji:
            return "character.magnify"
        }
    }
    
    var activeBackgroundColor: Color {
        DefaultColors.accent
    }
    
    var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
    
    func view() -> some View {
        switch self {
        case .kotoba:
            AppComposer.shared.makeKanaView()
                .id(ViewPagerTabs.kotoba)
        case .kanji:
            AppComposer.shared.makeKanjiView()
                .id(ViewPagerTabs.kanji)
        }
    }
}
