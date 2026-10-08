import SwiftUI

struct DailyGoalSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: DailyGoalViewModel
    private let targets: [Int?] = [nil, 5, 10, 20, 30]

    var body: some View {
        List {
            if viewModel.state.isLoading {
                ProgressView("Loading daily goal")
                    .listRowBackground(Forest.surface)
            } else if let error = viewModel.state.error {
                StateMessage(title: "Couldn't open daily goal", message: error, actionTitle: "Try again") { viewModel.send(.load) }
                    .listRowBackground(Forest.surface)
            } else {
                Section {
                    Picker("Daily goal", selection: Binding(get: { viewModel.state.selectedTarget }, set: { viewModel.send(.selectTarget($0)) })) {
                        ForEach(targets, id: \.self) { target in
                            Text(target.map { "\($0.formatted()) items" } ?? "Off").tag(target)
                        }
                    }
                    .pickerStyle(.inline)
                    .listRowBackground(Forest.surface)
                } footer: {
                    Text("Each saved word or kanji marked Got it counts once per day. Again doesn't count. Off hides the summary and keeps your practice activity.")
                        .foregroundStyle(Forest.inkMuted)
                }
                if let error = viewModel.state.saveError {
                    StateMessage(title: "Couldn't save daily goal", message: error, actionTitle: "Try again") { save() }
                        .listRowBackground(Forest.surface)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Forest.canvas)
        .foregroundStyle(Forest.ink)
        .tint(Forest.moss)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle("Daily practice goal")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if !viewModel.state.isLoading && viewModel.state.error == nil {
                Button("Save", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(Forest.Space.l)
                    .background(Forest.canvas)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { viewModel.send(.cancel); dismiss() }
            }
        }
        .onAppear { viewModel.send(.load) }
    }

    private func save() {
        viewModel.send(.save)
        if viewModel.state.didSave { dismiss() }
    }
}
