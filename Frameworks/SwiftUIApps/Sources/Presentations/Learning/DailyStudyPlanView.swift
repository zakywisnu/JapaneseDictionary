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
                    Text(viewModel.goalReached ? "Today's goal is complete. More practice is optional." : "A short session based on your saved items. Complete one batch, then return for an updated plan.")
                    if let snapshot = viewModel.state.snapshot {
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
                            ForEach(batch.items, id: \.compositeID) { item in
                                MaterialPrompt(text: item.headword)
                            }
                            Button("Review \(batch.items.count) items") {
                                router.push(.review(batch.session), hideNavBar: false)
                            }
                            .buttonStyle(.bordered)
                        }.listRowBackground(Forest.surface)
                    }
                }
                Section("Something new") {
                    Button("Learning practice") { router.push(.learningPractice, hideNavBar: false) }
                }.listRowBackground(Forest.surface)
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden)
        .foregroundStyle(Forest.ink).background(Forest.canvas)
        .navigationTitle("Daily study plan").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear { viewModel.send(.load) }
        .listRowBackground(Forest.surface)
    }
}

extension AppComposer {
    func makeDailyStudyPlanView() -> some View {
        DailyStudyPlanView(viewModel: .init(load: { [self] in
            let repository = StandardReviewRepository(store: store)
            let items = try SavedStudyKind.allCases.flatMap { try repository.savedItems(kind: $0) }.map(ReviewItem.init(saved:))
            let goals = StandardDailyGoalRepository(store: store)
            let day = PracticeActivity.dayKey(for: Date())
            return .init(items: items, reviews: try repository.records(), difficulties: try StandardStudyRatingRepository(store: store).records(), completed: Set(try goals.activities(dayKey: day).map(\.studyID)), target: try goals.target())
        }))
    }
}
