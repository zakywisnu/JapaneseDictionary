import SwiftUI

struct DailyGoalSummaryView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State var viewModel: DailyGoalViewModel

    var body: some View {
        Group {
            if viewModel.state.isLoading {
                ProgressView("Loading daily practice")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let error = viewModel.state.error {
                StateMessage(title: "Couldn't open daily practice", message: error, actionTitle: "Try again") { viewModel.send(.load) }
            } else if let summary = viewModel.state.summary, let target = summary.target {
                VStack(alignment: .leading, spacing: Forest.Space.s) {
                    Text("\(summary.completedCount.formatted()) of \(target.formatted()) items practiced today")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Forest.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    ProgressTrack(value: Double(summary.completedCount) / Double(target))
                    if summary.isReached {
                        Text("Goal reached. Keep studying if you'd like.")
                            .font(.subheadline)
                            .foregroundStyle(Forest.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(Forest.Space.l)
                .background(Forest.surface, in: RoundedRectangle(cornerRadius: Forest.Radius.card))
            }
        }
        .onAppear { viewModel.send(.load) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.send(.load) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in viewModel.send(.load) }
    }
}
