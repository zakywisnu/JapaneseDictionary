import SwiftUI
import DataKit

struct DictionaryBrowseDetailView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase
    @State private var pronunciation = PronunciationService()
    @State var viewModel: DictionaryBrowseDetailViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Forest.Space.xl) {
                if let word = viewModel.state.word {
                    specimen(word)
                    Text("Vocabulary JLPT levels are community estimates.").font(.footnote).foregroundStyle(Forest.inkMuted)
                    VStack(alignment: .leading, spacing: Forest.Space.s) {
                        Text("Study meaning").font(.headline)
                        Text(word.studyMeanings.joined(separator: "; ")).font(.body).textSelection(.enabled)
                    }
                    .foregroundStyle(Forest.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Forest.Space.l)
                    .background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
                    DictionaryDetailCard(word: word)
                    Button("Sources") { router.push(.sources, hideNavBar: false) }
                        .buttonStyle(.plain).foregroundStyle(Forest.ink)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                if viewModel.state.loadState == .loading {
                    ProgressView("Loading this dictionary entry")
                } else if viewModel.state.loadState == .failed {
                    StateMessage(title: "Couldn't open this entry", message: viewModel.state.loadError ?? "The dictionary or your saved collection didn't load.",
                                 actionTitle: "Try again", action: { viewModel.send(.load) })
                } else if viewModel.state.word == nil {
                    StateMessage(title: "Dictionary entry unavailable", message: "This word is no longer in the bundled study list. Return to the dictionary and choose another word.")
                }
            }
            .padding(Forest.Space.l)
        }
        .background(Forest.canvas)
        .navigationTitle("Dictionary word")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { collectionAction }
        .onAppear {
            pronunciation.refreshAvailability()
            viewModel.send(.load)
        }
        .onDisappear { pronunciation.stop() }
        .onChange(of: viewModel.state.word?.headword) { _, _ in pronunciation.stop() }
        .onChange(of: viewModel.state.word?.reading) { _, _ in pronunciation.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { pronunciation.refreshAvailability() }
            else { pronunciation.stop() }
        }
        .alert("Word couldn't be added", isPresented: Binding(get: { viewModel.state.errorMessage != nil }, set: { _ in viewModel.send(.dismissError) })) {
            Button("OK", role: .cancel) {}
        } message: { Text(viewModel.state.errorMessage ?? "") }
    }

    @ViewBuilder
    private var collectionAction: some View {
        if viewModel.state.loadState == .loaded, viewModel.state.word != nil {
            VStack(spacing: Forest.Space.s) {
                if let saved = viewModel.state.savedWord {
                    Text(viewModel.state.didAdd ? "Added to your collection" : "Already in your collection")
                        .font(.footnote).foregroundStyle(Forest.inkMuted)
                    Button("View saved word") { router.push(.detail(.init(kotoba: saved, kanji: nil)), hideNavBar: false) }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Add to collection") { viewModel.send(.add) }
                        .buttonStyle(PrimaryButtonStyle()).disabled(!viewModel.canAdd)
                    Text("Your next word on Today stays unchanged.").font(.footnote).foregroundStyle(Forest.inkMuted)
                }
            }
            .padding(Forest.Space.l)
            .background(Forest.canvas)
        }
    }

    private func specimen(_ word: DictionaryWord) -> some View {
        VStack(spacing: Forest.Space.m) {
            ViewThatFits(in: .horizontal) {
                ForEach([120, 96, 72, 56, 44] as [CGFloat], id: \.self) { size in
                    PracticeCells(text: word.headword, cellSize: size)
                }
                Text(word.headword).font(.headword(40, relativeTo: .largeTitle)).foregroundStyle(Forest.ink).multilineTextAlignment(.center)
            }
            if word.reading != word.headword {
                Text(word.reading).font(.title3).foregroundStyle(Forest.inkMuted).textSelection(.enabled)
            }
            if PronunciationService.normalizedReading(word.reading) != nil {
                PronunciationControl(reading: word.reading, service: pronunciation)
            }
            LevelTag(level: word.level)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Forest.Space.xl).padding(.horizontal, Forest.Space.l)
        .background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
    }
}
