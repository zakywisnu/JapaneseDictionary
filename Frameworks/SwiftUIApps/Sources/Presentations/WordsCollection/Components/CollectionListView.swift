//
//  CollectionListView.swift
//  SwiftUIApps
//

import SwiftUI

struct CollectionListView: View {
    let noun: String
    let entries: [StudyEntry]
    let loadState: TodayLoadState
    let query: String
    let onDelete: (StudyEntry) -> Void
    let onSelect: (StudyEntry) -> Void
    let onRetry: () -> Void
    let onGoToToday: () -> Void
    let onReview: () -> Void

    private static let levelOrder = ["N5", "N4", "N3", "N2", "N1"]

    private var nouns: String { noun.pluralNoun }

    var body: some View {
        switch loadState {
        case .loading:
            ProgressView("Loading your \(nouns)")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            StateMessage(
                title: "Couldn't open your collection",
                message: "Your saved \(nouns) didn't load.",
                actionTitle: "Try again",
                action: onRetry
            )
            .frame(maxHeight: .infinity)
        case .loaded where entries.isEmpty:
            StateMessage(
                title: "No \(nouns) yet",
                message: "Every \(noun) you add on Today is kept here, grouped by JLPT level.",
                actionTitle: "Go to Today",
                action: onGoToToday
            )
            .frame(maxHeight: .infinity)
        case .loaded:
            list
        }
    }

    private var filtered: [StudyEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter { entry in
            entry.headword.localizedCaseInsensitiveContains(trimmed)
                || (entry.reading?.localizedCaseInsensitiveContains(trimmed) ?? false)
                || entry.meaning.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var list: some View {
        let groups = Dictionary(grouping: filtered, by: \.level)
        return List {
            Section {
                Button(action: onReview) {
                    Text("Review \(nouns)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Forest.ink)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Forest.surface)
            }
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
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .contentMargins(.top, Forest.Space.s, for: .scrollContent)
    }
}
