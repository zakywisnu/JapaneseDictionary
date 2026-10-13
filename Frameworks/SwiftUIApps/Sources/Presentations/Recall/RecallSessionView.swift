import SwiftUI
import DataKit
import DomainKit

struct RecallSessionView: View {
    @State var viewModel: RecallSessionViewModel
    let title: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var answerFocused: Bool

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Forest.Space.xl) {
                    if viewModel.state.isLoading {
                        ProgressView("Opening practice")
                    } else if viewModel.state.contentChanged {
                        StateMessage(title: "This practice has changed", message: "Your submitted answers remain in History. Start a new session with the current available content.", actionTitle: "Start new session", action: { viewModel.send(.restart) })
                    } else if viewModel.questions.isEmpty {
                        StateMessage(title: "No questions available", message: "Return to practice setup and choose items with supplied readings.")
                    } else if viewModel.state.isComplete {
                        completion
                    } else if let question = viewModel.current {
                        questionContent(question)
                    }
                    if let error = viewModel.state.error {
                        StateMessage(title: "Practice couldn't be saved or opened", message: error)
                    }
                }.foregroundStyle(Forest.ink).padding(Forest.Space.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(viewModel.state.position)
            .scrollDismissesKeyboard(.interactively)
            .background(Forest.canvas).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { _ in
                if answerFocused { scrollProxy.scrollTo("recall-answer", anchor: .bottom) }
            }
            .onChange(of: answerFocused) { _, focused in
                if focused { scrollProxy.scrollTo("recall-answer", anchor: .bottom) }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { actions }
            .onAppear { viewModel.send(.load) }
            .onDisappear { viewModel.send(.cancel) }
            .onChange(of: viewModel.pronunciation.state) { _, _ in viewModel.send(.playbackChanged) }
            .onChange(of: scenePhase) { _, phase in if phase != .active { viewModel.send(.cancel) } }
        }
    }

    private var completion: some View {
        VStack(alignment: .leading, spacing: Forest.Space.m) {
            Text("Practice complete").font(.title2.bold())
            if viewModel.state.checkedCount > 0 {
                Text("\(viewModel.state.correctCount) of \(viewModel.state.checkedCount) matched")
                    .font(.title3.weight(.semibold))
                Text("Checked against supplied answers").font(.subheadline).foregroundStyle(Forest.inkMuted)
            }
            if viewModel.state.selfRatedCount > 0 {
                Text("\(viewModel.state.selfRatedCount) self-rated recalls. These are your own ratings.")
            }
            Text("Saved items, review dates and your daily saved-item goal stay unchanged.")
                .font(.subheadline).foregroundStyle(Forest.inkMuted)
        }.forestStudyCard()
    }

    @ViewBuilder
    private func questionContent(_ question: RecallQuestion) -> some View {
        Text("Question \(viewModel.state.position + 1) of \(viewModel.state.total)")
            .font(.subheadline.monospacedDigit()).foregroundStyle(Forest.inkMuted)
        if viewModel.promptVisible {
            if question.snapshot.questionKind == .conjugation, let metadata = question.snapshot.metadata {
                VStack(alignment: .leading, spacing: Forest.Space.s) {
                    Text(metadata.stimulus ?? question.snapshot.prompt).font(.headword(32, relativeTo: .title))
                    Text(metadata.translation ?? "")
                    Text("Target: " + ConjugationPolicy.formLabel(metadata.topicID.split(separator: ":").last.map(String.init) ?? ""))
                        .font(.headline)
                    Text(metadata.source).font(.footnote).foregroundStyle(Forest.inkMuted)
                }.fixedSize(horizontal: false, vertical: true)
            } else {
                Text(question.snapshot.prompt).font(.headword(32, relativeTo: .title)).fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(question.snapshot.questionKind == .meaningSelfRated ? "Listen, then recall the meaning." : "Listen, then type the supplied kana reading.").font(.headline)
        }
        if viewModel.isListening { playback }
        if question.snapshot.questionKind == .meaningSelfRated {
            if !viewModel.state.isAnswerShown {
                Text("Recall the meaning, then reveal it. You decide whether you remembered.")
                    .font(.subheadline).foregroundStyle(Forest.inkMuted)
            } else {
                Text(question.snapshot.explanation).forestStudyCard()
            }
        } else if question.snapshot.questionKind == .choice {
            ForEach(question.snapshot.choices.indices, id: \.self) { index in
                Button { viewModel.send(.choose(index)) } label: {
                    HStack(alignment: .top, spacing: Forest.Space.m) {
                        Text(question.snapshot.choices[index]).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: Forest.Space.s)
                        if viewModel.state.selectedIndex == index { Image(systemName: "checkmark").accessibilityHidden(true) }
                    }.padding(Forest.Space.l).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }.buttonStyle(ForestChoiceButtonStyle(isSelected: viewModel.state.selectedIndex == index)).disabled(viewModel.state.selectedIndex != nil || viewModel.state.error != nil)
                    .accessibilityAddTraits(viewModel.state.selectedIndex == index ? .isSelected : [])
            }
        } else if !viewModel.state.isAnswerShown {
            VStack(alignment: .leading, spacing: Forest.Space.s) {
                Text("Your answer").font(.subheadline.weight(.semibold))
                TextField(answerPlaceholder(question), text: Binding(get: { viewModel.state.draft }, set: { viewModel.send(.draft($0)) }))
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .focused($answerFocused).disabled(viewModel.state.error != nil)
                    .submitLabel(.done).onSubmit { submit() }
                    .padding(Forest.Space.m).frame(minHeight: 50)
                    .forestSurface(radius: Forest.Radius.control)
                    .accessibilityLabel("Your answer, " + answerPlaceholder(question))
                    .id("recall-answer")
                Text("Enter your answer, then check it against the supplied answers.")
                    .font(.footnote).foregroundStyle(Forest.inkMuted)
            }
        }
        if viewModel.state.isAnswerShown, !viewModel.state.isRevealed, question.snapshot.questionKind != .meaningSelfRated {
            VStack(alignment: .leading, spacing: Forest.Space.s) {
                Text("Supplied answers").font(.headline)
                Text(question.snapshot.acceptedAnswers.joined(separator: ", "))
                Text("Revealing without Check doesn't record a checked result.").font(.footnote).foregroundStyle(Forest.inkMuted)
            }.forestStudyCard()
        }
        if viewModel.state.isRevealed { feedbackCard(question) }
    }

    private var playback: some View {
        VStack(alignment: .leading, spacing: Forest.Space.s) {
            Button(viewModel.pronunciation.state == .playing ? "Replay" : "Listen") { viewModel.send(.play) }
                .buttonStyle(SecondaryButtonStyle()).frame(minHeight: 44).disabled(viewModel.state.error != nil)
            Text("Synthesized Japanese speech").font(.footnote).foregroundStyle(Forest.inkMuted)
            if viewModel.pronunciation.state == .playing { ProgressView("Playing Japanese speech") }
            if let message = viewModel.playbackFailure {
                StateMessage(title: "Listening unavailable", message: message, actionTitle: "Check again", action: { viewModel.pronunciation.refreshAvailability() })
            }
        }
    }

    private func feedbackCard(_ question: RecallQuestion) -> some View {
        VStack(alignment: .leading, spacing: Forest.Space.m) {
            Text(feedback).font(.headline)
            if question.snapshot.questionKind != .meaningSelfRated {
                if !viewModel.state.draft.isEmpty { answerRow("Your answer", viewModel.state.draft) }
                if !question.snapshot.acceptedAnswers.isEmpty { answerRow("Supplied answers", question.snapshot.acceptedAnswers.joined(separator: ", ")) }
                if let index = question.snapshot.correctIndex, question.snapshot.choices.indices.contains(index) {
                    if let selected = viewModel.state.selectedIndex, question.snapshot.choices.indices.contains(selected) { answerRow("Your answer", question.snapshot.choices[selected]) }
                    answerRow("Supplied answer", question.snapshot.choices[index])
                }
                Text(question.snapshot.explanation)
            }
        }.forestStudyCard()
    }

    private func answerRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Forest.Space.xs) {
            Text(label).font(.subheadline).foregroundStyle(Forest.inkMuted)
            Text(value).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
        }
    }

    @ViewBuilder private var actions: some View {
        if viewModel.state.error != nil {
            actionGroup {
                Button("Retry saving or opening") { answerFocused = false; viewModel.send(.retry) }.buttonStyle(PrimaryButtonStyle())
                Button("Exit practice") { exit() }.buttonStyle(.plain).frame(minHeight: 44)
            }
        } else if viewModel.state.isComplete {
            actionGroup {
                Button("Back to practice") { exit() }.buttonStyle(PrimaryButtonStyle())
                Button("Practice again") { viewModel.send(.restart) }.buttonStyle(.plain).frame(minHeight: 44)
            }
        } else if !viewModel.state.isLoading, !viewModel.state.contentChanged, let question = viewModel.current {
            actionGroup {
                if viewModel.state.isRevealed {
                    Button(nextTitle) { advance() }.buttonStyle(PrimaryButtonStyle())
                } else if question.snapshot.questionKind == .meaningSelfRated {
                    if viewModel.state.isAnswerShown {
                        Button("Remembered") { viewModel.send(.rate(true)) }.buttonStyle(PrimaryButtonStyle())
                        Button("Didn't remember") { viewModel.send(.rate(false)) }.buttonStyle(.plain).frame(minHeight: 44)
                    } else {
                        Button("Reveal meaning") { viewModel.send(.reveal) }.buttonStyle(PrimaryButtonStyle()).disabled(!canReveal)
                    }
                } else if viewModel.state.isAnswerShown {
                    Button(viewModel.state.position + 1 == viewModel.state.total ? "Finish without submitting" : "Next without submitting") { advance() }.buttonStyle(PrimaryButtonStyle())
                } else if question.snapshot.questionKind != .choice {
                    Button("Check answer") { submit() }.buttonStyle(PrimaryButtonStyle()).disabled(!viewModel.canSubmit)
                    if viewModel.isListening, question.snapshot.questionKind == .listeningReading {
                        Button("Reveal without checking") { answerFocused = false; viewModel.send(.reveal) }.buttonStyle(.plain).frame(minHeight: 44).disabled(!canReveal)
                    }
                }
            }
        }
    }

    private func actionGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: Forest.Space.s, content: content).foregroundStyle(Forest.ink)
            .padding(.horizontal, Forest.Space.l).padding(.vertical, Forest.Space.m).background(Forest.canvas)
    }
    private var canReveal: Bool { !viewModel.isListening || (viewModel.state.heardPlayback && viewModel.playbackFailure == nil) }
    private var nextTitle: String { viewModel.state.position + 1 == viewModel.state.total ? "Finish practice" : "Next question" }
    private func answerPlaceholder(_ question: RecallQuestion) -> String {
        question.snapshot.questionKind == .romanization ? "Romanization" : question.snapshot.questionKind == .conjugation ? "Japanese form" : "Kana reading"
    }
    private func submit() {
        guard viewModel.canSubmit else { return }
        answerFocused = false
        viewModel.send(.submit)
    }
    private func advance() { answerFocused = false; viewModel.send(.next) }
    private func exit() { answerFocused = false; viewModel.send(.cancel); dismiss() }
    private var feedback: String {
        switch viewModel.state.outcome {
        case .correct: return "Matches a supplied answer"
        case .incorrect: return "Compare with the supplied answers"
        case .selfRated: return viewModel.state.remembered == true ? "Self-rated: remembered" : "Self-rated: didn't remember"
        case nil: return ""
        }
    }
}
