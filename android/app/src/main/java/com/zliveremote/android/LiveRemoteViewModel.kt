package com.zliveremote.android

import android.app.Application
import android.os.SystemClock
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

class LiveRemoteViewModel(application: Application) : AndroidViewModel(application) {
    var songs by mutableStateOf<List<Song>>(emptyList())
        private set
    var currentIndex by mutableStateOf(0)
        private set
    var playbackState by mutableStateOf(PlaybackState.DISCONNECTED)
        private set

    var bridgeLinkReady by mutableStateOf(false)
        private set
    var maxTransportReady by mutableStateOf(false)
        private set
    var dataStreamHealthy by mutableStateOf(false)
        private set
    var isConnected by mutableStateOf(false)
        private set

    var timelineElapsed by mutableStateOf(0.0)
        private set
    var timelineDuration by mutableStateOf(0.0)
        private set
    var timelineProgress by mutableStateOf(0.0)
        private set

    var sceneBPMs by mutableStateOf<Map<Int, Double>>(emptyMap())
        private set
    var setlistRefreshPending by mutableStateOf(false)
        private set

    private var stagedScenes = mutableMapOf<Int, Song>()
    private var stagedSceneDurations = mutableMapOf<Int, Double>()
    private var stagedSceneBPMs = mutableMapOf<Int, Double>()
    private var sceneDurations = mutableMapOf<Int, Double>()
    private var isSceneScanInProgress = false
    private var pendingSelectedSceneIndex: Int? = null

    private var didRequestScanForCurrentMaxSession = false
    private var lastBridgeEventAt = 0L
    private var watchdogJob: Job? = null
    private var timelineJob: Job? = null
    private var timelineAnchorRealtime = 0L
    private var timelineAnchorElapsed = 0.0

    private val bridgeClient = BleBridgeClient(
        context = application,
        onReadyChanged = ::handleBridgeReady,
        onEvent = ::handleEvent,
        onLog = { message -> android.util.Log.d("ZLiveRemote", message) }
    )

    val currentSong: Song?
        get() = songs.getOrNull(currentIndex)

    val nextSong: Song?
        get() = songs.getOrNull(currentIndex + 1)

    val currentDisplayNumber: String
        get() = "%02d".format(currentIndex + 1)

    val timelineRemaining: Double
        get() = max(0.0, timelineDuration - timelineElapsed)

    val hasTimeline: Boolean
        get() = timelineDuration > 0

    val currentBPMLabel: String?
        get() = bpmLabel(currentSong)

    val totalSetlistDuration: Double
        get() = songs.sumOf { song -> max(0.0, sceneDurations[song.id] ?: 0.0) }

    val knownDurationSongCount: Int
        get() = songs.count { (sceneDurations[it.id] ?: 0.0) > 0 }

    val hasCompleteSetlistDuration: Boolean
        get() = songs.isNotEmpty() && knownDurationSongCount == songs.size

    val averageBPM: Double?
        get() {
            val values = songs.mapNotNull { sceneBPMs[it.id] }
            return if (values.isEmpty()) null else values.average()
        }

    val minimumBPM: Double?
        get() = songs.mapNotNull { sceneBPMs[it.id] }.minOrNull()

    val maximumBPM: Double?
        get() = songs.mapNotNull { sceneBPMs[it.id] }.maxOrNull()

    fun bpmFor(song: Song?): Double? = song?.let { sceneBPMs[it.id] }

    fun bpmLabel(song: Song?): String? {
        val bpm = bpmFor(song) ?: return null
        return if (abs(bpm - bpm.toInt()) < 0.01) {
            bpm.toInt().toString() + " BPM"
        } else {
            "%.1f BPM".format(bpm)
        }
    }

    fun startRemoteConnection() {
        startDataWatchdog()
        bridgeClient.start()
    }

    fun fire() {
        if (!isConnected || currentSong == null) return
        bridgeClient.send(BridgeCommand.Fire)
    }

    fun stop() {
        if (!isConnected) return
        bridgeClient.send(BridgeCommand.Stop)
    }

    fun selectPrevious() {
        if (!isConnected || playbackState == PlaybackState.PLAYING) return
        if (currentIndex <= 0) return
        selectPosition(currentIndex - 1)
    }

    fun selectNext() {
        if (!isConnected || playbackState == PlaybackState.PLAYING) return
        if (currentIndex + 1 >= songs.size) return
        selectPosition(currentIndex + 1)
    }

    fun select(song: Song) {
        if (!isConnected || playbackState == PlaybackState.PLAYING) return
        val position = songs.indexOfFirst { it.id == song.id }
        if (position >= 0) selectPosition(position)
    }

    private fun selectPosition(position: Int) {
        val song = songs.getOrNull(position) ?: return
        bridgeClient.send(BridgeCommand.Select(song.id))
    }

