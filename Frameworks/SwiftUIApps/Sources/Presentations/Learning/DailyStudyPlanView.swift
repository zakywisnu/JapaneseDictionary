import SwiftUI
import DataKit

struct DailyStudyPlanView: View {
    @EnvironmentObject private var router: AppRouter
    @State var viewModel: DailyStudyPlanViewModel
    var body: some View {
        List {
            if viewModel.state.isLoading {
                ProgressView("Preparing your study plan")
            } else if let error = viewModel.state.error {
                StateMessage(title: "Couldn't prepare your plan", message: error, actionTitle: "Try again") { viewModel.send(.load) }
            } else {
                Section {
                    Text(viewModel.goalReached ? "Today's goal is complete. More practice is optional." : "Choose a batch from your saved items.")
                    if let snapshot = viewModel.state.snapshot, !snapshot.completed.isEmpty {
                        Text("\(snapshot.completed.count) distinct items completed today")
                            .font(.subheadline).foregroundStyle(Forest.inkMuted)
                    }
                }.listRowBackground(Forest.surface)
                if viewModel.batches.isEmpty {
                    Section {
                        StateMessage(title: "Your reviews are up to date", message: "Save a lesson or try learning practice to study something new.")
                        Button("Practice kana") { router.push(.kanaPractice, hideNavBar: false) }
                        Button("Browse lessons") { router.push(.lessons, hideNavBar: false) }
                    }.listRowBackground(Forest.surface)
                } else {
                    ForEach(viewModel.batches) { batch in
                        Section(batch.title) {
                            Text(batch.explanation).foregroundStyle(Forest.inkMuted)
                            Button("Review \(batch.items.count) items") {
                                router.push(.review(batch.session), hideNavBar: false)
                            }.buttonStyle(.bordered).frame(minHeight: 44)
                            DisclosureGroup("Preview items") {
                                ForEach(batch.items, id: \.compositeID) { item in
                                    MaterialPrompt(text: item.headword).padding(.vertical, Forest.Space.xs)
                                }
                            }.tint(Forest.inkMuted)

                        }.listRowBackground(Forest.surface)
                    }
                }
                Section("Something new") {
                    Button("Learning practice") { router.push(.learningPractice, hideNavBar: false) }
                }.listRowBackground(Forest.surface)
            }
        }
        .forestTabList()
        .foregroundStyle(Forest.ink).background(Forest.canvas)
        .navigationTitle("Daily study plan").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear { viewModel.send(.load) }
        .listRowBackground(Forest.surface)
    }
}

extension AppComposer {
    func makeDailyStudyPlanView() -> some View {
        DailyStudyPlanView(viewModel: makeDailyStudyPlanViewModel())
    }
    func makeDailyStudyPlanViewModel() -> DailyStudyPlanViewModel {
        .init(load: { [self] in
            let repository = StandardReviewRepository(store: store)
            let items = try SavedStudyKind.allCases.flatMap { try repository.savedItems(kind: $0) }.map(ReviewItem.init(saved:))
            let goals = StandardDailyGoalRepository(store: store)
            let day = PracticeActivity.dayKey(for: Date())
            return .init(items: items, reviews: try repository.records(), difficulties: try StandardStudyRatingRepository(store: store).records(), completed: Set(try goals.activities(dayKey: day).map(\.studyID)), target: try goals.target())
        })
    }
    func makeDailyStudyPlanSummaryView() -> some View { DailyStudyPlanSummaryView(viewModel: makeDailyStudyPlanViewModel()) }
}


struct DailyStudyPlanSummaryView: View {
    @State var viewModel: DailyStudyPlanViewModel
    @EnvironmentObject private var router: AppRouter
    var body: some View {
        Group {
            if viewModel.state.isLoading { ProgressView("Preparing your plan") }
            else if let error = viewModel.state.error {
                StateMessage(title: "Couldn't prepare your plan", message: error, actionTitle: "Try again") { viewModel.send(.load) }
            } else {
                ForestNavigationRow(title: "Daily study plan", subtitle: summary) { router.push(.dailyStudyPlan, hideNavBar: false) }
                    .background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
            }
        }.onAppear { viewModel.send(.load) }
    }
    private var summary: String {
        if viewModel.goalReached { return "Goal complete. More practice is optional." }
        if viewModel.batches.isEmpty { return "Choose something new to practice" }
        return viewModel.batches.map { "\($0.title): \($0.items.count) items" }.joined(separator: " · ")
    }
}
