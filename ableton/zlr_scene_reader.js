autowatch = 1;

inlets = 1;
outlets = 2;

var playbackMonitor = null;
var monitoredSceneIndex = -1;
var monitorHasStarted = false;
var monitorStoppedTicks = 0;
var monitorTrackApis = [];
var monitorTimelineApi = null;
var monitorTimelineDuration = 0;
var monitorTimelineLoopStart = 0;
var monitorTimelineUsesSeconds = false;
var monitorTempo = 120;
var sceneDurationCache = {};

var MONITOR_INTERVAL_MS = 500;
var STOPPED_DEBOUNCE_TICKS = 2;

/*
 Z Live Remote v0.4.2 - Scene Reader local timeline
 Outlet 0: human-readable/status messages
 Outlet 1: machine-friendly scene rows

 Commands:
   bang / scan  -> enumerate scenes
   selected     -> report selected scene
*/

function bang() {
    scan();
}

function scan() {
    try {
        var setApi = new LiveAPI("live_set");
        var sceneCount = parseInt(setApi.getcount("scenes"), 10);

        outlet(0, ["scan_begin", sceneCount]);

        for (var i = 0; i < sceneCount; i++) {
            var sceneApi = new LiveAPI("live_set scenes " + i);
            var sceneName = cleanValue(sceneApi.get("name"));
            var sceneId = sceneApi.id;
            var hasClips = sceneHasAnyClip(i);
            var valid = isValidScene(sceneName, hasClips);

            outlet(1, [
                "scene",
                i,
                valid ? 1 : 0,
                hasClips ? 1 : 0,
                sceneId,
                sceneName
            ]);

            if (valid) {
                reportSceneTempo(i);
            }
        }

        reportSelected();
        outlet(0, ["scan_end"]);
    } catch (e) {
        outlet(0, ["error", String(e)]);
        post("Z Live Remote Scene Reader error: " + e + "\n");
    }
}

function selected() {
    reportSelected();
}

function reportSelected() {
    try {
        var viewApi = new LiveAPI("live_set view");
        var selectedRaw = viewApi.get("selected_scene");
        var selectedId = extractId(selectedRaw);

        if (!selectedId) {
            outlet(0, ["selected_scene", -1, "NONE"]);
            return;
        }

        var selectedApi = new LiveAPI("id " + selectedId);
        var selectedName = cleanValue(selectedApi.get("name"));
        var index = sceneIndexFromId(selectedId);

        outlet(0, ["selected_scene", index, selectedId, selectedName]);
        reportSceneTempo(index);
        reportSceneDuration(index);
        resumeWatchIfPlaying(index);
    } catch (e) {
        outlet(0, ["error_selected", String(e)]);
        post("Z Live Remote selected scene error: " + e + "\n");
    }
}


function resumeWatchIfPlaying(index) {
    if (index < 0) {
        return;
    }

    var trackApis = buildTrackApis();

    if (!sceneIsPlayingWithApis(index, trackApis)) {
        return;
    }

    if (playbackMonitor && monitoredSceneIndex === index) {
        return;
    }

    stopPlaybackMonitor();

    monitoredSceneIndex = index;
    monitorHasStarted = true;
    monitorStoppedTicks = 0;
    prepareMonitoringState(index, trackApis);

    outlet(0, ["scene_started", index]);
    reportCachedTimeline(index);

    playbackMonitor = new Task(pollMonitoredScene, this);
    playbackMonitor.interval = MONITOR_INTERVAL_MS;
    playbackMonitor.repeat();
}

