import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Sound effect identifiers. Drop matching `sfx_<rawValue>` audio files
/// (.caf / .m4a / .mp3 / .wav) into Resources/Sounds and they play
/// automatically; until then every call is a silent no-op.
enum SoundEffect: String, CaseIterable {
    case pop            // correct answer generic
    case bonk           // wrong answer generic
    case slice          // word sliced
    case cannonFire     // ball launched
    case explosion      // target destroyed
    case stamp          // factory accepts a word
    case reject         // factory rejects a word
    case monsterHit     // monster takes damage
    case monsterRoar    // monster attacks back
    case comboUp        // combo milestone
    case levelUp
    case victory        // round complete
    case bossDefeat
}

/// Looping background tracks: `bgm_<rawValue>` files in Resources/Sounds.
enum MusicTrack: String {
    case menu   // home / menus
    case arena  // during gameplay
}

final class SoundManager {
    static let shared = SoundManager()

    /// Mirrors of the profile's persisted audio preferences — WordStore sets
    /// these on launch and whenever the user toggles them.
    var isSoundEnabled = true
    var isMusicEnabled = true {
        didSet {
            guard isMusicEnabled != oldValue else { return }
            if isMusicEnabled {
                if let track = currentTrack { playMusic(track) }
            } else {
                musicPlayer?.pause()
            }
        }
    }

    private static let extensions = ["caf", "m4a", "mp3", "wav"]

    #if canImport(AVFoundation)
    private var players: [SoundEffect: AVAudioPlayer] = [:]
    private var musicPlayer: AVAudioPlayer?
    #endif
    private var currentTrack: MusicTrack?
    private var sessionCategoryConfigured = false

    private init() {}

    /// App audio follows its own in-app toggles rather than the hardware
    /// silent switch. Reactivate on every playback request because calls and
    /// other interruptions can deactivate an already configured session.
    private func activateSession() {
        #if canImport(AVFoundation) && os(iOS)
        let session = AVAudioSession.sharedInstance()
        if !sessionCategoryConfigured {
            do {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                sessionCategoryConfigured = true
            } catch {
                #if DEBUG
                print("SoundManager: failed to configure audio session: \(error)")
                #endif
            }
        }
        do {
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("SoundManager: failed to activate audio session: \(error)")
            #endif
        }
        #endif
    }

    private func bundleURL(named name: String) -> URL? {
        for ext in Self.extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    // MARK: Sound effects

    func play(_ effect: SoundEffect) {
        guard isSoundEnabled else { return }
        #if canImport(AVFoundation)
        activateSession()
        if let player = players[effect] {
            player.currentTime = 0
            player.play()
            return
        }
        guard let url = bundleURL(named: "sfx_\(effect.rawValue)") else { return }
        if let player = try? AVAudioPlayer(contentsOf: url) {
            player.volume = 0.9
            players[effect] = player
            player.play()
        }
        #endif
    }

    // MARK: Background music

    /// Starts (or switches to) a looping background track. Remembers the
    /// request even while music is muted, so unmuting resumes correctly.
    func playMusic(_ track: MusicTrack) {
        let switching = currentTrack != track
        currentTrack = track
        guard isMusicEnabled else { return }
        #if canImport(AVFoundation)
        activateSession()
        if !switching, let player = musicPlayer {
            if !player.isPlaying { player.play() }
            return
        }
        musicPlayer?.stop()
        musicPlayer = nil
        guard let url = bundleURL(named: "bgm_\(track.rawValue)") else { return }
        if let player = try? AVAudioPlayer(contentsOf: url) {
            player.numberOfLoops = -1
            player.volume = 0.3
            musicPlayer = player
            player.play()
        }
        #endif
    }

    func stopMusic() {
        currentTrack = nil
        #if canImport(AVFoundation)
        musicPlayer?.stop()
        musicPlayer = nil
        #endif
    }
}
