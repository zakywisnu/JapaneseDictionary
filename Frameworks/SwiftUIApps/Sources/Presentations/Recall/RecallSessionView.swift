import SwiftUI
import DataKit

struct RecallSessionView: View {
    @State var viewModel: RecallSessionViewModel
    let title: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var answerFocused: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Forest.Space.xl) {
                if viewModel.state.isLoading {
                    ProgressView("Opening practice")
                } else if viewModel.state.contentChanged {
                    StateMessage(title: "This practice has changed", message: "Your submitted answers remain in History. Start a new session with the current available content.", actionTitle: "Start new session", action: { viewModel.send(.restart) })
                } else if viewModel.questions.isEmpty {
                    StateMessage(title: "No questions available", message: "Return to practice setup and choose items with supplied readings.")
                } else if viewModel.state.isComplete {
                    Text("Practice complete").font(.title2.bold())
                    Text("\(viewModel.state.correctCount) of \(viewModel.state.checkedCount) checked answers matched.")
                    if viewModel.state.selfRatedCount > 0 { Text("\(viewModel.state.selfRatedCount) self-rated recalls. These are your own ratings.") }
                    Text("Saved items, review dates and your daily saved-item goal stay unchanged.")
                        .font(.subheadline).foregroundStyle(Forest.inkMuted)
                    Button("Practice again") { viewModel.send(.restart) }.buttonStyle(PrimaryButtonStyle())
                } else if let question = viewModel.current {
                    Text("Question \(viewModel.state.position + 1) of \(viewModel.state.total)")
                        .font(.subheadline).foregroundStyle(Forest.inkMuted)
                    if viewModel.promptVisible {
                        Text(question.snapshot.prompt).font(.headword(32, relativeTo: .title)).fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(question.snapshot.questionKind == .meaningSelfRated ? "Listen, then recall the meaning." : "Listen, then type the supplied kana reading.").font(.headline)
                    }
                    if viewModel.isListening {
                        Button(viewModel.pronunciation.state == .playing ? "Replay" : "Listen") { viewModel.send(.play) }
                            .buttonStyle(.bordered).frame(minHeight: 44)
                        Text("Synthesized Japanese speech").font(.footnote).foregroundStyle(Forest.inkMuted)
                        if viewModel.pronunciation.state == .playing { ProgressView("Playing Japanese speech") }
                        if let message = viewModel.playbackFailure {
                            StateMessage(title: "Listening unavailable", message: message, actionTitle: "Check again", action: { viewModel.pronunciation.refreshAvailability() })
                        }
                    }
                    if question.snapshot.questionKind == .meaningSelfRated {
                        if !viewModel.state.isAnswerShown {
                            Text("Recall the meaning, then reveal it. You decide whether you remembered.")
                                .font(.subheadline).foregroundStyle(Forest.inkMuted)
                            Button("Reveal meaning") { viewModel.send(.reveal) }.buttonStyle(PrimaryButtonStyle())
                                .disabled(viewModel.isListening && !viewModel.state.heardPlayback)
                        } else {
                            Text(question.snapshot.explanation)
                            if !viewModel.state.isRevealed {
                                Button("Remembered") { viewModel.send(.rate(true)) }.buttonStyle(PrimaryButtonStyle())
                                Button("Didn't remember") { viewModel.send(.rate(false)) }.buttonStyle(.bordered)
                            }
                        }
                    } else if question.snapshot.questionKind == .choice {
                        ForEach(question.snapshot.choices.indices, id: \.self) { index in
                            Button(question.snapshot.choices[index]) { viewModel.send(.choose(index)) }
                                .buttonStyle(.bordered).disabled(viewModel.state.selectedIndex != nil)
                        }
                    } else if !viewModel.state.isAnswerShown {
                        TextField(question.snapshot.questionKind == .romanization ? "Romanization" : "Kana answer", text: Binding(get: { viewModel.state.draft }, set: { viewModel.send(.draft($0)) }))
                            .textFieldStyle(.roundedBorder).autocorrectionDisabled().textInputAutocapitalization(.never)
                            .focused($answerFocused).disabled(viewModel.state.error != nil)
                        Text("Enter your answer, then tap Check.")
                            .font(.footnote).foregroundStyle(Forest.inkMuted)
                        Button("Check") { answerFocused = false; viewModel.send(.submit) }.buttonStyle(PrimaryButtonStyle()).disabled(!viewModel.canSubmit)
                    }
                    if viewModel.isListening, question.snapshot.questionKind == .listeningReading, !viewModel.state.isAnswerShown {
                        Button("Reveal without checking") { answerFocused = false; viewModel.send(.reveal) }
                            .buttonStyle(.bordered).disabled(!viewModel.state.heardPlayback || viewModel.state.error != nil)
                    }
                    if viewModel.state.isAnswerShown, !viewModel.state.isRevealed, question.snapshot.questionKind != .meaningSelfRated {
                        Text("Answer: " + question.snapshot.acceptedAnswers.joined(separator: ", "))
                        Text("Revealing without Check doesn't record a checked result.").font(.footnote).foregroundStyle(Forest.inkMuted)
                        Button(viewModel.state.position + 1 == viewModel.state.total ? "Finish without submitting" : "Next without submitting") { viewModel.send(.next) }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    if viewModel.state.isRevealed {
                        VStack(alignment: .leading, spacing: Forest.Space.s) {
                            Text(feedback).font(.headline)
                            if question.snapshot.questionKind != .meaningSelfRated {
                                if !viewModel.state.draft.isEmpty { Text("Your answer: \(viewModel.state.draft)") }
                                if !question.snapshot.acceptedAnswers.isEmpty { Text("Accepted answers: \(question.snapshot.acceptedAnswers.joined(separator: ", "))") }
                                if let index = question.snapshot.correctIndex, question.snapshot.choices.indices.contains(index) { Text("Answer: \(question.snapshot.choices[index])") }
                                Text(question.snapshot.explanation)
                            }
                        }
                        Button(viewModel.state.position + 1 == viewModel.state.total ? "Finish practice" : "Next") {
                            answerFocused = false; viewModel.send(.next)
                        }.buttonStyle(PrimaryButtonStyle())
                    }
                }
                if let error = viewModel.state.error {
                    StateMessage(title: "Practice couldn't be saved", message: error, actionTitle: "Retry", action: { viewModel.send(.retry) })
                    Button("Exit practice") { viewModel.send(.cancel); dismiss() }.buttonStyle(.bordered)
                }
            }.foregroundStyle(Forest.ink).padding(Forest.Space.l)
        }
        .background(Forest.canvas).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.send(.load) }
        .onDisappear { viewModel.send(.cancel) }
        .onChange(of: viewModel.pronunciation.state) { _, _ in viewModel.send(.playbackChanged) }
        .onChange(of: scenePhase) { _, phase in if phase != .active { viewModel.send(.cancel) } }
    }
    private var feedback: String {
        switch viewModel.state.outcome {
        case .correct: return "Matched a supplied answer"
        case .incorrect: return "Different from the supplied answers"
        case .selfRated: return viewModel.state.remembered == true ? "Self-rated: remembered" : "Self-rated: didn't remember"
        case nil: return ""
        }
    }
}
