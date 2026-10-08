import DataKit
import Foundation

struct DictionarySearchIndex {
    private struct Entry {
        let word: DictionaryWord
        let headword: String
        let reading: String
        let searchTerms: [String]
    }

    private let entries: [Entry]

    init(words: [DictionaryWord]) {
        entries = words.map { word in
            Entry(
                word: word,
                headword: Self.normalized(word.headword),
                reading: Self.normalized(word.reading),
                searchTerms: (word.forms.map(\.text) + word.readings.map(\.text) + word.senses.flatMap(\.meanings))
                    .map(Self.normalized)
            )
        }
    }

    func results(query: String, level: String?) -> [DictionaryWord] {
        let query = Self.normalized(query)
        var exact: [DictionaryWord] = []
        var prefix: [DictionaryWord] = []
        var remaining: [DictionaryWord] = []

        for entry in entries {
            guard level == nil || entry.word.level == level else { continue }
            if query.isEmpty {
                remaining.append(entry.word)
            } else if entry.headword == query || entry.reading == query {
                exact.append(entry.word)
            } else if entry.headword.hasPrefix(query) || entry.reading.hasPrefix(query) {
                prefix.append(entry.word)
            } else if entry.searchTerms.contains(where: { $0.contains(query) }) {
                remaining.append(entry.word)
            }
        }
        return exact + prefix + remaining
    }

    private static func normalized(_ value: String) -> String {
        value.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