function select(index) {
    try {
        var i = parseInt(index, 10);
        var setApi = new LiveAPI("live_set");
        var sceneCount = parseInt(setApi.getcount("scenes"), 10);

        if (isNaN(i) || i < 0 || i >= sceneCount) {
            outlet(0, ["select_error", "invalid_index", index]);
            return;
        }

        var sceneApi = new LiveAPI("live_set scenes " + i);
        var sceneName = cleanValue(sceneApi.get("name"));
        var hasClips = sceneHasAnyClip(i);

        if (!isValidScene(sceneName, hasClips)) {
            outlet(0, ["select_error", "invalid_scene", i, sceneName]);
            return;
        }

        var viewApi = new LiveAPI("live_set view");
        viewApi.set("selected_scene", "id", sceneApi.id);

        outlet(0, ["selected_by_zlr", i, sceneApi.id, sceneName]);
        reportSceneTempo(i);
        reportSceneDuration(i);
    } catch (e) {
        outlet(0, ["select_error", String(e)]);
        post("Z Live Remote select error: " + e + "\n");
    }
}

function fire() {
    try {
        var viewApi = new LiveAPI("live_set view");
        var selectedRaw = viewApi.get("selected_scene");
        var selectedId = extractId(selectedRaw);

        if (!selectedId) {
            outlet(0, ["fire_error", "no_selected_scene"]);
            return;
        }

        var selectedApi = new LiveAPI("id " + selectedId);
        var selectedName = cleanValue(selectedApi.get("name"));
        var index = sceneIndexFromId(selectedId);

        selectedApi.call("fire");
        outlet(0, ["fired_scene", index, selectedId, selectedName]);
    } catch (e) {
        outlet(0, ["fire_error", String(e)]);
        post("Z Live Remote fire error: " + e + "\n");
    }
}



function fire_watch() {
    try {
        stopPlaybackMonitor();

        var viewApi = new LiveAPI("live_set view");
        var selectedRaw = viewApi.get("selected_scene");
        var selectedId = extractId(selectedRaw);

        if (!selectedId) {
            outlet(0, ["fire_watch_error", "no_selected_scene"]);
            return;
        }

        var selectedApi = new LiveAPI("id " + selectedId);
        var selectedName = cleanValue(selectedApi.get("name"));
        var index = sceneIndexFromId(selectedId);

        if (index < 0) {
            outlet(0, ["fire_watch_error", "scene_index_not_found"]);
            return;
        }

        monitoredSceneIndex = index;
        monitorHasStarted = false;
        monitorStoppedTicks = 0;
        prepareMonitoringState(index, buildTrackApis());
        reportSceneTempo(index);
        reportSceneDuration(index);

        // Fire ONLY the prepared scene. Do not advance selection here.
        selectedApi.call("fire");
        outlet(0, ["fired_watching", index, selectedId, selectedName]);

        playbackMonitor = new Task(pollMonitoredScene, this);
        playbackMonitor.interval = MONITOR_INTERVAL_MS;
        playbackMonitor.repeat();
    } catch (e) {
        outlet(0, ["fire_watch_error", String(e)]);
        post("Z Live Remote fire_watch error: " + e + "\n");
    }
}

function pollMonitoredScene() {
    try {
        if (monitoredSceneIndex < 0) {
            stopPlaybackMonitor();
            return;
        }

        var active = sceneIsPlayingWithApis(
            monitoredSceneIndex,
            monitorTrackApis
        );

        if (active) {
            if (!monitorHasStarted) {
                monitorHasStarted = true;
                outlet(0, ["scene_started", monitoredSceneIndex]);

                // One real snapshot aligns the iPhone/iPad clock.
                // The progress bar then animates locally without polling Live.
                reportCachedTimeline(monitoredSceneIndex);
            }

            monitorStoppedTicks = 0;
            return;
        }

        // Ignore the launch-quantization gap until the Scene actually starts.
        if (!monitorHasStarted) {
            return;
        }

        monitorStoppedTicks += 1;
        if (monitorStoppedTicks < STOPPED_DEBOUNCE_TICKS) {
            return;
        }

        var finishedIndex = monitoredSceneIndex;
        stopPlaybackMonitor();

        var nextIndex = findNextValidSceneIndex(finishedIndex + 1);

        if (nextIndex < 0) {
            outlet(0, ["scene_finished", finishedIndex, "end_of_setlist"]);
            return;
        }

        selectSceneIndex(nextIndex);
        var nextApi = new LiveAPI("live_set scenes " + nextIndex);
        var nextName = cleanValue(nextApi.get("name"));

        outlet(0, ["scene_finished", finishedIndex]);
        outlet(0, ["prepared_next", nextIndex, nextApi.id, nextName]);
        reportSceneTempo(nextIndex);
        reportSceneDuration(nextIndex);
    } catch (e) {
        outlet(0, ["monitor_error", String(e)]);
        post("Z Live Remote monitor error: " + e + "\n");
        stopPlaybackMonitor();
    }
}

