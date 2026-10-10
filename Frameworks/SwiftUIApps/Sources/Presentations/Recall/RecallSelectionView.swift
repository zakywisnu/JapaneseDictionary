import SwiftUI
import DataKit

struct RecallSelectionView: View {
    @State var viewModel: RecallSelectionViewModel
    @EnvironmentObject private var router: AppRouter
    var body: some View {
        Form {
            if viewModel.state.isLoading {
                ProgressView("Opening practice choices")
            } else if let error = viewModel.state.error {
                StateMessage(title: "Couldn't open practice choices", message: error, actionTitle: "Try again", action: { viewModel.send(.load) })
            } else {
                Section("Practice") {
                    Picker("Mode", selection: Binding(get: { viewModel.state.mode }, set: { viewModel.send(.mode($0)) })) {
                        ForEach(RecallMode.allCases.filter { !viewModel.isListening || $0 != .romanization }) { Text($0.rawValue).tag($0) }
                    }
                    if viewModel.state.mode != .romanization {
                        Picker("Material", selection: Binding(get: { viewModel.state.source }, set: { viewModel.send(.source($0)) })) {
                            ForEach(RecallSource.allCases) { Text($0.rawValue).tag($0) }
                        }
                    }
                    if viewModel.state.mode == .romanization || viewModel.state.source == .kana {
                        Picker("Script", selection: Binding(get: { viewModel.state.script }, set: { viewModel.send(.script($0)) })) {
                            ForEach(KanaScript.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Picker("Group", selection: Binding(get: { viewModel.state.group }, set: { viewModel.send(.group($0)) })) {
                            ForEach(KanaGroup.allCases) { Text($0.rawValue).tag($0) }
                        }
                    } else {
                        Picker("Study list", selection: Binding(get: { viewModel.state.listID }, set: { viewModel.send(.list($0)) })) {
                            Text("All saved items").tag(String?.none)
                            ForEach(viewModel.state.lists) { Text($0.name).tag(Optional($0.id)) }
                        }
                    }
                    Picker("Questions", selection: Binding(get: { viewModel.state.limit }, set: { viewModel.send(.limit($0)) })) {
                        Text("10").tag(Optional(10)); Text("20").tag(Optional(20)); Text("All (up to 1,000)").tag(Int?.none)
                    }
                }
                if viewModel.state.source == .kanji, viewModel.state.mode == .reading {
                    Section("Choose the readings to practice") {
                        ForEach(viewModel.candidates) { question in
                            Toggle(isOn: Binding(get: { viewModel.state.selectedReadingIDs.contains(question.id) }, set: { _ in viewModel.send(.toggleReading(question.id)) })) {
                                Text(question.snapshot.prompt + " · " + question.snapshot.acceptedAnswers.joined(separator: ", "))
                            }
                        }
                    }
                }
                Section {
                    Text("\(viewModel.selected.count) questions selected")
                    Text("\(viewModel.excludedCount) items excluded because they have no suitable supplied reading or answer for this mode.")
                        .font(.subheadline).foregroundStyle(Forest.inkMuted)
                    if viewModel.selected.isEmpty {
                        Text("Choose another material or group, select a kanji reading, or save items with supplied readings.")
                            .font(.subheadline).foregroundStyle(Forest.inkMuted)
                    }
                    Button("Start practice") { viewModel.send(.start) }.buttonStyle(PrimaryButtonStyle()).disabled(viewModel.selected.isEmpty)
                    Text("Checked answers and self-rated recall stay separate. Practice doesn't change review dates or the saved-item daily goal.")
                        .font(.footnote).foregroundStyle(Forest.inkMuted)
                    if let error = viewModel.state.startError { Text(error).font(.subheadline) }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Forest.canvas).foregroundStyle(Forest.ink)
        .navigationTitle(viewModel.isListening ? "Listening practice" : "Typed practice")
        .onAppear { viewModel.send(.load) }
        .onChange(of: viewModel.state.startedKey) { _, key in if let key { router.push(.exerciseResume(key), hideNavBar: false) } }
    }
}
