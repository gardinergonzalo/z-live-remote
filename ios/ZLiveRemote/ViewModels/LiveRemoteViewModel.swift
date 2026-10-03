import Foundation

@MainActor
final class LiveRemoteViewModel: ObservableObject {
    @Published private(set) var songs: [Song]
    @Published private(set) var currentIndex: Int
    @Published private(set) var playbackState: PlaybackState
    @Published var isSetlistPresented = false

    init(
        songs: [Song] = Song.mockSetlist,
        initialIndex: Int = 4,
        playbackState: PlaybackState = .ready
    ) {
        self.songs = songs
        self.currentIndex = min(max(initialIndex, 0), max(songs.count - 1, 0))
        self.playbackState = playbackState
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

    func fire() {
        guard playbackState != .disconnected, currentSong != nil else { return }
        playbackState = .playing
    }

    func stop() {
        guard playbackState != .disconnected else { return }
        playbackState = .ready
    }

    func selectPrevious() {
        guard !songs.isEmpty, currentIndex > 0 else { return }
        currentIndex -= 1
        playbackState = .ready
    }

    func selectNext() {
        guard !songs.isEmpty, currentIndex + 1 < songs.count else { return }
        currentIndex += 1
        playbackState = .ready
    }

    func select(song: Song) {
        guard let index = songs.firstIndex(of: song) else { return }
        currentIndex = index
        playbackState = .ready
        isSetlistPresented = false
    }

    /// Será llamado por la integración con Ableton cuando termine la Scene actual.
    /// La siguiente canción queda preparada, nunca se dispara automáticamente.
    func markCurrentSongFinished() {
        guard playbackState == .playing else { return }

        if currentIndex + 1 < songs.count {
            currentIndex += 1
        }

        playbackState = .ready
    }

    func setConnected(_ connected: Bool) {
        playbackState = connected ? .ready : .disconnected
    }

    /// Reemplaza la setlist mock por las Scenes válidas recibidas desde Ableton.
    func loadSceneNames(_ sceneNames: [String]) {
        let parsed = sceneNames.enumerated().compactMap { offset, rawName in
            Song.parseSceneName(rawName, sceneIndex: offset)
        }

        songs = parsed
        currentIndex = min(currentIndex, max(parsed.count - 1, 0))
        playbackState = parsed.isEmpty ? .disconnected : .ready
    }
}
