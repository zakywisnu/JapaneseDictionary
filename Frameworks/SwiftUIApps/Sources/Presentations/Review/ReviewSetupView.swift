import SwiftUI

struct ReviewSetupView: View {
    @Environment(\.dismiss) private var dismiss
    var kind: StudyKind? = nil
    let items: [ReviewItem]
    var origin: ReviewOrigin = .collection
    let onStart: (ReviewSession) -> Void
    @State private var selection = ReviewSelection(level: nil, limit: 20)

    private var noun: String { kind == .words ? "word" : kind == .kanji ? "kanji" : "item" }
    private var selected: [ReviewItem] { selection.selected(items) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Forest.Space.xl) {
                    VStack(alignment: .leading, spacing: Forest.Space.s) {
                        Text("Study level").font(.headline)
                        Picker("Study level", selection: $selection.level) {
                            Text("All levels").tag(String?.none)
                            Text("Unspecified").tag(String?.some(""))
                            ForEach(["N5", "N4", "N3", "N2", "N1"], id: \.self) { level in
                                Text(level).tag(String?.some(level))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(minHeight: 44)
                    }
                    VStack(alignment: .leading, spacing: Forest.Space.s) {
                        Text("Session size").font(.headline)
                        Picker("Session size", selection: $selection.limit) {
                            Text("10").tag(Int?.some(10))
                            Text("20").tag(Int?.some(20))
                            Text("All").tag(Int?.none)
                        }
                        .pickerStyle(.segmented)
                        .frame(minHeight: 44)
                    }
                    Text("\(selected.count) \(selected.count == 1 ? noun : noun.pluralNoun) selected")
                        .font(.headline)
                    Text("Review starts with your newest collected items. Sentence levels come from their parent lessons. Search does not change this selection.")
                        .font(.subheadline)
                        .foregroundStyle(Forest.inkMuted)
                    if selected.isEmpty {
                        StateMessage(title: "No \(noun.pluralNoun) at this level", message: "Choose another study level. \(origin.emptyMessage)")
                    }
                }
                .foregroundStyle(Forest.ink)
                .padding(Forest.Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Forest.canvas)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button("Start review") {
                    let session = ReviewSession(kind: kind, items: selected, origin: origin)
                    dismiss()
                    onStart(session)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selected.isEmpty)
                .padding(Forest.Space.l)
                .background(Forest.canvas)
            }
            .navigationTitle("Review \(noun.pluralNoun)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(Forest.moss)
    }
}
