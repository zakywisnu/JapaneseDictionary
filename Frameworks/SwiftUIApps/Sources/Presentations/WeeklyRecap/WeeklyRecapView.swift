import SwiftUI
import DataKit
import DomainKit

struct WeeklyRecapView: View {
    @State var viewModel: WeeklyRecapViewModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Forest.Space.xl) {
                if viewModel.state.loading { ProgressView("Loading weekly recap") }
                else if let error = viewModel.state.error { StateMessage(title: "Couldn't load recap", message: error, actionTitle: "Try again", action: { viewModel.send(.retry) }) }
                else if let recap = viewModel.state.recap {
                    Text(recap.rangeCaption).font(.subheadline).foregroundStyle(Forest.inkMuted)
                    if recap.hasCurrentActivity { Text("\(recap.practiceDays) days practiced").font(.title2.weight(.semibold)) }
                    if !recap.hasCurrentActivity { StateMessage(title: "No practice recorded this week", message: "Answer a question or review a saved item to build your local history.") }
                    if let focus = recap.focus {
                        VStack(alignment: .leading, spacing: Forest.Space.m) {
                            Text("Next focus").font(.headline)
                            Text(focus.reason)
                            Button("Open next focus") { viewModel.send(.openFocus) }.buttonStyle(PrimaryButtonStyle())
                        }
                    }
                    ForEach(recap.firstAttemptCounts.keys.sorted { $0.rawValue < $1.rawValue }, id: \.self) { kind in
                        if let count = recap.firstAttemptCounts[kind] {
                            VStack(alignment: .leading, spacing: Forest.Space.s) {
                                Text(title(kind)).font(.headline)
                                Text("\(count.correct) correct / \(count.submitted) first attempts")
                                if let delta = recap.comparableDelta[kind] {
                                    Text(String(format: "%+.1f percentage points", delta.percentagePoints))
                                    Text("Unchanged questions: \(delta.current.correct)/\(delta.current.submitted) this week; \(delta.prior.correct)/\(delta.prior.submitted) in the preceding seven days.").font(.footnote).foregroundStyle(Forest.inkMuted)
                                }
                            }
                        }
                    }
                    if recap.selfRatedCurrent.submitted > 0 {
                    VStack(alignment: .leading, spacing: Forest.Space.s) {
                        Text("Self-rated responses").font(.headline)
                        Text("\(recap.selfRatedCurrent.correct) remembered / \(recap.selfRatedCurrent.submitted) first responses")
                        Text("Self-ratings are separate from graded accuracy.").font(.footnote).foregroundStyle(Forest.inkMuted)
                    }
                    }
                    if !recap.recurringTopics.isEmpty {
                        VStack(alignment: .leading, spacing: Forest.Space.s) {
                            Text("Topics to revisit").font(.headline)
                            ForEach(recap.recurringTopics, id: \.topicID) { topic in
                                Text("\(topicTitle(topic)): first-attempt misses in \(topic.sessions) sessions" + (topic.available ? "" : " · practice unavailable"))
                            }
                        }
                    }
                    DisclosureGroup("About this recap") {
                        VStack(alignment: .leading, spacing: Forest.Space.m) {
                            Text("Comparison period: " + recap.priorRangeCaption)
                            Text("Comparisons need at least 10 first attempts in each period on the same unchanged questions.")
                            Text(WeeklyRecap.historyDisclosure)
                        }.font(.footnote).foregroundStyle(Forest.inkMuted).padding(.top, Forest.Space.m)
                    }
                }
            }.padding(Forest.Space.l).frame(maxWidth: .infinity, alignment: .leading)
        }.background(Forest.canvas).foregroundStyle(Forest.ink).tint(Forest.moss).navigationTitle("Weekly recap").toolbar(.visible, for: .navigationBar).onAppear { viewModel.send(.load) }
    }
    private func topicTitle(_ topic: WeeklyTopic) -> String {
        if topic.kind == .conjugation {
            let parts = topic.topicID.split(separator: ":").map(String.init)
            if parts.count == 3 { return ConjugationPolicy.classLabel(parts[1]) + " · " + ConjugationPolicy.formLabel(parts[2]) }
        }
        return title(topic.kind)
    }
    private func title(_ kind: ExerciseQuestionKind) -> String {
        switch kind {
        case .choice: return "Choices"
        case .kanaReading: return "Kana readings"
        case .romanization: return "Romanization"
        case .listeningReading: return "Listening readings"
        case .meaningSelfRated: return "Self-rated meanings"
        case .conjugation: return "Conjugation"
        case .sentenceOrder: return "Sentence building"
        case .listeningComprehension: return "Listening comprehension"
        }
    }
}
struct WeeklyRecapSummaryView: View {
    @State var viewModel: WeeklyRecapViewModel
    let openRecap: () -> Void
    var body: some View {
        Group {
            if let recap = viewModel.state.recap, recap.hasCurrentActivity {
                Button("Weekly recap") { openRecap() }.buttonStyle(.plain).frame(minHeight: 44)
            }
        }.onAppear { viewModel.send(.load) }
    }
}
