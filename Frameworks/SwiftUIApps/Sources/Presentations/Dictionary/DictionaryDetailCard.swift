import SwiftUI
import DataKit

struct DictionaryDetailCard: View {
    let word: DictionaryWord

    var body: some View {
        VStack(alignment: .leading, spacing: Forest.Space.xl) {
            section("Dictionary meanings") {
                ForEach(Array(word.senses.enumerated()), id: \.offset) { index, sense in
                    VStack(alignment: .leading, spacing: Forest.Space.s) {
                        Text("\(index + 1). \(sense.meanings.joined(separator: "; "))")
                            .font(.body)
                            .foregroundStyle(Forest.ink)
                        annotation(sense.pos.joined(separator: ", "))
                        annotation(sense.labels.joined(separator: ", "))
                        if !sense.spellings.isEmpty {
                            annotation("Written forms: \(sense.spellings.joined(separator: ", "))")
                        }
                        if !sense.readings.isEmpty {
                            annotation("Readings: \(sense.readings.joined(separator: ", "))")
                        }
                        ForEach(sense.notes, id: \.self) { note in annotation(note) }
                    }
                }
            }
            if !word.readings.isEmpty {
                section("Readings") {
                    ForEach(Array(word.readings.enumerated()), id: \.offset) { _, reading in
                        VStack(alignment: .leading, spacing: Forest.Space.xs) {
                            Text(reading.text).font(.body).foregroundStyle(Forest.ink)
                            if reading.kanaOnly { annotation("Used without a written kanji form") }
                            if !reading.spellings.isEmpty {
                                annotation("For: \(reading.spellings.joined(separator: ", "))")
                            }
                            if reading.common { annotation("Marked common in JMdict") }
                            ForEach(reading.notes, id: \.self) { note in annotation(note) }
                        }
                    }
                }
            }
            if !word.forms.isEmpty {
                section("Written forms") {
                    ForEach(Array(word.forms.enumerated()), id: \.offset) { _, form in
                        VStack(alignment: .leading, spacing: Forest.Space.xs) {
                            Text(form.text).font(.headword(24, relativeTo: .title2)).foregroundStyle(Forest.ink)
                            if form.common { annotation("Marked common in JMdict") }
                            ForEach(form.notes, id: \.self) { note in annotation(note) }
                        }
                    }
                }
            }
        }
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Forest.Space.l) {
            Text(title).font(.headline).foregroundStyle(Forest.ink)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Forest.Space.l)
        .background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
    }

    @ViewBuilder
    private func annotation(_ text: String) -> some View {
        if !text.isEmpty {
            Text(text).font(.subheadline).foregroundStyle(Forest.inkMuted)
        }
    }
}
