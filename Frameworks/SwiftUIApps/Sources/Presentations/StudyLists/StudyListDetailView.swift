import SwiftUI
import DataKit

struct StudyListDetailView: View {
    @EnvironmentObject private var router: AppRouter
    @State var viewModel: StudyListDetailViewModel
    let savedDetail: (SavedStudyID) throws -> AppRoutes
    @State private var renaming = false
    @State private var deleting = false
    @State private var reviewing = false
    @State private var wordToRemove: SavedStudyItem?
    @State private var detailError: String?

    var body: some View {
        List {
            if viewModel.state.isLoading {
                ProgressView("Loading list items")
            } else if viewModel.state.isMissing {
                StateMessage(title: "List no longer available", message: viewModel.state.error ?? "Return to Study lists.", actionTitle: "Back to Study lists") { router.pop() }
            } else if let error = viewModel.state.error {
                StateMessage(title: "Couldn't open this list", message: error, actionTitle: "Try again") { viewModel.send(.load) }
            } else {
                if !viewModel.state.words.isEmpty {
                    Button("Review list") { reviewing = true }.foregroundStyle(Forest.ink).frame(minHeight: 44)
                }
                Text("Organize saved items from their detail screen. Removing an item here keeps it in your collection.").font(.subheadline).foregroundStyle(Forest.inkMuted)
                if viewModel.state.words.isEmpty {
                    StateMessage(title: "No items in this list", message: "Open a saved item in Collection and choose Organize in lists.")
                }
                ForEach(viewModel.state.words, id: \.id) { word in
                    Button {
                        do { router.push(try savedDetail(word.id), hideNavBar: false) }
                        catch { detailError = "This saved word couldn't be opened. Return to Collection or try again." }
                    } label: {
                        StudyRow(entry: .init(id: word.id.id, headword: word.headword, reading: word.reading, meaning: word.meanings.joined(separator: ", "), level: word.level))
                    }
                    .swipeActions(allowsFullSwipe: false) {
                        Button("Remove from this list", role: .destructive) { wordToRemove = word }.tint(Forest.danger)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Forest.canvas)
        .listRowBackground(Forest.surface)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle(viewModel.state.list?.name ?? "Study list")
        .toolbar {
            if let list = viewModel.state.list {
                ToolbarItem(placement: .primaryAction) {
                    Menu("List actions") {
                        Button("Rename list") { viewModel.send(.setName(list.name)); renaming = true }
                        Button("Delete list", role: .destructive) { deleting = true }
                    }
                }
            }
        }
        .sheet(isPresented: $renaming) {
            StudyListNameSheet(title: "Rename list", name: Binding(get: { viewModel.state.name }, set: { viewModel.send(.setName($0)) }), error: viewModel.state.actionError) { viewModel.send(.rename); if viewModel.state.didRename { renaming = false } }
        }
        .sheet(isPresented: $reviewing) {
            ReviewSetupView(kind: nil, items: viewModel.state.words.map(ReviewItem.init(saved:)), origin: .list(id: viewModel.id, name: viewModel.state.list?.name ?? "Study list")) { router.push(.review($0), hideNavBar: false) }
        }
        .confirmationDialog("Delete \(viewModel.state.list?.name ?? "this list")?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete list", role: .destructive) { viewModel.send(.delete); if viewModel.state.didDelete { router.pop() } }
        } message: { Text("Its items remain in your collection. Only this list and its memberships are removed.") }
        .confirmationDialog("Remove \(wordToRemove?.headword ?? "item") from this list?", isPresented: Binding(get: { wordToRemove != nil }, set: { if !$0 { wordToRemove = nil } }), titleVisibility: .visible) {
            Button("Remove from this list", role: .destructive) { if let wordToRemove { viewModel.send(.removeItem(wordToRemove.id)) }; wordToRemove = nil }
        } message: { Text("The item stays in your collection with its progress and review dates.") }
        .alert("Couldn't complete this action", isPresented: Binding(get: { detailError != nil || (!renaming && viewModel.state.actionError != nil) }, set: { if !$0 { detailError = nil; viewModel.send(.clearActionError) } })) {
            Button("OK") { detailError = nil; viewModel.send(.clearActionError) }
        } message: { Text(detailError ?? viewModel.state.actionError ?? "Try again.") }
        .onAppear { viewModel.send(.load) }
    }
}
