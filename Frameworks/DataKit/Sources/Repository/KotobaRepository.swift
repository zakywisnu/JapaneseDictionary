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
    private let prepare: () throws -> Void
    private let save: (ModelContext) throws -> Void
    private let contextProvider: () -> ModelContext
    private var context: ModelContext { contextProvider() }

    public init(context: ModelContext, prepare: @escaping () throws -> Void = {}, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.prepare = prepare
        self.save = save
        self.contextProvider = { context }
    }

    public init(store: StudyStore, prepare: @escaping () throws -> Void = {}, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.prepare = prepare
        self.save = save
        contextProvider = { store.context }
    }

    public func fetchAll() throws -> [KotobaDataModel] {
        try prepare()
        let words = try context.fetch(FetchDescriptor<KotobaDataModel>())
        return words
    }

    public func fetch(id: String) throws -> KotobaDataModel {
        try prepare()
        let descriptor = getDescriptor(with: id)
        guard let data = try context.fetch(descriptor).first else {
            throw DataError.dataNotFound
        }
        return data
    }

    public func add(_ param: KotobaDataModel) throws {
        try prepare()
        do {
            context.insert(param)
            try save(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    public func update(_ param: KotobaDataModel) throws {
        try prepare()
        let descriptor = getDescriptor(with: param.id)
        do {
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
                // Study-content updates retain the persisted catalog anchor after migration.
                try save(context)
            } else {
                throw DataError.dataNotFound
            }
        } catch {
            context.rollback()
            throw error
        }
    }

    public func delete(id: String) throws {
        try prepare()
        let descriptor = getDescriptor(with: id)

        do {
            if let data = try context.fetch(descriptor).first {
                context.delete(data)
                try save(context)
            } else {
                throw DataError.dataNotFound
            }
        } catch {
            context.rollback()
            throw error
        }
    }

    private func getDescriptor(with id: String) -> FetchDescriptor<KotobaDataModel> {
        return FetchDescriptor<KotobaDataModel>(
            predicate: #Predicate { $0.id == id }
        )
    }
}
