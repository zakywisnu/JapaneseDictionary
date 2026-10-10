import SwiftUI

struct ExerciseSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: ExerciseSessionViewModel
    let title: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Forest.Space.xl) {
                    Text("Original beginner practice. Not official exam material or independently reviewed.")
                        .font(.footnote).foregroundStyle(Forest.inkMuted)
                    if viewModel.state.isLoading {
                        ProgressView("Opening your practice")
                    } else if viewModel.state.contentChanged {
                        StateMessage(title: "These questions have changed", message: "Your submitted answers remain in History. Start a new session to use the current questions.", actionTitle: "Start new session", action: { viewModel.send(.restart) })
                    } else if viewModel.state.hasInvalidContent {
                        StateMessage(title: "Couldn't open these exercises", message: "The bundled questions are incomplete. Return to Learning practice and choose another activity.")
                    } else if viewModel.state.total == 0 {
                        StateMessage(title: "No questions here", message: "Return to Learning practice and choose another activity.")
                    } else if viewModel.state.isComplete {
                        Text("Practice complete").font(.title2.bold())
                        Text("\(viewModel.state.correctCount) of \(viewModel.state.total) correct in this session.")
                        Text("This practice doesn't change your saved items or review dates.").font(.subheadline).foregroundStyle(Forest.inkMuted)
                        Button("Practice again") { viewModel.send(.restart) }.buttonStyle(PrimaryButtonStyle())
                    } else if let question = viewModel.current {
                        Text("Question \(viewModel.state.position + 1) of \(viewModel.state.total)")
                            .font(.subheadline).foregroundStyle(Forest.inkMuted).id("question")
                        Text(question.kind == .fillBlank ? "Choose what fills the blank" : "Choose one answer")
                            .font(.subheadline).foregroundStyle(Forest.inkMuted)
                        Text(question.prompt).font(.title3).fixedSize(horizontal: false, vertical: true)
                        VStack(spacing: Forest.Space.m) {
                            ForEach(question.choices.indices, id: \.self) { index in
                                Button { viewModel.send(.choose(index)) } label: {
                                    HStack(alignment: .top, spacing: Forest.Space.m) {
                                        Text(question.choices[index]).frame(maxWidth: .infinity, alignment: .leading)
                                        if viewModel.state.selectedIndex == index {
                                            Image(systemName: "checkmark").accessibilityHidden(true)
                                        }
                                    }
                                    .padding(Forest.Space.l).frame(minHeight: 44)
                                    .foregroundStyle(Forest.ink)
                                    .background(Forest.surface, in: RoundedRectangle(cornerRadius: Forest.Radius.card))
                                    .overlay { RoundedRectangle(cornerRadius: Forest.Radius.card).strokeBorder(Forest.line) }
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.state.selectedIndex != nil)
                                .accessibilityAddTraits(viewModel.state.selectedIndex == index ? .isSelected : [])
                            }
                        }
                        if viewModel.state.isRevealed, let selected = viewModel.state.selectedIndex {
                            VStack(alignment: .leading, spacing: Forest.Space.s) {
                                Text(selected == question.correctIndex ? "Correct" : "Answer: \(question.choices[question.correctIndex])")
                                    .font(.headline)
                                Text(question.explanation).fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityElement(children: .combine)
                            Button(viewModel.state.position + 1 == viewModel.state.total ? "Finish practice" : "Next") {
                                viewModel.send(.next)
                            }.buttonStyle(PrimaryButtonStyle())
                        }
                    }
                    if let message = viewModel.state.errorMessage {
                        StateMessage(title: "Practice unavailable", message: message, actionTitle: "Retry", action: { viewModel.send(.retry) })
                        Button("Exit practice") { dismiss() }.buttonStyle(.bordered)
                    }
                }
                .foregroundStyle(Forest.ink).padding(Forest.Space.l)
            }
            .onChange(of: viewModel.state.position) { _, _ in proxy.scrollTo("question", anchor: .top) }
            .onChange(of: viewModel.state.isComplete) { _, complete in
                if !complete { proxy.scrollTo("question", anchor: .top) }
            }
        }
        .onAppear { viewModel.send(.load) }
        .background(Forest.canvas)
        .toolbar(.visible, for: .navigationBar)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
