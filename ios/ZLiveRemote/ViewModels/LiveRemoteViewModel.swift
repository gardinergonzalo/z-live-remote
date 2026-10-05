import Foundation

@MainActor
final class LiveRemoteViewModel: ObservableObject {
    @Published private(set) var songs: [Song]
    @Published private(set) var currentIndex: Int
    @Published private(set) var playbackState: PlaybackState
    @Published private(set) var isConnected: Bool

    @Published private(set) var timelineElapsed: Double = 0
    @Published private(set) var timelineDuration: Double = 0
    @Published private(set) var timelineProgress: Double = 0

    @Published var isSetlistPresented = false

    private var stagedScenes: [Int: Song] = [:]
    private var pendingSelectedSceneIndex: Int?
    private var sceneDurations: [Int: Double] = [:]

    private lazy var bridgeClient: BLEBridgeClient = {
        let client = BLEBridgeClient()
        client.delegate = self
        return client
    }()

    init(
        songs: [Song] = Song.mockSetlist,
        initialIndex: Int = 4,
        playbackState: PlaybackState = .ready
    ) {
        self.songs = songs
        self.currentIndex = min(max(initialIndex, 0), max(songs.count - 1, 0))
        self.playbackState = playbackState
        self.isConnected = playbackState != .disconnected
    }

    var currentSong: Song? {
        guard songs.indices.contains(currentIndex) else { return nil }
        return songs[currentIndex]
    }

    var nextSong: Song? {
        guard !songs.isEmpty else { return nil }
        let index = currentIndex + 1
        guard songs.indices.contains(index) else { return nil }
        return songs[index]
    }

    var currentDisplayNumber: String {
        String(format: "%02d", currentIndex + 1)
    }

    var timelineRemaining: Double {
        max(0, timelineDuration - timelineElapsed)
    }

    var hasTimeline: Bool {
        timelineDuration > 0
    }

    func startRemoteConnection() {
        bridgeClient.start()
    }

    func fire() {
        guard currentSong != nil else { return }

        if isConnected {
            bridgeClient.send(.fire)
        } else {
            playbackState = .playing
        }
    }

    func stop() {
        if isConnected {
            bridgeClient.send(.stop)
        } else if playbackState != .disconnected {
            playbackState = .ready
            resetTimelineProgress()
        }
    }

    func selectPrevious() {
        guard !songs.isEmpty, currentIndex > 0 else { return }
        selectPosition(currentIndex - 1)
    }

    func selectNext() {
        guard !songs.isEmpty, currentIndex + 1 < songs.count else { return }
        selectPosition(currentIndex + 1)
    }

    func select(song: Song) {
        guard let index = songs.firstIndex(of: song) else { return }
        isSetlistPresented = false
        selectPosition(index)
    }

    func markCurrentSongFinished() {
        guard playbackState == .playing else { return }

        if currentIndex + 1 < songs.count {
            currentIndex += 1
        }

        playbackState = .ready
        syncTimelineForCurrentScene()
    }

    func setConnected(_ connected: Bool) {
        isConnected = connected

        if connected {
            if playbackState == .disconnected {
                playbackState = .ready
            }
        } else {
            playbackState = .disconnected
            resetTimelineProgress()
        }
    }

    func loadSceneNames(_ sceneNames: [String]) {
        let parsed = sceneNames.enumerated().compactMap { offset, rawName in
            Song.parseSceneName(rawName, sceneIndex: offset)
        }

        songs = parsed
        currentIndex = min(currentIndex, max(parsed.count - 1, 0))
        playbackState = parsed.isEmpty ? .disconnected : .ready
        syncTimelineForCurrentScene()
    }

    private func selectPosition(_ position: Int) {
        guard songs.indices.contains(position) else { return }

        let song = songs[position]

        if isConnected {
            bridgeClient.send(.select(sceneIndex: song.id))
        } else {
            currentIndex = position
            playbackState = .ready
            syncTimelineForCurrentScene()
        }
    }

    private func selectSceneIndexFromAbleton(_ sceneIndex: Int) {
        guard let position = songs.firstIndex(where: { $0.id == sceneIndex }) else {
            pendingSelectedSceneIndex = sceneIndex
            return
        }

        currentIndex = position
        playbackState = .ready
        pendingSelectedSceneIndex = nil
        syncTimelineForCurrentScene()
    }

