import Foundation
import Combine

#if canImport(MusicKit)
import MusicKit
#endif

enum AppleMusicAccessState: String, Equatable {
    case unavailable
    case notDetermined
    case denied
    case restricted
    case authorized
    case needsAppService

    var title: String {
        switch self {
        case .unavailable: return "MusicKit 不可用"
        case .notDetermined: return "尚未连接"
        case .denied: return "访问被拒绝"
        case .restricted: return "系统限制访问"
        case .authorized: return "Apple Music 已连接"
        case .needsAppService: return "需要 MusicKit App Service"
        }
    }

    var detail: String {
        switch self {
        case .unavailable:
            return "当前 SDK 没有 MusicKit 模块。"
        case .notDetermined:
            return "连接后可读取资料库歌曲与歌单，并在游戏内独立播放。"
        case .denied:
            return "请到系统设置中允许“零点相位”访问媒体资料库。"
        case .restricted:
            return "此设备的账户或家长控制限制了媒体资料库访问。"
        case .authorized:
            return "资料库已由系统授权，账号密码不会交给游戏。"
        case .needsAppService:
            return "当前签名的 App ID 尚未启用 MusicKit 服务，代码已经就位，证书部门还在履行其传统职责。"
        }
    }
}

struct AppleMusicSongSummary: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let duration: TimeInterval
}

struct AppleMusicPlaylistSummary: Identifiable, Equatable {
    let id: String
    let name: String
}

@MainActor
final class AppleMusicService: ObservableObject {
    @Published private(set) var accessState: AppleMusicAccessState = .notDetermined
    @Published private(set) var songs: [AppleMusicSongSummary] = []
    @Published private(set) var playlists: [AppleMusicPlaylistSummary] = []
    @Published private(set) var isLoadingLibrary = false
    @Published private(set) var isPlaying = false
    @Published private(set) var playbackTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var currentTitle = "相位电台待机"
    @Published private(set) var currentSubtitle = "连接 Apple Music 后选择一首曲目"
    @Published private(set) var currentTrackSeed = "phase-zero-idle"
    @Published private(set) var errorMessage: String?
    @Published private(set) var libraryLoaded = false

    #if canImport(MusicKit)
    @Published private(set) var currentArtwork: Artwork?
    private let player = ApplicationMusicPlayer.shared
    private var librarySongs: [Song] = []
    private var libraryPlaylists: [Playlist] = []
    #endif

    var onPlaybackActivityChanged: ((Bool) -> Void)?

    private var monitorTask: Task<Void, Never>?
    private var isScrubbing = false
    private var lastReportedPlaybackActivity = false
    private var lastEntryIdentity: String?

    init() {
        refreshAuthorizationState()
    }

    func bootstrap() {
        refreshAuthorizationState()
        startMonitoring()
        if accessState == .authorized, !libraryLoaded {
            Task { [weak self] in
                await self?.loadLibrary()
            }
        }
    }

    func refreshAuthorizationState() {
        #if canImport(MusicKit)
        switch MusicAuthorization.currentStatus {
        case .notDetermined:
            accessState = .notDetermined
        case .denied:
            accessState = .denied
        case .restricted:
            accessState = .restricted
        case .authorized:
            accessState = .authorized
        @unknown default:
            accessState = .unavailable
        }
        #else
        accessState = .unavailable
        #endif
    }

    func requestAccessAndLoad() async {
        errorMessage = nil
        #if canImport(MusicKit)
        let status = await MusicAuthorization.request()
        switch status {
        case .authorized:
            accessState = .authorized
            await loadLibrary()
        case .denied:
            accessState = .denied
        case .restricted:
            accessState = .restricted
        case .notDetermined:
            accessState = .notDetermined
        @unknown default:
            accessState = .unavailable
        }
        #else
        accessState = .unavailable
        #endif
    }

    func loadLibrary() async {
        guard accessState == .authorized else { return }
        guard !isLoadingLibrary else { return }
        isLoadingLibrary = true
        errorMessage = nil
        defer { isLoadingLibrary = false }

        #if canImport(MusicKit)
        do {
            async let songResponse = MusicLibraryRequest<Song>().response()
            async let playlistResponse = MusicLibraryRequest<Playlist>().response()
            let (loadedSongs, loadedPlaylists) = try await (songResponse, playlistResponse)

            librarySongs = Array(loadedSongs.items.prefix(180))
            libraryPlaylists = Array(loadedPlaylists.items.prefix(60))

            songs = librarySongs.map { song in
                AppleMusicSongSummary(
                    id: String(describing: song.id),
                    title: song.title,
                    artist: song.artistName,
                    duration: song.duration ?? 0
                )
            }
            playlists = libraryPlaylists.map { playlist in
                AppleMusicPlaylistSummary(
                    id: String(describing: playlist.id),
                    name: playlist.name
                )
            }
            libraryLoaded = true
        } catch {
            handleMusicKitError(error)
        }
        #endif
    }

