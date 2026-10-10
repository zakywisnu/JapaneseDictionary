//
//  HomeView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 17/05/25.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var router: AppRouter
    @AppStorage("todayStudyKind") private var kind: StudyKind = .words
    
    var body: some View {
        Group {
            switch kind {
            case .words:
                AppComposer.shared.makeKanaView()
            case .kanji:
                AppComposer.shared.makeKanjiView()
            case .grammar, .sentences, .cards:
                AppComposer.shared.makeMaterialsTodayView(kind: kind.savedKind).id(kind)
            }
        }
        .environment(\.showsTodayHeader, true)
        .background(Forest.canvas)
    }
}

#Preview {
    HomeView()
}
