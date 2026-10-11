import SwiftUI
import DataKit

extension AppComposer {
    func makeSentenceBuildingSessionView(snapshots: [ExerciseSnapshot], activityKey: String, title: String) -> some View {
        SentenceBuildingView(viewModel: .init(snapshots: snapshots, activityKey: activityKey, persistence: exercisePersistence(activityKey: activityKey)), title: title)
    }
    func makeSentenceBuildingView(topicID: String? = nil) -> some View {
        SentenceBuildingSetupView(composer: self, topicID: topicID)
    }
}

private struct SentenceBuildingSetupView: View {
    @EnvironmentObject private var router: AppRouter
    let composer: AppComposer
    let topicID: String?
    @State private var activities: [AppliedPracticeActivity] = []
    @State private var failed = false
    @State private var loading = true
    @State private var limit = 10
    var body: some View {
        List {
            Text("Original beginner sentences with transparent model checks. Choose a topic and arrange its tokens.").foregroundStyle(Forest.inkMuted)
            Picker("Session size", selection: $limit) {
                Text("5").tag(5); Text("10").tag(10); Text("All").tag(Int.max)
            }
            if loading { ProgressView("Loading sentence topics") }
            else if failed {
                StateMessage(title: "Couldn't open sentence topics", message: "The bundled sentence content couldn't be read. Try again.", actionTitle: "Try again", action: load)
            } else if activities.isEmpty {
                StateMessage(title: "No sentence topics", message: "Return to Practice and choose another activity.")
            } else {
                ForEach(activities, id: \.id) { activity in
                    Button {
                        router.push(.sentenceBuildingSession(Array(activity.questions.prefix(limit)), "sentence-building:\(activity.id)", activity.title), hideNavBar: false)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(activity.title)
                            Text("\(min(limit, activity.questions.count)) sentences").font(.caption).foregroundStyle(Forest.inkMuted)
                        }
                    }.buttonStyle(.plain).foregroundStyle(Forest.ink)
                }
            }
        }.scrollContentBackground(.hidden).background(Forest.canvas)
            .navigationTitle("Sentence building").onAppear(perform: load)
    }
    private func load() {
        loading = true
        do {
            activities = try AppliedPracticeCatalogRepository.bundled().activities.filter {
                $0.kind == .sentenceOrder && (topicID == nil || $0.id == topicID || $0.questions.contains { $0.metadata?.topicID == topicID })
            }
            let grouped = Dictionary(grouping: activities.flatMap(\.questions), by: { $0.metadata?.topicID ?? "sentence:beginner" })
            activities = grouped.keys.sorted().map { key in
                AppliedPracticeActivity(id: key, title: "Beginner sentences", kind: .sentenceOrder, questions: grouped[key] ?? [])
            }
            failed = false
        } catch { failed = true }
        loading = false
    }
}
