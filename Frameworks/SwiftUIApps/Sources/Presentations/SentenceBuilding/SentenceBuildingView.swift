import SwiftUI
import DataKit
import CryptoKit

struct SentenceBuildingView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: SentenceBuildingViewModel
    let title: String
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Forest.Space.l) {
                if viewModel.state.isLoading {
                    ProgressView("Opening sentence practice")
                } else if viewModel.state.contentChanged {
                    StateMessage(title: "These sentences have changed", message: "Your submitted answers remain in History. Start again with the current examples.", actionTitle: "Start new session", action: { viewModel.send(.restart) })
                } else if viewModel.state.hasInvalidContent {
                    StateMessage(title: "Couldn't open sentence practice", message: "These questions are incomplete. Return to Practice and choose another activity.")
                } else if viewModel.state.total == 0 {
                    StateMessage(title: "No sentences here", message: "Return to Practice and choose another activity.")
                } else if viewModel.state.isComplete {
                    VStack(alignment: .leading, spacing: Forest.Space.m) {
                        Text("Practice complete").font(.title2.bold())
                        Text("\(viewModel.state.correctCount) of \(viewModel.state.total) matched a supplied order.")
                        Text("Your collection and review dates stay the same.").font(.subheadline).foregroundStyle(Forest.inkMuted)
                    }.forestStudyCard()
                } else if let question = viewModel.current, let metadata = question.metadata {
                    Text("Sentence \(viewModel.state.position + 1) of \(viewModel.state.total)").font(.subheadline).foregroundStyle(Forest.inkMuted)
                    Text(question.prompt).font(.title3).fixedSize(horizontal: false, vertical: true)
                    Text("Build a sentence with the predicate at the end. Tap a selected token to remove it.").font(.subheadline)
                    Text("Your order").font(.headline)
                    if viewModel.state.selectedIDs.isEmpty {
                        Text("Choose a token below.").foregroundStyle(Forest.inkMuted)
                    }
                    tokenGrid(viewModel.state.selectedIDs.compactMap { id in metadata.tokens.first { $0.id == id } }, selected: true)
                    HStack {
                        Button("Undo") { viewModel.send(.undo) }
                        Button("Clear") { viewModel.send(.clear) }
                    }.buttonStyle(.bordered).tint(Forest.ink).disabled(!viewModel.canEdit || viewModel.state.selectedIDs.isEmpty)
                    Text("Available tokens").font(.headline)
                    tokenGrid(shuffledTokens(metadata.tokens, seed: question.fingerprint).filter { !viewModel.state.selectedIDs.contains($0.id) }, selected: false)
                    if viewModel.state.isRevealed {
                        VStack(alignment: .leading, spacing: Forest.Space.s) {
                            Text(viewModel.state.outcome == .correct ? "Matches a supplied order" : "Compare with a supplied order").font(.headline)
                            if let order = metadata.acceptedOrders.first {
                                Text(order.compactMap { id in metadata.tokens.first { $0.id == id }?.text }.joined()).font(.headword(24, relativeTo: .title2)).fixedSize(horizontal: false, vertical: true)
                            }
                            Text(question.explanation)
                            Text("Other Japanese orders may be valid; this activity checks the supplied examples.").font(.footnote).foregroundStyle(Forest.inkMuted)
                        }.forestStudyCard()
                    }
                }
                DisclosureGroup("About these sentences") {
                    Text("Original beginner practice. Model-checked content; not independently reviewed.").font(.footnote).foregroundStyle(Forest.inkMuted).padding(.top, Forest.Space.s)
                }.tint(Forest.inkMuted)
                if let error = viewModel.state.errorMessage {
                    StateMessage(title: "Practice unavailable", message: error, actionTitle: "Retry", action: { viewModel.send(.retry) })
                    Button("Exit practice") { dismiss() }.buttonStyle(.bordered)
                }
            }.padding(Forest.Space.l).foregroundStyle(Forest.ink)
        }.id(viewModel.state.position).background(Forest.canvas).navigationTitle(title).navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if viewModel.state.errorMessage == nil && !viewModel.state.isLoading && !viewModel.state.contentChanged && !viewModel.state.hasInvalidContent && viewModel.state.total > 0 {
                    VStack(spacing: Forest.Space.s) {
                        if viewModel.state.isComplete {
                            Button("Back to practice") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                            Button("Practice again") { viewModel.send(.restart) }.buttonStyle(.plain).frame(minHeight: 44)
                        } else if viewModel.state.isRevealed {
                            Button(viewModel.state.position + 1 == viewModel.state.total ? "Finish practice" : "Next") { viewModel.send(.next) }.buttonStyle(PrimaryButtonStyle())
                        } else {
                            Button("Check") { viewModel.send(.check) }.buttonStyle(PrimaryButtonStyle()).disabled(!viewModel.canCheck)
                        }
                    }.padding(Forest.Space.l).background(Forest.canvas)
                }
            }
            .onAppear { viewModel.send(.load) }
    }
    private func shuffledTokens(_ tokens: [PracticeToken], seed: String) -> [PracticeToken] {
        tokens.sorted { left, right in
            let lhs = SHA256.hash(data: Data((seed + left.id).utf8))
            let rhs = SHA256.hash(data: Data((seed + right.id).utf8))
            return lhs.lexicographicallyPrecedes(rhs)
        }
    }
    private func tokenGrid(_ tokens: [PracticeToken], selected: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .leading)], alignment: .leading, spacing: Forest.Space.s) {
            ForEach(tokens, id: \.id) { token in
                Button { viewModel.send(selected ? .remove(token.id) : .append(token.id)) } label: {
                    Text(token.text).font(.headword(22, relativeTo: .title3)).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 44).padding(Forest.Space.s)
                }.buttonStyle(.bordered).tint(Forest.ink).disabled(!viewModel.canEdit)
                    .accessibilityLabel("\(selected ? "Remove" : "Add") \(token.text)")
            }
        }
    }
}
