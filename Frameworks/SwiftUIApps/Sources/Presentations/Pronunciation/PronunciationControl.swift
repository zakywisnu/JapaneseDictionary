import SwiftUI

struct PronunciationControl: View {
    let reading: String
    let service: PronunciationService
    var showsReading = false
    @State private var requestedID: UUID?

    private var isPlaying: Bool {
        requestedID != nil && requestedID == service.activeID && service.state == .playing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Forest.Space.xs) {
            if showsReading {
                Text(reading)
                    .font(.body)
                    .foregroundStyle(Forest.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            switch service.state {
            case .unavailable:
                Text("Japanese voice unavailable")
                    .font(.subheadline).foregroundStyle(Forest.ink)
                Text("This device has no available Japanese system voice.")
                    .font(.footnote).foregroundStyle(Forest.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Check again") { service.refreshAvailability() }
                    .buttonStyle(.plain).foregroundStyle(Forest.ink)
                    .frame(minHeight: 44)
            case let .failed(message):
                Text(message)
                    .font(.subheadline).foregroundStyle(Forest.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Try again") { listen() }
                    .buttonStyle(.plain).foregroundStyle(Forest.ink)
                    .frame(minHeight: 44)
            case .idle, .playing:
                Button(isPlaying ? "Stop" : "Listen", systemImage: isPlaying ? "stop.fill" : "speaker.wave.2") {
                    if isPlaying { service.stop() } else { listen() }
                }
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(Forest.ink)
                .frame(minHeight: 44)
            }
            Text("Synthesized speech")
                .font(.footnote).foregroundStyle(Forest.inkMuted)
        }
        .onChange(of: reading) { _, _ in
            if isPlaying { service.stop() }
            requestedID = nil
        }
        .onDisappear {
            if isPlaying { service.stop() }
        }
    }

    private func listen() {
        service.listen(reading: reading)
        requestedID = service.activeID
    }
}
