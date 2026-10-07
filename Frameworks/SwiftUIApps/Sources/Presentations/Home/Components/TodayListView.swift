//
//  TodayListView.swift
//  SwiftUIApps
//

import SwiftUI

extension Array {
    /// The saved progress index points into this order, so it must not shuffle between launches.
    func stableSorted(by areInIncreasingOrder: (Element, Element) -> Bool) -> [Element] {
        enumerated()
            .sorted { lhs, rhs in
                if areInIncreasingOrder(lhs.element, rhs.element) { return true }
                if areInIncreasingOrder(rhs.element, lhs.element) { return false }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}

enum TodayLoadState {
    case loading
    case loaded
    case failed
}

struct TodayListView: View {
    let dueCount: Int
    let dueLoadState: TodayLoadState
    let onRetryDue: () -> Void
    let onReviewDue: () -> Void
    let noun: String
    let entries: [StudyEntry]
    let loadState: TodayLoadState
    let nextLevel: String?
    let hasFinished: Bool
    let onAdd: () -> Void
    let onDelete: (StudyEntry) -> Void
    let onSelect: (StudyEntry) -> Void
    let onRetry: () -> Void
    let onReview: () -> Void

    private var nouns: String { noun.pluralNoun }

    var body: some View {
        switch loadState {
        case .loading:
            ProgressView("Loading today's \(nouns)")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            StateMessage(
                title: "Couldn't open your \(noun) list",
                message: "The bundled \(noun) data or your saved progress didn't load.",
                actionTitle: "Try again",
                action: onRetry
            )
            .frame(maxHeight: .infinity)
        case .loaded:
            loadedList
        }
    }

    private var loadedList: some View {
        List {
            Section {
                addCard
                    .listRowBackground(Forest.surface)
            }

            Section {
                dueContent
                    .listRowBackground(Forest.surface)
            } header: {
                Text("Due for review")
                    .textCase(nil)
            }

            Section {
                if entries.isEmpty {
                    Text("Nothing added yet today. Your first \(noun) will show up here.")
                        .font(.subheadline)
                        .foregroundStyle(Forest.inkMuted)
                        .padding(.vertical, Forest.Space.s)
                        .listRowBackground(Forest.surface)
                } else {
                    VStack(alignment: .leading, spacing: Forest.Space.s) {
                        Button(action: onReview) {
                            Text("Review today's \(nouns)")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Forest.ink)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        Text("Try the reading and meaning before revealing the answer.")
                            .font(.subheadline)
                            .foregroundStyle(Forest.inkMuted)
                    }
                    .listRowBackground(Forest.surface)
                    ForEach(entries) { entry in
                        Button { onSelect(entry) } label: {
                            StudyRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Forest.surface)
                        .studyRemovalActions(entry: entry, noun: noun, onDelete: onDelete)
                    }
                }
            } header: {
                Text("Added today")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Forest.inkMuted)
                    .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .animation(.default, value: entries)
    }

    @ViewBuilder
    private var dueContent: some View {
        switch dueLoadState {
        case .loading:
            ProgressView("Loading due \(nouns)")
        case .failed:
            StateMessage(title: "Couldn't read due \(nouns)", message: "Your saved collection or review schedule didn't load.", actionTitle: "Try again", action: onRetryDue)
        case .loaded:
            if dueCount == 0 {
                StateMessage(title: "No \(nouns) due", message: "Add a \(noun) to begin, or return when your next review is due.")
            } else {
                VStack(alignment: .leading, spacing: Forest.Space.s) {
                    Button(action: onReviewDue) {
                        Text("Review \(dueCount) due \(dueCount == 1 ? noun : nouns)")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Forest.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    Text("Ratings save your next review date. Intervals are 1, 3, 7, 14 and 30 days; Again resets to 1 day.")
                        .font(.subheadline)
                        .foregroundStyle(Forest.inkMuted)
                }
            }
        }
    }

    private var addCard: some View {
        VStack(alignment: .leading, spacing: Forest.Space.m) {
            HStack(alignment: .firstTextBaseline, spacing: Forest.Space.s) {
                Text("\(entries.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Forest.ink)
                    .contentTransition(.numericText())
                Text(entries.count == 1 ? "\(noun) added today" : "\(nouns) added today")
                    .font(.headline)
                    .foregroundStyle(Forest.ink)
            }
            .accessibilityElement(children: .combine)

            Text(caption)
                .font(.subheadline)
                .foregroundStyle(Forest.inkMuted)

            Button("Add next \(noun)", action: onAdd)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(hasFinished)
        }
        .padding(.vertical, Forest.Space.s)
    }

    private var caption: String {
        if hasFinished {
            return "You've added every \(noun) in the list."
        }
        if let nextLevel {
            return "The next \(noun) comes from JLPT \(nextLevel)."
        }
        return "Add one, read it, then add the next when you're ready."
    }
}
