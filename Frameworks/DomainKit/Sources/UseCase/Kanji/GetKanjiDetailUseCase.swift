
import Foundation
import DataKit

public protocol GetKanjiDetailUseCase {
    func execute(id: String) throws -> KanjiDataModel
}

public struct DefaultGetKanjiDetailUseCase: GetKanjiDetailUseCase {
    private let repository: KanjiRepository
    
    public init(repository: KanjiRepository) {
        self.repository = repository
    }
    
    public func execute(id: String) throws -> KanjiDataModel {
        try repository.fetch(id: id)
    }
}
