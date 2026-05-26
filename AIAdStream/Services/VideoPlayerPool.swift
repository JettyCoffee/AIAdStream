import Foundation
import AVFoundation

final class VideoPlayerPool {
    static let shared = VideoPlayerPool()

    private var availablePlayers: [AVPlayer] = []
    private var inUsePlayers: Set<AVPlayer> = []
    private let poolSize = Constants.videoPlayerPoolSize
    private let lock = NSLock()

    private init() {
        for _ in 0..<poolSize {
            let player = AVPlayer()
            player.isMuted = true
            availablePlayers.append(player)
        }
    }

    func dequeuePlayer() -> AVPlayer {
        lock.lock()
        defer { lock.unlock() }

        if let player = availablePlayers.first {
            availablePlayers.removeFirst()
            inUsePlayers.insert(player)
            return player
        }
        let player = AVPlayer()
        player.isMuted = true
        inUsePlayers.insert(player)
        return player
    }

    func recyclePlayer(_ player: AVPlayer) {
        lock.lock()
        defer { lock.unlock() }

        player.pause()
        player.replaceCurrentItem(with: nil)
        inUsePlayers.remove(player)
        if availablePlayers.count < poolSize {
            availablePlayers.append(player)
        }
    }

    func resetAll() {
        lock.lock()
        defer { lock.unlock() }

        for player in inUsePlayers {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        availablePlayers.append(contentsOf: inUsePlayers)
        inUsePlayers.removeAll()
    }
}