    func playSong(id: String) {
        #if canImport(MusicKit)
        guard let song = librarySongs.first(where: { String(describing: $0.id) == id }) else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let queue = ApplicationMusicPlayer.Queue(for: [song])
                self.player.queue = queue
                self.duration = song.duration ?? 0
                self.currentTitle = song.title
                self.currentSubtitle = song.artistName
                self.currentTrackSeed = "\(song.title)|\(song.artistName)"
                self.currentArtwork = song.artwork
                try await self.player.prepareToPlay()
                try await self.player.play()
                self.refreshPlaybackSnapshot()
            } catch {
                self.handleMusicKitError(error)
            }
        }
        #endif
    }

    func playPlaylist(id: String) {
        #if canImport(MusicKit)
        guard let playlist = libraryPlaylists.first(where: { String(describing: $0.id) == id }) else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let resolvedPlaylist = try await playlist.with([.entries], preferredSource: .library)
                guard let entries = resolvedPlaylist.entries, let firstEntry = entries.first else {
                    self.errorMessage = "这个歌单没有返回可播放曲目。"
                    return
                }
                let queue = ApplicationMusicPlayer.Queue(
                    playlist: resolvedPlaylist,
                    startingAt: firstEntry
                )
                self.player.queue = queue
                self.duration = 0
                self.currentTitle = resolvedPlaylist.name
                self.currentSubtitle = "Apple Music 资料库歌单"
                self.currentTrackSeed = "playlist|\(resolvedPlaylist.name)"
                self.currentArtwork = resolvedPlaylist.artwork
                try await self.player.prepareToPlay()
                try await self.player.play()
                self.refreshPlaybackSnapshot()
            } catch {
                self.handleMusicKitError(error)
            }
        }
        #endif
    }

    func togglePlayback() {
        #if canImport(MusicKit)
        if isPlaying {
            player.pause()
            refreshPlaybackSnapshot()
        } else {
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.player.play()
                    self.refreshPlaybackSnapshot()
                } catch {
                    self.handleMusicKitError(error)
                }
            }
        }
        #endif
    }

    func skipNext() {
        #if canImport(MusicKit)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.player.skipToNextEntry()
                try? await Task.sleep(nanoseconds: 140_000_000)
                self.refreshPlaybackSnapshot()
            } catch {
                self.handleMusicKitError(error)
            }
        }
        #endif
    }

    func skipPrevious() {
        #if canImport(MusicKit)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.player.skipToPreviousEntry()
                try? await Task.sleep(nanoseconds: 140_000_000)
                self.refreshPlaybackSnapshot()
            } catch {
                self.handleMusicKitError(error)
            }
        }
        #endif
    }

    func beginScrubbing() {
        isScrubbing = true
    }

    func commitSeek(to value: TimeInterval) {
        #if canImport(MusicKit)
        let upper = duration > 0 ? duration : max(value, 0)
        player.playbackTime = min(max(value, 0), upper)
        playbackTime = player.playbackTime
        #endif
        isScrubbing = false
    }

    func cancelScrubbing() {
        isScrubbing = false
        refreshPlaybackSnapshot()
    }

    func refreshPlaybackSnapshot() {
        #if canImport(MusicKit)
        let active = player.state.playbackStatus == .playing
        if active != isPlaying { isPlaying = active }
        reportPlaybackActivityIfNeeded(active)

        if !isScrubbing {
            playbackTime = max(0, player.playbackTime)
        }

        if let entry = player.queue.currentEntry {
            let subtitle = entry.subtitle ?? "Apple Music"
            let identity = "\(entry.title)|\(subtitle)"

            // Queue metadata only changes when the entry changes. Avoid publishing the
            // same title, artwork and duration four times a second, which used to make
            // every glass panel in the radio rebuild while a progress slider was moving.
            if identity != lastEntryIdentity {
                lastEntryIdentity = identity
                currentTitle = entry.title
                currentSubtitle = subtitle
                currentTrackSeed = identity
                currentArtwork = entry.artwork

                if let known = songs.first(where: { $0.title == entry.title && $0.artist == subtitle }) {
                    duration = known.duration
                } else if let end = entry.endTime, end > 0 {
                    duration = end
                } else {
                    duration = 0
                }
            }
        }
        #endif
    }

    func startMonitoring() {
        guard monitorTask == nil else { return }
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.refreshPlaybackSnapshot()
                let delay: UInt64 = self.isPlaying ? 250_000_000 : 900_000_000
                try? await Task.sleep(nanoseconds: delay)
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    private func reportPlaybackActivityIfNeeded(_ active: Bool) {
        guard active != lastReportedPlaybackActivity else { return }
        lastReportedPlaybackActivity = active
        onPlaybackActivityChanged?(active)
    }

    private func handleMusicKitError(_ error: Error) {
        let text = error.localizedDescription
        errorMessage = text
        let lowered = text.lowercased()
        if lowered.contains("developer token") || lowered.contains("music user token") || lowered.contains("not authorized") {
            accessState = .needsAppService
        }
    }
}
