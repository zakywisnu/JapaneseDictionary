import SwiftUI

struct ReviewSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var textSize
    var kind: StudyKind? = nil
    let items: [ReviewItem]
    var origin: ReviewOrigin = .collection
    let onStart: (ReviewSession) -> Void
    @AppStorage("contextualWordReviews") private var useSentenceContext = false
    @State private var selection = ReviewSelection(level: nil, limit: 20)

    private var noun: String { kind == .words ? "word" : kind == .kanji ? "kanji" : "item" }
    private var selected: [ReviewItem] { selection.selected(items) }

    private var selectionExplanation: String {
        var text = "Newest saved items come first. Search does not change this selection."
        if items.contains(where: { $0.compositeID.kind == .sentence }) { text += " Sentence levels come from their parent lessons." }
        return text
    }
    private var sizePicker: some View {
        Picker("Session size", selection: $selection.limit) {
            Text("10").tag(Int?.some(10))
            Text("20").tag(Int?.some(20))
            Text("All").tag(Int?.none)
        }.frame(minHeight: 44)
    }

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
                    }.forestStudyCard()
                    VStack(alignment: .leading, spacing: Forest.Space.s) {
                        Text("Session size").font(.headline)
                        if textSize.isAccessibilitySize { sizePicker.pickerStyle(.menu) }
                        else { sizePicker.pickerStyle(.segmented) }

                    }.forestStudyCard()
                    if !items.isEmpty && items.allSatisfy({ $0.compositeID.kind == .word }) {
                        VStack(alignment: .leading, spacing: Forest.Space.s) {
                            Toggle("Use sentence context", isOn: $useSentenceContext)
                            Text("Matching words use an original sentence prompt. Answers are self-rated.").font(.footnote).foregroundStyle(Forest.inkMuted)
                        }.forestStudyCard()
                    }
                    Text("\(selected.count) \(selected.count == 1 ? noun : noun.pluralNoun) selected")
                        .font(.headline)
                    Text(selectionExplanation)
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
                    let session = ReviewSession(useSentenceContext: useSentenceContext, kind: kind, items: selected, origin: origin)
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
