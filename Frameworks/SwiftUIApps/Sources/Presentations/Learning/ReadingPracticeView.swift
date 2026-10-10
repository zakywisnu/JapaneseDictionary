import SwiftUI

struct ReadingPracticeView: View {
    @State var viewModel: ReadingPracticeViewModel
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        Group {
            switch viewModel.state.loadState {
            case .loading:
                ProgressView("Loading reading practice")
            case .failed:
                ScrollView {
                    StateMessage(title: "Couldn't open the passages", message: "The bundled reading practice couldn't be loaded. Try again.", actionTitle: "Try again", action: { viewModel.send(.retry) })
                }
            case .loaded where viewModel.state.passages.isEmpty:
                ScrollView {
                    StateMessage(title: "No passages available", message: "Return to Learning practice and choose another activity.")
                }
            case .loaded:
                List {
                    Section {
                        ForEach(viewModel.state.passages) { passage in
                            Button {
                                router.push(.readingPassage(passage.id), hideNavBar: false)
                            } label: {
                                VStack(alignment: .leading, spacing: Forest.Space.s) {
                                    Text(passage.title).font(.headline).foregroundStyle(Forest.ink)
                                    Text("\(passage.questions.count) comprehension questions").font(.subheadline).foregroundStyle(Forest.inkMuted)
                                }.padding(.vertical, Forest.Space.s)
                            }.buttonStyle(.plain).listRowBackground(Forest.surface)
                        }
                    } footer: {
                        Text("Original beginner practice. Not official exam material or independently reviewed. Browsing and answering don't change saved study or review dates.")
                            .font(.footnote).foregroundStyle(Forest.inkMuted)
                    }
                }
                .listStyle(.insetGrouped).scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Forest.canvas)
        .toolbar(.visible, for: .navigationBar)
        .navigationTitle("Reading practice")
        .onAppear { viewModel.send(.load) }
    }
}

private struct ReadingDetailView: View {
    let passage: ReadingPassage
    @EnvironmentObject private var router: AppRouter
    @State private var viewModel = ReadingDetailViewModel()
    @State var vocabularyModel: PassageVocabularyViewModel
    private var passageContext: PassageContext { PassageContext(id: passage.id, title: passage.title) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Forest.Space.xl) {
                Text(linkedPassage)
                    .font(.custom(Font.headwordFace, size: 24, relativeTo: .title2))
                    .lineSpacing(Forest.Space.s).fixedSize(horizontal: false, vertical: true)
                    .environment(\.openURL, OpenURLAction { url in
                        guard url.scheme == "reading-word", let index = Int(url.lastPathComponent), passage.vocabulary.indices.contains(index) else { return .discarded }
                        router.push(.readingVocabulary(passage.vocabulary[index], passageContext), hideNavBar: false)
                        return .handled
                    })
                Text("Tap an underlined word to search the bundled dictionary.")
                    .font(.footnote).foregroundStyle(Forest.inkMuted)
                Menu("Vocabulary") {
                    ForEach(passage.vocabulary, id: \.self) { word in
                        Button(word) { router.push(.readingVocabulary(word, passageContext), hideNavBar: false) }
                    }
                }
                .frame(minHeight: 44)
                if vocabularyModel.state.isLoading {
                    ProgressView("Opening saved passage vocabulary")
                } else if let error = vocabularyModel.state.error {
                    StateMessage(title: "Couldn't open passage vocabulary", message: error, actionTitle: "Try again", action: { vocabularyModel.send(.load) })
                } else if vocabularyModel.state.savedCount == 0 {
                    Text("No vocabulary saved for this passage. Tap a word, choose its study meaning, then Save to passage list.")
                        .font(.subheadline).foregroundStyle(Forest.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let list = vocabularyModel.state.list {
                    Text("\(vocabularyModel.state.savedCount) items in \(list.name)")
                        .font(.subheadline).foregroundStyle(Forest.inkMuted)
                    Button("Review passage vocabulary") { router.push(.studyList(list.id), hideNavBar: false) }
                        .buttonStyle(.bordered)
                    Text("Choose Review list on the saved list to practice its current members. Review dates stay unchanged.")
                        .font(.footnote).foregroundStyle(Forest.inkMuted)
                }
                Toggle("Show kana reading", isOn: Binding(get: { viewModel.state.showsReading }, set: { viewModel.send(.readingChanged($0)) }))
                if viewModel.state.showsReading {
                    Text(passage.reading).fixedSize(horizontal: false, vertical: true)
                }
                Toggle("Show English translation", isOn: Binding(get: { viewModel.state.showsTranslation }, set: { viewModel.send(.translationChanged($0)) }))
                if viewModel.state.showsTranslation {
                    Text(passage.translation).fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    router.push(.readingQuestions(passage.id), hideNavBar: false)
                } label: { Text("Answer questions").multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true).padding(.horizontal, Forest.Space.l) }
                    .buttonStyle(PrimaryButtonStyle())
                Text("Original beginner practice. Not official exam material or independently reviewed.")
                    .font(.footnote).foregroundStyle(Forest.inkMuted)
            }
            .foregroundStyle(Forest.ink).tint(Forest.moss).padding(Forest.Space.l)
        }
        .background(Forest.canvas).toolbar(.visible, for: .navigationBar).navigationTitle(passage.title).navigationBarTitleDisplayMode(.inline)
        .onAppear { vocabularyModel.send(.load) }
    }

    private var linkedPassage: AttributedString {
        var text = AttributedString(passage.text)
        for (index, word) in passage.vocabulary.enumerated() {
            if let range = text.range(of: word) {
                text[range].link = URL(string: "reading-word://vocabulary/\(index)")
                text[range].underlineStyle = .single
            }
        }
        return text
    }
}

extension AppComposer {
    func makeReadingPracticeView() -> some View {
        ReadingPracticeView(viewModel: .init())
    }

    @ViewBuilder
    func makeReadingPassageView(id: String) -> some View {
        if let passage = ReadingCatalog.passages.first(where: { $0.id == id }) {
            ReadingDetailView(passage: passage, vocabularyModel: .init(load: { [self] in
                try passageWordRepository().list(passageID: id)
            }))
        } else {
            missingReadingPassage
        }
    }

    func makeReadingVocabularyView(query: String, passageContext: PassageContext? = nil) -> some View {
        let model = DictionaryBrowseViewModel(loadSavedWords: { [self] in
            _ = try useCase.getWordsProgressUseCase.execute()
            return try useCase.getAllKotobaUseCase.execute().mapToKotobas()
        })
        model.send(.queryChanged(query))
        return DictionaryBrowseView(passageContext: passageContext, viewModel: model)
    }

    @ViewBuilder
    func makeReadingQuestionsView(id: String) -> some View {
        if let passage = ReadingCatalog.passages.first(where: { $0.id == id }) {
            makeExerciseSessionView(exercises: passage.questions, activityKey: "reading:" + id, title: "Comprehension")
        } else {
            missingReadingPassage
        }
    }

    private var missingReadingPassage: some View {
        ScrollView {
            StateMessage(title: "Passage unavailable", message: "This passage isn't in the bundled reading practice. Go back and choose another passage.")
        }
        .background(Forest.canvas)
        .navigationTitle("Reading practice")
        .toolbar(.visible, for: .navigationBar)
    }
}