function stopPlaybackMonitor() {
    if (playbackMonitor) {
        try {
            playbackMonitor.cancel();
        } catch (ignore) {}
    }

    playbackMonitor = null;
    monitoredSceneIndex = -1;
    monitorHasStarted = false;
    monitorStoppedTicks = 0;
    monitorTrackApis = [];
    monitorTimelineApi = null;
    monitorTimelineDuration = 0;
    monitorTimelineLoopStart = 0;
    monitorTimelineUsesSeconds = false;
}

function buildTrackApis() {
    var setApi = new LiveAPI("live_set");
    var trackCount = parseInt(setApi.getcount("tracks"), 10);
    var result = [];

    for (var t = 0; t < trackCount; t++) {
        result.push(new LiveAPI("live_set tracks " + t));
    }

    return result;
}

function sceneIsPlayingWithApis(sceneIndex, trackApis) {
    for (var t = 0; t < trackApis.length; t++) {
        var playingIndex = parseInt(
            cleanValue(trackApis[t].get("playing_slot_index")),
            10
        );

        if (!isNaN(playingIndex) && playingIndex === sceneIndex) {
            return true;
        }
    }

    return false;
}

function prepareMonitoringState(sceneIndex, trackApis) {
    var allTrackApis = trackApis || buildTrackApis();
    var relevantTrackApis = [];

    monitorTrackApis = [];
    monitorTimelineApi = null;
    monitorTimelineDuration = 0;
    monitorTimelineLoopStart = 0;
    monitorTimelineUsesSeconds = false;
    monitorTempo = sceneTempoBPM(sceneIndex);

    for (var t = 0; t < allTrackApis.length; t++) {
        var trackApi = allTrackApis[t];
        var slotCount = parseInt(trackApi.getcount("clip_slots"), 10);

        if (sceneIndex >= slotCount) {
            continue;
        }

        var slotPath = "live_set tracks " + t + " clip_slots " + sceneIndex;
        var slotApi = new LiveAPI(slotPath);
        var hasClip = parseInt(cleanValue(slotApi.get("has_clip")), 10);

        if (hasClip !== 1) {
            continue;
        }

        relevantTrackApis.push(trackApi);

        var clipApi = new LiveAPI(slotPath + " clip");
        var duration = clipDurationSeconds(clipApi, monitorTempo);

        if (duration > monitorTimelineDuration) {
            monitorTimelineDuration = duration;
            monitorTimelineApi = clipApi;

            var isAudio = parseInt(
                cleanValue(clipApi.get("is_audio_clip")),
                10
            );
            var warping = isAudio === 1
                ? parseInt(cleanValue(clipApi.get("warping")), 10)
                : 1;
            var loopStart = parseFloat(
                cleanValue(clipApi.get("loop_start"))
            );

            monitorTimelineLoopStart = isNaN(loopStart) ? 0 : loopStart;
            monitorTimelineUsesSeconds = isAudio === 1 && warping === 0;
        }
    }

    monitorTrackApis = relevantTrackApis;

    if (monitorTimelineDuration > 0) {
        sceneDurationCache[sceneIndex] = monitorTimelineDuration;
    }
}

