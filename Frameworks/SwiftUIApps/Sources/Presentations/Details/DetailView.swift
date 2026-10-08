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
    @State private var memoryAid: MemoryAidViewModel?
    @State private var isConfirmingDelete = false
    private let examples: ExampleRepository
    
    public init(viewModel: DetailViewModel, examples: ExampleRepository = .bundled(), memoryAid: MemoryAidViewModel? = nil) {
        self.examples = examples
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
                    specimen(headword: entry.headword, reading: entry.reading, level: kotoba.jlptLevel.rawValue)
                    definitionCard([("Meanings", kotoba.english)])
                    if let example = examples.example(for: .init(
                        headword: kotoba.kanji, reading: kotoba.furigana, level: kotoba.jlptLevel.rawValue
                    )) {
                        ExampleSentenceCard(example: example)
                    }
                    if let memoryAid {
                        MemoryAidCard(viewModel: memoryAid)
                    }
                }
            }
            .padding(Forest.Space.l)
        }
        .background(Forest.canvas)
        .navigationTitle(viewModel.state.type.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await memoryAid?.send(.load) }
        .onAppear { Task { await memoryAid?.send(.refreshAvailability) } }
        .onDisappear { memoryAid?.cancel() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await memoryAid?.send(.refreshAvailability) } }
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
                    Text("This \(viewModel.state.type.noun) will be removed from your collection and progress, then offered next on Today.")
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
    
    private func specimen(headword: String, reading: String?, level: String) -> some View {
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
                    Text(row.values.joined(separator: ", "))
                        .font(.body)
                        .foregroundStyle(Forest.ink)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
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
