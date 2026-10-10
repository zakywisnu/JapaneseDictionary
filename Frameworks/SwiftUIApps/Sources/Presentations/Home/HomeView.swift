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
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Forest.Space.l) {
                ScreenHeader(
                    title: "Today",
                    caption: Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))
                )
                AppComposer.shared.makeDailyGoalSummaryView()
                StudyKindPicker(selection: $kind)
                Button("Practice difficult items") { router.push(.difficult, hideNavBar: false) }.buttonStyle(.plain).foregroundStyle(Forest.ink).frame(minHeight: 44)
            }
            .padding(.horizontal, Forest.Space.l)
            .padding(.top, Forest.Space.s)
            
            switch kind {
            case .words:
                AppComposer.shared.makeKanaView()
            case .kanji:
                AppComposer.shared.makeKanjiView()
            case .grammar, .sentences, .cards:
                AppComposer.shared.makeMaterialsTodayView(kind: kind.savedKind).id(kind)
            }
        }
        .background(Forest.canvas)
    }
}

#Preview {
    HomeView()
}
