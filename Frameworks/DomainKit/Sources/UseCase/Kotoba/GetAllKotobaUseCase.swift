
import Foundation
import DataKit

public protocol GetAllKotobaUseCase {
    func execute() throws -> [KotobaDataModel]
}

public struct DefaultGetAllKotobaUseCase: GetAllKotobaUseCase {
    private let repository: KotobaRepository
    
    public init(repository: KotobaRepository) {
        self.repository = repository
    }
    
    public func execute() throws -> [KotobaDataModel] {
        try repository.fetchAll()
    }
}
