import Foundation
import CryptoKit
import Observation
import DataKit
import DomainKit

enum RecallMode: String, CaseIterable, Identifiable {
    case reading = "Kana reading", romanization = "Kana romanization", meaning = "Meaning recall"
    var id: String { rawValue }
}
enum RecallSource: String, CaseIterable, Identifiable {
    case kana = "Bundled kana", words = "Words", kanji = "Kanji", grammar = "Grammar", sentences = "Sentences", cards = "Your cards"
    var id: String { rawValue }
    var kind: SavedStudyKind? {
        switch self { case .kana: return nil; case .words: return .word; case .kanji: return .kanji; case .grammar: return .grammar; case .sentences: return .sentence; case .cards: return .customCard }
    }
}

@MainActor
@Observable
final class RecallSelectionViewModel {
    let isListening: Bool
    private let loadItems: () throws -> [SavedStudyItem]
    private let loadLists: () throws -> [StudyList]
    private let loadMembers: (String) throws -> [SavedStudyItem]
    private let save: (ExerciseCheckpoint) throws -> Void
    private var items: [SavedStudyItem] = []
    private var members: Set<SavedStudyID>?
    private(set) var state = State()
    init(isListening: Bool, loadItems: @escaping () throws -> [SavedStudyItem], loadLists: @escaping () throws -> [StudyList], loadMembers: @escaping (String) throws -> [SavedStudyItem], save: @escaping (ExerciseCheckpoint) throws -> Void) {
        self.isListening = isListening; self.loadItems = loadItems; self.loadLists = loadLists; self.loadMembers = loadMembers; self.save = save
    }
    var candidates: [RecallQuestion] {
        if state.mode == .romanization || state.source == .kana {
            return KanaCatalog.entries.filter { $0.script == state.script && $0.group == state.group }.compactMap { entry in
                Self.kanaQuestion(entry, mode: state.mode, listening: isListening)
            }
        }
        let filtered = items.filter { $0.id.kind == state.source.kind && (members == nil || members!.contains($0.id)) }
        return filtered.flatMap { Self.savedQuestions($0, mode: state.mode, listening: isListening) }
    }
    var selected: [RecallQuestion] {
        let eligible = state.source == .kanji && state.mode == .reading ? candidates.filter { state.selectedReadingIDs.contains($0.id) } : candidates
        return Array(eligible.prefix(state.limit ?? 1_000))
    }
    var excludedCount: Int {
        if state.mode == .romanization || state.source == .kana {
            return KanaCatalog.entries.filter { $0.script == state.script && $0.group == state.group }.count - candidates.count
        }
        let filtered = items.filter { $0.id.kind == state.source.kind && (members == nil || members!.contains($0.id)) }
        return filtered.filter { Self.savedQuestions($0, mode: state.mode, listening: isListening).isEmpty }.count
    }
    func send(_ action: Action) {
        switch action {
        case .load:
            state.isLoading = true; state.error = nil
            do {
                let loaded = try loadItems().sorted { $0.id.key < $1.id.key }
                var seen: Set<SavedStudyID> = []
                items = loaded.filter { seen.insert($0.id).inserted }; state.lists = try loadLists()
                members = try state.listID.map { Set(try loadMembers($0).map(\.id)) }
            } catch { state.error = "Your saved items or study lists couldn't be opened. Try again." }
            state.isLoading = false
        case .mode(let value): state.mode = value; state.startedKey = nil
        case .source(let value): state.source = value; state.startedKey = nil
        case .list(let value): state.listID = value; send(.load)
        case .limit(let value): state.limit = value
        case .script(let value): state.script = value
        case .group(let value): state.group = value
        case .toggleReading(let value): if !state.selectedReadingIDs.insert(value).inserted { state.selectedReadingIDs.remove(value) }
        case .start:
            guard !state.isLoading, state.error == nil, !selected.isEmpty else { return }
            let key = (isListening ? "listening:" : "typed:") + UUID().uuidString
            do {
                try save(ExerciseCheckpoint(activityKey: key, sessionID: UUID(), orderedSnapshots: selected.map(\.snapshot), position: 0, updatedAt: Date()))
                state.startedKey = key; state.startError = nil
            } catch { state.startError = "Your practice session couldn't be saved. Keep this selection and try Start practice again." }
        }
    }
    nonisolated static func kanaQuestion(_ entry: KanaEntry, mode: RecallMode, listening: Bool) -> RecallQuestion? {
        guard let reading = entry.reading, SpeechTextValidator.normalizedReading(reading) != nil, mode != .meaning else { return nil }
        let kind: ExerciseQuestionKind = listening ? .listeningReading : mode == .romanization ? .romanization : .kanaReading
        let accepted = mode == .romanization && !listening ? TypedAnswerPolicy.romanizationAliases(for: entry) : [reading]
        let id = kind == .romanization ? entry.id : (listening ? "listening:" : "typed:") + entry.id
        return RecallQuestion(snapshot: ExerciseSnapshot(id: id, revision: 1, questionKind: kind, prompt: entry.kana, acceptedAnswers: accepted, explanation: entry.note), suppliedReading: reading)
    }
    nonisolated static func savedQuestions(_ item: SavedStudyItem, mode: RecallMode, listening: Bool) -> [RecallQuestion] {
        guard mode != .romanization else { return [] }
        let readings = item.id.kind == .kanji ? item.onyomi + item.kunyomi : [item.exampleWordKey?.reading ?? item.material?.reading ?? item.reading].compactMap { $0 }
        let supplied = Array(Set(readings.compactMap { SpeechTextValidator.normalizedReading($0) })).sorted()
        let prefix = (listening ? "listening:" : "typed:") + (mode == .meaning ? "meaning:" : "reading:") + item.id.key
        if mode == .meaning {
            guard !item.meanings.isEmpty, !listening || supplied.count == 1 else { return [] }
            return [RecallQuestion(snapshot: ExerciseSnapshot(id: prefix, revision: 1, questionKind: .meaningSelfRated, prompt: item.headword, explanation: item.meanings.joined(separator: "; ")), source: item.id, suppliedReading: supplied.first)]
        }
        return supplied.map { reading in
            let suffix = item.id.kind == .kanji ? ":" + digest(reading) : ""
            return RecallQuestion(snapshot: ExerciseSnapshot(id: prefix + suffix, revision: 1, questionKind: listening ? .listeningReading : .kanaReading, prompt: item.headword, acceptedAnswers: [reading], explanation: "Supplied reading: " + reading), source: item.id, suppliedReading: reading)
        }
    }
    nonisolated static func digest(_ value: String) -> String { SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined() }
    struct State {
        var mode: RecallMode = .reading
        var source: RecallSource = .words
        var script: KanaScript = .hiragana
        var group: KanaGroup = .basic
        var listID: String?
        var limit: Int? = 20
        var selectedReadingIDs: Set<String> = []
        var lists: [StudyList] = []
        var isLoading = true
        var error: String?
        var startError: String?
        var startedKey: String?
    }
    enum Action { case load, mode(RecallMode), source(RecallSource), list(String?), limit(Int?), script(KanaScript), group(KanaGroup), toggleReading(String), start }
}
