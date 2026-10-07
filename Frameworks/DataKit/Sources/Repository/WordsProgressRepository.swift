//
//  WordsProgressRepository.swift
//  DataKit
//
//  Created by Ahmad Zaky W on 10/05/25.
//

import Foundation
import SwiftData

public protocol WordsProgressRepository {
    func setup() throws
    @discardableResult func getProgress() throws -> WordsProgressModel
    func updateProgress(_ progress: WordsProgressModel) throws
}

public final class StandardWordsProgressRepository: WordsProgressRepository {

    private let contextProvider: () -> ModelContext
    private var context: ModelContext { contextProvider() }

    public init(context: ModelContext) {
        self.contextProvider = { context }
        try? setup()
    }

    public init(store: StudyStore) {
        contextProvider = { store.context }
    }

    public func setup() throws {
        guard try context.fetch(getDescriptor()).isEmpty else { return }
        do {
            let data = WordsProgressModel(
                id: UUID().uuidString,
                kanjiProgress: 0,
                kotobaProgress: 0,
                kanjiLevel: .n5,
                kotobaLevel: .n5,
                kanjiIndex: 0,
                kotobaIndex: 0,
                lastKotobaUpdated: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                lastKanjiUpdated: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            )

            context.insert(data)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    @discardableResult
    public func getProgress() throws -> WordsProgressModel {
        try setup()
        let descriptor = getDescriptor()
        guard let progress = try context.fetch(descriptor).first else {
            throw DataError.dataNotFound
        }
        return progress
    }

    public func updateProgress(_ progress: WordsProgressModel) throws {
        let descriptor = getDescriptor()
        if let data = try context.fetch(descriptor).first {
            data.kanjiLevel = progress.kanjiLevel
            data.kanjiProgress = progress.kanjiProgress
            data.kotobaLevel = progress.kotobaLevel
            data.kotobaProgress = progress.kotobaProgress
            data.lastKanjiUpdated = progress.lastKanjiUpdated
            data.lastKotobaUpdated = progress.lastKotobaUpdated
            data.kanjiIndex = progress.kanjiIndex
            data.kotobaIndex = progress.kotobaIndex
            try context.save()
        } else {
            throw DataError.dataNotFound
        }
    }

    private func getDescriptor() -> FetchDescriptor<WordsProgressModel> {
        return FetchDescriptor<WordsProgressModel>()
    }
}
