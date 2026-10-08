import DataKit

// A catalog anchor may link updated meanings without changing the learner's study content.
enum DictionaryLink: Equatable {
    case loading
    case linked(DictionaryWord)
    case unavailable
    case ambiguous
    case failed

    static func resolve(_ saved: Kotoba, in repository: VocabularyCatalogRepository) -> DictionaryLink {
        if let id = saved.catalogID {
            return repository.word(id: id).map(Self.linked) ?? .unavailable
        }
        if let word = repository.word(headword: saved.kanji, reading: saved.furigana, meanings: saved.english) {
            return .linked(word)
        }
        let candidates = repository.catalog.entries.filter { word in
            let spellingMatches = word.headword == saved.kanji || word.forms.contains { $0.text == saved.kanji }
                || (word.forms.isEmpty && word.readings.contains { $0.text == saved.kanji })
            return spellingMatches && word.readings.contains { reading in
                reading.text == saved.furigana && (reading.spellings.isEmpty || reading.spellings.contains(saved.kanji))
            }
        }
        return candidates.count > 1 ? .ambiguous : .unavailable
    }
}

extension Kotoba {
    func updatedStudyWord(from word: DictionaryWord) -> Kotoba? {
        guard let level = Level(rawValue: word.level), !word.studyMeanings.isEmpty else { return nil }
        guard kanji != word.headword || furigana != word.reading || english != word.studyMeanings || jlptLevel != level else { return nil }
        var updated = self
        updated.kanji = word.headword
        updated.furigana = word.reading
        updated.english = word.studyMeanings
        updated.jlptLevel = level
        return updated
    }
}