    private fun handleBridgeReady(ready: Boolean) {
        if (ready) {
            bridgeLinkReady = true
            maxTransportReady = false
            dataStreamHealthy = false
            lastBridgeEventAt = 0L
            didRequestScanForCurrentMaxSession = false
            refreshEndToEndConnection()
            bridgeClient.send(BridgeCommand.Ping)
        } else {
            bridgeLinkReady = false
            maxTransportReady = false
            dataStreamHealthy = false
            lastBridgeEventAt = 0L
            didRequestScanForCurrentMaxSession = false
            refreshEndToEndConnection()
        }
    }

    private fun refreshEndToEndConnection() {
        val connected = bridgeLinkReady && maxTransportReady && dataStreamHealthy
        if (isConnected == connected) return

        isConnected = connected

        if (connected) {
            if (playbackState == PlaybackState.DISCONNECTED && currentSong != null) {
                playbackState = PlaybackState.READY
            }
        } else {
            playbackState = PlaybackState.DISCONNECTED
            stopLocalTimeline()
            resetTimelineProgress()
        }
    }

    private fun noteBridgeEventReceived() {
        lastBridgeEventAt = SystemClock.elapsedRealtime()
        dataStreamHealthy = true
        refreshEndToEndConnection()
    }

    private fun startDataWatchdog() {
        watchdogJob?.cancel()
        watchdogJob = viewModelScope.launch {
            while (isActive) {
                delay(1_000)

                if (!bridgeLinkReady || lastBridgeEventAt == 0L) {
                    dataStreamHealthy = false
                } else {
                    dataStreamHealthy =
                        SystemClock.elapsedRealtime() - lastBridgeEventAt <= 6_000
                }

                refreshEndToEndConnection()
            }
        }
    }

    private fun markMaxAvailable(available: Boolean) {
        val wasReady = maxTransportReady
        maxTransportReady = available

        if (!available) {
            didRequestScanForCurrentMaxSession = false
        }

        refreshEndToEndConnection()

        if (available && (!wasReady || !didRequestScanForCurrentMaxSession)) {
            didRequestScanForCurrentMaxSession = true
            bridgeClient.send(BridgeCommand.Scan)
        }
    }

    private fun handleEvent(event: BridgeEvent) {
        noteBridgeEventReceived()

        when (event.type) {
            "hello" -> {
                bridgeLinkReady = true
                refreshEndToEndConnection()
                bridgeClient.send(BridgeCommand.Ping)
            }

            "bridge_status" -> {
                markMaxAvailable(event.maxConnected ?: false)
            }

            "pong", "max_transport_ready" -> {
                markMaxAvailable(true)
            }

            "scan_begin" -> {
                isSceneScanInProgress = true
                setlistRefreshPending = false
                stagedScenes.clear()
                stagedSceneDurations.clear()
                stagedSceneBPMs.clear()
            }

            "scene" -> {
                if (event.valid != 1) return
                val sceneIndex = event.index ?: return
                val rawName = event.name ?: return
                val normalized = normalizeScenePayload(rawName, event.bpm)
                val song = Song.parseSceneName(normalized.first, sceneIndex) ?: return

                stagedScenes[sceneIndex] = song
                normalized.second?.takeIf { it > 0 }?.let { bpm ->
                    if (isSceneScanInProgress) {
                        stagedSceneBPMs[sceneIndex] = bpm
                    } else {
                        sceneBPMs = sceneBPMs + (sceneIndex to bpm)
                    }
                }
            }

            "scan_end" -> finishSceneScan()

            "selected_scene" -> {
                event.index?.let(::selectSceneIndexFromAbleton)
            }

            "scene_bpm" -> {
                val sceneIndex = event.index ?: return
                val bpm = event.bpm?.takeIf { it > 0 } ?: return

                if (isSceneScanInProgress) {
                    stagedSceneBPMs[sceneIndex] = bpm
                } else {
                    sceneBPMs = sceneBPMs + (sceneIndex to bpm)
                }
            }

            "scene_duration" -> {
                val sceneIndex = event.index ?: return
                val duration = max(0.0, event.duration ?: return)

                if (isSceneScanInProgress) {
                    stagedSceneDurations[sceneIndex] = duration
                } else {
                    sceneDurations[sceneIndex] = duration
                }

                if (currentSong?.id == sceneIndex) {
                    timelineDuration = duration
                    if (playbackState != PlaybackState.PLAYING) {
                        timelineElapsed = 0.0
                        timelineProgress = 0.0
                    }
                }
            }

            "scene_started" -> {
                event.index?.let(::selectSceneIndexFromAbleton)
                playbackState = PlaybackState.PLAYING
                startLocalTimeline(timelineElapsed)
            }

            "timeline" -> {
                val sceneIndex = event.index ?: return
                val elapsed = event.elapsed ?: return
                val duration = event.duration ?: return
                val progress = event.progress ?: return
                updateTimeline(sceneIndex, elapsed, duration, progress)
            }

            "timeline_reset" -> {
                stopLocalTimeline()
                resetTimelineProgress()
            }

            "scene_finished" -> {
                stopLocalTimeline()
                if (timelineDuration > 0) {
                    timelineElapsed = timelineDuration
                    timelineProgress = 1.0
                }
                playbackState = PlaybackState.READY
            }

            "setlist_change_pending" -> {
                setlistRefreshPending = true
            }

            "prepared_next" -> {
                val sceneIndex = event.index ?: return
                stopLocalTimeline()
                playbackState = PlaybackState.READY
                selectSceneIndexFromAbleton(sceneIndex)
            }

            "stop_all_clips" -> {
                stopLocalTimeline()
                playbackState = PlaybackState.READY
                resetTimelineProgress()
            }
        }
    }

