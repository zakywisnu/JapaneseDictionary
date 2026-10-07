import SwiftUI
import DataKit

struct ReviewView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let examples: ExampleRepository
    @State private var viewModel: ReviewViewModel

    init(viewModel: ReviewViewModel, examples: ExampleRepository = .bundled()) {
        self.examples = examples
        self.viewModel = viewModel
    }

    private var session: ReviewSession { viewModel.state.session }

    var body: some View {
        ScrollView {
            VStack(spacing: Forest.Space.xl) {
                if session.items.isEmpty {
                    StateMessage(
                        title: "No \(session.nouns) to review",
                        message: session.origin.emptyMessage
                    )
                } else if viewModel.state.isComplete {
                    StateMessage(
                        title: "Review complete",
                        message: "You've gone through \(viewModel.state.distinctItemCount) \(viewModel.state.distinctItemCount == 1 ? session.noun : session.nouns) \(session.origin.completionContext)."
                    )
                    Text("\(viewModel.state.repeatAttempts) \(viewModel.state.repeatAttempts == 1 ? "repeat attempt" : "repeat attempts")")
                        .font(.subheadline)
                        .foregroundStyle(Forest.inkMuted)
                } else if let item = viewModel.state.currentItem {
                    Text("\(viewModel.state.remainingCount) remaining")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Forest.inkMuted)
                    specimen(item)
                    if viewModel.state.isAnswerVisible {
                        answer(item)
                            .transition(.opacity)
                        if let key = item.exampleWordKey, let example = examples.example(for: key) {
                            ExampleSentenceCard(example: example)
                        }
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
        .id(viewModel.state.presentationRevision)
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
                Button(session.origin.backTitle) { router.pop() }
                    .buttonStyle(PrimaryButtonStyle())
                if viewModel.state.isComplete && session.origin != .due {
                    Button("Review again") { viewModel.send(.restart) }
                        .buttonStyle(.plain)
                        .foregroundStyle(Forest.inkMuted)
                        .frame(minHeight: 44)
                }
            } else if let error = viewModel.state.saveError {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(Forest.ink)
                    .multilineTextAlignment(.center)
                Button("Retry") { viewModel.send(.retry) }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Exit review") { router.pop() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Forest.ink)
                    .frame(minHeight: 44)
            } else {
                if viewModel.state.isAnswerVisible {
                    Text("Again repeats this item in this session.")
                        .font(.footnote)
                        .foregroundStyle(Forest.inkMuted)
                        .multilineTextAlignment(.center)
                    Button("Got it") { viewModel.send(.rate(.gotIt)) }
                        .buttonStyle(PrimaryButtonStyle())
                    Button { viewModel.send(.rate(.again)) } label: {
                        Text("Again")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Forest.ink)
                } else {
                    Button("Reveal answer") { viewModel.send(.reveal) }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
        .padding(.horizontal, Forest.Space.l)
        .padding(.vertical, Forest.Space.m)
        .background(Forest.canvas)
    }

}
