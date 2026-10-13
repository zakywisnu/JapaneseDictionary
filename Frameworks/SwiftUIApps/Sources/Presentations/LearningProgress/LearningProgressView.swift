import SwiftUI
import DataKit
import DomainKit
import SwiftData

struct ProgressWeekOverview: View {
    @State var viewModel: LearningProgressViewModel
    @EnvironmentObject private var router: AppRouter
    var body: some View {
        VStack(alignment: .leading, spacing: Forest.Space.m) {
            Text("Last 7 days").font(.title2.weight(.semibold))
            if viewModel.state.loading { ProgressView("Loading recent activity") }
            else if let error = viewModel.state.error {
                StateMessage(title: "Couldn't load activity", message: error, actionTitle: "Try again", action: { viewModel.send(.load) })
            } else if let summary = viewModel.state.summary {
                Text(summary.rangeCaption).font(.subheadline).foregroundStyle(Forest.inkMuted)
                if summary.practiceDays == 0 {
                    ProgressDayStrip(days: summary.dailyPractice, timeZoneIdentifier: summary.timeZoneIdentifier)
                    Text("No practice recorded in the last 7 days. Your reviews and exercises will appear here.").font(.subheadline).foregroundStyle(Forest.inkMuted).fixedSize(horizontal: false, vertical: true)
                    Button("Choose practice") { router.push(.learningPractice, hideNavBar: false) }.buttonStyle(PrimaryButtonStyle())
                } else {
                    if summary.distinctSavedItemsPracticed > 0 {
                        Text(summary.distinctSavedItemsPracticed.formatted()).font(.system(.largeTitle, design: .rounded).weight(.semibold)).monospacedDigit()
                        Text("Distinct saved items practiced").font(.headline)
                    }
                    Text("\(summary.practiceDays) " + (summary.practiceDays == 1 ? "day practiced" : "days practiced")).font(.headline)
                    ProgressDayStrip(days: summary.dailyPractice, timeZoneIdentifier: summary.timeZoneIdentifier)
                    if summary.gradedTotal > 0 { Text("\(summary.gradedCorrect) correct / \(summary.gradedTotal) graded answers") }
                    if summary.selfRatedTotal > 0 { Text("\(summary.selfRatedGotIt) Got it / \(summary.selfRatedTotal) self-rated responses") }
                    if summary.meaningSelfRatedSubmitted > 0 { Text("\(summary.meaningSelfRatedRemembered) remembered / \(summary.meaningSelfRatedSubmitted) self-rated meanings") }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).onAppear { viewModel.send(.load) }
    }
}

private struct ProgressDayStrip: View {
    let days: [LearningPracticeDay]
    let timeZoneIdentifier: String
    @Environment(\.dynamicTypeSize) private var textSize
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Forest.Space.s), count: textSize.isAccessibilitySize ? 2 : days.contains(where: { $0.responses >= 1_000 }) ? 4 : 7)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: Forest.Space.s) {
            LazyVGrid(columns: columns, spacing: Forest.Space.s) {
                ForEach(days) { day in
                    VStack(spacing: Forest.Space.s) {
                        Text(dateLabel(day.date)).font(.caption).foregroundStyle(Forest.inkMuted)
                        Text(day.responses > 0 ? day.responses.formatted() : day.practiced ? "✓" : "–")
                            .font(.headline.monospacedDigit())
                    }.padding(.vertical, Forest.Space.m).frame(maxWidth: .infinity, minHeight: 66)
                        .forestSurface(radius: Forest.Radius.control)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(fullDate(day.date) + ": " + (day.responses > 0 ? "\(day.responses) recorded " + (day.responses == 1 ? "response" : "responses") : day.practiced ? "Saved-item practice recorded" : "No practice recorded"))
                }
            }
            Text("Recorded answers and review ratings per day").font(.footnote).foregroundStyle(Forest.inkMuted)
            if days.contains(where: { $0.practiced && $0.responses == 0 }) {
                Text("✓ Saved-item practice with no retained answer count").font(.footnote).foregroundStyle(Forest.inkMuted)
            }
        }
    }
    private func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.dateFormat = format
        return formatter
    }
    private func dateLabel(_ date: Date) -> String { formatter(textSize.isAccessibilitySize ? "EEE d" : "EEEEE").string(from: date) }
    private func fullDate(_ date: Date) -> String { formatter("EEEE, MMM d").string(from: date) }
}

