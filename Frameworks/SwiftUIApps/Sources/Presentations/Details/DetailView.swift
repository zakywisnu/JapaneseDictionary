//
//  DetailView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 03/06/25.
//

import SwiftUI
import DataKit

public struct DetailView: View {
    @EnvironmentObject var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: DetailViewModel
    @State private var pronunciation = PronunciationService()
    @State private var memoryAid: MemoryAidViewModel?
    @State private var isConfirmingDelete = false
    @State private var isConfirmingUpdate = false
    @State private var isOrganizingLists = false
    private let makeMemoryAid: ((Kotoba) -> MemoryAidViewModel)?
    private let examples: ExampleRepository
    
    public init(viewModel: DetailViewModel, examples: ExampleRepository = .bundled(), memoryAid: MemoryAidViewModel? = nil) {
        self.init(viewModel: viewModel, examples: examples, memoryAid: memoryAid, makeMemoryAid: nil)
    }

    init(viewModel: DetailViewModel, examples: ExampleRepository, memoryAid: MemoryAidViewModel?, makeMemoryAid: ((Kotoba) -> MemoryAidViewModel)?) {
        self.examples = examples
        self.makeMemoryAid = makeMemoryAid
        self.viewModel = viewModel
        _memoryAid = State(initialValue: memoryAid)
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: Forest.Space.xl) {
                if let kanji = viewModel.state.kanji {
                    specimen(headword: kanji.kanji, reading: nil, level: kanji.jlptLevel.rawValue)
                    definitionCard([
                        ("Meanings", kanji.meanings),
                        ("On'yomi", kanji.onyomi),
                        ("Kun'yomi", kanji.kunyomi),
                        ("Strokes", kanji.stroke > 0 ? ["\(kanji.stroke)"] : [])
                    ])
                } else if let kotoba = viewModel.state.kotoba {
                    let entry = kotoba.studyEntry
                    specimen(headword: entry.headword, reading: entry.reading, level: kotoba.jlptLevel.rawValue, spokenReading: kotoba.furigana)
                    Button("Organize in lists") { isOrganizingLists = true }
                        .buttonStyle(.plain)
                        .foregroundStyle(Forest.ink)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    Text("Vocabulary JLPT levels are community estimates.")
                        .font(.footnote)
                        .foregroundStyle(Forest.inkMuted)
                    definitionCard([("Study meaning", kotoba.english)])
                    dictionaryContent
                    if viewModel.canUpdateStudyWord {
                        Button("Update study word") { isConfirmingUpdate = true }
                            .buttonStyle(.bordered)
                            .tint(Forest.moss)
                            .frame(minHeight: 44)
                    }
                    if viewModel.state.didUpdateStudyWord {
                        Text("Study word updated. Review uses the study meaning above.")
                            .font(.footnote).foregroundStyle(Forest.inkMuted)
                    }
                    if let example = examples.example(for: .init(
                        headword: kotoba.kanji, reading: kotoba.furigana, level: kotoba.jlptLevel.rawValue
                    )) {
                        ExampleSentenceCard(example: example)
                    }
                    if let memoryAid {
                        MemoryAidCard(viewModel: memoryAid)
                    }
                    Button("Sources") { router.push(.sources, hideNavBar: false) }
                        .buttonStyle(.plain)
                        .foregroundStyle(Forest.ink)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            }
            .padding(Forest.Space.l)
        }
        .background(Forest.canvas)
        .navigationTitle(viewModel.state.type.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.send(.loadDictionary)
            await memoryAid?.send(.load)
        }
        .onChange(of: viewModel.state.kotoba) { old, updated in
            guard old != updated, let updated else { return }
            pronunciation.stop()
            memoryAid?.cancel()
            memoryAid = makeMemoryAid?(updated)
            Task { await memoryAid?.send(.load) }
        }
        .onChange(of: viewModel.state.kanji) { _, _ in pronunciation.stop() }
        .sheet(isPresented: $isOrganizingLists) {
            if let word = viewModel.state.kotoba {
                AppComposer.shared.makeWordListMembershipView(wordID: word.id)
            }
        }
        .sheet(isPresented: $isConfirmingUpdate) {
            studyUpdatePreview
        }
        .onAppear {
            pronunciation.refreshAvailability()
            Task { await memoryAid?.send(.refreshAvailability) }
        }
        .onDisappear {
            pronunciation.stop()
            memoryAid?.cancel()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                pronunciation.refreshAvailability()
                Task { await memoryAid?.send(.refreshAvailability) }
            } else { pronunciation.stop() }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Remove from collection", systemImage: "trash", role: .destructive) {
                    isConfirmingDelete = true
                }
                .tint(Forest.danger)
                .confirmationDialog(
                    "Remove this \(viewModel.state.type.noun) from your collection?",
                    isPresented: $isConfirmingDelete,
                    titleVisibility: .visible
                ) {
                    Button("Remove", role: .destructive) {
                        viewModel.send(.didConfirmDelete({ router.pop() }))
                    }
                } message: {
                    Text(viewModel.state.kotoba != nil ? "This word will be removed from your collection and progress." : "This kanji will be removed from your collection and progress, then offered next on Today.")
                }
            }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { viewModel.state.errorMessage != nil }, set: { _ in viewModel.send(.didDismissError) })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.state.errorMessage ?? "")
        }
    }
    
    @ViewBuilder
    private var dictionaryContent: some View {
        switch viewModel.state.dictionary {
        case .loading:
            ProgressView("Loading dictionary meanings")
        case let .linked(word):
            DictionaryDetailCard(word: word)
        case .unavailable:
            StateMessage(title: "Dictionary entry unavailable", message: "This saved word has no verified entry in the current dictionary. Your study meaning remains available.")
        case .ambiguous:
            StateMessage(title: "Dictionary match needs review", message: "More than one entry matches this spelling and reading. Your saved meaning is kept; no dictionary entry was chosen.")
        case .failed:
            StateMessage(title: "Couldn't open the dictionary", message: "The bundled vocabulary details couldn't be read. Your saved study word is still available.", actionTitle: "Try again", action: { viewModel.send(.loadDictionary) })
        }
    }

    private var studyUpdatePreview: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Forest.Space.l) {
                    if let replacement = viewModel.state.studyUpdate {
                        Text("Update your saved study word to these dictionary values?").font(.body)
                        Text(replacement.kanji).font(.headword(32, relativeTo: .largeTitle))
                        definitionCard([("Reading", [replacement.furigana]), ("Study meaning", replacement.english), ("Community JLPT level", [replacement.jlptLevel.rawValue])])
                        Text("Your added date and review schedule are kept. Any AI suggestion based on changed readings or meanings will be cleared.")
                            .font(.subheadline).foregroundStyle(Forest.inkMuted)
                        Button("Update study word") {
                            viewModel.send(.confirmStudyUpdate)
                            isConfirmingUpdate = false
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .foregroundStyle(Forest.ink)
                .padding(Forest.Space.l)
            }
            .background(Forest.canvas)
            .navigationTitle("Update study word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isConfirmingUpdate = false }
                }
            }
        }
        .tint(Forest.moss)
    }

    private func specimen(headword: String, reading: String?, level: String, spokenReading: String? = nil) -> some View {
        VStack(spacing: Forest.Space.m) {
            ViewThatFits(in: .horizontal) {
                ForEach([120, 96, 72, 56, 44] as [CGFloat], id: \.self) { size in
                    PracticeCells(text: headword, cellSize: size)
                }
                Text(headword)
                    .font(.headword(40, relativeTo: .largeTitle))
                    .foregroundStyle(Forest.ink)
                    .multilineTextAlignment(.center)
            }
            
            if let reading {
                Text(reading)
                    .font(.title3)
                    .foregroundStyle(Forest.inkMuted)
                    .textSelection(.enabled)
            }
            if let spokenReading, PronunciationService.normalizedReading(spokenReading) != nil {
                PronunciationControl(reading: spokenReading, service: pronunciation)
            }
            LevelTag(level: level)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Forest.Space.xl)
        .padding(.horizontal, Forest.Space.l)
        .background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
    }
    
    private func definitionCard(_ rows: [(title: String, values: [String])]) -> some View {
        let visible = rows.filter { !$0.values.isEmpty }
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(visible.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    Rectangle()
                        .fill(Forest.line)
                        .frame(height: 1)
                        .padding(.leading, Forest.Space.l)
                }
                VStack(alignment: .leading, spacing: Forest.Space.xs) {
                    Text(row.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Forest.inkMuted)
                    if row.title == "On'yomi" || row.title == "Kun'yomi" {
                        ForEach(Array(row.values.enumerated()), id: \.offset) { _, reading in
                            if PronunciationService.normalizedReading(reading) != nil {
                                PronunciationControl(reading: reading, service: pronunciation, showsReading: true)
                            } else {
                                Text(reading).font(.body).foregroundStyle(Forest.ink).textSelection(.enabled)
                            }
                        }
                    } else {
                        Text(row.values.joined(separator: ", "))
                            .font(.body)
                            .foregroundStyle(Forest.ink)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Forest.Space.l)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
    }
}

#Preview {
    AppComposer.shared.makeDetailView(
        .init(
            kotoba: .init(
                id: "preview",
                kanji: "原則",
                furigana: "げんそく",
                english: ["principle", "general rule"],
                jlptLevel: .n1
            ),
            kanji: nil
        )
    )
}
