import Foundation
import MediaPlayer
import MusicKit
import AppIntents

/// SPIKE (#29, capture-wave slice S1) — REMOVE AFTER THE SPIKE IS CONFIRMED.
///
/// Answers the media-context ADR's open question: can Jackdaw read the current
/// Apple Music item (a) in the foreground, and (b) from a no-launch App Intent
/// while the app is backgrounded or terminated? Ships via TestFlight on the
/// merge-then-revert route (no local Xcode); the owner reads the probe strings
/// off the device and the findings land in the media-context ADR.
///
/// Reads BOTH public routes so one round-trip yields maximum signal:
/// MediaPlayer (`MPMusicPlayerController.systemMusicPlayer`) and MusicKit
/// (`SystemMusicPlayer.shared.queue.currentEntry`).
enum NowPlayingProbe {
    /// One-shot snapshot of everything the platform will tell us right now.
    /// `@MainActor`: `MPMusicPlayerController` is main-thread-only.
    @MainActor
    static func snapshot() -> String {
        let player = MPMusicPlayerController.systemMusicPlayer
        let mpItem: String
        if let now = player.nowPlayingItem {
            mpItem = "\(now.title ?? "untitled") — \(now.artist ?? "unknown artist")"
        } else {
            mpItem = "nil"
        }
        let mkEntry = SystemMusicPlayer.shared.queue.currentEntry?.title ?? "nil"
        return """
        MP auth: \(describe(MPMediaLibrary.authorizationStatus()))
        MP state: \(describe(player.playbackState))
        MP item: \(mpItem)
        MK auth: \(String(describing: MusicAuthorization.currentStatus))
        MK entry: \(mkEntry)
        """
    }

    /// Foreground path only: prompt for both authorizations (first run), then
    /// snapshot. The no-launch intent never calls this — a background intent
    /// cannot present a permission prompt.
    @MainActor
    static func authorizeAndSnapshot() async -> String {
        _ = await withCheckedContinuation { (cont: CheckedContinuation<MPMediaLibraryAuthorizationStatus, Never>) in
            MPMediaLibrary.requestAuthorization { cont.resume(returning: $0) }
        }
        _ = await MusicAuthorization.request()
        return snapshot()
    }

    private static func describe(_ status: MPMediaLibraryAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        @unknown default: return "unknown"
        }
    }

    private static func describe(_ state: MPMusicPlaybackState) -> String {
        switch state {
        case .playing: return "playing"
        case .paused: return "paused"
        case .stopped: return "stopped"
        case .interrupted: return "interrupted"
        case .seekingForward: return "seekingForward"
        case .seekingBackward: return "seekingBackward"
        @unknown default: return "unknown"
        }
    }
}

/// The no-launch half of the spike: run from Shortcuts / the Action button
/// WITHOUT opening Jackdaw. Reports the same snapshot via the result dialog.
/// Run it twice on-device: with Jackdaw freshly backgrounded (warm), and after
/// force-quitting Jackdaw (cold) — prior reports suggest the two differ.
struct NowPlayingProbeIntent: AppIntent {
    static let title: LocalizedStringResource = "Probe Now Playing"
    static let description = IntentDescription(
        "Spike #29: reports what Jackdaw can see of the current Apple Music item without launching the app."
    )
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let report = NowPlayingProbe.snapshot()
        return .result(dialog: "No-launch probe — \(report)")
    }
}
