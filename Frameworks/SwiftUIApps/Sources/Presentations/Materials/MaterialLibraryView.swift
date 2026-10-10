import SwiftUI
import DataKit

struct MaterialLibraryView: View {
    @State var viewModel: MaterialLibraryViewModel
    let onOpen: (StudyMaterial) -> Void
    let onReview: ([StudyMaterial]) -> Void
    var onCreate: () -> Void = {}
    var onBrowse: () -> Void = {}

    var body: some View {
        List {
            Section {
                TextField("Search prompts, readings or answers", text: Binding(get: { viewModel.state.query }, set: { viewModel.send(.queryChanged($0)) }))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Picker("Study level", selection: Binding(get: { viewModel.state.level }, set: { viewModel.send(.levelChanged($0)) })) {
                    Text("All levels").tag(String?.none)
                    Text("Unspecified").tag(String?.some(""))
                    ForEach(["N5", "N4", "N3", "N2", "N1"], id: \.self) { Text($0).tag(Optional($0)) }
                }.pickerStyle(.menu)
            }.listRowBackground(Forest.surface)
            if viewModel.mode == .bundled {
                Section {
                    Picker("Material", selection: Binding(get: { viewModel.state.kind }, set: { viewModel.send(.kindChanged($0)) })) {
                        Text("Grammar").tag(SavedStudyKind.grammar)
                        Text("Sentences").tag(SavedStudyKind.sentence)
                    }.pickerStyle(.segmented)
                    Text("Community lessons bundled on this iPhone. Save a lesson to practice it.")
                        .font(.footnote).foregroundStyle(Forest.inkMuted)
                }.listRowBackground(Forest.surface)
            } else {
                Section {
                    if viewModel.state.kind == .customCard {
                        Button("Create card", action: onCreate).foregroundStyle(Forest.ink)
                    }
                    if viewModel.state.loadState == .loaded && !viewModel.reviewMaterials.isEmpty {
                        Button("Review items") { onReview(viewModel.reviewMaterials) }.foregroundStyle(Forest.ink)
                        Text("Review includes this material type. Search and level filters only change browsing.")
                            .font(.footnote).foregroundStyle(Forest.inkMuted)
                    }
                }.listRowBackground(Forest.surface)
            }
            Section {
                switch viewModel.state.loadState {
                case .loading:
                    ProgressView("Loading \(viewModel.title.lowercased())")
                case .failed:
                    StateMessage(title: "Couldn't open \(viewModel.title.lowercased())", message: viewModel.state.errorMessage ?? "Try opening the collection again.", actionTitle: "Try again") { viewModel.send(.retry) }
                case .loaded:
                    if viewModel.state.results.isEmpty {
                        if !viewModel.state.query.isEmpty || viewModel.state.level != nil {
                            StateMessage(title: "No matching items", message: "Choose another level or search term.", actionTitle: "Clear filters") { viewModel.send(.clearFilters) }
                        } else {
                            StateMessage(title: "No \(viewModel.title.lowercased()) yet", message: viewModel.mode == .bundled ? "The bundle contains no items of this type. Try loading lessons again." : "Save lessons or create your own cards to build this collection.", actionTitle: viewModel.mode == .bundled ? "Try again" : viewModel.state.kind == .customCard ? "Create card" : "Browse lessons") {
                                if viewModel.mode == .bundled { viewModel.send(.retry) }
                                else if viewModel.state.kind == .customCard { onCreate() }
                                else { onBrowse() }
                            }
                        }
                    } else {
                        ForEach(viewModel.state.results, id: \.id) { material in
                            Button { onOpen(material) } label: {
                                VStack(alignment: .leading, spacing: Forest.Space.s) {
                                    MaterialPrompt(text: material.prompt)
                                    Text(material.answer).font(.body).foregroundStyle(Forest.ink).lineLimit(2)
                                    if let level = material.level {
                                        Text(material.kind == .sentence ? "From an \(level) lesson" : level)
                                            .font(.caption).foregroundStyle(Forest.inkMuted)
                                    }
                                    if viewModel.mode == .bundled && viewModel.isSaved(material) {
                                        Text("In collection").font(.caption).foregroundStyle(Forest.inkMuted)
                                    }
                                }.padding(.vertical, Forest.Space.xs)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }.listRowBackground(Forest.surface)
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden)
        .background(Forest.canvas).tint(Forest.moss)
        .navigationTitle(viewModel.title)
        .scrollDismissesKeyboard(.interactively)
        .toolbar(viewModel.mode == .bundled ? .visible : .hidden, for: .navigationBar)
        .onAppear { viewModel.send(.load) }
    }
}

struct MaterialPrompt: View {
    let text: String
    private var containsJapanese: Bool {
        text.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) || (0x3400...0x9FFF).contains($0.value) }
    }
    var body: some View {
        Text(text)
            .font(containsJapanese ? .custom(Font.headwordFace, size: 24, relativeTo: .title2) : .title2)
            .foregroundStyle(Forest.ink)
            .fixedSize(horizontal: false, vertical: true)
    }
}
