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
            return "资料库已由系统授权，游戏原声仍会保留在相位电台中。"
        case .needsAppService:
            return "当前签名的 App ID 尚未启用 MusicKit 服务。"
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
    @Published private(set) var isPreparingPlayback = false
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

    /// Called when actual playback starts or stops.
    var onPlaybackActivityChanged: ((Bool) -> Void)?

    /// Called before a queue change as well as after playback changes. The game
    /// can fade its procedural soundtrack before MusicKit takes the audio queue,
    /// avoiding two nonmixable players fighting during prepare/play.
    var onAudioFocusChanged: ((Bool) -> Void)?

    var holdsAudioFocus: Bool { isPreparingPlayback || isPlaying }

    private var monitorTask: Task<Void, Never>?
    private var playbackCommandTask: Task<Void, Never>?
    private var playbackRequestID = UUID()
    private var isScrubbing = false
    private var hasQueuedContent = false
    private var lastReportedPlaybackActivity = false
    private var lastReportedAudioFocus = false
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
        guard let song = librarySongs.first(where: { String(describing: $0.id) == id }) else {
            errorMessage = "没有在当前资料库快照中找到这首歌，请刷新后重试。"
            return
        }

        let requestID = beginPlaybackTransition()
        playbackCommandTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard self.isCurrentRequest(requestID), !Task.isCancelled else { return }

            self.player.pause()
            self.player.queue = ApplicationMusicPlayer.Queue(for: [song])
            self.hasQueuedContent = true
            self.duration = song.duration ?? 0
            self.currentTitle = song.title
            self.currentSubtitle = song.artistName
            self.currentTrackSeed = "\(song.title)|\(song.artistName)"
            self.currentArtwork = song.artwork
            self.lastEntryIdentity = nil

            await self.startCurrentQueue(requestID: requestID)
        }
        #endif
    }

    func playPlaylist(id: String) {
        #if canImport(MusicKit)
        guard let playlist = libraryPlaylists.first(where: { String(describing: $0.id) == id }) else {
            errorMessage = "没有在当前资料库快照中找到这个歌单，请刷新后重试。"
            return
        }

        let requestID = beginPlaybackTransition()
        playbackCommandTask = Task { [weak self] in
            guard let self else { return }
            do {
                let resolvedPlaylist = try await playlist.with([.entries], preferredSource: .library)
                guard self.isCurrentRequest(requestID), !Task.isCancelled else { return }
                guard let entries = resolvedPlaylist.entries, let firstEntry = entries.first else {
                    self.finishPlaybackTransition(requestID: requestID)
                    self.errorMessage = "这个歌单没有返回可播放曲目。"
                    return
                }

                try? await Task.sleep(nanoseconds: 150_000_000)
                guard self.isCurrentRequest(requestID), !Task.isCancelled else { return }

                self.player.pause()
                self.player.queue = ApplicationMusicPlayer.Queue(
                    playlist: resolvedPlaylist,
                    startingAt: firstEntry
                )
                self.hasQueuedContent = true
                self.duration = 0
                self.currentTitle = resolvedPlaylist.name
                self.currentSubtitle = "Apple Music 资料库歌单"
                self.currentTrackSeed = "playlist|\(resolvedPlaylist.name)"
                self.currentArtwork = resolvedPlaylist.artwork
                self.lastEntryIdentity = nil

                await self.startCurrentQueue(requestID: requestID)
            } catch {
                guard self.isCurrentRequest(requestID), !Task.isCancelled else { return }
                self.finishPlaybackTransition(requestID: requestID)
                self.handleMusicKitError(error)
            }
        }
        #endif
    }

    func togglePlayback() {
        #if canImport(MusicKit)
        if isPlaying || isPreparingPlayback {
            pausePlayback(clearError: true)
            return
        }

        guard hasQueuedContent else {
            errorMessage = "请先从 Apple Music 资料库中选择一首歌或一个歌单。"
            return
        }

        let requestID = beginPlaybackTransition(pausePlayer: false)
        playbackCommandTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard self.isCurrentRequest(requestID), !Task.isCancelled else { return }
            await self.startCurrentQueue(requestID: requestID)
        }
        #endif
    }

    func pauseForGameSoundtrack() {
        pausePlayback(clearError: true)
    }

    func skipNext() {
        #if canImport(MusicKit)
        runTransportCommand {
            try await self.player.skipToNextEntry()
        }
        #endif
    }

    func skipPrevious() {
        #if canImport(MusicKit)
        runTransportCommand {
            try await self.player.skipToPreviousEntry()
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

    func clearError() {
        errorMessage = nil
    }

    func refreshPlaybackSnapshot() {
        #if canImport(MusicKit)
        let active = player.state.playbackStatus == .playing
        if active != isPlaying { isPlaying = active }
        reportPlaybackActivityIfNeeded(active)
        reportAudioFocusIfNeeded()

        // A queue-interruption error can arrive from an obsolete preparation task
        // after the replacement queue has already started. Never keep displaying a
        // raw failure banner while MusicKit is demonstrably playing successfully.
        if active, errorMessage != nil {
            errorMessage = nil
        }

        if !isScrubbing {
            playbackTime = max(0, player.playbackTime)
        }

        if let entry = player.queue.currentEntry {
            hasQueuedContent = true
            let subtitle = entry.subtitle ?? "Apple Music"
            let identity = "\(entry.title)|\(subtitle)"

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

    #if canImport(MusicKit)
    private func beginPlaybackTransition(pausePlayer: Bool = true) -> UUID {
        playbackCommandTask?.cancel()
        let requestID = UUID()
        playbackRequestID = requestID
        errorMessage = nil
        setPreparingPlayback(true)
        if pausePlayer {
            player.pause()
            isPlaying = false
            reportPlaybackActivityIfNeeded(false)
        }
        reportAudioFocusIfNeeded()
        return requestID
    }

    private func startCurrentQueue(requestID: UUID) async {
        guard isCurrentRequest(requestID), !Task.isCancelled else { return }

        do {
            try await player.play()
        } catch {
            guard isCurrentRequest(requestID), !Task.isCancelled else { return }

            if isQueueInterruption(error) {
                // Error 2 can be delivered by an obsolete queue request even after
                // the replacement queue has already won the handoff. Check the real
                // player state before issuing another play command; retry only when
                // the new queue is still genuinely idle.
                try? await Task.sleep(nanoseconds: 260_000_000)
                guard isCurrentRequest(requestID), !Task.isCancelled else { return }
                refreshPlaybackSnapshot()
                if isPlaying {
                    finishPlaybackTransition(requestID: requestID)
                    errorMessage = nil
                    return
                }

                do {
                    try await player.play()
                } catch {
                    guard isCurrentRequest(requestID), !Task.isCancelled else { return }
                    refreshPlaybackSnapshot()
                    finishPlaybackTransition(requestID: requestID)
                    if !isPlaying { handleMusicKitError(error) }
                    return
                }
            } else {
                finishPlaybackTransition(requestID: requestID)
                handleMusicKitError(error)
                return
            }
        }

        guard isCurrentRequest(requestID), !Task.isCancelled else { return }
        try? await Task.sleep(nanoseconds: 90_000_000)
        refreshPlaybackSnapshot()
        finishPlaybackTransition(requestID: requestID)
        if isPlaying {
            errorMessage = nil
        }
    }

    private func runTransportCommand(_ operation: @escaping @MainActor () async throws -> Void) {
        errorMessage = nil
        playbackCommandTask?.cancel()
        let requestID = UUID()
        playbackRequestID = requestID
        playbackCommandTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await operation()
                guard self.isCurrentRequest(requestID), !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: 140_000_000)
                self.refreshPlaybackSnapshot()
                self.errorMessage = nil
            } catch {
                guard self.isCurrentRequest(requestID), !Task.isCancelled else { return }
                self.refreshPlaybackSnapshot()
                if !self.isPlaying { self.handleMusicKitError(error) }
            }
        }
    }

    private func pausePlayback(clearError: Bool) {
        playbackCommandTask?.cancel()
        playbackRequestID = UUID()
        player.pause()
        setPreparingPlayback(false)
        isPlaying = false
        reportPlaybackActivityIfNeeded(false)
        reportAudioFocusIfNeeded()
        if clearError { errorMessage = nil }
        refreshPlaybackSnapshot()
    }

    private func isCurrentRequest(_ requestID: UUID) -> Bool {
        requestID == playbackRequestID
    }

    private func finishPlaybackTransition(requestID: UUID) {
        guard isCurrentRequest(requestID) else { return }
        setPreparingPlayback(false)
        playbackCommandTask = nil
    }
    #else
    private func pausePlayback(clearError: Bool) {
        if clearError { errorMessage = nil }
    }
    #endif

    private func setPreparingPlayback(_ value: Bool) {
        guard isPreparingPlayback != value else { return }
        isPreparingPlayback = value
        reportAudioFocusIfNeeded()
    }

    private func reportPlaybackActivityIfNeeded(_ active: Bool) {
        guard active != lastReportedPlaybackActivity else { return }
        lastReportedPlaybackActivity = active
        onPlaybackActivityChanged?(active)
    }

    private func reportAudioFocusIfNeeded() {
        let focused = holdsAudioFocus
        guard focused != lastReportedAudioFocus else { return }
        lastReportedAudioFocus = focused
        onAudioFocusChanged?(focused)
    }

    private func isQueueInterruption(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == "MPMusicPlayerControllerErrorDomain", nsError.code == 2 {
            return true
        }
        let text = "\(nsError.localizedDescription) \(nsError.userInfo)".lowercased()
        return text.contains("queue was interrupted") || text.contains("队列") && text.contains("中断")
    }

    private func handleMusicKitError(_ error: Error) {
        let nsError = error as NSError
        let text = "\(nsError.localizedDescription) \(nsError.userInfo)"
        let lowered = text.lowercased()

        if isQueueInterruption(error) {
            errorMessage = "Apple Music 切换播放队列时被系统打断。已自动重试；若仍未播放，请再点一次曲目。"
        } else if nsError.domain == "MPMusicPlayerControllerErrorDomain", nsError.code == 6 {
            errorMessage = "这首曲目当前无法由 MusicKit 播放，可能尚未下载、地区不可用或不在有效订阅范围内。"
        } else if lowered.contains("developer token") || lowered.contains("music user token") || lowered.contains("not authorized") {
            accessState = .needsAppService
            errorMessage = "MusicKit 服务认证失败。请确认当前 Bundle ID 已启用 MusicKit App Service。"
        } else {
            errorMessage = nsError.localizedDescription
        }
    }
}
