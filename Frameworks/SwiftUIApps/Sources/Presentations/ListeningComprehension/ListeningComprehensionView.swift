import SwiftUI
import DataKit

struct ListeningComprehensionView: View {
    @State var viewModel: ListeningComprehensionViewModel
    let title: String
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Forest.Space.xl) {
                if viewModel.state.loading { ProgressView("Opening listening practice") }
                else if viewModel.state.contentChanged {
                    StateMessage(title: "This passage has changed", message: "Your submitted answers remain in History. Start a new session with the current passage.", actionTitle: "Start new session", action: { viewModel.send(.restart) })
                } else if viewModel.state.isComplete {
                    Text("Listening practice complete").font(.title2.bold())
                    Text("\(viewModel.state.matched) correct / \(viewModel.state.checked) checked answers")
                    Text("Transcript-assisted questions are ungraded. Review dates and your saved-item goal stay unchanged.").foregroundStyle(Forest.inkMuted)
                    Button("Practice again") { viewModel.send(.restart) }.buttonStyle(SecondaryButtonStyle()).tint(Forest.ink)
                } else if let question = viewModel.current {
                    Text("Question \(viewModel.state.position + 1) of \(viewModel.snapshots.count)").font(.subheadline).foregroundStyle(Forest.inkMuted)
                    Text("Listen to the passage, then answer its meaning question.").font(.headline)
                    (textSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: Forest.Space.s)) : AnyLayout(HStackLayout(spacing: Forest.Space.s))) {
                        Button(viewModel.state.heardPlayback ? "Replay passage" : "Listen to passage") { viewModel.send(.play) }.buttonStyle(SecondaryButtonStyle()).tint(Forest.ink)
                        if viewModel.pronunciation.state == .playing { Button("Stop") { viewModel.send(.stop) }.buttonStyle(SecondaryButtonStyle()).tint(Forest.ink) }
                    }.frame(minHeight: 44)
                    Text("Synthesized Japanese speech").font(.footnote).foregroundStyle(Forest.inkMuted)
                    if let error = viewModel.playbackError {
                        StateMessage(title: "Listening unavailable", message: error, actionTitle: "Check again", action: { viewModel.pronunciation.refreshAvailability() })
                    }
                    Text(question.prompt).font(.title3.weight(.semibold))
                    ForEach(question.choices.indices, id: \.self) { index in
                        Button { viewModel.send(.choose(index)) } label: {
                            HStack(alignment: .top) {
                                Image(systemName: viewModel.state.selected == index ? "checkmark.circle" : "circle")
                                Text(question.choices[index]).frame(maxWidth: .infinity, alignment: .leading)
                            }.padding(Forest.Space.m).frame(minHeight: 44)
                        }.buttonStyle(ForestChoiceButtonStyle(isSelected: viewModel.state.selected == index)).disabled(viewModel.state.answered || viewModel.state.error != nil)
                            .accessibilityAddTraits(viewModel.state.selected == index ? .isSelected : [])
                    }
                    if viewModel.state.assisted {
                        Text("Transcript-assisted practice. This question won't count toward checked accuracy.").font(.subheadline).foregroundStyle(Forest.inkMuted)
                    }
                    if viewModel.state.answered {
                        Text(viewModel.state.correct.map { $0 ? "Correct" : "Try the supplied answer" } ?? "Ungraded practice").font(.headline)
                        if let answer = question.correctIndex { Text("Answer: " + question.choices[answer]) }
                        if viewModel.state.transcriptVisible { Text(question.explanation) }
                        Button(viewModel.state.position + 1 == viewModel.snapshots.count ? "Finish" : "Next") { viewModel.send(.next) }.buttonStyle(PrimaryButtonStyle()).disabled(viewModel.state.error != nil)
                    } else {
                        Button("Check") { viewModel.send(.check) }.buttonStyle(PrimaryButtonStyle()).disabled(!viewModel.canCheck)
                    }
                    if viewModel.state.transcriptVisible {
                        VStack(alignment: .leading, spacing: Forest.Space.m) {
                            Text("Transcript").font(.headline)
                            Text(question.metadata?.stimulus ?? "").font(.headword(24, relativeTo: .title2))
                            Text(question.metadata?.suppliedReading ?? "")
                            Text(question.metadata?.translation ?? "")
                        }.padding(Forest.Space.l).forestSurface()
                    } else {
                        Button("Show transcript · remaining questions become ungraded") { viewModel.send(.revealTranscript) }
                            .buttonStyle(SecondaryButtonStyle()).tint(Forest.ink).disabled(viewModel.state.error != nil)
                    }
                    Text(question.metadata?.source ?? "Original beginner practice").font(.footnote).foregroundStyle(Forest.inkMuted)
                } else { StateMessage(title: "No passage available", message: "Return to Practice and choose another activity.") }
                if let error = viewModel.state.error {
                    StateMessage(title: "Couldn't save or open practice", message: error, actionTitle: "Retry", action: { viewModel.send(.retry) })
                }
            }.padding(Forest.Space.l)
        }.background(Forest.canvas).foregroundStyle(Forest.ink).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar).toolbar(.hidden, for: .tabBar)
            .onAppear { viewModel.send(.load) }.onDisappear { viewModel.send(.cancel) }
            .onChange(of: viewModel.pronunciation.state) { _, _ in viewModel.send(.playbackChanged) }
            .onChange(of: scenePhase) { _, phase in if phase != .active { viewModel.send(.cancel) } }
    }
}