function reportCachedTimeline(sceneIndex) {
    try {
        if (
            sceneIndex !== monitoredSceneIndex ||
            !monitorTimelineApi ||
            monitorTimelineDuration <= 0
        ) {
            return;
        }

        var playingPosition = parseFloat(
            cleanValue(monitorTimelineApi.get("playing_position"))
        );

        if (isNaN(playingPosition)) {
            return;
        }

        var units = Math.max(
            0,
            playingPosition - monitorTimelineLoopStart
        );

        var elapsed = monitorTimelineUsesSeconds
            ? units
            : units * 60.0 / monitorTempo;

        elapsed = Math.max(
            0,
            Math.min(elapsed, monitorTimelineDuration)
        );

        outlet(0, [
            "timeline",
            sceneIndex,
            elapsed,
            monitorTimelineDuration,
            monitorTimelineDuration > 0
                ? elapsed / monitorTimelineDuration
                : 0
        ]);
    } catch (e) {
        outlet(0, ["timeline_error", "cached_progress", sceneIndex, String(e)]);
    }
}

function findNextValidSceneIndex(startIndex) {
    var setApi = new LiveAPI("live_set");
    var sceneCount = parseInt(setApi.getcount("scenes"), 10);

    for (var i = startIndex; i < sceneCount; i++) {
        var sceneApi = new LiveAPI("live_set scenes " + i);
        var sceneName = cleanValue(sceneApi.get("name"));
        var hasClips = sceneHasAnyClip(i);

        if (isValidScene(sceneName, hasClips)) {
            return i;
        }
    }

    return -1;
}

function selectSceneIndex(index) {
    var sceneApi = new LiveAPI("live_set scenes " + index);
    var viewApi = new LiveAPI("live_set view");
    viewApi.set("selected_scene", "id", sceneApi.id);
}

function fire_next() {
    try {
        var viewApi = new LiveAPI("live_set view");
        var selectedRaw = viewApi.get("selected_scene");
        var selectedId = extractId(selectedRaw);

        if (!selectedId) {
            outlet(0, ["fire_next_error", "no_selected_scene"]);
            return;
        }

        var selectedApi = new LiveAPI("id " + selectedId);
        var selectedName = cleanValue(selectedApi.get("name"));
        var index = sceneIndexFromId(selectedId);

        // Live's fire_as_selected launches the currently selected Scene
        // and selects the following Scene without launching it.
        selectedApi.call("fire_as_selected");

        outlet(0, ["fired_and_prepared_next", index, selectedId, selectedName]);

        // Report the newly prepared Scene after Live has advanced selection.
        reportSelected();
    } catch (e) {
        outlet(0, ["fire_next_error", String(e)]);
        post("Z Live Remote fire_next error: " + e + "\n");
    }
}

function stop() {
    try {
        // Manual STOP must not be interpreted as a natural song ending.
        stopPlaybackMonitor();

        var setApi = new LiveAPI("live_set");
        setApi.call("stop_all_clips");
        outlet(0, ["stop_all_clips"]);
        outlet(0, ["timeline_reset"]);
    } catch (e) {
        outlet(0, ["stop_error", String(e)]);
        post("Z Live Remote stop error: " + e + "\n");
    }
}


function sceneTempoBPM(sceneIndex) {
    try {
        var sceneApi = new LiveAPI("live_set scenes " + sceneIndex);
        var enabled = parseInt(cleanValue(sceneApi.get("tempo_enabled")), 10);
        var tempo = parseFloat(cleanValue(sceneApi.get("tempo")));

        if (enabled === 1 && !isNaN(tempo) && tempo > 0) {
            return tempo;
        }
    } catch (ignore) {}

    var setApi = new LiveAPI("live_set");
    var setTempo = parseFloat(cleanValue(setApi.get("tempo")));

    if (isNaN(setTempo) || setTempo <= 0) {
        return 120;
    }

    return setTempo;
}

function reportSceneTempo(sceneIndex) {
    try {
        outlet(0, ["scene_bpm", sceneIndex, sceneTempoBPM(sceneIndex)]);
    } catch (e) {
        outlet(0, ["timeline_error", "tempo", sceneIndex, String(e)]);
    }
}

