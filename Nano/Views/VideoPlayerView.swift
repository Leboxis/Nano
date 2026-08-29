import SwiftUI
import AVKit
import AVFoundation

// MARK: - Interactive Video Player with Timeline Scrubber Bar

struct InteractiveVideoPlayerView: View {
    let url: URL
    let isCurrent: Bool

    @State private var player: AVPlayer? = nil
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 1
    @State private var isEditingSlider = false
    @State private var timeObserverToken: Any? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                CustomAVPlayerWrapper(player: player)
                    .ignoresSafeArea()
                    .onTapGesture {
                        togglePlayPause()
                    }

                // Play / Pause center indicator overlay
                if !isPlaying {
                    Button(action: togglePlayPause) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .padding(20)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                }

                // Bottom Timeline Scrubber Control Bar
                VStack {
                    Spacer()

                    VStack(spacing: 8) {
                        // Slider Scrubber to seek forward / backward
                        Slider(
                            value: Binding(
                                get: { currentTime },
                                set: { newValue in
                                    currentTime = newValue
                                    seekToTime(newValue)
                                }
                            ),
                            in: 0...max(1, duration),
                            onEditingChanged: { editing in
                                isEditingSlider = editing
                            }
                        )
                        .accentColor(.white)

                        // Time Labels
                        HStack {
                            Text(formatTime(currentTime))
                                .font(.system(size: 12, weight: .regular))
                                .monospacedDigit()
                                .foregroundColor(Color.white.opacity(0.8))

                            Spacer()

                            Text(formatTime(duration))
                                .font(.system(size: 12, weight: .regular))
                                .monospacedDigit()
                                .foregroundColor(Color.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .padding(.bottom, 24)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0.85), Color.black.opacity(0.0)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
        .onChange(of: isCurrent) { active in
            if active {
                player?.play()
                isPlaying = true
            } else {
                player?.pause()
                isPlaying = false
            }
        }
    }

    private func setupPlayer() {
        let avPlayer = AVPlayer(url: url)
        self.player = avPlayer

        // Track duration
        if let currentItem = avPlayer.currentItem {
            let asset = currentItem.asset
            Task {
                if let dur = try? await asset.load(.duration) {
                    let seconds = CMTimeGetSeconds(dur)
                    if !seconds.isNaN && seconds > 0 {
                        await MainActor.run {
                            self.duration = seconds
                        }
                    }
                }
            }
        }

        // Periodic time observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak avPlayer] time in
            guard avPlayer != nil else { return }
            if !isEditingSlider {
                let seconds = CMTimeGetSeconds(time)
                if !seconds.isNaN {
                    self.currentTime = seconds
                }
            }
        }

        if isCurrent {
            avPlayer.play()
            isPlaying = true
        }
    }

    private func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    private func seekToTime(_ seconds: Double) {
        guard let player = player else { return }
        let targetTime = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func cleanupPlayer() {
        if let token = timeObserverToken, let player = player {
            player.removeTimeObserver(token)
        }
        timeObserverToken = nil
        player?.pause()
        player = nil
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds >= 0 else { return "00:00" }
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

struct CustomAVPlayerWrapper: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> AVPlayerViewContainer {
        let container = AVPlayerViewContainer()
        container.playerLayer.player = player
        container.playerLayer.videoGravity = .resizeAspect
        return container
    }

    func updateUIView(_ uiView: AVPlayerViewContainer, context: Context) {
        uiView.playerLayer.player = player
    }
}

class AVPlayerViewContainer: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
