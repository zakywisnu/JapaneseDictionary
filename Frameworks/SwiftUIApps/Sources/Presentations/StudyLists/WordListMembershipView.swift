import SwiftUI

struct WordListMembershipView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: WordListMembershipViewModel
    let makeLists: () -> AnyView
    var body: some View {
        NavigationStack {
            List {
                if viewModel.state.isLoading {
                    ProgressView("Loading this item's lists")
                } else if let error = viewModel.state.error {
                    StateMessage(title: "Couldn't open item lists", message: error, actionTitle: "Try again") { viewModel.send(.load) }
                } else {
                    if viewModel.state.lists.isEmpty {
                        StateMessage(title: "No study lists yet", message: "Create a list, then return here to select it.")
                    }
                    NavigationLink("Manage study lists") { makeLists().onDisappear { viewModel.send(.refreshLists) } }
                    ForEach(viewModel.state.lists) { list in
                        Button { viewModel.send(.toggle(list.id)) } label: {
                            HStack(alignment: .firstTextBaseline, spacing: Forest.Space.m) {
                                Text(list.name).foregroundStyle(Forest.ink).fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                Image(systemName: viewModel.state.selected.contains(list.id) ? "checkmark.square" : "square").foregroundStyle(Forest.inkMuted)
                            }.frame(minHeight: 44)
                        }.accessibilityValue(viewModel.state.selected.contains(list.id) ? "Selected" : "Not selected")
                    }
                    if let error = viewModel.state.saveError { Text(error).foregroundStyle(Forest.ink).fixedSize(horizontal: false, vertical: true) }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Forest.canvas)
            .listRowBackground(Forest.surface)
            .navigationTitle("Organize in lists")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button("Save") { viewModel.send(.save); if viewModel.state.didSave { dismiss() } }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(viewModel.state.isLoading || viewModel.state.error != nil)
                    .padding(Forest.Space.l).background(Forest.canvas)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { viewModel.send(.cancel); dismiss() } } }
        }
        .tint(Forest.moss)
        .onAppear { viewModel.send(.load) }
    }
}
