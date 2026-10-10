import SwiftUI

struct LearningPracticeView: View {
    @EnvironmentObject private var router: AppRouter
    var body: some View {
        List {
            Section {
                destination("Kana", caption: "Hiragana, katakana and combination sounds", route: .kanaPractice)
                destination("Grammar exercises", caption: "Choose a pattern and check its explanation", route: .grammarExercises)
                destination("Reading practice", caption: "Short passages with vocabulary and questions", route: .readingPractice)
            }.listRowBackground(Forest.surface)
            Section {
                destination("Daily study plan", caption: "A short plan from your collection and review dates", route: .dailyStudyPlan)
            }.listRowBackground(Forest.surface)
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden).background(Forest.canvas)
        .navigationTitle("Learning practice").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
    private func destination(_ title: String, caption: String, route: AppRoutes) -> some View {
        Button { router.push(route, hideNavBar: false) } label: {
            VStack(alignment: .leading, spacing: Forest.Space.s) {
                Text(title).font(.headline).foregroundStyle(Forest.ink)
                Text(caption).font(.subheadline).foregroundStyle(Forest.inkMuted)
            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }.buttonStyle(.plain)
    }
}
