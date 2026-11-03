import SwiftUI
import AVKit
import AVFoundation

// MARK: - 视频

struct VideoPage: View {

    let url: URL
    let isActive: Bool

    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView().tint(.white)
            }
        }
        .onAppear {
            if player == nil {
                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
                player = AVPlayer(url: url)
            }
        }
        .onDisappear { player?.pause() }
        .onChange(of: isActive) { _, active in
            if !active { player?.pause() }
        }
    }
}

// MARK: - 音频

final class AudioPlayerModel: ObservableObject {

    @Published var isPlaying = false
    @Published var current: Double = 0
    @Published var duration: Double = 0

    let player: AVPlayer
    private var observer: Any?
    private var isScrubbing = false

    init(url: URL) {
        player = AVPlayer(url: url)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)

        observer = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.3, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            if !self.isScrubbing {
                let seconds = time.seconds
                self.current = seconds.isFinite ? seconds : 0
            }
            if let total = self.player.currentItem?.duration.seconds, total.isFinite, total > 0 {
                self.duration = total
            }
        }
    }

    deinit {
        if let observer { player.removeTimeObserver(observer) }
    }

    func toggle() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func seek(to value: Double) {
        let time = CMTime(seconds: max(0, value), preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        current = value
    }

    func skip(_ delta: Double) {
        seek(to: min(max(current + delta, 0), max(duration, 0)))
    }

    func setScrubbing(_ value: Bool) {
        isScrubbing = value
    }
}

struct AudioPage: View {

    let url: URL
    let isActive: Bool

    @StateObject private var model: AudioPlayerModel

    init(url: URL, isActive: Bool) {
        self.url = url
        self.isActive = isActive
        _model = StateObject(wrappedValue: AudioPlayerModel(url: url))
    }

    var body: some View {
        VStack(spacing: 26) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.elevatedHi, Theme.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 190, height: 190)
                Image(systemName: "waveform")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(Theme.textSecondary)
                Circle()
                    .strokeBorder(Theme.stroke, lineWidth: 1)
                    .frame(width: 190, height: 190)
            }

            VStack(spacing: 6) {
                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(url.pathExtension.uppercased() + " · " + Fmt.size(Int64(fileSize)))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 28)

            VStack(spacing: 6) {
                Slider(
                    value: $model.current,
                    in: 0...max(model.duration, 1),
                    onEditingChanged: { editing in
                        model.setScrubbing(editing)
                        if !editing { model.seek(to: model.current) }
                    }
                )
                .tint(Theme.accent)

                HStack {
                    Text(timeText(model.current))
                    Spacer()
                    Text("-" + timeText(max(model.duration - model.current, 0)))
                }
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 32)

            HStack(spacing: 36) {
                Button { model.skip(-15) } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)

                Button { model.toggle() } label: {
                    ZStack {
                        Circle().fill(Theme.text).frame(width: 64, height: 64)
                        Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.black)
                            .offset(x: model.isPlaying ? 0 : 2)
                    }
                }
                .buttonStyle(PressableStyle())

                Button { model.skip(15) } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear { model.pause() }
        .onChange(of: isActive) { _, active in
            if !active { model.pause() }
        }
    }

    private var fileSize: Int64 {
        Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
    }

    private func timeText(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        if m >= 60 {
            return String(format: "%d:%02d:%02d", m / 60, m % 60, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
