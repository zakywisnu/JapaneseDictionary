import SwiftUI
import DataKit
import DomainKit

struct KanaPracticeView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var textSize
    @State var viewModel: KanaPracticeViewModel
    @State private var pronunciation = PronunciationService()
    private var sharedNote: String? {
        let notes = viewModel.visible.map(\.note).filter { !$0.isEmpty }
        let counts = Dictionary(grouping: notes, by: { $0 }).mapValues(\.count)
        guard let highestCount = counts.values.max(), highestCount > 1 else { return nil }
        return notes.first { counts[$0] == highestCount }
    }
    var body: some View {
        List {
            Section {
                Text("Select kana to save as local cards and practice.")
                    .foregroundStyle(Forest.inkMuted)
                Picker("Script", selection: Binding(get: { viewModel.state.script }, set: { pronunciation.stop(); viewModel.send(.script($0)) })) {
                    ForEach(KanaScript.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Group", selection: Binding(get: { viewModel.state.group }, set: { pronunciation.stop(); viewModel.send(.group($0)) })) {
                    ForEach(KanaGroup.allCases) { Text($0.rawValue).tag($0) }
                }
                if let sharedNote {
                    Text(sharedNote).font(.subheadline).foregroundStyle(Forest.inkMuted)
                }
                Text("\(viewModel.state.selected.count) selected across all groups")
                    .font(.subheadline).foregroundStyle(Forest.inkMuted)
            }.listRowBackground(Forest.surface)
            if viewModel.state.isLoading {
                ProgressView("Loading kana").listRowBackground(Forest.surface)
            } else if let error = viewModel.state.error {
                StateMessage(title: "Couldn't open kana", message: error, actionTitle: "Try again") { viewModel.send(.load) }.listRowBackground(Forest.surface)
            } else if viewModel.visible.isEmpty {
                StateMessage(title: "No kana in this group", message: "Choose another script or group.").listRowBackground(Forest.surface)
            } else {
                Section {
                    Button("Select this group") { viewModel.send(.selectVisible) }.foregroundStyle(Forest.ink).frame(minHeight: 44)
                    ForEach(viewModel.visible) { entry in
                        VStack(alignment: .leading, spacing: Forest.Space.s) {
                            Toggle(isOn: Binding(get: { viewModel.state.selected.contains(entry.id) }, set: { _ in viewModel.send(.toggle(entry.id)) })) {
                                VStack(alignment: .leading, spacing: Forest.Space.s) {
                                    HStack(spacing: Forest.Space.m) {
                                        Headword(text: entry.kana, cellSize: 34)
                                        Text(entry.romanization).font(.headline).foregroundStyle(Forest.ink).fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }.toggleStyle(.checkboxKana)
                            if entry.note != sharedNote, !entry.note.isEmpty {
                                Text(entry.note).font(.subheadline).foregroundStyle(Forest.inkMuted).fixedSize(horizontal: false, vertical: true)
                            }
                            if let reading = entry.reading {
                                (textSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: Forest.Space.s)) : AnyLayout(HStackLayout(spacing: Forest.Space.l))) {
                                    PronunciationControl(reading: reading, service: pronunciation, showsAttribution: false)
                                    Button("Record and replay") {
                                        pronunciation.stop()
                                        router.push(.speaking(.init(id: entry.id, prompt: entry.kana, suppliedReading: reading, isIsolatedSound: true)), hideNavBar: false)
                                    }.buttonStyle(.plain).foregroundStyle(Forest.ink).font(.subheadline).frame(minHeight: 44)
                                }

                            }
                        }.padding(.vertical, Forest.Space.xs)
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: Forest.Space.s) {
                        Text("Listen uses synthesized speech.")
                    }.font(.footnote).foregroundStyle(Forest.inkMuted).textCase(nil)
                }.listRowBackground(Forest.surface)
            }
            if let error = viewModel.state.saveError {
                StateMessage(title: "Kana cards weren't all saved", message: error, actionTitle: "Try again") { start() }.listRowBackground(Forest.surface)
            }
        }
        .forestTabList().tint(Forest.moss)
        .safeAreaInset(edge: .bottom) {
            Button { start() } label: {
                Text("Save and practice").multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true).padding(.horizontal, Forest.Space.l)
            }
                .buttonStyle(PrimaryButtonStyle()).disabled(viewModel.state.isLoading || viewModel.state.error != nil || viewModel.state.selected.isEmpty)
                .padding(Forest.Space.l).background(Forest.canvas)
        }
        .navigationTitle("Kana").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar).toolbar(.hidden, for: .tabBar)
        .onAppear { viewModel.send(.load) }
        .onDisappear { pronunciation.stop() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { pronunciation.stop() } }
    }
    private func start() {
        pronunciation.stop(); viewModel.send(.saveAndPractice)
        if let session = viewModel.state.session { router.push(.review(session), hideNavBar: false) }
    }
}

private struct KanaSelectionStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack { configuration.label; Spacer(); Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle").foregroundStyle(Forest.inkMuted) }
                .frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}
private extension ToggleStyle where Self == KanaSelectionStyle {
    static var checkboxKana: KanaSelectionStyle { KanaSelectionStyle() }
}
