//
//  WordsCollectionView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 24/05/25.
//

import SwiftUI

struct WordsCollectionView: View {
    @AppStorage("collectionStudyKind") private var kind: StudyKind = .words
    @State private var query = ""
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Forest.Space.l) {
                ScreenHeader(title: "Collection")
                searchField
                StudyKindPicker(selection: $kind)
            }
            .padding(.horizontal, Forest.Space.l)
            .padding(.top, Forest.Space.s)
            
            switch kind {
            case .words:
                AppComposer.shared.makeCollectionKotobaView(query: query)
            case .kanji:
                AppComposer.shared.makeCollectionKanjiView(query: query)
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
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Forest.inkMuted)
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
