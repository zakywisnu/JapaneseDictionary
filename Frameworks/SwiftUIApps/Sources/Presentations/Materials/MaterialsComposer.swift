import SwiftUI
import DataKit
import DomainKit

extension AppComposer {
    func makeCustomCardEditor(material: StudyMaterial? = nil, onSaved: @escaping (StudyMaterial) -> Void) -> some View {
        CustomCardEditorView(viewModel: CustomCardEditorViewModel(material: material, repository: StandardStudyMaterialRepository(store: store)), onSaved: onSaved)
    }
    func makeLessonsView() -> some View {
        MaterialLibraryScreen(mode: .bundled, composer: self)
    }
    func makeMaterialLibraryView(kind: SavedStudyKind) -> some View {
        MaterialLibraryScreen(mode: .saved(kind), composer: self)
    }
    func makeMaterialDetailView(_ material: StudyMaterial, saved: Bool) -> some View {
        let catalog = LessonCatalogRepository()
        return MaterialDetailView(viewModel: MaterialDetailViewModel(material: material, mode: saved ? .saved : .bundled, repository: StandardStudyMaterialRepository(store: store), catalog: catalog), related: { id in
            try? catalog.materials().first { $0.source?.sourceID == id }
        })
    }
    func makeMaterialsTodayView(kind: SavedStudyKind) -> some View {
        MaterialsTodayView(kind: kind, repository: StandardStudyMaterialRepository(store: store), due: DefaultGetDueReviewsUseCase(repository: StandardReviewRepository(store: store)))
    }
}

private struct MaterialLibraryScreen: View {
    @EnvironmentObject private var router: AppRouter
    let mode: MaterialLibraryViewModel.Mode
    let composer: AppComposer
    @State private var creating = false
    @State private var reviewItems: [ReviewItem] = []
    @State private var reviewing = false
    var body: some View {
        MaterialLibraryView(viewModel: MaterialLibraryViewModel(mode: mode, repository: StandardStudyMaterialRepository(store: composer.store), catalog: LessonCatalogRepository()), onOpen: { material in
            router.push(.material(material, saved: mode != .bundled), hideNavBar: false)
        }, onReview: { materials in reviewItems = materials.map(ReviewItem.init(material:)); reviewing = true }, onCreate: { creating = true }, onBrowse: { router.push(.lessons, hideNavBar: false) })
        .sheet(isPresented: $creating) { composer.makeCustomCardEditor { material in router.push(.material(material, saved: true), hideNavBar: false) } }
        .sheet(isPresented: $reviewing) {
            ReviewSetupView(kind: .cards, items: reviewItems) { session in router.push(.review(session), hideNavBar: false) }
        }
    }
}

private struct MaterialsTodayView: View {
    @Environment(\.showsTodayHeader) private var showsTodayHeader
    @EnvironmentObject private var router: AppRouter
    let kind: SavedStudyKind
    let repository: StandardStudyMaterialRepository
    let due: any GetDueReviewsUseCase
    @State private var items: [StudyMaterial] = []
    @State private var dueItems: [ReviewItem] = []
    @State private var error: String?
    @State private var loading = true
    @State private var creating = false
    var body: some View {
        List {
            if showsTodayHeader { Section { TodayLearningHeader() }.listRowBackground(Forest.canvas).listRowInsets(EdgeInsets(top: Forest.Space.m, leading: 0, bottom: Forest.Space.l, trailing: 0)) }
            Section {
                if loading { ProgressView("Loading due items") }
                else if let error { StateMessage(title: "Couldn't open your study items", message: error, actionTitle: "Try again", action: load) }
                else if dueItems.isEmpty {
                    VStack(alignment: .leading, spacing: Forest.Space.xs) {
                        Text("No items due").font(.headline)
                        Text("Save a lesson or return when your next review is due.").font(.subheadline).foregroundStyle(Forest.inkMuted)
                    }
                } else {
                    ForestNavigationRow(title: "Review \(dueItems.count) due items", subtitle: "Practice and update your review dates") { router.push(.review(ReviewSession(items: dueItems, origin: .due)), hideNavBar: false) }.listRowInsets(EdgeInsets())
                }
                if kind == .customCard {
                    ForestNavigationRow(title: "Create card", subtitle: "Add something of your own to practice") { creating = true }.listRowInsets(EdgeInsets())
                } else {
                    ForestNavigationRow(title: "Browse lessons", subtitle: "Find grammar and sentences to study") { router.push(.lessons, hideNavBar: false) }.listRowInsets(EdgeInsets())
                }
            }.listRowBackground(Forest.surface)
            if !loading && error == nil {
                Section("Added today") {
                    if items.isEmpty { Text("Nothing added yet today.").font(.subheadline).foregroundStyle(Forest.inkMuted) }
                    else {
                        Button("Review today's items") { router.push(.review(ReviewSession(items: items.map(ReviewItem.init(material:)), origin: .today)), hideNavBar: false) }.foregroundStyle(Forest.ink)
                        ForEach(items, id: \.id) { material in
                            Button { router.push(.material(material, saved: true), hideNavBar: false) } label: { MaterialPrompt(text: material.prompt) }.buttonStyle(.plain)
                        }
                    }
                }.listRowBackground(Forest.surface)
            }
        }.forestTabList()
            .onAppear(perform: load).onChange(of: kind) { _, _ in load() }
            .sheet(isPresented: $creating) { AppComposer.shared.makeCustomCardEditor { _ in load() } }
    }
    private func load() {
        loading = true; error = nil
        do {
            items = try repository.materials(kind: kind).filter { Calendar.autoupdatingCurrent.isDateInToday($0.createdAt) }.sorted { $0.createdAt > $1.createdAt }
            dueItems = try due.execute(kind: kind, now: Date()).map { ReviewItem(saved: $0.item) }
        } catch { self.error = "The saved collection or review dates couldn't be read. Try again." }
        loading = false
    }
}
