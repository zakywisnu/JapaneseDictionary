import DataKit
import Foundation

public protocol AddSelectedWordUseCase {
    func execute(catalogID: String) throws
}

public struct DefaultAddSelectedWordUseCase: AddSelectedWordUseCase {
    private let additionRepository: WordAdditionRepository
    private let makeID: () -> String
    private let now: () -> Date

    public init(additionRepository: WordAdditionRepository,
                makeID: @escaping () -> String = { UUID().uuidString },
                now: @escaping () -> Date = { Date() }) {
        self.additionRepository = additionRepository
        self.makeID = makeID
        self.now = now
    }

    public func execute(catalogID: String) throws {
        let persisted = try additionRepository.addWord(catalogID: catalogID, savedID: makeID(),
            addedAt: now(), source: .selected)
        UpdateProgressUserDefaults.update(persisted.mapToParam())
    }
}