struct ListeningComprehensionSetupView: View {
    @EnvironmentObject private var router: AppRouter
    @State private var activities: [AppliedPracticeActivity] = []
    @State private var loading = true
    @State private var error: String?
    let topicID: String?
    var body: some View {
        List {
            if loading { ProgressView("Loading passages") }
            else if let error { StateMessage(title: "Couldn't open passages", message: error, actionTitle: "Try again", action: reload) }
            else if activities.isEmpty { StateMessage(title: "No matching passages", message: "Return to Practice and choose Listening comprehension without a topic filter.") }
            else {
                Section {
                    Text("Original beginner practice").font(.headline)
                    Text("Listen first. You can reveal the transcript at any time; remaining questions then become ungraded.").font(.subheadline).foregroundStyle(Forest.inkMuted)
                    ForEach(activities, id: \.id) { activity in
                        Button { router.push(.listeningComprehensionSession(activity.questions, "comprehension:" + activity.id, activity.title), hideNavBar: false) } label: {
                            VStack(alignment: .leading, spacing: Forest.Space.s) { Text(activity.title).font(.headline); Text("\(activity.questions.count) meaning questions").font(.subheadline).foregroundStyle(Forest.inkMuted) }
                        }.buttonStyle(.plain).frame(minHeight: 44)
                    }
                }.listRowBackground(Forest.surface)
            }
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden).background(Forest.canvas).foregroundStyle(Forest.ink)
            .navigationTitle("Listening comprehension").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
            .onAppear(perform: reload)
    }
    private func reload() {
        loading = true; error = nil
        do { activities = try AppliedPracticeCatalogRepository.bundled().activities.filter { $0.kind == .listeningComprehension && (topicID == nil || $0.questions.contains { $0.metadata?.topicID == topicID }) } }
        catch { activities = []; self.error = "The bundled practice passages couldn't load. Try again." }
        loading = false
    }
}

@MainActor
extension AppComposer {
    func makeListeningComprehensionView(topicID: String? = nil) -> some View { ListeningComprehensionSetupView(topicID: topicID) }
    func makeListeningComprehensionSessionView(snapshots: [ExerciseSnapshot], activityKey: String, title: String) -> some View {
        ListeningComprehensionView(viewModel: .init(snapshots: snapshots, activityKey: activityKey, persistence: exercisePersistence(activityKey: activityKey)), title: title)
    }
}
