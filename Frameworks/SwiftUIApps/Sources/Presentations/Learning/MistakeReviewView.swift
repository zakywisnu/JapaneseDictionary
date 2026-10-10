import SwiftUI

struct MistakeReviewView: View {
    let viewModel: ExerciseHistoryViewModel
    var body: some View { ExerciseHistoryView(viewModel: viewModel, mistakesOnly: true) }
}
