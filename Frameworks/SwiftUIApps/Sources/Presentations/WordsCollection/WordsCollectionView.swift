//
//  WordsCollectionView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 24/05/25.
//

import SwiftUI

struct WordsCollectionView: View {
    @EnvironmentObject private var router: AppRouter
    @AppStorage("collectionStudyKind") private var kind: StudyKind = .words
    @State private var query = ""
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Forest.Space.l) {
                ScreenHeader(title: "Collection")
                if kind == .words || kind == .kanji { searchField }
                StudyKindPicker(selection: $kind)
                Menu("Study options") {
                    Button("Learning practice") { router.push(.learningPractice, hideNavBar: false) }
                    Button("Study lists") { router.push(.studyLists, hideNavBar: false) }
                    Button("Practice difficult items") { router.push(.difficult, hideNavBar: false) }
                    Button("Lessons") { router.push(.lessons, hideNavBar: false) }
                    if kind == .words {
                        Button("Browse dictionary") { router.push(.dictionary, hideNavBar: false) }
                    }
                }
                .foregroundStyle(Forest.ink)
                .frame(minHeight: 44)

            }
            .padding(.horizontal, Forest.Space.l)
            .padding(.top, Forest.Space.s)
            
            switch kind {
            case .words:
                AppComposer.shared.makeCollectionKotobaView(query: query)
            case .kanji:
                AppComposer.shared.makeCollectionKanjiView(query: query)
            case .grammar, .sentences, .cards:
                AppComposer.shared.makeMaterialLibraryView(kind: kind.savedKind).id(kind)
            }
        }
        .background(Forest.canvas)
    }
    
    private var searchField: some View {
        HStack(spacing: Forest.Space.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Forest.inkMuted)
                .accessibilityHidden(true)
            TextField(
                "Search",
                text: $query,
                prompt: Text("Search Japanese, reading, or English").foregroundStyle(Forest.inkMuted)
            )
                .foregroundStyle(Forest.ink)
                .padding(.vertical, Forest.Space.s)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Forest.inkMuted)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Forest.Space.m)
        .frame(minHeight: 44)
        .background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: Forest.Radius.card)
                .strokeBorder(Forest.line)
        }
    }
}

#Preview {
    WordsCollectionView()
}
