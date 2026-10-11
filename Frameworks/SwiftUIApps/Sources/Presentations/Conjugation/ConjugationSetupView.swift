import SwiftUI
import DomainKit

struct ConjugationSetupView: View {
    @State var viewModel: ConjugationSetupViewModel
    @EnvironmentObject private var router: AppRouter
    var body: some View {
        Form {
            if viewModel.state.isLoading { ProgressView("Opening conjugation practice") }
            else if let error = viewModel.state.error {
                StateMessage(title: "Practice unavailable", message: error, actionTitle: "Try again", action: { viewModel.send(.load) })
            } else {
                Section("Choose practice") {
                    Picker("Word class", selection: Binding(get: { viewModel.state.classID }, set: { viewModel.send(.classID($0)) })) {
                        Text("All classes").tag(String?.none)
                        ForEach(ConjugationPolicy.classes, id: \.self) { Text(ConjugationPolicy.classLabel($0)).tag(Optional($0)) }
                    }
                    Picker("Target form", selection: Binding(get: { viewModel.state.formID }, set: { viewModel.send(.formID($0)) })) {
                        Text("All forms").tag(String?.none)
                        ForEach(ConjugationPolicy.forms, id: \.self) { Text(ConjugationPolicy.formLabel($0)).tag(Optional($0)) }
                    }
                    Picker("Questions", selection: Binding(get: { viewModel.state.limit }, set: { viewModel.send(.limit($0)) })) {
                        Text("5").tag(Optional(5)); Text("10").tag(Optional(10)); Text("All").tag(Int?.none)
                    }
                }
                Section {
                    Text("\(viewModel.selected.count) questions selected · \(viewModel.candidates.count) available")
                    if viewModel.selected.isEmpty {
                        StateMessage(title: "No matching questions", message: "This word class and target form have no bundled questions. Choose another class or form.")
                    }
                    Button("Start practice") { viewModel.send(.start) }.buttonStyle(PrimaryButtonStyle()).disabled(viewModel.selected.isEmpty)
                    if let error = viewModel.state.startError { StateMessage(title: "Couldn't save session", message: error) }
                }
                Section("Original beginner practice") {
                    Text("Model-checked original content. Independent human language review is pending.")
                        .font(.footnote).foregroundStyle(Forest.inkMuted)
                }
            }
        }
        .scrollContentBackground(.hidden).background(Forest.canvas).foregroundStyle(Forest.ink)
        .navigationTitle("Conjugation")
        .onAppear { viewModel.send(.load) }
        .onChange(of: viewModel.state.startedKey) { _, key in
            if let key { router.push(.exerciseResume(key), hideNavBar: false) }
        }
    }
}
