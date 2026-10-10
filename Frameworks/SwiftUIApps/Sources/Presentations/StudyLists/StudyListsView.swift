import SwiftUI

struct StudyListsView: View {
    @EnvironmentObject private var router: AppRouter
    @State var viewModel: StudyListsViewModel
    var opensDetails = true
    @State private var creating = false

    var body: some View {
        List {
            if viewModel.state.isLoading {
                ProgressView("Loading study lists")
            } else if let error = viewModel.state.error {
                StateMessage(title: "Couldn't open study lists", message: error, actionTitle: "Try again") { viewModel.send(.load) }
            } else if viewModel.state.lists.isEmpty {
                StateMessage(title: "No study lists yet", message: "Create a list, then organize saved items from their detail screen.", actionTitle: "Create list") { creating = true }
            } else {
                ForEach(viewModel.state.lists) { list in
                    Button { if opensDetails { router.push(.studyList(list.id), hideNavBar: false) } } label: {
                        VStack(alignment: .leading, spacing: Forest.Space.xs) {
                            Text(list.name).font(.headline).foregroundStyle(Forest.ink)
                            Text("\(list.itemCount) \(list.itemCount == 1 ? "item" : "items")").font(.subheadline).foregroundStyle(Forest.inkMuted)
                        }.frame(minHeight: 44)
                    }
                    .disabled(!opensDetails)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Forest.canvas)
        .listRowBackground(Forest.surface)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle("Study lists")
        .toolbar { ToolbarItem(placement: .primaryAction) { Button("Create list") { viewModel.send(.setName("")); creating = true } } }
        .sheet(isPresented: $creating) {
            StudyListNameSheet(title: "Create list", name: Binding(get: { viewModel.state.name }, set: { viewModel.send(.setName($0)) }), error: viewModel.state.actionError) { viewModel.send(.create); if viewModel.state.didCreate { creating = false } }
        }
        .onAppear { viewModel.send(.load) }
    }
}

struct StudyListNameSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var name: String
    let error: String?
    let save: () -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Forest.Space.l) {
                    TextField("List name", text: $name).textFieldStyle(.roundedBorder)
                    Text("Use a unique name from 1 to 60 characters.").font(.subheadline).foregroundStyle(Forest.inkMuted)
                    if let error { Text(error).foregroundStyle(Forest.ink).fixedSize(horizontal: false, vertical: true) }
                }.padding(Forest.Space.l)
            }
            .background(Forest.canvas)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { Button("Save", action: save).buttonStyle(PrimaryButtonStyle()).padding(Forest.Space.l).background(Forest.canvas) }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }.tint(Forest.moss)
    }
}
