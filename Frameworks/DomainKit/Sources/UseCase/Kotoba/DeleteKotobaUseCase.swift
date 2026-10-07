import DataKit

public protocol DeleteKotobaUseCase {
    func execute(kotoba: KotobaParam) throws
}

public struct DefaultDeleteKotobaUseCase: DeleteKotobaUseCase {
    private let mutationRepository: StudyMutationRepository

    public init(mutationRepository: StudyMutationRepository) {
        self.mutationRepository = mutationRepository
    }

    public func execute(kotoba: KotobaParam) throws {
        let progress = try mutationRepository.delete(id: .init(kind: .word, id: kotoba.id))
        UpdateProgressUserDefaults.update(progress.mapToParam())
    }
}
