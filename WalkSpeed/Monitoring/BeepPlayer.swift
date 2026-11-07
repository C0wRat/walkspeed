import AVFoundation
import os
import WalkSpeedCore

private let logger = Logger(subsystem: "com.c0wrat.walkspeed", category: "audio")

/// Plays the alert beeps over whatever else is playing, such as music or a
/// podcast.
///
/// The audio session is only active while a beep plays. When lowering other
/// audio is on, iOS ducks the music for the length of the beep and then brings
/// it back. The session is mixable, so it can start from the background.
@MainActor
final class BeepPlayer: NSObject {
    private let session = AVAudioSession.sharedInstance()
    private var players: [AlertLevel: AVAudioPlayer] = [:]
    private var sessionDucksOthers: Bool?

    override init() {
        super.init()
        for level in AlertLevel.allCases {
            do {
                let player = try AVAudioPlayer(
                    data: BeepSynthesizer.wavData(for: level),
                    fileTypeHint: AVFileType.wav.rawValue
                )
                player.delegate = self
                player.prepareToPlay()
                players[level] = player
            } catch {
                logger.error("Couldn't load the \(level.beepCount)-beep sound: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Plays a beep pattern, unless one is already playing.
    ///
    /// - Parameters:
    ///   - level: The pattern to play.
    ///   - volume: The beep volume from 0 to 1, relative to the media volume.
    ///   - lowersOtherAudio: Whether to duck other audio while the beep plays.
    func play(_ level: AlertLevel, volume: Double, lowersOtherAudio: Bool) {
        guard let player = players[level], !isPlaying else { return }
        do {
            try configureSession(ducksOthers: lowersOtherAudio)
            try session.setActive(true)
        } catch {
            logger.error("Couldn't start the audio session: \(error.localizedDescription, privacy: .public)")
            return
        }
        player.volume = Float(volume)
        player.currentTime = 0
        if !player.play() {
            logger.error("Couldn't play the \(level.beepCount)-beep sound")
            deactivateSession()
        }
    }

    private var isPlaying: Bool {
        players.values.contains { $0.isPlaying }
    }

    private func configureSession(ducksOthers: Bool) throws {
        guard sessionDucksOthers != ducksOthers else { return }
        let options: AVAudioSession.CategoryOptions = ducksOthers ? [.mixWithOthers, .duckOthers] : [.mixWithOthers]
        try session.setCategory(.playback, mode: .default, options: options)
        sessionDucksOthers = ducksOthers
    }

    fileprivate func playerDidFinish() {
        guard !isPlaying else { return }
        deactivateSession()
    }

    /// Ends the session and tells other apps they can raise their volume again.
    private func deactivateSession() {
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Couldn't end the audio session: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension BeepPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.playerDidFinish()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        Task { @MainActor in
            self.playerDidFinish()
        }
    }
}
