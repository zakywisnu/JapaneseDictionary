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
    @Environment(\.showsTodayHeader) private var showsTodayHeader
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
        if loadState == .loaded {
            loadedList
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Forest.Space.xl) {
                    if showsTodayHeader { TodayLearningHeader() }
                    if loadState == .loading {
                        ProgressView("Loading today's \(nouns)")
                    } else {
                        StateMessage(title: "Couldn't open your \(noun) list", message: "The bundled \(noun) data or your saved progress didn't load.", actionTitle: "Try again", action: onRetry)
                    }
                }.padding(Forest.Space.l).frame(maxWidth: .infinity, alignment: .leading)
            }.background(Forest.canvas)
        }
    }

    private var loadedList: some View {
        List {
            if showsTodayHeader { Section { TodayLearningHeader() }.listRowBackground(Forest.canvas).listRowInsets(EdgeInsets(top: Forest.Space.m, leading: 0, bottom: Forest.Space.l, trailing: 0)) }
            Section {
                dueContent
                addCard
            }.listRowBackground(Forest.surface)

            Section {
                if entries.isEmpty {
                    Text("Nothing added yet today. Your first \(noun) will show up here.")
                        .font(.subheadline)
                        .foregroundStyle(Forest.inkMuted)
                        .padding(.vertical, Forest.Space.s)
                        .listRowBackground(Forest.surface)
                } else {
                    Group {
                        Button(action: onReview) {
                            Text("Review today's \(nouns)")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Forest.ink)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)

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
        .forestTabList()
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
                VStack(alignment: .leading, spacing: Forest.Space.xs) {
                    Text("No \(nouns) due").font(.headline)
                    Text("Add a \(noun) or return when your next review is due.").font(.subheadline).foregroundStyle(Forest.inkMuted)
                }
            } else {
                ForestNavigationRow(title: "Review \(dueCount) due \(dueCount == 1 ? noun : nouns)", subtitle: "Practice and update your review dates", action: onReviewDue)
                    .listRowInsets(EdgeInsets())
            }
        }
    }

    private var addCard: some View {
        ForestNavigationRow(title: "Add next \(noun)", subtitle: caption, action: onAdd)
            .disabled(hasFinished).listRowInsets(EdgeInsets())
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
