import XCTest
@testable import DataKit

final class DictionaryCatalogTests: XCTestCase {
    func testMissingFieldsAndMalformedJSONThrow() {
        XCTAssertThrowsError(try VocabularyCatalogRepository(data: Data("{".utf8)))
        XCTAssertThrowsError(try VocabularyCatalogRepository(data: Data("{\"version\":2}".utf8)))
    }

    func testVersionDuplicateIdentitiesAndMissingLegacyTargetsThrow() {
        XCTAssertThrowsError(try repository([word()], version: 1))
        XCTAssertThrowsError(try repository([word(), word()]))
        XCTAssertThrowsError(try repository([word()], legacyMap: ["missing"]))
        XCTAssertNoThrow(try repository([word()], legacyMap: [nil, "cat"]))
    }

    func testInvalidPrimaryReadingLevelAndEmptyMeaningsThrow() {
        XCTAssertThrowsError(try repository([word(reading: "いぬ")]))
        XCTAssertThrowsError(try repository([word(level: "N6")]))
        XCTAssertThrowsError(try repository([word(meanings: [])]))
        XCTAssertThrowsError(try repository([word(meanings: ["  "])]))
        XCTAssertThrowsError(try repository([word(id: " ")]))
    }

    func testAliasesPreserveSelectedPrimaryReading() throws {
        let value = DictionaryWord(id: "cat", jmdictID: 1, headword: "猫", reading: "ねこ", level: "N5", studyMeanings: ["cat"], forms: [.init(text: "猫"), .init(text: "ネコ")], readings: [.init(text: "ねこ"), .init(text: "ネコ")], senses: [.init(meanings: ["cat"])])
        let repo = try repository([value])
        XCTAssertEqual(repo.word(id: "cat")?.reading, "ねこ")
        XCTAssertEqual(repo.word(headword: "ネコ", reading: "ネコ", meanings: ["Cat."])?.id, "cat")
        XCTAssertNil(repo.word(id: "missing"))
        XCTAssertNil(repo.word(headword: "猫", reading: "ねこ", meanings: ["dog"]))
    }

    func testRestrictedReadingsAndSenseRestrictionsAreRespected() throws {
        let value = DictionaryWord(id: "restricted", jmdictID: 2, headword: "生", reading: "なま", level: "N4", studyMeanings: ["raw"], forms: [.init(text: "生"), .init(text: "姓")], readings: [.init(text: "なま", spellings: ["生"]), .init(text: "せい", spellings: ["姓"])], senses: [.init(meanings: ["raw"], spellings: ["生"], readings: ["なま"]), .init(meanings: ["surname"], spellings: ["姓"], readings: ["せい"])])
        let repo = try repository([value])
        XCTAssertEqual(repo.word(headword: "生", reading: "なま", meanings: ["raw"])?.id, "restricted")
        XCTAssertNil(repo.word(headword: "姓", reading: "なま", meanings: ["raw"]))
        XCTAssertNil(repo.word(headword: "生", reading: "なま", meanings: ["surname"]))
    }

    func testKanaOnlyReadingCannotMatchWrittenForm() throws {
        let value = DictionaryWord(id: "kana", jmdictID: 3, headword: "ねこ", reading: "ねこ", level: "N5", studyMeanings: ["cat"], forms: [.init(text: "猫")], readings: [.init(text: "ねこ", kanaOnly: true)], senses: [.init(meanings: ["cat"])])
        let repo = try repository([value])
        XCTAssertEqual(repo.word(headword: "ねこ", reading: "ねこ", meanings: ["cat"])?.id, "kana")
        XCTAssertNil(repo.word(headword: "猫", reading: "ねこ", meanings: ["cat"]))
    }

    func testHomographsRequireUniqueEnglishEvidence() throws {
        let repo = try repository([word(id: "cat"), word(id: "other", meanings: ["a different word"], jmdictID: 2)])
        XCTAssertEqual(repo.word(headword: "猫", reading: "ねこ", meanings: ["cat"])?.id, "cat")
        XCTAssertNil(repo.word(headword: "猫", reading: "ねこ", meanings: []))
        let ambiguous = try repository([word(id: "cat"), word(id: "other", jmdictID: 2)])
        XCTAssertNil(ambiguous.word(headword: "猫", reading: "ねこ", meanings: ["cat"]))
    }

    func testSharedDictionaryEntryPrefersSelectedReadingAndForm() throws {
        let forms: [DictionaryForm] = [.init(text: "明日"), .init(text: "あした")]
        let readings: [DictionaryReading] = [.init(text: "あした"), .init(text: "あす")]
        let senses: [DictionarySense] = [.init(meanings: ["tomorrow"])]
        let first = DictionaryWord(id: "tomorrow-ashita", jmdictID: 100, headword: "明日", reading: "あした", level: "N5", studyMeanings: ["tomorrow"], forms: forms, readings: readings, senses: senses)
        let second = DictionaryWord(id: "tomorrow-asu", jmdictID: 100, headword: "明日", reading: "あす", level: "N4", studyMeanings: ["tomorrow"], forms: forms, readings: readings, senses: senses)
        let kana = DictionaryWord(id: "tomorrow-kana", jmdictID: 100, headword: "あした", reading: "あした", level: "N5", studyMeanings: ["tomorrow"], forms: forms, readings: readings, senses: senses)
        let repo = try repository([first, second, kana])
        XCTAssertEqual(repo.word(headword: "明日", reading: "あした", meanings: ["tomorrow"])?.id, first.id)
        XCTAssertEqual(repo.word(headword: "明日", reading: "あす", meanings: ["tomorrow"])?.id, second.id)
        XCTAssertEqual(repo.word(headword: "あした", reading: "あした", meanings: ["tomorrow"])?.id, kana.id)
    }

