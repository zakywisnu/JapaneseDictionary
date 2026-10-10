import AVFoundation
import Foundation

@MainActor
final class AudioSessionCoordinator {
    enum Purpose { case playback, recording }
    static let shared = AudioSessionCoordinator()
    private var owner: (id: UUID, stop: () -> Void, deactivate: () -> Void)?
    private let activate: (Purpose) throws -> Void
    private let deactivate: () -> Void

    nonisolated static func isExternalRouteChange(_ notification: Notification) -> Bool {
        guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return false }
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable, .noSuitableRouteForCategory, .routeConfigurationChange: return true
        default: return false
        }
    }

    init(activate: @escaping (Purpose) throws -> Void = { purpose in
        let session = AVAudioSession.sharedInstance()
        switch purpose {
        case .playback: try session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        case .recording: try session.setCategory(.record, mode: .default)
        }
        try session.setActive(true)
    }, deactivate: @escaping () -> Void = {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }) {
        self.activate = activate
        self.deactivate = deactivate
    }

    func acquire(_ purpose: Purpose, activate overrideActivate: (() throws -> Void)? = nil, deactivate overrideDeactivate: (() -> Void)? = nil, stop: @escaping () -> Void) throws -> UUID {
        if let previous = owner { release(previous.id); previous.stop() }
        let id = UUID()
        do {
            if let overrideActivate { try overrideActivate() } else { try activate(purpose) }
        } catch { if overrideActivate == nil { deactivate() }; throw error }
        owner = (id, stop, overrideDeactivate ?? deactivate)
        return id
    }

    func release(_ id: UUID) {
        guard owner?.id == id else { return }
        let release = owner?.deactivate
        owner = nil
        release?()
    }
}
