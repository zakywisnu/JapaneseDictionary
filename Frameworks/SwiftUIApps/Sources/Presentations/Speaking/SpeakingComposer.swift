import DataKit
import DomainKit
import SwiftUI

extension AppComposer {
    @MainActor public func makeSpeakingView(target: SpeakingTarget) -> some View {
        SpeakingView(viewModel: .init(target: target, service: SpeakingRecorder(), pronunciation: PronunciationService(), explainer: SpeakingExplainerFactory.make()))
    }
    @MainActor public func makeSpeakingPracticeView() -> some View { SpeakingPracticeView() }
}

struct SpeakingPracticeView: View {
    @EnvironmentObject private var router: AppRouter
    private var phrases: [SpeakingTarget] {
        ReadingCatalog.passages.map { passage in
            let prompt = String(passage.text.split(separator: "。").first ?? "") + "。"
            let reading = String(passage.reading.split(separator: "。").first ?? "") + "。"
            return .init(id: "passage:" + passage.id, prompt: prompt, suppliedReading: reading)
        }
    }
    var body: some View {
        List {
            Section {
                ForEach(phrases) { target in destination(target) }
            } header: { Text("Short phrases") } footer: { Text("Supplied phrases from the original beginner reading passages. Recognition compares text, without a pronunciation score.") }
            Section {
                ForEach(KanaCatalog.entries.filter { $0.script == .hiragana && $0.reading != nil }) { entry in
                    destination(.init(id: entry.id, prompt: entry.kana, suppliedReading: entry.reading ?? "", isIsolatedSound: true))
                }
            } header: { Text("Kana listen and replay") } footer: { Text("Isolated sounds do not give a reliable phrase verdict. Marks without standalone sound are omitted.") }
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden).background(Forest.canvas)
            .navigationTitle("Speaking practice").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
    }
    private func destination(_ target: SpeakingTarget) -> some View {
        Button { router.push(.speaking(target), hideNavBar: false) } label: {
            VStack(alignment: .leading, spacing: Forest.Space.s) {
                Text(target.prompt).font(.headword(22)).foregroundStyle(Forest.ink)
                if target.prompt != target.suppliedReading { Text(target.suppliedReading).font(.subheadline).foregroundStyle(Forest.inkMuted) }
            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).fixedSize(horizontal: false, vertical: true)
        }.buttonStyle(.plain).listRowBackground(Forest.surface)
    }
}
