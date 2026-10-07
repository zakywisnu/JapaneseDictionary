import Foundation
import SwiftData

public protocol MemoryAidRepository {
    func load(for word: MemoryAidWord) throws -> MemoryAidSuggestion?
    func save(_ suggestion: MemoryAidSuggestion, for word: MemoryAidWord) throws
}

public final class StandardMemoryAidRepository: MemoryAidRepository {
    private let store: StudyStore
    private let saveContext: (ModelContext) throws -> Void

    public init(store: StudyStore, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.store = store
        self.saveContext = save
    }

    public func load(for word: MemoryAidWord) throws -> MemoryAidSuggestion? {
        let saved = try matchingWord(word, context: store.makeContext())
        switch (saved.memoryExplanation, saved.memoryMnemonic) {
        case (nil, nil): return nil
        case (.some(let explanation), .some(let mnemonic)):
            return try MemoryAidSuggestion(explanation: explanation, mnemonic: mnemonic).validated()
        default: throw MemoryAidStorageError.invalidSuggestion
        }
    }

    public func save(_ suggestion: MemoryAidSuggestion, for word: MemoryAidWord) throws {
        let suggestion = try suggestion.validated()
        // Isolate rollback from pending collection or review edits in the shared context.
        let context = store.makeContext()
        let saved = try matchingWord(word, context: context)
        saved.memoryExplanation = suggestion.explanation
        saved.memoryMnemonic = suggestion.mnemonic
        do {
            try saveContext(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    private func matchingWord(_ word: MemoryAidWord, context: ModelContext) throws -> KotobaDataModel {
        let id = word.id
        let descriptor = FetchDescriptor<KotobaDataModel>(predicate: #Predicate { $0.id == id })
        guard let saved = try context.fetch(descriptor).first else { throw MemoryAidStorageError.missingWord }
        guard saved.kanji == word.headword, saved.furigana == word.reading,
              saved.english.map(\.value) == word.meanings, saved.jlptLevel.rawValue == word.level else {
            throw MemoryAidStorageError.changedWord
        }
        return saved
    }
}
