//
//  CollectionListView.swift
//  SwiftUIApps
//

import SwiftUI

struct CollectionListView: View {
    let noun: String
    let entries: [StudyEntry]
    let loadState: TodayLoadState
    @Binding var query: String
    var alternateSearchTerms: [String: [String]] = [:]
    let onDelete: (StudyEntry) -> Void
    let onSelect: (StudyEntry) -> Void
    let onRetry: () -> Void
    let onGoToToday: () -> Void
    let onReview: () -> Void

    private static let levelOrder = ["N5", "N4", "N3", "N2", "N1"]

    private var nouns: String { noun.pluralNoun }

    var body: some View {
        List {
            Section {
                CollectionScreenHeader(query: $query, onReview: loadState == .loaded && !entries.isEmpty ? onReview : nil)
            }.listRowBackground(Forest.canvas).listRowInsets(EdgeInsets(top: Forest.Space.m, leading: 0, bottom: Forest.Space.s, trailing: 0))
            switch loadState {
            case .loading:
                ProgressView("Loading your \(nouns)").listRowBackground(Forest.surface)
            case .failed:
                StateMessage(title: "Couldn't open your collection", message: "Your saved \(nouns) didn't load.", actionTitle: "Try again", action: onRetry).listRowBackground(Forest.surface)
            case .loaded where entries.isEmpty:
                StateMessage(title: "No \(nouns) yet", message: "Add a \(noun) on Today or browse the bundled lessons.", actionTitle: "Go to Today", action: onGoToToday).listRowBackground(Forest.surface)
            case .loaded:
                collectionSections
            }
        }.forestTabList().scrollDismissesKeyboard(.immediately)
            .contentMargins(.top, Forest.Space.s, for: .scrollContent)
    }

    private var filtered: [StudyEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter { entry in
            entry.headword.localizedCaseInsensitiveContains(trimmed)
                || (entry.reading?.localizedCaseInsensitiveContains(trimmed) ?? false)
                || entry.meaning.localizedCaseInsensitiveContains(trimmed)
                || (alternateSearchTerms[entry.id]?.contains { $0.localizedCaseInsensitiveContains(trimmed) } ?? false)
        }
    }

    private var collectionSections: some View {
        let groups = Dictionary(grouping: filtered, by: \.level)
        return Group {
            if filtered.isEmpty {
                StateMessage(
                    title: "No matches for \"\(query)\"",
                    message: "Search looks at the Japanese, the reading, and the English meaning."
                )
                .listRowBackground(Forest.surface)
            }
            ForEach(Self.levelOrder.filter { groups[$0] != nil }, id: \.self) { level in
                let items = groups[level] ?? []
                Section {
                    ForEach(items) { entry in
                        Button { onSelect(entry) } label: {
                            StudyRow(entry: entry, showsLevel: false)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Forest.surface)
                        .studyRemovalActions(entry: entry, noun: noun, onDelete: onDelete)
                    }
                } header: {
                    HStack {
                        Text("JLPT \(level)")
                        Spacer()
                        Text("\(items.count)")
                            .monospacedDigit()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Forest.inkMuted)
                    .textCase(nil)
                }
            }
        }
    }
}
