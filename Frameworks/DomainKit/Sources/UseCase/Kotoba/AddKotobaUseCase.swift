//
//  AddKotobaUseCase.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 13/05/25.
//

import DataKit
import Foundation

public struct KotobaParam {
    public var id: String
    public var kanji: String
    public var furigana: String
    public var english: [String]
    public var jlptLevel: Level
    public var dateAdded: Date
    public var addedIndex: Int
    public var catalogID: String?
    public var expectedCursor: Int?
    
    public init(
        id: String,
        kanji: String,
        furigana: String,
        english: [String],
        jlptLevel: Level,
        dateAdded: Date,
        addedIndex: Int,
        catalogID: String? = nil,
        expectedCursor: Int? = nil
    ) {
        self.id = id
        self.kanji = kanji
        self.furigana = furigana
        self.english = english
        self.jlptLevel = jlptLevel
        self.dateAdded = dateAdded
        self.addedIndex = addedIndex
        self.catalogID = catalogID
        self.expectedCursor = expectedCursor
    }
    
    public enum Level: String {
        case n1 = "N1"
        case n2 = "N2"
        case n3 = "N3"
        case n4 = "N4"
        case n5 = "N5"
    }
    
    func toKotoba() -> KotobaDataModel {
        .init(
            id: id,
            kanji: kanji,
            furigana: furigana,
            english: english.map { ArrayString(value: $0) },
            jlptLevel: KotobaDataModel.Level(rawValue: jlptLevel.rawValue) ?? .n5,
            dateAdded: dateAdded,
            addedIndex: addedIndex,
            catalogID: catalogID
        )
    }
}

public protocol AddKotobaUseCase {
    func execute(param: KotobaParam, progress: WordsProgressParam) throws
}

public struct DefaultAddKotobaUseCase: AddKotobaUseCase {
    private let additionRepository: WordAdditionRepository
    private let loadCatalog: () throws -> VocabularyCatalogRepository

    public init(additionRepository: WordAdditionRepository,
                loadCatalog: @escaping () throws -> VocabularyCatalogRepository = { try .bundled() }) {
        self.additionRepository = additionRepository
        self.loadCatalog = loadCatalog
    }

    public func execute(param: KotobaParam, progress: WordsProgressParam) throws {
        let catalog = try loadCatalog()
        guard let catalogID = param.catalogID, let entry = catalog.word(id: catalogID),
              let expectedCursor = param.expectedCursor, expectedCursor >= 0,
              catalog.catalog.entries.indices.contains(param.addedIndex),
              catalog.catalog.entries[param.addedIndex].id == catalogID,
              entry.headword == param.kanji, entry.reading == param.furigana,
              entry.studyMeanings == param.english, entry.level == param.jlptLevel.rawValue else {
            throw BackupError.invalid("sequential word parameters")
        }
        let persisted = try additionRepository.addWord(catalogID: catalogID, savedID: param.id,
            addedAt: param.dateAdded, source: .next(expectedCursor: expectedCursor))
        UpdateProgressUserDefaults.update(persisted.mapToParam())
    }
}
