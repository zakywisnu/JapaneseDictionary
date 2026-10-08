//
//  KotobaRepository.swift
//  DataKit
//
//  Created by Ahmad Zaky W on 10/05/25.
//

import Foundation
import SwiftData

public protocol KotobaRepository {
    func fetchAll() throws -> [KotobaDataModel]
    func fetch(id: String) throws -> KotobaDataModel
    func add(_ param: KotobaDataModel) throws
    func update(_ param: KotobaDataModel) throws
    func delete(id: String) throws
}

public final class StandardKotobaRepository: KotobaRepository {
    private let contextProvider: () -> ModelContext
    private var context: ModelContext { contextProvider() }

    public init(context: ModelContext) {
        self.contextProvider = { context }
    }

    public init(store: StudyStore) {
        contextProvider = { store.context }
    }

    public func fetchAll() throws -> [KotobaDataModel] {
        let words = try context.fetch(FetchDescriptor<KotobaDataModel>())
        return words
    }

    public func fetch(id: String) throws -> KotobaDataModel {
        let descriptor = getDescriptor(with: id)
        guard let data = try context.fetch(descriptor).first else {
            throw DataError.dataNotFound
        }
        return data
    }

    public func add(_ param: KotobaDataModel) throws {
        context.insert(param)
        try context.save()
    }

    public func update(_ param: KotobaDataModel) throws {
        let descriptor = getDescriptor(with: param.id)
        if let data = try context.fetch(descriptor).first {
            if data.kanji != param.kanji || data.furigana != param.furigana ||
               data.english.map(\.value) != param.english.map(\.value) || data.jlptLevel != param.jlptLevel {
                data.memoryExplanation = nil
                data.memoryMnemonic = nil
            }
            data.english = param.english
            data.furigana = param.furigana
            data.kanji = param.kanji
            data.jlptLevel = param.jlptLevel
            try context.save()
        } else {
            throw DataError.dataNotFound
        }
    }

    public func delete(id: String) throws {
        let descriptor = getDescriptor(with: id)

        if let data = try context.fetch(descriptor).first {
            context.delete(data)
            try context.save()
        } else {
            throw DataError.dataNotFound
        }
    }

    private func getDescriptor(with id: String) -> FetchDescriptor<KotobaDataModel> {
        return FetchDescriptor<KotobaDataModel>(
            predicate: #Predicate { $0.id == id }
        )
    }
}
