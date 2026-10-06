import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: ReviewViewModel

    init(viewModel: ReviewViewModel) {
        self.viewModel = viewModel
    }

    private var session: ReviewSession { viewModel.state.session }

    var body: some View {
        ScrollView {
            VStack(spacing: Forest.Space.xl) {
                if session.items.isEmpty {
                    StateMessage(
                        title: "No \(session.nouns) to review",
                        message: "Add an item on Today to begin."
                    )
                } else if viewModel.state.isComplete {
                    StateMessage(
                        title: "Review complete",
                        message: "You've gone through \(session.items.count) \(session.items.count == 1 ? session.noun : session.nouns) added today."
                    )
                } else if let item = viewModel.state.currentItem {
                    Text("\(session.noun.capitalized) \(viewModel.state.index + 1) of \(session.items.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Forest.inkMuted)
                    specimen(item)
                    if viewModel.state.isAnswerVisible {
                        answer(item)
                            .transition(.opacity)
                    } else {
                        Text("Try the reading and meaning.")
                            .font(.subheadline)
                            .foregroundStyle(Forest.inkMuted)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Forest.Space.l)
        }
        .id(viewModel.state.isComplete ? -1 : viewModel.state.index)
        .background(Forest.canvas)
        .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        .navigationTitle("Review \(session.nouns)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: viewModel.state.isAnswerVisible)
    }

    private func specimen(_ item: ReviewItem) -> some View {
        VStack(spacing: Forest.Space.m) {
            ViewThatFits(in: .horizontal) {
                ForEach([120, 96, 72, 56, 44] as [CGFloat], id: \.self) { size in
                    PracticeCells(text: item.headword, cellSize: size)
                }
                Text(item.headword)
                    .font(.headword(40, relativeTo: .largeTitle))
                    .foregroundStyle(Forest.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LevelTag(level: item.level)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Forest.Space.xl)
        .padding(.horizontal, Forest.Space.l)
        .background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
    }

    private func answer(_ item: ReviewItem) -> some View {
        VStack(spacing: Forest.Space.l) {
            if let reading = item.reading, !reading.isEmpty {
                Text(reading)
                    .font(.title3)
                    .foregroundStyle(Forest.inkMuted)
                    .textSelection(.enabled)
            }
            VStack(alignment: .leading, spacing: Forest.Space.l) {
                definition("Meanings", values: item.meanings.isEmpty ? ["No meaning is available for this item."] : item.meanings)
                if !item.onyomi.isEmpty { definition("On'yomi", values: item.onyomi) }
                if !item.kunyomi.isEmpty { definition("Kun'yomi", values: item.kunyomi) }
                if let strokes = item.strokes { definition("Strokes", values: ["\(strokes)"]) }
            }
            .padding(Forest.Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
        }
    }

    private func definition(_ title: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: Forest.Space.xs) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Forest.inkMuted)
            Text(values.joined(separator: ", "))
                .font(.body)
                .foregroundStyle(Forest.ink)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private var actions: some View {
        VStack(spacing: Forest.Space.s) {
            if session.items.isEmpty || viewModel.state.isComplete {
                Button("Back to Today") { router.pop() }
                    .buttonStyle(PrimaryButtonStyle())
                if viewModel.state.isComplete {
                    Button("Review again") { viewModel.send(.restart) }
                        .buttonStyle(.plain)
                        .foregroundStyle(Forest.inkMuted)
                        .frame(minHeight: 44)
                }
            } else {
                Button(primaryTitle) {
                    viewModel.send(viewModel.state.isAnswerVisible ? .next : .reveal)
                }
                .buttonStyle(PrimaryButtonStyle())
                if viewModel.state.canGoBack {
                    Button("Previous \(session.noun)") { viewModel.send(.previous) }
                        .buttonStyle(.plain)
                        .foregroundStyle(Forest.inkMuted)
                        .frame(minHeight: 44)
                }
            }
        }
        .padding(.horizontal, Forest.Space.l)
        .padding(.vertical, Forest.Space.m)
        .background(Forest.canvas)
    }

    private var primaryTitle: String {
        if !viewModel.state.isAnswerVisible { return "Reveal answer" }
        return viewModel.state.isLastItem ? "Finish review" : "Next \(session.noun)"
    }
}
