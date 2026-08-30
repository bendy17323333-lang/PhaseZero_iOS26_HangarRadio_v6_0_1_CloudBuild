import SwiftUI

#if canImport(MusicKit)
import MusicKit
#endif

struct PhaseRadioView: View {
    @ObservedObject var model: GameViewModel
    @ObservedObject private var music: AppleMusicService
    @ObservedObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var visualizerSuspended = false

    init(model: GameViewModel) {
        self.model = model
        self._music = ObservedObject(wrappedValue: model.appleMusic)
        self._settings = ObservedObject(wrappedValue: model.settings)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let compact = proxy.size.height < 520 || proxy.size.width < 780
                ScrollView {
                    HStack(alignment: .top, spacing: compact ? 12 : 18) {
                        nowPlayingPanel(compact: compact)
                            .frame(width: compact ? min(330, proxy.size.width * 0.42) : min(430, proxy.size.width * 0.40))
                        libraryPanel(compact: compact)
                    }
                    .padding(18)
                }
            }
            .navigationTitle("相位电台")
            .toolbar {
                // The old leading status label was rendered by iOS 26 as a
                // pressable glass control even though it had no action. Keep
                // status readouts inside the content and reserve the toolbar for
                // controls that actually do something.
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .buttonStyle(.glassProminent)
                }
            }
        }
        .presentationSizing(.page)
        .onAppear {
            music.startMonitoring()
            music.refreshAuthorizationState()
        }
        .onDisappear {
            model.flushSettingsChanges()
        }
    }

    private var showingAppleMusic: Bool {
        model.radioSource == .appleMusic
    }

    private var activeGameTrack: BuiltInSoundtrack {
        model.activeBuiltInSoundtrack
    }

    private var outputTitle: String {
        showingAppleMusic ? music.currentTitle : activeGameTrack.title
    }

    private var outputSubtitle: String {
        showingAppleMusic ? music.currentSubtitle : "\(activeGameTrack.subtitle) · \(activeGameTrack.tempoLabel)"
    }

    private var outputSeed: String {
        showingAppleMusic ? music.currentTrackSeed : "game|\(activeGameTrack.id)"
    }

    private var outputIsPlaying: Bool {
        showingAppleMusic ? music.isPlaying : model.isBuiltInSoundtrackAudible
    }

    private var primaryTint: Color {
        showingAppleMusic ? .pink : activeGameTrack.tint
    }

    private var secondaryTint: Color {
        showingAppleMusic ? .cyan : activeGameTrack.secondaryTint
    }

    private func nowPlayingPanel(compact: Bool) -> some View {
        GlassPanel(tint: primaryTint, cornerRadius: compact ? 22 : 30, padding: compact ? 13 : 19) {
            VStack(alignment: .leading, spacing: compact ? 9 : 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(showingAppleMusic ? "APPLE MUSIC // PHASE RADIO" : "PHASE ZERO OST // SYNTH CORE")
                            .font(.system(size: compact ? 7 : 9, weight: .black, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(primaryTint)
                        Text("正在播放")
                            .font(compact ? .headline : .title3)
                            .fontWeight(.black)
                    }
                    Spacer()
                    if music.isPreparingPlayback, showingAppleMusic {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(
                            showingAppleMusic ? "APPLE" : "GAME",
                            systemImage: showingAppleMusic ? "music.note" : "waveform.path.ecg"
                        )
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(primaryTint)
                    }
                }

                HStack(spacing: compact ? 10 : 14) {
                    RadioArtworkView(
                        source: model.radioSource,
                        music: music,
                        gameTrack: activeGameTrack,
                        size: compact ? 84 : 124
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(outputTitle)
                            .font(compact ? .subheadline.weight(.black) : .headline.weight(.black))
                            .lineLimit(2)
                        Text(outputSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Text(outputStatusText)
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(outputIsPlaying ? .mint : .secondary)
                    }
                }

                PhaseAudioVisualizer(
                    seed: outputSeed,
                    playbackTime: showingAppleMusic ? music.playbackTime : 0,
                    isPlaying: outputIsPlaying,
                    tint: secondaryTint,
                    secondaryTint: primaryTint,
                    suspended: visualizerSuspended,
                    barCount: compact ? 22 : 34
                )
                .frame(height: compact ? 50 : 78)
                .padding(.horizontal, 7)
                .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                if showingAppleMusic {
                    appleTransport(compact: compact)
                } else {
                    gameTransport(compact: compact)
                }

                if showingAppleMusic, let error = music.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(4)
                }

                Toggle("Apple Music 播放时压低游戏原声", isOn: $settings.duckGameMusicForAppleMusic)
                    .font(.caption)
            }
        }
    }

    private var outputStatusText: String {
        if showingAppleMusic {
            if music.isPreparingPlayback { return "QUEUE HANDOFF" }
            if music.isPlaying { return "LIVE OUTPUT" }
            if settings.gameMusicEnabled { return "APPLE PAUSED · GAME OST ACTIVE" }
            return "SIGNAL PAUSED"
        }
        return model.isBuiltInSoundtrackAudible ? "PROCEDURAL LOOP" : "GAME OST PAUSED"
    }

    @ViewBuilder
    private func appleTransport(compact: Bool) -> some View {
        DeferredSeekSlider(
            playbackTime: music.playbackTime,
            duration: music.duration,
            tint: .pink,
            onBegin: { music.beginScrubbing() },
            onCommit: { music.commitSeek(to: $0) },
            onCancel: { music.cancelScrubbing() },
            onEditingChanged: { visualizerSuspended = $0 }
        )

        HStack(spacing: 11) {
            Button { model.skipAppleMusicPrevious() } label: {
                Image(systemName: "backward.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)

            Button { model.toggleAppleMusicPlayback() } label: {
                Group {
                    if music.isPreparingPlayback {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(.pink)

            Button { model.skipAppleMusicNext() } label: {
                Image(systemName: "forward.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
        .disabled(music.isPreparingPlayback)
    }

    @ViewBuilder
    private func gameTransport(compact: Bool) -> some View {
        HStack {
            Label(activeGameTrack.tempoLabel, systemImage: "metronome")
            Spacer()
            Text("GENERATIVE LOOP")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(activeGameTrack.tint)

        HStack(spacing: 11) {
            Button { model.skipBuiltInSoundtrack(delta: -1) } label: {
                Image(systemName: "backward.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)

            Button { model.toggleBuiltInSoundtrack() } label: {
                Image(systemName: settings.gameMusicEnabled ? "pause.fill" : "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(activeGameTrack.tint)

            Button { model.skipBuiltInSoundtrack(delta: 1) } label: {
                Image(systemName: "forward.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
    }

    private func libraryPanel(compact: Bool) -> some View {
        GlassPanel(tint: .cyan, cornerRadius: compact ? 22 : 30, padding: compact ? 13 : 19) {
            VStack(alignment: .leading, spacing: compact ? 9 : 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("UNIFIED AUDIO LIBRARY")
                        .font(.system(size: compact ? 7 : 9, weight: .black, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(.cyan)
                    Text("音乐来源")
                        .font(compact ? .headline : .title3)
                        .fontWeight(.black)
                }

                gameSoundtrackLibrary(compact: compact)

                Divider().opacity(0.18)

                appleMusicLibrary(compact: compact)
            }
        }
    }

    @ViewBuilder
    private func gameSoundtrackLibrary(compact: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("游戏原声")
                    .font(.caption.weight(.black))
                Text("无需账户 · 程序合成 · 始终保留")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(settings.gameMusicEnabled ? "ON" : "OFF")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(settings.gameMusicEnabled ? .mint : .secondary)
        }

        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(BuiltInSoundtrack.all) { track in
                    Button {
                        model.selectBuiltInSoundtrack(track.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Image(systemName: track.systemImage)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(track.tint)
                                Spacer()
                                if settings.gameMusicTrackID == track.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.mint)
                                }
                            }
                            Text(track.title)
                                .font(.caption.weight(.black))
                                .lineLimit(1)
                            Text(track.subtitle)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text(track.tempoLabel)
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                                .foregroundStyle(track.tint)
                        }
                        .frame(width: compact ? 112 : 136, height: compact ? 76 : 92, alignment: .leading)
                        .padding(10)
                    }
                    .buttonStyle(.glass)
                    .tint(track.tint.opacity(0.30))
                }
            }
        }
    }

    @ViewBuilder
    private func appleMusicLibrary(compact: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Apple Music")
                    .font(.caption.weight(.black))
                Text(music.accessState.detail)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Label(
                music.accessState == .authorized ? "已连接" : music.accessState.title,
                systemImage: music.accessState == .authorized ? "checkmark.circle.fill" : "music.note"
            )
            .font(.system(size: 8, weight: .black))
            .foregroundStyle(music.accessState == .authorized ? .mint : .secondary)

            Button {
                Task { await music.loadLibrary() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.glass)
            .disabled(music.accessState != .authorized || music.isLoadingLibrary)
        }

        if music.accessState != .authorized {
            Button {
                Task { await music.requestAccessAndLoad() }
            } label: {
                Label("连接 Apple Music", systemImage: "person.badge.key.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(.pink)
            .disabled(music.accessState == .restricted || music.accessState == .unavailable)
        } else {
            if !music.playlists.isEmpty {
                Text("歌单")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(music.playlists) { playlist in
                            Button {
                                model.playAppleMusicPlaylist(id: playlist.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Image(systemName: "music.note.list")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(.pink)
                                    Text(playlist.name)
                                        .font(.caption.weight(.bold))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(width: compact ? 108 : 132, height: compact ? 68 : 82, alignment: .leading)
                                .padding(10)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                }
            }

            HStack {
                Text("资料库歌曲")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(music.songs.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            LazyVStack(spacing: 6) {
                ForEach(music.songs.prefix(compact ? 36 : 72)) { song in
                    Button {
                        model.playAppleMusicSong(id: song.id)
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(.white.opacity(0.06))
                                Image(systemName: "music.note")
                                    .foregroundStyle(.cyan)
                            }
                            .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(song.title)
                                    .font(.caption.weight(.bold))
                                    .lineLimit(1)
                                Text(song.artist)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if song.duration > 0 {
                                Text(format(song.duration))
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "play.fill")
                                .font(.caption2)
                                .foregroundStyle(.pink)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, compact ? 5 : 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            if music.songs.isEmpty, !music.isLoadingLibrary {
                Text("资料库没有返回歌曲。游戏原声仍可独立使用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func format(_ value: TimeInterval) -> String {
        let total = max(0, Int(value))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

struct RadioArtworkView: View {
    let source: PhaseRadioSource
    @ObservedObject var music: AppleMusicService
    let gameTrack: BuiltInSoundtrack
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(
                    AngularGradient(
                        colors: artworkColors,
                        center: .center
                    )
                )

            if source == .appleMusic {
                #if canImport(MusicKit)
                if let artwork = music.currentArtwork {
                    ArtworkImage(artwork, width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
                } else {
                    appleFallback
                }
                #else
                appleFallback
                #endif
            } else {
                gameFallback
            }
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: shadowTint.opacity(0.28), radius: 18)
    }

    private var artworkColors: [Color] {
        if source == .appleMusic {
            return [.cyan.opacity(0.50), .purple.opacity(0.48), .pink.opacity(0.52), .cyan.opacity(0.50)]
        }
        return [
            gameTrack.tint.opacity(0.56),
            gameTrack.secondaryTint.opacity(0.48),
            gameTrack.tint.opacity(0.38),
            gameTrack.secondaryTint.opacity(0.56)
        ]
    }

    private var shadowTint: Color {
        source == .appleMusic ? .pink : gameTrack.tint
    }

    private var appleFallback: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.28), lineWidth: max(2, size * 0.035))
                .padding(size * 0.20)
            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: size * 0.12, height: size * 0.12)
            Image(systemName: "music.note")
                .font(.system(size: size * 0.23, weight: .black))
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private var gameFallback: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(.white.opacity(0.16 + Double(index) * 0.05), lineWidth: 1)
                    .padding(size * (0.10 + CGFloat(index) * 0.10))
            }
            Image(systemName: gameTrack.systemImage)
                .font(.system(size: size * 0.28, weight: .black))
                .foregroundStyle(.white.opacity(0.86))
            Text(gameTrack.code)
                .font(.system(size: max(7, size * 0.065), weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.60))
                .offset(y: size * 0.32)
        }
    }
}
