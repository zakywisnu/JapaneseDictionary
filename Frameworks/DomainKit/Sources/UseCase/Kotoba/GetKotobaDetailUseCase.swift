
import Foundation
import DataKit

public protocol GetKotobaDetailUseCase {
    func execute(id: String) throws -> KotobaDataModel
}

public struct DefaultGetKotobaDetailUseCase: GetKotobaDetailUseCase {
    private let repository: KotobaRepository
    
    public init(repository: KotobaRepository) {
        self.repository = repository
    }
    
    public func execute(id: String) throws -> KotobaDataModel {
        try repository.fetch(id: id)
    }
}
