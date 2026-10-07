import SwiftUI
import DataKit

struct SourcesView: View {
    private let credits: String

    init(credits: String = ExampleRepository.bundled().attributionText) {
        self.credits = credits
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Forest.Space.l) {
                Text("Example sentence sources")
                    .font(.headline)
                    .foregroundStyle(Forest.ink)
                Text(credits)
                    .font(.body)
                    .foregroundStyle(Forest.ink)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Forest.Space.l)
        }
        .background(Forest.canvas)
        .navigationTitle("Sources")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}
