import SwiftUI
import DataKit

extension AppComposer {
    public func makeKanaPracticeView() -> some View {
        let repository = StandardStudyMaterialRepository(store: store)
        let saver = KanaCardSaver(load: { try repository.materials(kind: .customCard) }, save: repository.save)
        return KanaPracticeView(viewModel: .init(save: saver.saveSelection))
    }
}
