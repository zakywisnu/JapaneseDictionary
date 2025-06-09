
import Foundation
import DataKit

public protocol GetAllKanjiUseCase {
    func execute() throws -> [KanjiDataModel]
}

public struct DefaultGetAllKanjiUseCase: GetAllKanjiUseCase {
    private let repository: KanjiRepository
    
    public init(repository: KanjiRepository) {
        self.repository = repository
    }
    
    public func execute() throws -> [KanjiDataModel] {
        try repository.fetchAll()
    }
}
