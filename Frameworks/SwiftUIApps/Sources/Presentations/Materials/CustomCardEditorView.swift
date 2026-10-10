import SwiftUI
import DataKit

struct CustomCardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: CustomCardEditorViewModel
    let onSaved: (StudyMaterial) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Your card") {
                    Text("Saved only on this iPhone.").font(.footnote).foregroundStyle(Forest.inkMuted)
                    field("Prompt", text: $viewModel.state.draft.prompt, limit: 500)
                    field("Answer", text: $viewModel.state.draft.answer, limit: 4_000)
                }.listRowBackground(Forest.surface)
                Section("Optional details") {
                    field("Kana reading", text: $viewModel.state.draft.reading, limit: 500)
                    Text("Listen uses only a supplied kana reading.").font(.footnote).foregroundStyle(Forest.inkMuted)
                    field("Notes", text: $viewModel.state.draft.notes, limit: 4_000)
                    Picker("Category", selection: $viewModel.state.draft.category) {
                        ForEach(["grammar", "sentence", "kana", "other"], id: \.self) { value in Text(value.capitalized).tag(value) }
                    }
                    Picker("JLPT level", selection: $viewModel.state.draft.level) {
                        Text("Unspecified").tag(String?.none)
                        ForEach(["N5", "N4", "N3", "N2", "N1"], id: \.self) { Text($0).tag(Optional($0)) }
                    }
                }.listRowBackground(Forest.surface)
                if let message = viewModel.state.errorMessage {
                    Section { Text(message).foregroundStyle(Forest.ink).fixedSize(horizontal: false, vertical: true) }.listRowBackground(Forest.surface)
                }
            }
            .scrollContentBackground(.hidden).background(Forest.canvas).tint(Forest.moss)
            .navigationTitle(viewModel.isEditing ? "Edit card" : "Create card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { viewModel.send(.save); finishIfSaved() } }
            }
            .confirmationDialog("Reset practice for this card?", isPresented: Binding(get: { viewModel.state.needsResetConfirmation }, set: { if !$0 { viewModel.send(.cancelConfirmation) } }), titleVisibility: .visible) {
                Button("Save and reset practice") { viewModel.send(.confirmSave); finishIfSaved() }
                Button("Cancel", role: .cancel) { viewModel.send(.cancelConfirmation) }
            } message: {
                Text("Changing the prompt, answer or reading clears this card's review date and difficult-item record. Past daily goal activity stays.")
            }
        }
    }
    private func field(_ title: String, text: Binding<String>, limit: Int) -> some View {
        VStack(alignment: .leading, spacing: Forest.Space.xs) {
            TextField(title, text: text, axis: .vertical).lineLimit(2...8)
            Text("\(text.wrappedValue.count) of \(limit) characters")
                .font(.caption).foregroundStyle(Forest.inkMuted)
        }
    }
    private func finishIfSaved() {
        if let saved = viewModel.state.savedMaterial { onSaved(saved); dismiss() }
    }
}