struct LearningProgressView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State var viewModel: LearningProgressViewModel
    @EnvironmentObject private var router: AppRouter
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Forest.Space.xl) {
                if dynamicTypeSize.isAccessibilitySize { rangePicker.pickerStyle(.menu) }
                else { rangePicker.pickerStyle(.segmented) }
                if viewModel.state.loading { ProgressView("Loading activity") }
                else if let error = viewModel.state.error {
                    StateMessage(title: "Couldn't load activity", message: error, actionTitle: "Try again", action: { viewModel.send(.load) })
                } else if let summary = viewModel.state.summary {
                    Text(summary.rangeCaption).font(.subheadline).foregroundStyle(Forest.inkMuted)
                    if summary.practiceDays == 0 {
                        StateMessage(title: "No practice in this period", message: "Answer a question or review an item to build your history.", actionTitle: "Choose practice", action: { router.push(.learningPractice, hideNavBar: false) })
                    } else {
                        VStack(alignment: .leading, spacing: Forest.Space.m) {
                            if summary.gradedTotal > 0 {
                                Text("Graded exercises").font(.title2.weight(.semibold))
                                Text("\(summary.gradedCorrect) correct / \(summary.gradedTotal) answered").font(.headline)
                                if let accuracy = summary.gradedAccuracy { Text(accuracy.formatted(.percent.precision(.fractionLength(0))) + " correct").foregroundStyle(Forest.inkMuted) }
                                VStack(alignment: .leading, spacing: Forest.Space.l) {
                                    if summary.choice.submitted > 0 { metric("Choices", "\(summary.choice.correct) / \(summary.choice.submitted)") }
                                    if summary.kanaReading.submitted > 0 { metric("Kana readings", "\(summary.kanaReading.correct) / \(summary.kanaReading.submitted)") }
                                    if summary.romanization.submitted > 0 { metric("Romanization", "\(summary.romanization.correct) / \(summary.romanization.submitted)") }
                                    if summary.listeningReading.submitted > 0 { metric("Listening", "\(summary.listeningReading.correct) / \(summary.listeningReading.submitted)") }
                                    if summary.conjugation.submitted > 0 { metric("Conjugation", "\(summary.conjugation.correct) / \(summary.conjugation.submitted)") }
                                    if summary.sentenceOrder.submitted > 0 { metric("Sentence building", "\(summary.sentenceOrder.correct) / \(summary.sentenceOrder.submitted)") }
                                    if summary.listeningComprehension.submitted > 0 { metric("Listening comprehension", "\(summary.listeningComprehension.correct) / \(summary.listeningComprehension.submitted)") }
                                }.padding(Forest.Space.l).frame(maxWidth: .infinity, alignment: .leading).forestSurface()
                            }
                            if summary.selfRatedTotal > 0 || summary.meaningSelfRatedSubmitted > 0 {
                                Text("Self-rated recall").font(.title2.weight(.semibold))
                                if summary.selfRatedTotal > 0 { metric("Reviews", "\(summary.selfRatedGotIt) Got it / \(summary.selfRatedTotal) first responses") }
                                if summary.meaningSelfRatedSubmitted > 0 { metric("Meanings", "\(summary.meaningSelfRatedRemembered) remembered / \(summary.meaningSelfRatedSubmitted) responses") }
                            }
                            Text("\(summary.practiceDays) days practiced").font(.subheadline)
                            if summary.distinctAttemptedContent > 0 { Text("\(summary.distinctAttemptedContent) distinct questions attempted").font(.subheadline) }
                            if summary.distinctSavedItemsPracticed > 0 { Text("\(summary.distinctSavedItemsPracticed) distinct saved items practiced").font(.subheadline) }
                        }
                    }
                    VStack(spacing: 0) {
                        ForestNavigationRow(title: "Starter path", subtitle: "\(summary.pathStepStatuses.filter { $0.status == .completed }.count) of \(summary.pathStepStatuses.count) steps completed") { router.push(.learningPath, hideNavBar: false) }
                        Divider().overlay(Forest.line)
                        ForestNavigationRow(title: "Answer history") { router.push(.exerciseHistory, hideNavBar: false) }
                    }.forestSurface()
                    VStack(alignment: .leading, spacing: Forest.Space.m) {
                        Text("Ready to revisit").font(.title2.weight(.semibold))
                        metric("Reviews due now", "\(viewModel.state.dueCount) saved items")
                        if summary.remainingMistakes > 0 {
                            ForestNavigationRow(title: "Practice remaining mistakes", subtitle: "\(summary.remainingMistakes) questions") { router.push(.mistakeReview, hideNavBar: false) }
                                .forestSurface()
                            DisclosureGroup("Mistakes by practice type") {
                                ForEach(mistakeKinds, id: \.0) { kind, title in
                                    if let count = summary.remainingMistakesByKind[kind], count > 0 { metric(title, "\(count)").padding(.top, Forest.Space.s) }
                                }
                            }
                        }
                    }
                    DisclosureGroup("How counts work") {
                        VStack(alignment: .leading, spacing: Forest.Space.m) {
                            Text("Graded rows show correct answers out of submitted answers. Self-ratings are separate and describe recall, not mastery.")
                            Text("Review counts use the first response per item in a session. Due reviews use today's date, independently of the selected period. Remaining mistakes use the latest incorrect answers across retained history.")
                            Text("History keeps up to 10,000 recent answers and ratings. Earlier results and speaking recordings are not included.")
                            if let start = summary.reviewRecordedSince { Text("Available review history starts \(start.formatted(date: .abbreviated, time: .omitted)).") }
                        }.font(.footnote).foregroundStyle(Forest.inkMuted).padding(.top, Forest.Space.m)
                    }
                }
            }.padding(Forest.Space.l).frame(maxWidth: .infinity, alignment: .leading)
        }.background(Forest.canvas).foregroundStyle(Forest.ink).tint(Forest.moss)
            .navigationTitle("Activity").toolbar(.visible, for: .navigationBar).onAppear { viewModel.send(.load) }
    }
    private var rangePicker: some View {
        Picker("Time range", selection: Binding(get: { viewModel.state.days }, set: { viewModel.send(.range($0)) })) {
            Text("Today").tag(1)
            Text("7 days").tag(7)
            Text("30 days").tag(30)
        }.frame(minHeight: 44)
    }
    private var mistakeKinds: [(ExerciseQuestionKind, String)] { [(.choice, "Choices"), (.kanaReading, "Kana readings"), (.romanization, "Romanization"), (.listeningReading, "Listening recall"), (.conjugation, "Conjugation"), (.sentenceOrder, "Sentence building"), (.listeningComprehension, "Listening comprehension")] }
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Forest.Space.xs) {
            Text(title).font(.subheadline).foregroundStyle(Forest.inkMuted)
            Text(value).font(.body).fixedSize(horizontal: false, vertical: true)
        }.accessibilityElement(children: .combine)
    }
}

extension AppComposer {
    func makeLearningProgressView() -> some View {
        LearningProgressView(viewModel: makeLearningProgressViewModel())
    }
    func makeLearningProgressViewModel() -> LearningProgressViewModel {
        .init(load: { [self] in
            (try StandardExerciseHistoryRepository(store: store).attempts(), try StandardStudyRatingRepository(store: store).events())
        }, loadAdditional: { [self] in
            (try store.makeContext().fetch(FetchDescriptor<PracticeActivityModel>()).map(\.value), try StandardLearningPathRepository(store: store).progress(pathID: StarterPathCatalog.id))
        }, loadDue: { [self] instant in
            let due = DefaultGetDueReviewsUseCase(repository: StandardReviewRepository(store: store))
            return try SavedStudyKind.allCases.flatMap { try due.execute(kind: $0, now: instant) }
        })
    }
}
