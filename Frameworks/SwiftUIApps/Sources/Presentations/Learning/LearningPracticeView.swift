import SwiftUI

public enum PracticeSkill: String, Hashable {
    case kana = "Kana and recall", grammar = "Grammar", listening = "Listening"
}

struct LearningPracticeView: View {
    var isTabRoot = false
    @EnvironmentObject private var router: AppRouter
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Forest.Space.xl) {
                    if isTabRoot { ScreenHeader(title: "Practice") }
                    VStack(alignment: .leading, spacing: Forest.Space.m) {
                        Text("Starter path").font(.title2.weight(.semibold))
                        Text("Eight connected steps in kana, grammar and reading.").font(.subheadline).foregroundStyle(Forest.inkMuted)
                        Button("Open starter path") { router.push(.learningPath, hideNavBar: false) }.buttonStyle(PrimaryButtonStyle())
                    }
                }
            }.listRowBackground(Forest.canvas).listRowInsets(EdgeInsets(top: Forest.Space.m, leading: 0, bottom: Forest.Space.s, trailing: 0))
            Section("Choose a skill") {
                row("Kana and recall", "Kana and typed recall", .practiceSkill(.kana))
                row("Grammar", "Patterns, forms and word order", .practiceSkill(.grammar))
                row("Reading", "Passages and questions", .readingPractice)
                row("Listening", "Readings and short passages", .practiceSkill(.listening))
                row("Speaking", "Record and replay phrases", .speakingPractice)
            }.listRowBackground(Forest.surface).textCase(nil)
            Section {
                DisclosureGroup("Practice options") {
                    row("Practice mistakes", "Retry your latest incorrect answers", .mistakeReview)
                    row("Exercise history", "Your saved answers and explanations", .exerciseHistory)
                    row("Daily study plan", "Practice from your saved collection", .dailyStudyPlan)
                }.tint(Forest.inkMuted).font(.headline)
            }.listRowBackground(Forest.surface)
        }
        .forestTabList()
        .foregroundStyle(Forest.ink)
        .navigationTitle("Practice").navigationBarTitleDisplayMode(.inline)
        .toolbar(isTabRoot ? .hidden : .visible, for: .navigationBar)
    }
    private func row(_ title: String, _ subtitle: String, _ route: AppRoutes) -> some View {
        ForestNavigationRow(title: title, subtitle: subtitle) { router.push(route, hideNavBar: false) }
            .listRowInsets(EdgeInsets())
    }
}

struct PracticeSkillView: View {
    let skill: PracticeSkill
    @EnvironmentObject private var router: AppRouter
    var body: some View {
        List {
            Section {
                switch skill {
                case .kana:
                    row("Kana", "Hiragana, katakana and combination sounds", .kanaPractice)
                    row("Typed practice", "Recall supplied readings and romanization", .typedPractice)
                case .grammar:
                    row("Grammar exercises", "Choose a pattern and check its explanation", .grammarExercises)
                    row("Conjugation", "Practice verb and adjective forms", .conjugationPractice())
                    row("Sentence building", "Arrange words and understand their particles", .sentenceBuilding())
                case .listening:
                    row("Listening practice", "Listen first, then type the reading", .listeningPractice)
                    row("Listening comprehension", "Hear passages and answer meaning questions", .listeningComprehension())
                }
            }.listRowBackground(Forest.surface)
        }.forestTabList().navigationTitle(skill.rawValue).navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
    }
    private func row(_ title: String, _ subtitle: String, _ route: AppRoutes) -> some View {
        ForestNavigationRow(title: title, subtitle: subtitle) { router.push(route, hideNavBar: false) }.listRowInsets(EdgeInsets())
    }
}
