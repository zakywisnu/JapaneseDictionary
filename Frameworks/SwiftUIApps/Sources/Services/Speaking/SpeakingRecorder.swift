import AVFoundation
import DomainKit
import Foundation
import Speech
import UIKit

enum SpeakingAvailability: Equatable { case supported, microphoneDenied, speechDenied, localRecognitionUnavailable }
enum SpeakingError: Error { case localRecognitionUnavailable, permissionDenied, recordingFailed, noRecording, noSpeech }
struct SpeakingRecording: Equatable {
    let id: UUID
    let temporaryURL: URL
    let duration: TimeInterval
}

@MainActor
protocol SpeakingServicing: AnyObject {
    var availability: SpeakingAvailability { get }
    func requestPermissions() async -> Bool
    func startRecording() throws
    func stopRecording() async throws -> SpeakingRecording
    func recognize(_ recording: SpeakingRecording) async throws -> SpeechRecognitionEvidence
    func replay(_ recording: SpeakingRecording) throws
    func cancelRecognition()
    func cancel()
}

@MainActor
final class SpeakingRecorder: NSObject, SpeakingServicing {
    private let recognition: any LocalSpeechRecognizing
    private let audio: AudioSessionCoordinator
    private let microphonePermission: () async -> Bool
    private let speechPermission: () async -> Bool
    private var permissionsGranted = false
    private var captureStarted: Date?
    private var permissionFailure: SpeakingAvailability?
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var lease: UUID?
    private var recording: SpeakingRecording?
    private var captureURL: URL?
    private var limitTask: Task<Void, Never>?
    private var replayTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var operationID = UUID()

    var availability: SpeakingAvailability {
        if !recognition.isAvailable { return .localRecognitionUnavailable }
        return permissionFailure ?? .supported
    }

    init(recognition: (any LocalSpeechRecognizing)? = nil, audio: AudioSessionCoordinator? = nil,
         microphonePermission: @escaping () async -> Bool = {
             await withCheckedContinuation { continuation in AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) } }
         }, speechPermission: @escaping () async -> Bool = {
             await withCheckedContinuation { continuation in SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) } }
         }) {
        self.recognition = recognition ?? OnDeviceSpeechRecognizer()
        self.audio = audio ?? .shared
        self.microphonePermission = microphonePermission
        self.speechPermission = speechPermission
        super.init()
        _ = SpeakingTemporaryFiles.cleanupAtLaunch
        for name in [UIApplication.didEnterBackgroundNotification, AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                if name == AVAudioSession.interruptionNotification {
                    guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                          AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
                }
                if name == AVAudioSession.routeChangeNotification, !AudioSessionCoordinator.isExternalRouteChange(notification) { return }
                MainActor.assumeIsolated { self?.cancel() }
            })
        }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        limitTask?.cancel()
        replayTask?.cancel()
        recorder?.stop()
        player?.stop()
        if let captureURL { try? FileManager.default.removeItem(at: captureURL) }
        if let recording { try? FileManager.default.removeItem(at: recording.temporaryURL) }
        let heldLease = lease
        let coordinator = audio
        let recognizer = recognition
        Task { @MainActor in
            recognizer.cancel()
            if let heldLease { coordinator.release(heldLease) }
        }
    }

    func requestPermissions() async -> Bool {
        guard recognition.isAvailable else { return false }
        let id = operationID
        guard await microphonePermission() else { if id == operationID { permissionFailure = .microphoneDenied }; return false }
        guard id == operationID else { return false }
        guard await speechPermission() else { if id == operationID { permissionFailure = .speechDenied }; return false }
        guard id == operationID else { return false }
        permissionFailure = nil
        permissionsGranted = true
        return true
    }

    func startRecording() throws {
        guard availability == .supported else { throw SpeakingError.localRecognitionUnavailable }
        guard permissionsGranted else { throw SpeakingError.permissionDenied }
        cancel()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(SpeakingTemporaryFiles.prefix + UUID().uuidString + ".m4a")
        captureURL = url
        do {
            lease = try audio.acquire(.recording) { [weak self] in self?.cancel() }
            let recorder = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue])
            self.recorder = recorder
            guard recorder.record(forDuration: 15) else { throw SpeakingError.recordingFailed }
            captureStarted = Date()
            let id = operationID
            limitTask = Task { @MainActor [weak self] in
                do { try await Task.sleep(nanoseconds: 15_000_000_000) } catch { return }
                guard let self, self.operationID == id else { return }
                _ = try? self.finishCapture()
            }
        } catch { cancel(); throw error }
    }

    func stopRecording() async throws -> SpeakingRecording { try finishCapture() }

    private func finishCapture() throws -> SpeakingRecording {
        if let recording { return recording }
        guard let recorder, let url = captureURL else { throw SpeakingError.noRecording }
        let duration = min(15, recorder.isRecording ? recorder.currentTime : Date().timeIntervalSince(captureStarted ?? Date()))
        recorder.stop()
        self.recorder = nil
        captureStarted = nil
        limitTask?.cancel()
        limitTask = nil
        releaseAudio()
        guard duration > 0, FileManager.default.fileExists(atPath: url.path) else { cancel(); throw SpeakingError.recordingFailed }
        let result = SpeakingRecording(id: UUID(), temporaryURL: url, duration: duration)
        recording = result
        captureURL = nil
        return result
    }

    func recognize(_ recording: SpeakingRecording) async throws -> SpeechRecognitionEvidence {
        guard self.recording?.id == recording.id else { throw SpeakingError.noRecording }
        let id = operationID
        let result = try await recognition.recognize(recording.temporaryURL)
        guard id == operationID, !Task.isCancelled else { throw CancellationError() }
        return result
    }

    func replay(_ recording: SpeakingRecording) throws {
        guard self.recording?.id == recording.id, recorder == nil else { throw SpeakingError.noRecording }
        player?.stop()
        replayTask?.cancel()
        releaseAudio()
        do {
            lease = try audio.acquire(.playback) { [weak self] in self?.stopReplay() }
            let player = try AVAudioPlayer(contentsOf: recording.temporaryURL)
            self.player = player
            guard player.play() else { throw SpeakingError.recordingFailed }
            let id = operationID
            replayTask = Task { @MainActor [weak self] in
                do { try await Task.sleep(nanoseconds: UInt64((player.duration + 0.1) * 1_000_000_000)) } catch { return }
                guard let self, self.operationID == id else { return }
                self.stopReplay()
            }
        } catch { stopReplay(); throw error }
    }

    func cancelRecognition() {
        operationID = UUID()
        recognition.cancel()
        stopReplay()
    }

    func cancel() {
        operationID = UUID()
        recognition.cancel()
        limitTask?.cancel()
        limitTask = nil
        recorder?.stop()
        recorder = nil
        captureStarted = nil
        stopReplay()
        if let captureURL { try? FileManager.default.removeItem(at: captureURL) }
        if let recording { try? FileManager.default.removeItem(at: recording.temporaryURL) }
        captureURL = nil
        recording = nil
    }

    private func stopReplay() {
        replayTask?.cancel()
        replayTask = nil
        player?.stop()
        player = nil
        releaseAudio()
    }
    private func releaseAudio() { if let lease { audio.release(lease) }; lease = nil }
}

enum SpeakingTemporaryFiles {
    static let prefix = "kotoba-speaking-"
    static let cleanupAtLaunch: Void = cleanAbandoned(in: FileManager.default.temporaryDirectory)

    static func cleanAbandoned(in directory: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for url in files where url.lastPathComponent.hasPrefix(prefix) && url.pathExtension == "m4a" { try? FileManager.default.removeItem(at: url) }
    }
}
