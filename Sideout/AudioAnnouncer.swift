import AVFoundation
import SideoutEngine

/// Speaks from pre-rendered audio clips played in sequence — the vocabulary
/// is closed (numbers 0-25 plus a handful of words), so callouts cannot be
/// arbitrary sentences. Clips are expected at
/// `AudioClips/<clipName>.caf` in the app bundle; see the README for how
/// to record and add them (they are not included with this scaffold).
@MainActor
final class AudioAnnouncer {
    private var player: AVQueuePlayer?
    var volume: Float = 1.0

    func speak(_ clips: [SpokenClip]) {
        stop()
        guard !clips.isEmpty else { return }
        let urls = clips.compactMap { clip in
            Bundle.main.url(forResource: clip.clipName, withExtension: "caf", subdirectory: "AudioClips")
        }
        guard urls.count == clips.count else { return } // missing clip(s); stay silent rather than guess
        let items = urls.map { AVPlayerItem(url: $0) }
        let queue = AVQueuePlayer(items: items)
        queue.volume = volume
        queue.play()
        player = queue
    }

    func stop() {
        player?.removeAllItems()
        player = nil
    }
}
