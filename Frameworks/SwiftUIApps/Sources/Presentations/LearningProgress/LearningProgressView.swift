import SwiftUI
import DataKit
import DomainKit
import SwiftData

struct LearningProgressView: View {
    @State var viewModel: LearningProgressViewModel
    @EnvironmentObject private var router: AppRouter
    var body: some View {
        VStack(alignment: .leading, spacing: Forest.Space.m) {
            Text("Learning activity").font(.title2.weight(.semibold))
            Picker("Time range", selection: Binding(get: { viewModel.state.days }, set: { viewModel.send(.range($0)) })) {
                Text("Today").tag(1); Text("7 days").tag(7); Text("30 days").tag(30)
            }.pickerStyle(.segmented)
            if viewModel.state.loading { ProgressView("Loading activity") }
            else if let error = viewModel.state.error {
                StateMessage(title: "Couldn't load activity", message: error, actionTitle: "Try again", action: { viewModel.send(.load) })
            } else if let summary = viewModel.state.summary {
                Text(summary.rangeCaption).font(.caption).foregroundStyle(Forest.inkMuted)
                if summary.practiceDays == 0 {
                    StateMessage(title: "No practice recorded in this period", message: "Answer a question or review an item to build your learning history.", actionTitle: "Choose practice", action: { router.push(.learningPractice, hideNavBar: false) })
                }
                metric("Graded exercises", "\(summary.gradedCorrect) correct / \(summary.gradedTotal) answered")
                if let accuracy = summary.gradedAccuracy { Text(accuracy.formatted(.percent.precision(.fractionLength(0))) + " correct").font(.subheadline) }
                else { Text("No graded answers in this period.").foregroundStyle(Forest.inkMuted) }
                if summary.choice.submitted > 0 { metric("Choices", "\(summary.choice.correct) correct / \(summary.choice.submitted) answered") }
                if summary.kanaReading.submitted > 0 { metric("Kana readings", "\(summary.kanaReading.correct) correct / \(summary.kanaReading.submitted) answered") }
                if summary.romanization.submitted > 0 { metric("Romanization", "\(summary.romanization.correct) correct / \(summary.romanization.submitted) answered") }
                if summary.listeningReading.submitted > 0 { metric("Listening", "\(summary.listeningReading.correct) correct / \(summary.listeningReading.submitted) answered") }
                if summary.meaningSelfRatedSubmitted > 0 { metric("Self-rated meanings", "\(summary.meaningSelfRatedRemembered) remembered / \(summary.meaningSelfRatedSubmitted) responses") }
                if summary.distinctAttemptedContent > 0 { metric("Distinct questions attempted", "\(summary.distinctAttemptedContent)") }
                if summary.distinctSavedItemsPracticed > 0 { metric("Saved items practiced", "\(summary.distinctSavedItemsPracticed) distinct items in this period") }
                metric("Self-rated review", "\(summary.selfRatedGotIt) Got it / \(summary.selfRatedTotal) first responses")
                if let start = summary.reviewRecordedSince { Text("Available review history starts \(start.formatted(date: .abbreviated, time: .omitted)).").font(.footnote).foregroundStyle(Forest.inkMuted) }
                Button("Starter path: \(summary.pathStepStatuses.filter { $0.status == .completed }.count) / \(summary.pathStepStatuses.count) steps completed") { router.push(.learningPath, hideNavBar: false) }.buttonStyle(.plain).frame(minHeight: 44)
                metric("Days practiced", "\(summary.practiceDays) in this period")
                metric("Reviews due now", "\(viewModel.state.dueCount) saved items")
                Text("Due reviews include items waiting for their first review and use today's date, independently of the history period.").font(.footnote).foregroundStyle(Forest.inkMuted)
                if summary.remainingMistakes > 0 {
                    VStack(alignment: .leading, spacing: Forest.Space.s) {
                        Text("Remaining mistakes by practice type").font(.headline)
                        ForEach(mistakeKinds, id: \.0) { kind, title in
                            if let count = summary.remainingMistakesByKind[kind], count > 0 { Text("\(title): \(count)").font(.subheadline) }
                        }
                        Text("Latest incorrect answers still awaiting a correct retry, across all retained history.").font(.footnote).foregroundStyle(Forest.inkMuted)
                    }
                }
                Button("Practice \(summary.remainingMistakes) remaining mistakes") { router.push(.mistakeReview, hideNavBar: false) }.frame(minHeight: 44).buttonStyle(.plain)
                Text("Review counts use the first response per item in a session. History keeps up to 10,000 recent answers and review ratings. History starts with this update; earlier results are unavailable. These counts describe practice, not mastery. Speaking recordings are not included.").font(.footnote).foregroundStyle(Forest.inkMuted)
            }
        }.foregroundStyle(Forest.ink).tint(Forest.moss).onAppear { viewModel.send(.load) }
    }
    private var mistakeKinds: [(ExerciseQuestionKind, String)] { [(.choice, "Choices"), (.kanaReading, "Kana readings"), (.romanization, "Romanization"), (.listeningReading, "Listening")] }
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Forest.Space.xs) { Text(title).font(.headline); Text(value).font(.subheadline).fixedSize(horizontal: false, vertical: true) }
            .padding(Forest.Space.l).frame(maxWidth: .infinity, alignment: .leading).background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
    }
}

extension AppComposer {
    func makeLearningProgressView() -> some View {
        LearningProgressView(viewModel: .init(load: { [self] in
            (try StandardExerciseHistoryRepository(store: store).attempts(), try StandardStudyRatingRepository(store: store).events())
        }, loadAdditional: { [self] in
            (try store.makeContext().fetch(FetchDescriptor<PracticeActivityModel>()).map(\.value), try StandardLearningPathRepository(store: store).progress(pathID: StarterPathCatalog.id))
        }, loadDue: { [self] instant in
            let due = DefaultGetDueReviewsUseCase(repository: StandardReviewRepository(store: store))
            return try SavedStudyKind.allCases.flatMap { try due.execute(kind: $0, now: instant) }
        }))
    }
}
