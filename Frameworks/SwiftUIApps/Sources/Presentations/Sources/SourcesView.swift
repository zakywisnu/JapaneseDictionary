import SwiftUI
import DataKit

struct SourcesView: View {
    private let vocabularyCredits: String
    private let credits: String

    init(credits: String = ExampleRepository.bundled().attributionText, vocabularyCredits: String = VocabularyCatalogRepository.attributionText) {
        self.vocabularyCredits = vocabularyCredits
        self.credits = credits
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Forest.Space.l) {
                Text("Vocabulary dictionary")
                    .font(.headline)
                    .foregroundStyle(Forest.ink)
                Text("JMdict supplies dictionary meanings, readings and written forms. Vocabulary JLPT levels are reviewed community estimates, not official exam coverage. The dictionary snapshot is bundled and works offline.")
                    .font(.body)
                    .foregroundStyle(Forest.ink)
                Text(vocabularyCredits)
                    .font(.body)
                    .foregroundStyle(Forest.ink)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
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
