//
//  HomeView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 17/05/25.
//

import SwiftUI

struct HomeView: View {
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
            }
            .padding(.horizontal, Forest.Space.l)
            .padding(.top, Forest.Space.s)
            
            switch kind {
            case .words:
                AppComposer.shared.makeKanaView()
            case .kanji:
                AppComposer.shared.makeKanjiView()
            }
        }
        .background(Forest.canvas)
    }
}

#Preview {
    HomeView()
}