function reportSceneDuration(sceneIndex) {
    try {
        var duration = sceneDurationSeconds(sceneIndex);
        outlet(0, ["scene_duration", sceneIndex, duration]);
    } catch (e) {
        outlet(0, ["timeline_error", "duration", sceneIndex, String(e)]);
    }
}

function reportTimeline(sceneIndex) {
    try {
        var info = sceneTimelineInfo(sceneIndex);

        if (!info) {
            return;
        }

        outlet(0, [
            "timeline",
            sceneIndex,
            info.elapsed,
            info.duration,
            info.progress
        ]);
    } catch (e) {
        outlet(0, ["timeline_error", "progress", sceneIndex, String(e)]);
    }
}

function sceneDurationSeconds(sceneIndex) {
    if (
        sceneDurationCache.hasOwnProperty(sceneIndex) &&
        sceneDurationCache[sceneIndex] > 0
    ) {
        return sceneDurationCache[sceneIndex];
    }

    var tempo = sceneTempoBPM(sceneIndex);
    var trackApis = buildTrackApis();
    var maxDuration = 0;

    for (var t = 0; t < trackApis.length; t++) {
        var trackApi = trackApis[t];
        var slotCount = parseInt(trackApi.getcount("clip_slots"), 10);

        if (sceneIndex >= slotCount) {
            continue;
        }

        var slotPath = "live_set tracks " + t + " clip_slots " + sceneIndex;
        var slotApi = new LiveAPI(slotPath);
        var hasClip = parseInt(cleanValue(slotApi.get("has_clip")), 10);

        if (hasClip !== 1) {
            continue;
        }

        var clipApi = new LiveAPI(slotPath + " clip");
        var duration = clipDurationSeconds(clipApi, tempo);

        if (duration > maxDuration) {
            maxDuration = duration;
        }
    }

    if (maxDuration > 0) {
        sceneDurationCache[sceneIndex] = maxDuration;
    }

    return maxDuration;
}

function sceneTimelineInfo(sceneIndex) {
    var setApi = new LiveAPI("live_set");
    var tempo = parseFloat(cleanValue(setApi.get("tempo")));
    if (isNaN(tempo) || tempo <= 0) {
        tempo = 120;
    }

    var trackCount = parseInt(setApi.getcount("tracks"), 10);
    var maxDuration = 0;
    var maxElapsed = 0;
    var foundPlayingClip = false;

    for (var t = 0; t < trackCount; t++) {
        var trackApi = new LiveAPI("live_set tracks " + t);
        var slotCount = parseInt(trackApi.getcount("clip_slots"), 10);

        if (sceneIndex >= slotCount) {
            continue;
        }

        var slotPath = "live_set tracks " + t + " clip_slots " + sceneIndex;
        var slotApi = new LiveAPI(slotPath);
        var hasClip = parseInt(cleanValue(slotApi.get("has_clip")), 10);

        if (hasClip !== 1) {
            continue;
        }

        var clipApi = new LiveAPI(slotPath + " clip");
        var duration = clipDurationSeconds(clipApi, tempo);

        if (duration > maxDuration) {
            maxDuration = duration;
        }

        var isPlaying = parseInt(cleanValue(clipApi.get("is_playing")), 10);
        if (isPlaying !== 1) {
            continue;
        }

        foundPlayingClip = true;

        var elapsed = clipElapsedSeconds(clipApi, tempo);
        if (elapsed > maxElapsed) {
            maxElapsed = elapsed;
        }
    }

    if (!foundPlayingClip || maxDuration <= 0) {
        return null;
    }

    maxElapsed = Math.max(0, Math.min(maxElapsed, maxDuration));

    return {
        elapsed: maxElapsed,
        duration: maxDuration,
        progress: maxDuration > 0 ? maxElapsed / maxDuration : 0
    };
}

