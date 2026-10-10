import SwiftUI
import DataKit
import DomainKit

struct MaterialDetailView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase
    @State var viewModel: MaterialDetailViewModel
    @State private var editing = false
    @State private var organizing = false
    @State private var removing = false
    @State private var pronunciation = PronunciationService()
    @State private var showingSource = false
    let related: (String) -> StudyMaterial?

    var speakingTarget: SpeakingTarget? { Self.speakingTarget(for: material) }
    static func speakingTarget(for material: StudyMaterial) -> SpeakingTarget? {
        guard [.sentence, .customCard].contains(material.kind), let reading = material.reading,
              let supplied = SpeechTextValidator.normalizedReading(reading) else { return nil }
        return .init(id: SavedStudyID(kind: material.kind, id: material.id).key, prompt: material.prompt, suppliedReading: supplied, acceptedWrittenForms: [material.prompt])
    }
    private var material: StudyMaterial { viewModel.state.material }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Forest.Space.xl) {
                MaterialPrompt(text: material.prompt)
                if let level = material.level {
                    Text(material.kind == .sentence ? "From an \(level) lesson" : "JLPT \(level)").font(.subheadline).foregroundStyle(Forest.inkMuted)
                }
                if material.kind == .customCard { Text("Your card").font(.subheadline).foregroundStyle(Forest.inkMuted) }
                if let reading = material.reading {
                    Text(reading).foregroundStyle(Forest.inkMuted)
                    PronunciationControl(reading: reading, service: pronunciation)
                }
                if let target = speakingTarget {
                    Button("Practice speaking") {
                        pronunciation.stop()
                        router.push(.speaking(target), hideNavBar: false)
                    }.buttonStyle(.bordered).frame(minHeight: 44)
                }
                MaterialAnswer(material: material)
                let references = Array(Set(material.relatedSourceIDs + (material.source?.parentIDs ?? []))).sorted()
                if !references.isEmpty {
                    VStack(alignment: .leading, spacing: Forest.Space.s) {
                        Text("Related lessons").font(.headline)
                        ForEach(references, id: \.self) { id in
                            if let lesson = related(id) {
                                Button(lesson.prompt) { router.push(.material(lesson, saved: false), hideNavBar: false) }.foregroundStyle(Forest.ink).frame(minHeight: 44)
                            } else { Text(id).font(.subheadline).foregroundStyle(Forest.inkMuted) }
                        }
                    }
                }
                if let source = material.source {
                    Button("Source information") { showingSource = true }.foregroundStyle(Forest.ink).frame(minHeight: 44)
                        .sheet(isPresented: $showingSource) {
                            NavigationStack {
                                ScrollView { VStack(alignment: .leading, spacing: Forest.Space.l) {
                                    Text("Community material from \(source.provider).")
                                    Text(source.sourceURL)
                                    Text("Snapshot: \(source.snapshot)")
                                    Text(source.license).font(.headline)
                                    Text(source.notice)
                                }.padding(Forest.Space.l) }.background(Forest.canvas).navigationTitle("Source information").tint(Forest.moss)
                                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingSource = false } } }
                            }
                        }
                }
                if viewModel.mode == .saved {
                    Button("Organize in lists") { organizing = true }.foregroundStyle(Forest.ink).frame(minHeight: 44)
                    Button("Review item") { router.push(.review(ReviewSession(items: [ReviewItem(material: material)], origin: .collection)), hideNavBar: false) }.foregroundStyle(Forest.ink).frame(minHeight: 44)
                }
                if let error = viewModel.state.errorMessage {
                    StateMessage(title: "Couldn't finish this action", message: error, actionTitle: "Try again") { viewModel.send(.load) }
                }
            }.padding(Forest.Space.l).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Forest.canvas).tint(Forest.moss)
        .navigationTitle(material.kind == .customCard ? "Your card" : "Lesson")
        .navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            if viewModel.mode == .bundled {
                VStack {
                    if let saved = viewModel.state.savedMaterial {
                        Button("View saved item") { router.push(.material(saved, saved: true), hideNavBar: false) }.buttonStyle(PrimaryButtonStyle())
                    } else {
                        Button("Save to collection") { viewModel.send(.save) }.buttonStyle(PrimaryButtonStyle()).disabled(!viewModel.canSave)
                    }
                }.padding(Forest.Space.l).background(Forest.canvas)
            }
        }
        .toolbar {
            if viewModel.mode == .saved {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if material.kind == .customCard { Button("Edit card") { pronunciation.stop(); editing = true } }
                        Button("Remove from collection", role: .destructive) { removing = true }
                    } label: { Label("Item actions", systemImage: "ellipsis") }
                }
            }
        }
        .confirmationDialog("Remove this item?", isPresented: $removing, titleVisibility: .visible) {
            Button("Remove from collection", role: .destructive) { viewModel.send(.delete); if viewModel.state.didDelete { router.pop() } }
        } message: { Text("\(material.prompt) will be removed from Collection, study lists, review dates and difficult items. Past daily goal activity stays.") }
        .sheet(isPresented: $editing) { AppComposer.shared.makeCustomCardEditor(material: material) { _ in viewModel.send(.load) } }
        .sheet(isPresented: $organizing) { AppComposer.shared.makeItemListMembershipView(id: SavedStudyID(kind: material.kind, id: material.id)) }
        .onAppear { viewModel.send(.load); pronunciation.refreshAvailability() }
        .onDisappear { pronunciation.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { pronunciation.refreshAvailability() }
            else { pronunciation.stop() }
        }
        .onChange(of: editing) { _, editing in if editing { pronunciation.stop() } }
        .onChange(of: showingSource) { _, showing in if showing { pronunciation.stop() } }
        .onChange(of: organizing) { _, organizing in if organizing { pronunciation.stop() } }
    }
}

struct MaterialAnswer: View {
    let material: StudyMaterial
    var body: some View {
        VStack(alignment: .leading, spacing: Forest.Space.l) {
            block(material.kind == .sentence ? "Translation" : "Answer", material.answer)
            if !material.structures.isEmpty { block("Formation", material.structures.joined(separator: "\n")) }
            if let notes = material.notes { block(material.kind == .grammar ? "Explanation and usage" : "Notes", notes) }
            ForEach(Array(material.examples.enumerated()), id: \.offset) { _, example in
                VStack(alignment: .leading, spacing: Forest.Space.s) {
                    MaterialPrompt(text: example.japanese)
                    Text(example.english).font(.body)
                }
            }
            if material.kind == .sentence, let parents = material.source?.parentIDs, !parents.isEmpty {
                block("Lesson context", parents.joined(separator: "\n"))
            }
        }.padding(Forest.Space.l).frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Forest.ink).background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
    }
    private func block(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Forest.Space.s) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Forest.inkMuted)
            Text(value).font(.body).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
        }
    }
}