    private func finishSceneScan() {
        let parsed = stagedScenes
            .sorted { $0.key < $1.key }
            .map(\.value)

        songs = parsed
        stagedScenes.removeAll(keepingCapacity: true)

        if let pendingSelectedSceneIndex {
            selectSceneIndexFromAbleton(pendingSelectedSceneIndex)
        } else if currentIndex >= songs.count {
            currentIndex = max(songs.count - 1, 0)
            syncTimelineForCurrentScene()
        }
    }

    private func syncTimelineForCurrentScene() {
        timelineElapsed = 0
        timelineProgress = 0

        guard let sceneIndex = currentSong?.id else {
            timelineDuration = 0
            return
        }

        timelineDuration = sceneDurations[sceneIndex] ?? 0
    }

    private func resetTimelineProgress() {
        timelineElapsed = 0
        timelineProgress = 0
    }

    private func updateTimeline(
        sceneIndex: Int,
        elapsed: Double,
        duration: Double,
        progress: Double
    ) {
        sceneDurations[sceneIndex] = max(0, duration)

        guard currentSong?.id == sceneIndex else { return }

        timelineDuration = max(0, duration)
        timelineElapsed = min(max(0, elapsed), timelineDuration)
        timelineProgress = min(max(0, progress), 1)
    }
}

extension LiveRemoteViewModel: BLEBridgeClientDelegate {
    nonisolated func bridgeClientDidConnect(_ client: BLEBridgeClient) {
        Task { @MainActor in
            self.setConnected(true)
            client.send(.scan)
        }
    }

    nonisolated func bridgeClientDidDisconnect(_ client: BLEBridgeClient) {
        Task { @MainActor in
            self.setConnected(false)
        }
    }

    nonisolated func bridgeClient(
        _ client: BLEBridgeClient,
        didReceive event: BridgeEvent
    ) {
        Task { @MainActor in
            switch event.type {
            case "hello":
                self.setConnected(true)
                client.send(.scan)

            case "max_transport_ready":
                client.send(.scan)

            case "scan_begin":
                self.stagedScenes.removeAll(keepingCapacity: true)

            case "scene":
                guard
                    event.valid == 1,
                    let sceneIndex = event.index,
                    let rawName = event.name,
                    let song = Song.parseSceneName(rawName, sceneIndex: sceneIndex)
                else { return }

                self.stagedScenes[sceneIndex] = song

            case "scan_end":
                self.finishSceneScan()

            case "selected_scene":
                guard let sceneIndex = event.index else { return }
                self.selectSceneIndexFromAbleton(sceneIndex)

            case "scene_duration":
                guard
                    let sceneIndex = event.index,
                    let duration = event.duration
                else { return }

                self.sceneDurations[sceneIndex] = max(0, duration)

                if self.currentSong?.id == sceneIndex {
                    self.timelineDuration = max(0, duration)
                    self.timelineElapsed = 0
                    self.timelineProgress = 0
                }

            case "fired_watching":
                break

            case "scene_started":
                if let sceneIndex = event.index {
                    self.selectSceneIndexFromAbleton(sceneIndex)
                }
                self.playbackState = .playing

            case "timeline":
                guard
                    let sceneIndex = event.index,
                    let elapsed = event.elapsed,
                    let duration = event.duration,
                    let progress = event.progress
                else { return }

                self.updateTimeline(
                    sceneIndex: sceneIndex,
                    elapsed: elapsed,
                    duration: duration,
                    progress: progress
                )

            case "timeline_reset":
                self.resetTimelineProgress()

            case "scene_finished":
                break

            case "prepared_next":
                guard let sceneIndex = event.index else { return }
                self.selectSceneIndexFromAbleton(sceneIndex)
                self.playbackState = .ready

            case "stop_all_clips":
                self.playbackState = .ready
                self.resetTimelineProgress()

            case "max_error":
                self.playbackState = .ready

            default:
                break
            }
        }
    }

    nonisolated func bridgeClient(
        _ client: BLEBridgeClient,
        didLog message: String
    ) {
        print("[Z Live Remote BLE] \(message)")
    }
}
