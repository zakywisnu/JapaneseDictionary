import DomainKit
import SwiftUI

struct SpeakingView: View {
    @State var viewModel: SpeakingViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Forest.Space.l) {
                VStack(alignment: .leading, spacing: Forest.Space.m) {
                    Text(viewModel.target.prompt).font(.headword(28)).foregroundStyle(Forest.ink)
                        .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                    Text(viewModel.target.suppliedReading).font(.body).foregroundStyle(Forest.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    if viewModel.state.phase != .recording && viewModel.state.phase != .requestingPermission && viewModel.state.phase != .comparing {
                        PronunciationControl(reading: viewModel.target.suppliedReading, service: viewModel.pronunciation)
                    }
                }.padding(Forest.Space.l).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Forest.surface, in: RoundedRectangle(cornerRadius: Forest.Radius.card))
                availabilityMessage
                captureControls
                if let error = viewModel.state.error {
                    StateMessage(title: "Speaking check unavailable", message: error)
                }
                if let result = viewModel.state.comparison {
                    comparisonCard(result)
                    explanationControls
                }
                Text("Recognition matching does not assess pitch accent or pronunciation accuracy. Recordings stay temporarily on this iPhone and are deleted when you leave or try again.")
                    .font(.footnote).foregroundStyle(Forest.inkMuted).fixedSize(horizontal: false, vertical: true)
            }.padding(Forest.Space.l)
        }
        .background(Forest.canvas).navigationTitle("Speaking practice").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onDisappear { viewModel.send(.exit) }
        .onChange(of: scenePhase) { _, phase in viewModel.send(.sceneChanged(phase)) }
    }

    @ViewBuilder private var availabilityMessage: some View {
        switch viewModel.state.availability {
        case .supported:
            if !viewModel.canRecord {
                StateMessage(title: "Supplied reading needed", message: "This item has no playable kana reading. Return and choose an item with a supplied reading.")
            } else if viewModel.target.isIsolatedSound {
                Text("Isolated sounds offer listen and replay practice. A recognized sound cannot give a reliable phrase verdict.")
                    .font(.subheadline).foregroundStyle(Forest.inkMuted)
            }
        case .localRecognitionUnavailable:
            StateMessage(title: "Japanese recognition unavailable", message: "On-device Japanese recognition is unavailable. You can still listen to the example.", actionTitle: "Check again", action: { viewModel.send(.retry) })
        case .microphoneDenied:
            StateMessage(title: "Microphone access needed", message: "Allow microphone access for this app in Settings, then return and try Record again.", actionTitle: "Check again", action: { viewModel.send(.retry) })
        case .speechDenied:
            StateMessage(title: "Speech recognition access needed", message: "Allow speech recognition for this app in Settings, then return and try Record again.", actionTitle: "Check again", action: { viewModel.send(.retry) })
        }
    }

    @ViewBuilder private var captureControls: some View {
        switch viewModel.state.phase {
        case .ready:
            Button("Record") { viewModel.send(.record) }.buttonStyle(PrimaryButtonStyle()).disabled(!viewModel.canRecord)
        case .requestingPermission:
            ProgressView("Requesting recording access")
            Button("Cancel") { viewModel.send(.retry) }.buttonStyle(.bordered).frame(minHeight: 44)
        case .recording:
            Text("Recording, up to 15 seconds").font(.subheadline).foregroundStyle(Forest.ink)
            Button("Stop recording") { viewModel.send(.stop) }.buttonStyle(PrimaryButtonStyle())
        case .comparing:
            ProgressView("Recognizing your phrase on this iPhone")
            Button("Cancel") { viewModel.send(.cancelComparison) }.buttonStyle(.bordered).frame(minHeight: 44)
        case .recorded:
            if viewModel.state.recording == nil { ProgressView("Keeping your recording") }
            else {
                Button("Replay my recording") { viewModel.send(.replay) }.buttonStyle(.bordered).frame(minHeight: 44)
                if viewModel.state.comparison == nil {
                    Button("Compare recognized phrase") { viewModel.send(.compare) }.buttonStyle(PrimaryButtonStyle())
                }
                Button("Try again") { viewModel.send(.retry) }.buttonStyle(.bordered).frame(minHeight: 44)
            }
        }
    }

    private func comparisonCard(_ result: SpeakingComparisonResult) -> some View {
        VStack(alignment: .leading, spacing: Forest.Space.m) {
            Text(result.outcome == .match ? "Expected phrase heard" : result.outcome == .different ? "Different phrase heard" : "Inconclusive phrase evidence").font(.headline)
            Text("Expected").font(.caption).foregroundStyle(Forest.inkMuted)
            Text(result.expected).font(.body).textSelection(.enabled)
            Text("Recognized").font(.caption).foregroundStyle(Forest.inkMuted)
            Text(result.recognized.isEmpty ? "No final phrase" : result.recognized).font(.body).textSelection(.enabled)
            Text(result.reason).font(.subheadline)
        }.foregroundStyle(Forest.ink).fixedSize(horizontal: false, vertical: true)
            .padding(Forest.Space.l).frame(maxWidth: .infinity, alignment: .leading)
            .background(Forest.surface, in: RoundedRectangle(cornerRadius: Forest.Radius.card))
    }

    @ViewBuilder private var explanationControls: some View {
        if viewModel.state.isExplaining {
            ProgressView("Explaining the transcript comparison")
            Button("Cancel explanation") { viewModel.send(.cancelExplanation) }.buttonStyle(.bordered).frame(minHeight: 44)
        } else if viewModel.explanationAvailability == .available {
            Button("Explain this result") { viewModel.send(.explain) }.buttonStyle(.bordered).frame(minHeight: 44)
        } else {
            Text(explanationUnavailable).font(.footnote).foregroundStyle(Forest.inkMuted)
        }
        if let feedback = viewModel.state.explanation {
            VStack(alignment: .leading, spacing: Forest.Space.m) {
                Text("Explanation").font(.headline)
                Text(feedback.explanation)
                Text("Practice tip").font(.headline)
                Text(feedback.practiceTip)
                Text("AI-selected suggestion. Based only on transcript evidence.").font(.footnote).foregroundStyle(Forest.inkMuted)
            }.foregroundStyle(Forest.ink).fixedSize(horizontal: false, vertical: true)
        }
        if let error = viewModel.state.explanationError { Text(error).font(.subheadline).foregroundStyle(Forest.inkMuted) }
    }

    private var explanationUnavailable: String {
        switch viewModel.explanationAvailability {
        case .requiresNewerOS: return "Optional explanations need iOS 26 or later. The transcript comparison is available."
        case .deviceNotEligible: return "This iPhone doesn't support optional Apple Intelligence explanations."
        case .notEnabled: return "Enable Apple Intelligence in Settings to use optional explanations."
        case .modelNotReady: return "Apple Intelligence isn't ready. Try the optional explanation later."
        case .unsupportedLanguage: return "The optional model doesn't support the required Japanese and English languages."
        case .unavailable: return "Optional explanations are unavailable. The transcript comparison is available."
        case .available: return ""
        }
    }
}
