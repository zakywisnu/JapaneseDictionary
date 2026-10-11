import SwiftUI

struct LearningPracticeView: View {
    var isTabRoot = false
    @EnvironmentObject private var router: AppRouter
    var body: some View {
        List {
            if isTabRoot { ScreenHeader(title: "Practice").listRowBackground(Forest.canvas) }
            Section {
                destination("Starter path", caption: "Eight steps connecting kana, grammar and reading", route: .learningPath)
                destination("Conjugation", caption: "Practice explicit verb and adjective forms", route: .conjugationPractice())
                destination("Sentence building", caption: "Arrange words and understand their particles", route: .sentenceBuilding())
                destination("Listening comprehension", caption: "Hear short passages and answer meaning questions", route: .listeningComprehension())
                destination("Typed practice", caption: "Recall supplied readings and kana romanization", route: .typedPractice)
                destination("Listening practice", caption: "Listen first, then type the supplied reading", route: .listeningPractice)
                destination("Speaking practice", caption: "Record, replay and compare recognized phrases", route: .speakingPractice)
                destination("Kana", caption: "Hiragana, katakana and combination sounds", route: .kanaPractice)
                destination("Grammar exercises", caption: "Choose a pattern and check its explanation", route: .grammarExercises)
                destination("Reading practice", caption: "Short passages with vocabulary and questions", route: .readingPractice)
            }.listRowBackground(Forest.surface)
            Section {
                destination("Exercise history", caption: "Your saved answers and explanations", route: .exerciseHistory)
                destination("Practice mistakes", caption: "Retry questions you last answered incorrectly", route: .mistakeReview)
                destination("Daily study plan", caption: "A short plan from your collection and review dates", route: .dailyStudyPlan)
            }.listRowBackground(Forest.surface)
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden).background(Forest.canvas)
        .navigationTitle("Learning practice").navigationBarTitleDisplayMode(.inline)
        .toolbar(isTabRoot ? .hidden : .visible, for: .navigationBar)
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
