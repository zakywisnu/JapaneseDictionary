import SwiftUI
import DataKit

struct ExampleSentenceCard: View {
    let example: ExampleSentence

    var body: some View {
        VStack(alignment: .leading, spacing: Forest.Space.m) {
            Text("Example sentence")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Forest.inkMuted)
            Text(example.japanese)
                .font(.headword(22, relativeTo: .title3))
                .foregroundStyle(Forest.ink)
            if let reading = example.sentenceReading {
                Text(reading)
                    .font(.subheadline)
                    .foregroundStyle(Forest.inkMuted)
            }
            Text(example.english)
                .font(.body)
                .foregroundStyle(Forest.ink)
            Text("Tatoeba · \(example.license). Credits in Sources.")
                .font(.caption)
                .foregroundStyle(Forest.inkMuted)
        }
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Forest.Space.l)
        .background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
    }
}
