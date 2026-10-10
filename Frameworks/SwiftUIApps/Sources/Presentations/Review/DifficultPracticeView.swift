import SwiftUI
import DataKit

struct DifficultPracticeView: View {
    @EnvironmentObject private var router: AppRouter
    @State var viewModel: DifficultPracticeViewModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Forest.Space.xl) {
                Text("Practice items you've marked Again. First-try recall in a later session clears an item from this group. Extra practice keeps your review dates unchanged.").foregroundStyle(Forest.inkMuted)
                if viewModel.state.isLoading {
                    ProgressView("Loading difficult items")
                } else if let error = viewModel.state.error {
                    StateMessage(title: "Couldn't open difficult items", message: error, actionTitle: "Try again") { viewModel.send(.load) }
                } else if viewModel.difficultItems.isEmpty {
                    StateMessage(title: "No difficult items yet", message: "Use Again when an answer is difficult to recall during review. Those saved items will appear here.")
                } else {
                    Picker("Study material", selection: Binding(get: { viewModel.state.kind }, set: { viewModel.send(.setKind($0)) })) {
                        Text("All material").tag(SavedStudyKind?.none)
                        ForEach(StudyKind.allCases) { kind in Text(kind.rawValue).tag(SavedStudyKind?.some(kind.savedKind)) }
                    }
                    Picker("JLPT level", selection: Binding(get: { viewModel.state.level }, set: { viewModel.send(.setLevel($0)) })) {
                        Text("All levels").tag(String?.none)
                        ForEach(["N5", "N4", "N3", "N2", "N1", "Unspecified"], id: \.self) { Text($0).tag(String?.some($0)) }
                    }
                    Picker("Study list", selection: Binding(get: { viewModel.state.listID }, set: { viewModel.send(.setList($0)) })) {
                        Text("All lists and unlisted items").tag(String?.none)
                        ForEach(viewModel.state.snapshot.lists) { Text($0.name).tag(String?.some($0.id)) }
                    }
                    Text("Session size").font(.headline)
                    Picker("Session size", selection: Binding(get: { viewModel.state.limit }, set: { viewModel.send(.setLimit($0)) })) {
                        Text("10").tag(Int?.some(10)); Text("20").tag(Int?.some(20)); Text("All").tag(Int?.none)
                    }.pickerStyle(.segmented)
                    Text("\(viewModel.selected.count) items selected").font(.headline)
                    Text("Most-missed items come first, followed by the latest miss.").font(.subheadline).foregroundStyle(Forest.inkMuted)
                    if viewModel.selected.isEmpty {
                        StateMessage(title: "No items match these filters", message: "Choose another material, level or list.", actionTitle: "Clear filters") { viewModel.send(.clearFilters) }
                    }
                }
            }.pickerStyle(.menu).foregroundStyle(Forest.ink).padding(Forest.Space.l).frame(maxWidth: .infinity, alignment: .leading)
        }.background(Forest.canvas)
        .safeAreaInset(edge: .bottom) {
            Button("Start practice") { router.push(.review(.init(items: viewModel.selected, origin: .difficult)), hideNavBar: false) }
                .buttonStyle(PrimaryButtonStyle()).disabled(viewModel.state.isLoading || viewModel.state.error != nil || viewModel.selected.isEmpty)
                .padding(Forest.Space.l).background(Forest.canvas)
        }
        .navigationTitle("Difficult items").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar).toolbar(.hidden, for: .tabBar)
        .onAppear { viewModel.send(.load) }
    }
}
