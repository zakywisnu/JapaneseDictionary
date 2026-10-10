import SwiftUI
import DataKit

struct KanaPracticeView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase
    @State var viewModel: KanaPracticeViewModel
    @State private var pronunciation = PronunciationService()
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
                                    PracticeCells(text: entry.kana, cellSize: 44)
                                    Text(entry.romanization).font(.headline).foregroundStyle(Forest.ink).fixedSize(horizontal: false, vertical: true)
                                }
                            }.toggleStyle(.checkboxKana)
                            Text(entry.note).font(.subheadline).foregroundStyle(Forest.inkMuted).fixedSize(horizontal: false, vertical: true)
                            if let reading = entry.reading { PronunciationControl(reading: reading, service: pronunciation) }
                        }.padding(.vertical, Forest.Space.xs)
                    }
                }.listRowBackground(Forest.surface)
            }
            if let error = viewModel.state.saveError {
                StateMessage(title: "Kana cards weren't all saved", message: error, actionTitle: "Try again") { start() }.listRowBackground(Forest.surface)
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden).background(Forest.canvas).tint(Forest.moss)
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
