import SwiftUI
import DataKit

struct DictionaryBrowseView: View {
    @EnvironmentObject private var router: AppRouter
    var passageContext: PassageContext? = nil
    @State var viewModel: DictionaryBrowseViewModel

    var body: some View {
        VStack(spacing: Forest.Space.m) {
            VStack(alignment: .leading, spacing: Forest.Space.s) {
                if let passageContext {
                    Text("Choose the study meaning to save to \(passageContext.title).")
                        .font(.subheadline).foregroundStyle(Forest.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                searchField
                Picker("Community JLPT level", selection: Binding(get: { viewModel.state.level }, set: { viewModel.send(.levelChanged($0)) })) {
                    Text("All levels").tag(String?.none)
                    ForEach(["N5", "N4", "N3", "N2", "N1"], id: \.self) { level in
                        Text(level).tag(Optional(level))
                    }
                }
                .pickerStyle(.menu)
                .tint(Forest.moss)
                .frame(minHeight: 44)
                Text("JLPT levels are community estimates.")
                    .font(.footnote).foregroundStyle(Forest.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Forest.Space.l)
            content
        }
        .background(Forest.canvas)
        .navigationTitle("Dictionary")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { viewModel.send(.load) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state.loadState {
        case .loading:
            ProgressView("Loading the dictionary").frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            ScrollView {
                StateMessage(title: "Couldn't open the dictionary", message: viewModel.state.errorMessage ?? "The dictionary or your saved collection didn't load.",
                         actionTitle: "Try again", action: { viewModel.send(.retry) })
            }
            .frame(maxHeight: .infinity)
        case .loaded where viewModel.state.results.isEmpty:
            ScrollView {
                StateMessage(title: "No matching words", message: "Search Japanese, a reading or an English meaning, or choose another level.",
                         actionTitle: "Clear filters", action: { viewModel.send(.clearFilters) })
            }
            .frame(maxHeight: .infinity)
        case .loaded:
            List {
                Section {
                    ForEach(viewModel.state.results, id: \.id) { word in
                        Button { router.push(.dictionaryEntry(word.id, passageContext), hideNavBar: false) } label: {
                            VStack(alignment: .leading, spacing: Forest.Space.s) {
                                StudyRow(entry: word.browseEntry)
                                if viewModel.state.savedWordsByCatalogID[word.id] != nil {
                                    Text("In collection").font(.footnote).foregroundStyle(Forest.inkMuted)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Forest.surface)
                    }
                } header: {
                    Text("\(viewModel.state.results.count.formatted()) words")
                        .font(.subheadline).foregroundStyle(Forest.inkMuted).textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .contentMargins(.top, Forest.Space.s, for: .scrollContent)
        }
    }

    private var searchField: some View {
        HStack(spacing: Forest.Space.s) {
            Image(systemName: "magnifyingglass").foregroundStyle(Forest.inkMuted).accessibilityHidden(true)
            TextField("Search dictionary", text: Binding(get: { viewModel.state.query }, set: { viewModel.send(.queryChanged($0)) }),
                      prompt: Text("Japanese, reading or English").foregroundStyle(Forest.inkMuted))
                .foregroundStyle(Forest.ink).textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search)
                .padding(.vertical, Forest.Space.s)
            if !viewModel.state.query.isEmpty {
                Button { viewModel.send(.queryChanged("")) } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Forest.inkMuted).frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Forest.Space.m)
        .frame(minHeight: 44)
        .background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
        .overlay { RoundedRectangle(cornerRadius: Forest.Radius.card).strokeBorder(Forest.line) }
    }
}

extension DictionaryWord {
    var browseEntry: StudyEntry {
        .init(id: id, headword: headword, reading: reading == headword ? nil : reading,
              meaning: studyMeanings.joined(separator: ", "), level: level)
    }
}
