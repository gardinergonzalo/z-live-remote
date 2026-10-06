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
    @Published private(set) var sceneBPMs: [Int: Double] = [:]

    @Published var isSetlistPresented = false

    private var stagedScenes: [Int: Song] = [:]
    private var pendingSelectedSceneIndex: Int?
    private var sceneDurations: [Int: Double] = [:]
    private var localTimelineTimer: Timer?
    private var timelineAnchorDate: Date?
    private var timelineAnchorElapsed: Double = 0

    private var bridgeLinkReady = false
    private var maxTransportReady = false
    private var didRequestScanForCurrentMaxSession = false

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

    var currentBPM: Double? {
        guard let sceneIndex = currentSong?.id else { return nil }
        return sceneBPMs[sceneIndex]
    }

    func bpm(for song: Song?) -> Double? {
        guard let song else { return nil }
        return sceneBPMs[song.id]
    }

    func bpmLabel(for song: Song?) -> String? {
        guard let bpm = bpm(for: song) else { return nil }

        if abs(bpm.rounded() - bpm) < 0.01 {
            return String(format: "%.0f BPM", bpm)
        }

        return String(format: "%.1f BPM", bpm)
    }

    var currentBPMLabel: String? {
        bpmLabel(for: currentSong)
    }

    func startRemoteConnection() {
        bridgeClient.start()
    }

    func fire() {
        guard isConnected, currentSong != nil else { return }
        bridgeClient.send(.fire)
    }

    func stop() {
        guard isConnected else { return }
        bridgeClient.send(.stop)
    }

    func selectPrevious() {
        guard isConnected, !songs.isEmpty, currentIndex > 0 else { return }
        selectPosition(currentIndex - 1)
    }

    func selectNext() {
        guard
            isConnected,
            !songs.isEmpty,
            currentIndex + 1 < songs.count
        else { return }

        selectPosition(currentIndex + 1)
    }

    func select(song: Song) {
        guard isConnected else { return }
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
        guard isConnected != connected else { return }

        isConnected = connected

        if connected {
            if playbackState == .disconnected, currentSong != nil {
                playbackState = .ready
            }
        } else {
            playbackState = .disconnected
            stopLocalTimeline()
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

    private func refreshEndToEndConnection() {
        setConnected(bridgeLinkReady && maxTransportReady)
    }

    private func markMaxAvailable(
        _ available: Bool,
        client: BLEBridgeClient
    ) {
        let wasReady = maxTransportReady
        maxTransportReady = available

        if !available {
            didRequestScanForCurrentMaxSession = false
        }

        refreshEndToEndConnection()

        if available && (!wasReady || !didRequestScanForCurrentMaxSession) {
            didRequestScanForCurrentMaxSession = true
            client.send(.scan)
        }
    }

    private func selectPosition(_ position: Int) {
        guard isConnected, songs.indices.contains(position) else { return }

        let song = songs[position]
        bridgeClient.send(.select(sceneIndex: song.id))
    }

    private func selectSceneIndexFromAbleton(_ sceneIndex: Int) {
        guard let position = songs.firstIndex(where: { $0.id == sceneIndex }) else {
            pendingSelectedSceneIndex = sceneIndex
            return
        }

        currentIndex = position

        // A scan/reconnect can report the selected Scene while it is already
        // playing. Do not downgrade that recovered state back to PREPARADA.
        if playbackState != .playing {
            playbackState = .ready
        }

        pendingSelectedSceneIndex = nil

        if playbackState == .playing {
            timelineDuration = sceneDurations[sceneIndex] ?? timelineDuration
        } else {
            stopLocalTimeline()
            syncTimelineForCurrentScene()
        }
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

        if isConnected, !songs.isEmpty, playbackState == .disconnected {
            playbackState = .ready
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
        timelineAnchorElapsed = 0
        timelineAnchorDate = nil
    }

    private func startLocalTimeline(initialElapsed: Double? = nil) {
        stopLocalTimeline()

        guard timelineDuration > 0 else { return }

        let elapsed = min(
            max(0, initialElapsed ?? timelineElapsed),
            timelineDuration
        )

        timelineElapsed = elapsed
        timelineProgress = timelineDuration > 0
            ? elapsed / timelineDuration
            : 0

        timelineAnchorElapsed = elapsed
        timelineAnchorDate = Date()

        localTimelineTimer = Timer.scheduledTimer(
            withTimeInterval: 0.10,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                guard
                    let self,
                    self.playbackState == .playing,
                    let anchor = self.timelineAnchorDate,
                    self.timelineDuration > 0
                else { return }

                let elapsed = min(
                    self.timelineDuration,
                    self.timelineAnchorElapsed + Date().timeIntervalSince(anchor)
                )

                self.timelineElapsed = elapsed
                self.timelineProgress = min(
                    max(elapsed / self.timelineDuration, 0),
                    1
                )
            }
        }
    }

    private func stopLocalTimeline() {
        localTimelineTimer?.invalidate()
        localTimelineTimer = nil
        timelineAnchorDate = nil
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

        if playbackState == .playing {
            startLocalTimeline(initialElapsed: timelineElapsed)
        }
    }
}

extension LiveRemoteViewModel: BLEBridgeClientDelegate {
    nonisolated func bridgeClientDidConnect(_ client: BLEBridgeClient) {
        Task { @MainActor in
            self.bridgeLinkReady = true
            self.maxTransportReady = false
            self.didRequestScanForCurrentMaxSession = false
            self.refreshEndToEndConnection()
            client.send(.ping)
        }
    }

    nonisolated func bridgeClientDidDisconnect(_ client: BLEBridgeClient) {
        Task { @MainActor in
            self.bridgeLinkReady = false
            self.maxTransportReady = false
            self.didRequestScanForCurrentMaxSession = false
            self.refreshEndToEndConnection()
        }
    }

    nonisolated func bridgeClient(
        _ client: BLEBridgeClient,
        didReceive event: BridgeEvent
    ) {
        Task { @MainActor in
            switch event.type {
            case "hello":
                self.bridgeLinkReady = true
                self.refreshEndToEndConnection()
                client.send(.ping)

            case "bridge_status":
                self.markMaxAvailable(
                    event.maxConnected ?? false,
                    client: client
                )

            case "pong", "max_transport_ready":
                self.markMaxAvailable(true, client: client)

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

            case "scene_bpm":
                guard
                    let sceneIndex = event.index,
                    let bpm = event.bpm,
                    bpm > 0
                else { return }

                self.sceneBPMs[sceneIndex] = bpm

            case "scene_duration":
                guard
                    let sceneIndex = event.index,
                    let duration = event.duration
                else { return }

                self.sceneDurations[sceneIndex] = max(0, duration)

                if self.currentSong?.id == sceneIndex {
                    self.timelineDuration = max(0, duration)

                    if self.playbackState != .playing {
                        self.timelineElapsed = 0
                        self.timelineProgress = 0
                    }
                }

            case "fired_watching":
                break

            case "scene_started":
                if let sceneIndex = event.index {
                    self.selectSceneIndexFromAbleton(sceneIndex)
                }
                self.playbackState = .playing
                self.startLocalTimeline(initialElapsed: self.timelineElapsed)

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
                self.stopLocalTimeline()
                self.resetTimelineProgress()

            case "scene_finished":
                break

            case "prepared_next":
                guard let sceneIndex = event.index else { return }
                self.stopLocalTimeline()
                self.playbackState = .ready
                self.selectSceneIndexFromAbleton(sceneIndex)

            case "stop_all_clips":
                self.stopLocalTimeline()
                self.playbackState = .ready
                self.resetTimelineProgress()

            case "max_error":
                if let message = event.message {
                    print("[Z Live Remote Max] \(message)")
                }

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