    private fun normalizeScenePayload(
        rawName: String,
        explicitBPM: Double?
    ): Pair<String, Double?> {
        if (explicitBPM != null && explicitBPM > 0) {
            return rawName to explicitBPM
        }

        val parts = rawName.trim().split(Regex("\\s+"), limit = 2)
        if (parts.size != 2) return rawName to null

        val bpm = parts[0].toDoubleOrNull() ?: return rawName to null
        if (bpm !in 20.0..300.0) return rawName to null

        return parts[1] to bpm
    }

    private fun finishSceneScan() {
        songs = stagedScenes.toSortedMap().values.toList()
        sceneDurations = stagedSceneDurations.toMutableMap()
        sceneBPMs = stagedSceneBPMs.toMap()

        stagedScenes.clear()
        stagedSceneDurations.clear()
        stagedSceneBPMs.clear()
        isSceneScanInProgress = false
        setlistRefreshPending = false

        val pending = pendingSelectedSceneIndex
        if (pending != null) {
            pendingSelectedSceneIndex = null
            selectSceneIndexFromAbleton(pending)
        } else if (currentIndex >= songs.size) {
            currentIndex = max(0, songs.size - 1)
            syncTimelineForCurrentScene()
        } else if (playbackState != PlaybackState.PLAYING) {
            syncTimelineForCurrentScene()
        }
    }

    private fun selectSceneIndexFromAbleton(sceneIndex: Int) {
        if (isSceneScanInProgress) {
            pendingSelectedSceneIndex = sceneIndex
            return
        }

        val position = songs.indexOfFirst { it.id == sceneIndex }
        if (position < 0) {
            pendingSelectedSceneIndex = sceneIndex
            return
        }

        currentIndex = position

        if (playbackState != PlaybackState.PLAYING) {
            playbackState = PlaybackState.READY
        }

        pendingSelectedSceneIndex = null

        if (playbackState == PlaybackState.PLAYING) {
            timelineDuration = sceneDurations[sceneIndex] ?: timelineDuration
        } else {
            stopLocalTimeline()
            syncTimelineForCurrentScene()
        }
    }

    private fun syncTimelineForCurrentScene() {
        timelineElapsed = 0.0
        timelineProgress = 0.0
        timelineDuration = currentSong?.let { sceneDurations[it.id] } ?: 0.0
    }

    private fun resetTimelineProgress() {
        timelineElapsed = 0.0
        timelineProgress = 0.0
        timelineAnchorElapsed = 0.0
        timelineAnchorRealtime = 0L
    }

    private fun startLocalTimeline(initialElapsed: Double = timelineElapsed) {
        stopLocalTimeline()
        if (timelineDuration <= 0) return

        val elapsed = min(max(0.0, initialElapsed), timelineDuration)
        timelineElapsed = elapsed
        timelineProgress = elapsed / timelineDuration
        timelineAnchorElapsed = elapsed
        timelineAnchorRealtime = SystemClock.elapsedRealtime()

        timelineJob = viewModelScope.launch {
            while (isActive && playbackState == PlaybackState.PLAYING) {
                val delta =
                    (SystemClock.elapsedRealtime() - timelineAnchorRealtime) / 1_000.0
                val current = min(
                    timelineDuration,
                    timelineAnchorElapsed + delta
                )

                timelineElapsed = current
                timelineProgress =
                    if (timelineDuration > 0) current / timelineDuration else 0.0

                delay(100)
            }
        }
    }

    private fun stopLocalTimeline() {
        timelineJob?.cancel()
        timelineJob = null
        timelineAnchorRealtime = 0L
    }

    private fun updateTimeline(
        sceneIndex: Int,
        elapsed: Double,
        duration: Double,
        progress: Double
    ) {
        sceneDurations[sceneIndex] = max(0.0, duration)
        if (currentSong?.id != sceneIndex) return

        timelineDuration = max(0.0, duration)
        timelineElapsed = min(max(0.0, elapsed), timelineDuration)
        timelineProgress = min(max(0.0, progress), 1.0)

        if (playbackState == PlaybackState.PLAYING) {
            startLocalTimeline(timelineElapsed)
        }
    }

    override fun onCleared() {
        bridgeClient.stop()
        watchdogJob?.cancel()
        timelineJob?.cancel()
        super.onCleared()
    }
}