function clipDurationSeconds(clipApi, tempo) {
    var isAudio = parseInt(cleanValue(clipApi.get("is_audio_clip")), 10);
    var warping = isAudio === 1
        ? parseInt(cleanValue(clipApi.get("warping")), 10)
        : 1;

    var loopStart = parseFloat(cleanValue(clipApi.get("loop_start")));
    var loopEnd = parseFloat(cleanValue(clipApi.get("loop_end")));
    var length = parseFloat(cleanValue(clipApi.get("length")));

    var units = 0;

    if (!isNaN(loopStart) && !isNaN(loopEnd) && loopEnd > loopStart) {
        units = loopEnd - loopStart;
    } else if (!isNaN(length) && length > 0) {
        units = length;
    }

    if (units <= 0) {
        return 0;
    }

    // Unwarped audio exposes loop positions in seconds.
    if (isAudio === 1 && warping === 0) {
        return units;
    }

    // MIDI and warped audio expose clip time in beats.
    return units * 60.0 / tempo;
}

function clipElapsedSeconds(clipApi, tempo) {
    var isAudio = parseInt(cleanValue(clipApi.get("is_audio_clip")), 10);
    var warping = isAudio === 1
        ? parseInt(cleanValue(clipApi.get("warping")), 10)
        : 1;

    var loopStart = parseFloat(cleanValue(clipApi.get("loop_start")));
    var playingPosition = parseFloat(cleanValue(clipApi.get("playing_position")));

    if (isNaN(loopStart)) {
        loopStart = 0;
    }

    if (isNaN(playingPosition)) {
        return 0;
    }

    var units = Math.max(0, playingPosition - loopStart);

    if (isAudio === 1 && warping === 0) {
        return units;
    }

    return units * 60.0 / tempo;
}

function isValidScene(name, hasClips) {
    // A scene is valid if it has a meaningful custom name OR contains any clip.
    // This deliberately skips completely empty spacer rows.
    var normalized = String(name || "").replace(/^\s+|\s+$/g, "");

    // Some Live sets may expose an automatically generated numeric scene label.
    var onlyNumber = /^\d+$/.test(normalized);

    if (hasClips) {
        return true;
    }

    return normalized.length > 0 && !onlyNumber;
}

function sceneHasAnyClip(sceneIndex) {
    var setApi = new LiveAPI("live_set");
    var trackCount = parseInt(setApi.getcount("tracks"), 10);

    for (var t = 0; t < trackCount; t++) {
        var trackApi = new LiveAPI("live_set tracks " + t);
        var slotCount = parseInt(trackApi.getcount("clip_slots"), 10);

        if (sceneIndex >= slotCount) {
            continue;
        }

        var slotApi = new LiveAPI(
            "live_set tracks " + t + " clip_slots " + sceneIndex
        );

        var hasClip = parseInt(cleanValue(slotApi.get("has_clip")), 10);
        if (hasClip === 1) {
            return true;
        }
    }

    return false;
}

function sceneIndexFromId(sceneId) {
    var setApi = new LiveAPI("live_set");
    var sceneCount = parseInt(setApi.getcount("scenes"), 10);
    var targetId = parseInt(sceneId, 10);

    for (var i = 0; i < sceneCount; i++) {
        var sceneApi = new LiveAPI("live_set scenes " + i);
        var candidateId = parseInt(sceneApi.id, 10);

        if (!isNaN(candidateId) && candidateId === targetId) {
            return i;
        }
    }

    return -1;
}

function extractId(value) {
    if (value === null || value === undefined) {
        return 0;
    }

    if (value instanceof Array) {
        for (var i = 0; i < value.length; i++) {
            var n = parseInt(value[i], 10);
            if (!isNaN(n) && n > 0) {
                return n;
            }
        }
        return 0;
    }

    var text = String(value);
    var match = text.match(/\d+/);
    return match ? parseInt(match[0], 10) : 0;
}

function cleanValue(value) {
    if (value === null || value === undefined) {
        return "";
    }

    if (value instanceof Array) {
        if (value.length === 0) {
            return "";
        }
        if (value.length === 1) {
            return String(value[0]);
        }
        return value.join(" ");
    }

    return String(value);
}
