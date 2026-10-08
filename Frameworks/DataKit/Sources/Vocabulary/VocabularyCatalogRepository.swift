import Foundation

public enum VocabularyCatalogError: Error, LocalizedError {
    case unsupportedVersion(Int)
    case invalidCatalog(String)
    case missingResource(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version): return "Vocabulary catalog version \(version) is not supported."
        case .invalidCatalog(let reason): return "The vocabulary catalog is invalid: \(reason)."
        case .missingResource(let name): return "The bundled vocabulary resource \(name) is missing."
        }
    }
}

public struct VocabularyCatalogRepository: Sendable {
    public let catalog: DictionaryCatalog
    private let byID: [String: DictionaryWord]
    private let byHeadword: [String: [DictionaryWord]]

    public init(catalog: DictionaryCatalog) throws {
        guard catalog.version == 2 else { throw VocabularyCatalogError.unsupportedVersion(catalog.version) }
        guard Self.nonempty(catalog.created), Self.nonempty(catalog.jmdictCreated) else {
            throw VocabularyCatalogError.invalidCatalog("missing snapshot dates")
        }
        var byID: [String: DictionaryWord] = [:]
        var byHeadword: [String: [DictionaryWord]] = [:]
        for word in catalog.entries {
            try Self.validate(word)
            guard byID[word.id] == nil else { throw VocabularyCatalogError.invalidCatalog("duplicate identity \(word.id)") }
            byID[word.id] = word
            for form in Set(word.forms.map(\.text) + word.readings.map(\.text)) {
                byHeadword[form, default: []].append(word)
            }
        }
        for id in catalog.legacyMap.compactMap({ $0 }) where byID[id] == nil {
            throw VocabularyCatalogError.invalidCatalog("legacy mapping references missing identity \(id)")
        }
        self.catalog = catalog
        self.byID = byID
        self.byHeadword = byHeadword
    }

    public init(data: Data) throws {
        try self.init(catalog: JSONDecoder().decode(DictionaryCatalog.self, from: data))
    }

    public static func bundled() throws -> VocabularyCatalogRepository {
        try bundledResult.get()
    }

    private static let bundledResult: Result<VocabularyCatalogRepository, Error> = Result {
        guard let url = Bundle(for: StandardVocabRepository.self).url(forResource: "vocabulary-v2", withExtension: "json") else {
            throw VocabularyCatalogError.missingResource("vocabulary-v2.json")
        }
        let repository = try VocabularyCatalogRepository(data: Data(contentsOf: url))
        guard repository.catalog.legacyMap.count == 8_130 else {
            throw VocabularyCatalogError.invalidCatalog("legacy mapping must contain all 8,130 original slots")
        }
        return repository
    }

    public static var attributionText: String {
        (try? attributionResult.get()) ?? "Vocabulary source notices could not be loaded."
    }

    private static let attributionResult: Result<String, Error> = Result {
        guard let url = Bundle(for: StandardVocabRepository.self).url(forResource: "vocabulary-attribution", withExtension: "txt") else {
            throw VocabularyCatalogError.missingResource("vocabulary-attribution.txt")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    public func word(id: String) -> DictionaryWord? { byID[id] }

    public func word(headword: String, reading: String, meanings: [String]) -> DictionaryWord? {
        let requestedMeanings = Set(meanings.map(Self.normalizedMeaning).filter { !$0.isEmpty && !["to", "a", "an", "the"].contains($0) })
        guard !requestedMeanings.isEmpty else { return nil }
        let candidates = (byHeadword[headword] ?? []).filter { word in
            guard Self.compatible(word, headword: headword, reading: reading) else { return false }
            let glosses = Self.selectedSenses(word).filter { sense in
                Self.compatibleSense(sense, word: word, headword: headword, reading: reading)
            }.flatMap(\.meanings)
            return !requestedMeanings.isDisjoint(with: Set(glosses.map(Self.normalizedMeaning)))
        }
        guard Set(candidates.map(\.jmdictID)).count == 1 else { return nil }
        let primaryReadings = candidates.filter { $0.reading == reading }
        let readingMatches = primaryReadings.isEmpty ? candidates : primaryReadings
        let primaryForms = readingMatches.filter { $0.headword == headword }
        let preferred = primaryForms.isEmpty ? readingMatches : primaryForms
        return preferred.count == 1 ? preferred.first : nil
    }

    private static func selectedSenses(_ word: DictionaryWord) -> [DictionarySense] {
        let studyMeanings = Set(word.studyMeanings)
        return word.senses.filter { sense in
            compatibleSense(sense, word: word, headword: word.headword, reading: word.reading) &&
                studyMeanings.isSubset(of: Set(sense.meanings))
        }
    }

    private static func compatibleSense(_ sense: DictionarySense, word: DictionaryWord, headword: String, reading: String) -> Bool {
        guard sense.readings.isEmpty || sense.readings.contains(reading) else { return false }
        if sense.spellings.isEmpty || sense.spellings.contains(headword) { return true }
        guard headword == reading else { return false }
        return word.readings.contains { item in
            item.text == reading && !item.kanaOnly && sense.spellings.contains { spelling in
                item.spellings.isEmpty || item.spellings.contains(spelling)
            }
        }
    }

    private static func compatible(_ word: DictionaryWord, headword: String, reading: String) -> Bool {
        word.readings.contains { item in
            guard item.text == reading else { return false }
            if headword == reading { return true }
            return !item.kanaOnly && word.forms.contains(where: { $0.text == headword }) &&
                (item.spellings.isEmpty || item.spellings.contains(headword))
        }
    }

    private static func normalizedMeaning(_ value: String) -> String {
        value.lowercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            .trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
    }

    private static func nonempty(_ value: String) -> Bool { !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private static func validate(_ word: DictionaryWord) throws {
        let forms = Set(word.forms.map(\.text))
        let readings = Set(word.readings.map(\.text))
        guard nonempty(word.id), word.jmdictID > 0, nonempty(word.headword), nonempty(word.reading),
              ["N1", "N2", "N3", "N4", "N5"].contains(word.level),
              !word.studyMeanings.isEmpty, word.studyMeanings.allSatisfy(nonempty),
              !selectedSenses(word).isEmpty,
              !word.readings.isEmpty, !word.senses.isEmpty,
              // JMdict retains distinct code-point forms that Swift considers canonically equivalent.
              Set(word.forms.map { Array($0.text.utf8) }).count == word.forms.count,
              Set(word.readings.map { Array($0.text.utf8) }).count == word.readings.count,
              word.forms.allSatisfy({ nonempty($0.text) }),
              word.readings.allSatisfy({ nonempty($0.text) && Set($0.spellings).isSubset(of: forms) }),
              word.senses.allSatisfy({ !$0.meanings.isEmpty && $0.meanings.allSatisfy(nonempty) && Set($0.spellings).isSubset(of: forms) && Set($0.readings).isSubset(of: readings) }),
              compatible(word, headword: word.headword, reading: word.reading) else {
            throw VocabularyCatalogError.invalidCatalog("invalid word or form/reading restrictions for \(word.id)")
        }
    }
}
