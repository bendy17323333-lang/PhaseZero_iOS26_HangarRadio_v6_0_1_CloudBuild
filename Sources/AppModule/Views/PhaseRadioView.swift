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
                    Group {
                        if compact {
                            HStack(alignment: .top, spacing: 12) {
                                nowPlayingPanel(compact: true)
                                    .frame(width: min(330, proxy.size.width * 0.42))
                                libraryPanel(compact: true)
                            }
                        } else {
                            HStack(alignment: .top, spacing: 18) {
                                nowPlayingPanel(compact: false)
                                    .frame(width: min(430, proxy.size.width * 0.40))
                                libraryPanel(compact: false)
                            }
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("相位电台")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Label(music.accessState.title, systemImage: music.accessState == .authorized ? "music.note.house.fill" : "music.note")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(music.accessState == .authorized ? .mint : .secondary)
                }
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

    private func nowPlayingPanel(compact: Bool) -> some View {
        GlassPanel(tint: .pink, cornerRadius: compact ? 22 : 30, padding: compact ? 13 : 19) {
            VStack(alignment: .leading, spacing: compact ? 9 : 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("APPLE MUSIC // PHASE RADIO")
                            .font(.system(size: compact ? 7 : 9, weight: .black, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(.pink)
                        Text("正在播放")
                            .font(compact ? .headline : .title3)
                            .fontWeight(.black)
                    }
                    Spacer()
                    if music.isLoadingLibrary { ProgressView().controlSize(.small) }
                }

                HStack(spacing: compact ? 10 : 14) {
                    PhaseArtworkView(music: music, size: compact ? 84 : 124)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(music.currentTitle)
                            .font(compact ? .subheadline.weight(.black) : .headline.weight(.black))
                            .lineLimit(2)
                        Text(music.currentSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Text(music.isPlaying ? "LIVE OUTPUT" : "SIGNAL PAUSED")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(music.isPlaying ? .mint : .secondary)
                    }
                }

                PhaseAudioVisualizer(
                    seed: music.currentTrackSeed,
                    playbackTime: music.playbackTime,
                    isPlaying: music.isPlaying,
                    tint: .cyan,
                    secondaryTint: .pink,
                    suspended: visualizerSuspended,
                    barCount: compact ? 22 : 34
                )
                .frame(height: compact ? 50 : 78)
                .padding(.horizontal, 7)
                .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

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
                    Button { music.skipPrevious() } label: {
                        Image(systemName: "backward.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)

                    Button { music.togglePlayback() } label: {
                        Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.pink)

                    Button { music.skipNext() } label: {
                        Image(systemName: "forward.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }

                if let error = music.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(3)
                }

                Toggle("Apple Music 播放时压低游戏合成音乐", isOn: $settings.duckGameMusicForAppleMusic)
                    .font(.caption)
            }
        }
    }

    private func libraryPanel(compact: Bool) -> some View {
        GlassPanel(tint: .cyan, cornerRadius: compact ? 22 : 30, padding: compact ? 13 : 19) {
            VStack(alignment: .leading, spacing: compact ? 9 : 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PERSONAL LIBRARY")
                            .font(.system(size: compact ? 7 : 9, weight: .black, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(.cyan)
                        Text("我的音乐库")
                            .font(compact ? .headline : .title3)
                            .fontWeight(.black)
                    }
                    Spacer()
                    Button {
                        Task { await music.loadLibrary() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.glass)
                    .disabled(music.accessState != .authorized || music.isLoadingLibrary)
                }

                if music.accessState != .authorized {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(music.accessState.title, systemImage: "music.note.house")
                            .font(.headline.weight(.bold))
                        Text(music.accessState.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            Task { await music.requestAccessAndLoad() }
                        } label: {
                            Label("连接 Apple Music", systemImage: "person.badge.key.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.cyan)
                        .disabled(music.accessState == .restricted || music.accessState == .unavailable)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    if !music.playlists.isEmpty {
                        Text("歌单")
                            .font(.caption.weight(.black))
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 8) {
                                ForEach(music.playlists) { playlist in
                                    Button {
                                        music.playPlaylist(id: playlist.id)
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
                                music.playSong(id: song.id)
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
                        Text("资料库没有返回歌曲。未订阅时，MusicKit 仍可读取已购买或已同步到设备的内容。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func format(_ value: TimeInterval) -> String {
        let total = max(0, Int(value))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private struct PhaseArtworkView: View {
    @ObservedObject var music: AppleMusicService
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(
                    AngularGradient(
                        colors: [.cyan.opacity(0.50), .purple.opacity(0.48), .pink.opacity(0.52), .cyan.opacity(0.50)],
                        center: .center
                    )
                )
            #if canImport(MusicKit)
            if let artwork = music.currentArtwork {
                ArtworkImage(artwork, width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
            } else {
                fallback
            }
            #else
            fallback
            #endif
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: .pink.opacity(0.28), radius: 18)
    }

    private var fallback: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.28), lineWidth: max(2, size * 0.035))
                .padding(size * 0.20)
            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: size * 0.12, height: size * 0.12)
            Image(systemName: "waveform")
                .font(.system(size: size * 0.23, weight: .black))
                .foregroundStyle(.white.opacity(0.72))
        }
    }
}