    func testSelectedSensesDisambiguateIdenticalDictionaryFormsAndReadings() throws {
        let senses: [DictionarySense] = [.init(meanings: ["one's own house", "home"]), .init(meanings: ["one's husband", "my husband"])]
        let home = senseWord(id: "home", studyMeanings: ["one's own house"], senses: senses)
        let husband = senseWord(id: "husband", studyMeanings: ["one's husband"], senses: senses)
        let repo = try repository([home, husband])
        XCTAssertEqual(repo.word(headword: "宅", reading: "たく", meanings: ["one's own house"])?.id, home.id)
        XCTAssertEqual(repo.word(headword: "宅", reading: "たく", meanings: ["my husband"])?.id, husband.id)
        XCTAssertNil(repo.word(headword: "宅", reading: "たく", meanings: []))
        XCTAssertNil(repo.word(headword: "宅", reading: "たく", meanings: ["unrelated"]))
        XCTAssertNil(repo.word(headword: "宅", reading: "たく", meanings: ["home", "my husband"]))
        let duplicate = senseWord(id: "home-other", studyMeanings: ["home"], senses: senses)
        let ambiguous = try repository([home, duplicate])
        XCTAssertNil(ambiguous.word(headword: "宅", reading: "たく", meanings: ["one's own house"]))
    }

    func testPrimaryStudySenseCanBeLaterButCannotCombineUnrelatedSenses() throws {
        let senses: [DictionarySense] = [.init(meanings: ["one's own house"]), .init(meanings: ["one's husband"])]
        XCTAssertNoThrow(try repository([senseWord(id: "husband", studyMeanings: ["one's husband"], senses: senses)]))
        XCTAssertThrowsError(try repository([senseWord(id: "combined", studyMeanings: ["one's own house", "one's husband"], senses: senses)]))
        let repo = try repository([senseWord(id: "home", studyMeanings: ["one's own house"], senses: senses)])
        XCTAssertNil(repo.word(headword: "宅", reading: "たく", meanings: ["one's husband"]))
    }

    private func senseWord(id: String, studyMeanings: [String], senses: [DictionarySense]) -> DictionaryWord {
        .init(id: id, jmdictID: 123, headword: "宅", reading: "たく", level: "N3", studyMeanings: studyMeanings, forms: [.init(text: "宅")], readings: [.init(text: "たく")], senses: senses)
    }

    func testRestrictionReferencesMustExist() {
        let invalid = DictionaryWord(id: "cat", jmdictID: 1, headword: "猫", reading: "ねこ", level: "N5", studyMeanings: ["cat"], forms: [.init(text: "猫")], readings: [.init(text: "ねこ", spellings: ["犬"])], senses: [.init(meanings: ["cat"])])
        XCTAssertThrowsError(try repository([invalid]))
    }

    func testCodableRoundTripAndOptionalModelDefaults() throws {
        let catalog = try repository([word()]).catalog
        XCTAssertEqual(try VocabularyCatalogRepository(data: JSONEncoder().encode(catalog)).catalog, catalog)
        let model = KotobaDataModel(id: "saved", kanji: "猫", furigana: "ねこ", english: [], jlptLevel: .n5, dateAdded: nil, addedIndex: nil)
        XCTAssertNil(model.catalogID)
        let progress = WordsProgressModel(id: "progress", kanjiProgress: 0, kotobaProgress: 0, kanjiLevel: .n5, kotobaLevel: .n5, kanjiIndex: 0, kotobaIndex: 0, lastKotobaUpdated: .distantPast, lastKanjiUpdated: .distantPast)
        XCTAssertNil(progress.catalogVersion)
    }

    func testShippedCatalogLoadsAndLegacySlotCountMatchesActualReader() throws {
        let catalog = try VocabularyCatalogRepository.bundled().catalog
        let legacy = try StandardVocabRepository().fetchLegacyKotobaData()
        XCTAssertEqual(catalog.legacyMap.count, legacy.count)
        XCTAssertFalse(catalog.entries.isEmpty)
    }

    private func repository(_ words: [DictionaryWord], version: Int = 2, legacyMap: [String?] = []) throws -> VocabularyCatalogRepository {
        try VocabularyCatalogRepository(catalog: .init(version: version, created: "2026-10-07", jmdictCreated: "2026-10-07", entries: words, legacyMap: legacyMap))
    }

    private func word(id: String = "cat", reading: String = "ねこ", level: String = "N5", meanings: [String] = ["cat"], jmdictID: Int = 1) -> DictionaryWord {
        .init(id: id, jmdictID: jmdictID, headword: "猫", reading: reading, level: level, studyMeanings: meanings, forms: [.init(text: "猫")], readings: [.init(text: "ねこ")], senses: [.init(meanings: meanings)])
    }
}
