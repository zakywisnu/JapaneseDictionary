import SwiftUI
import DataKit

struct ExerciseHistoryView: View {
    @State var viewModel: ExerciseHistoryViewModel
    var mistakesOnly = false
    @EnvironmentObject private var router: AppRouter
    private var entries: [ExerciseAttempt] { mistakesOnly ? viewModel.state.mistakes : viewModel.state.attempts }
    var body: some View {
        List {
            if !viewModel.state.isLoading, viewModel.state.errorMessage == nil, !viewModel.state.checkpoints.isEmpty {
                Section("Unfinished practice") {
                    ForEach(viewModel.state.checkpoints, id: \.activityKey) { checkpoint in
                        Button { router.push(.exerciseResume(checkpoint.activityKey), hideNavBar: false) } label: {
                            VStack(alignment: .leading, spacing: Forest.Space.s) {
                                Text(checkpoint.activityKey.hasPrefix("mistakes:") ? "Resume mistake practice" : checkpoint.activityKey.hasPrefix("listening:") ? "Resume listening practice" : checkpoint.activityKey.hasPrefix("typed:") ? "Resume typed practice" : "Resume learning practice")
                                    .font(.headline)
                                Text("Question \(checkpoint.position + 1) of \(checkpoint.orderedSnapshots.count)")
                                    .font(.subheadline).foregroundStyle(Forest.inkMuted)
                            }.foregroundStyle(Forest.ink)
                        }.buttonStyle(.plain).listRowBackground(Forest.surface)
                    }
                }
            }
            if viewModel.state.isLoading {
                ProgressView("Opening submitted answers")
            } else if let message = viewModel.state.errorMessage {
                StateMessage(title: "Couldn't open exercise history", message: message, actionTitle: "Try again", action: { viewModel.send(.load) })
            } else if entries.isEmpty {
                StateMessage(title: mistakesOnly ? "No mistakes to practice" : "No submitted answers yet", message: mistakesOnly ? "Incorrect checked answers appear here until a later correct answer. Choose an activity in Learning practice." : "Submit an answer in Grammar exercises or Reading practice to see its result here.")
            } else {
                Section {
                    Text("\(entries.count) \(mistakesOnly ? "questions to practice" : "submitted answers")")
                    if mistakesOnly {
                        Text("Each session practices up to 1,000 mistakes. Only the latest checked answer for each version of a question is used. Practice leaves review dates unchanged.")
                            .font(.subheadline).foregroundStyle(Forest.inkMuted)
                        Button("Practice these mistakes") { viewModel.send(.startMistakes) }
                            .buttonStyle(.bordered)
                        if let error = viewModel.state.startError { Text(error).font(.subheadline) }
                    }
                }
                Section(mistakesOnly ? "Latest incorrect answers" : "Submitted answers") {
                    ForEach(entries, id: \.id) { attempt in
                        VStack(alignment: .leading, spacing: Forest.Space.s) {
                            Text(attempt.snapshot.prompt).font(.headline)
                            Text(outcome(attempt)).font(.subheadline)
                            Text("Your answer: \(response(attempt))").font(.subheadline)
                            if let index = attempt.snapshot.correctIndex, attempt.snapshot.choices.indices.contains(index) {
                                Text("Answer: \(attempt.snapshot.choices[index])").font(.subheadline)
                            }
                            Text(attempt.snapshot.explanation).font(.body)
                            Text(attempt.submittedAt, format: .dateTime.year().month().day().hour().minute())
                                .font(.caption).foregroundStyle(Forest.inkMuted)
                        }.foregroundStyle(Forest.ink).padding(.vertical, Forest.Space.s)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .listRowBackground(Forest.surface)
        .background(Forest.canvas)
        .navigationTitle(mistakesOnly ? "Mistakes" : "Exercise history")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.send(.load) }
        .onChange(of: viewModel.state.startedKey) { _, key in if let key { router.push(.exerciseResume(key), hideNavBar: false) } }
    }
    private func outcome(_ attempt: ExerciseAttempt) -> String {
        switch attempt.outcome { case .correct: return "Correct"; case .incorrect: return "Incorrect"; case .selfRated: return "Self-rated recall" }
    }
    private func response(_ attempt: ExerciseAttempt) -> String {
        switch attempt.response {
        case .choice(let index): return attempt.snapshot.choices.indices.contains(index) ? attempt.snapshot.choices[index] : "Unavailable"
        case .text(let text): return text
        case .selfRating(let remembered): return remembered ? "Remembered" : "Didn't remember"
        }
    }
}
