import SwiftUI
import DomainKit

struct MemoryAidCard: View {
    let viewModel: MemoryAidViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Forest.Space.l) {
            Text("Help me remember")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if let suggestion = viewModel.state.suggestion {
                field("Explanation", text: suggestion.explanation)
                field("Memory tip", text: suggestion.mnemonic)
                Text("AI-generated suggestion. Check it against your study meaning.")
                    .font(.footnote)
                    .foregroundStyle(Forest.inkMuted)
                Text(viewModel.state.isSaved ? "Saved on this iPhone" : "Not saved")
                    .font(.subheadline)
                    .foregroundStyle(Forest.inkMuted)
            } else if viewModel.state.availability == .available {
                Text("Create a short explanation and memory tip using this word's meanings. Save it only if it helps you.")
                    .font(.subheadline)
                    .foregroundStyle(Forest.inkMuted)
            }

            if let error = viewModel.state.loadError {
                failure(error, action: "Try loading again", send: .load)
            }
            if let message = availabilityMessage {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Forest.inkMuted)
                neutralButton("Check availability", action: .refreshAvailability)
            }

            if viewModel.state.isGenerating {
                ProgressView("Creating a memory suggestion")
                    .font(.subheadline)
                    .tint(Forest.inkMuted)
                neutralButton("Cancel", action: .cancel)
            } else {
                if let error = viewModel.state.generationError {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(Forest.inkMuted)
                }
                neutralButton(
                    viewModel.state.generationError != nil ? "Try generating again" :
                        (viewModel.state.suggestion == nil ? "Help me remember" : "Regenerate"),
                    action: .generate
                )
                .disabled(!viewModel.state.canGenerate)
            }

            if let error = viewModel.state.saveError {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(Forest.inkMuted)
            }
            if viewModel.state.suggestion != nil && !viewModel.state.isSaved {
                Button(viewModel.state.saveError == nil ? "Save suggestion" : "Try saving again") {
                    Task { await viewModel.send(.save) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.state.isGenerating)
            }
        }
        .foregroundStyle(Forest.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Forest.Space.l)
        .background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
    }

    private func field(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: Forest.Space.xs) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Forest.inkMuted)
            Text(text)
                .font(.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func neutralButton(_ title: String, action: MemoryAidViewModel.Action) -> some View {
        Button { Task { await viewModel.send(action) } } label: {
            Text(title)
                .font(.body)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Forest.ink)
        .background(Forest.sunken, in: .rect(cornerRadius: Forest.Radius.card))
    }

    private func failure(_ text: String, action: String, send: MemoryAidViewModel.Action) -> some View {
        VStack(alignment: .leading, spacing: Forest.Space.s) {
            Text(text).font(.subheadline).foregroundStyle(Forest.inkMuted)
            neutralButton(action, action: send)
        }
    }

    private var availabilityMessage: String? {
        switch viewModel.state.availability {
        case .available: return nil
        case .requiresNewerOS: return "Creating suggestions requires iOS 26 or later and an iPhone that supports Apple Intelligence. Saved suggestions remain available."
        case .deviceNotEligible: return "This iPhone doesn't support the Apple Intelligence model used for suggestions. Saved suggestions remain available."
        case .notEnabled: return "Turn on Apple Intelligence in Settings to create suggestions, then check availability here."
        case .modelNotReady: return "Apple Intelligence is preparing its model. Try checking availability again when it's ready."
        case .unsupportedLanguage: return "The on-device model doesn't currently support the Japanese and English used by this helper. Check your Apple Intelligence language in Settings."
        case .unavailable: return "The on-device model is unavailable. Check availability and try again later. Saved suggestions remain available."
        }
    }
}
