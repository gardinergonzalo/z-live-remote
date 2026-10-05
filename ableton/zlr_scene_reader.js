autowatch = 1;

inlets = 1;
outlets = 2;

var playbackMonitor = null;
var monitoredSceneIndex = -1;
var monitorHasStarted = false;
var monitorStoppedTicks = 0;
var monitorTimelineTicks = 0;

/*
 Z Live Remote v0.4.0 - Scene Reader
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
        reportSceneDuration(index);
        resumeWatchIfPlaying(index);
    } catch (e) {
        outlet(0, ["error_selected", String(e)]);
        post("Z Live Remote selected scene error: " + e + "\n");
    }
}


function resumeWatchIfPlaying(index) {
    if (index < 0 || !sceneIsPlayingOrTriggered(index)) {
        return;
    }

    outlet(0, ["scene_started", index]);
    reportTimeline(index);

    if (playbackMonitor && monitoredSceneIndex === index) {
        return;
    }

    stopPlaybackMonitor();

    monitoredSceneIndex = index;
    monitorHasStarted = true;
    monitorStoppedTicks = 0;
    monitorTimelineTicks = 0;

    playbackMonitor = new Task(pollMonitoredScene, this);
    playbackMonitor.interval = 100;
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
        monitorTimelineTicks = 0;
        reportSceneDuration(index);

        // Fire ONLY the prepared scene. Do not advance selection here.
        selectedApi.call("fire");
        outlet(0, ["fired_watching", index, selectedId, selectedName]);

        playbackMonitor = new Task(pollMonitoredScene, this);
        playbackMonitor.interval = 100;
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

        var active = sceneIsPlayingOrTriggered(monitoredSceneIndex);

        if (active) {
            if (!monitorHasStarted) {
                monitorHasStarted = true;
                outlet(0, ["scene_started", monitoredSceneIndex]);
            }
            monitorStoppedTicks = 0;
            monitorTimelineTicks += 1;

            if (monitorTimelineTicks >= 3) {
                monitorTimelineTicks = 0;
                reportTimeline(monitoredSceneIndex);
            }

            return;
        }

        // Ignore the quantization/pre-launch gap until the scene has actually started.
        if (!monitorHasStarted) {
            return;
        }

        // Small debounce so a transient API state does not advance the show.
        monitorStoppedTicks += 1;
        if (monitorStoppedTicks < 3) {
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
    monitorTimelineTicks = 0;
}

function sceneIsPlayingOrTriggered(sceneIndex) {
    var setApi = new LiveAPI("live_set");
    var trackCount = parseInt(setApi.getcount("tracks"), 10);

    for (var t = 0; t < trackCount; t++) {
        var trackApi = new LiveAPI("live_set tracks " + t);
        var playingIndex = parseInt(cleanValue(trackApi.get("playing_slot_index")), 10);

        if (!isNaN(playingIndex) && playingIndex === sceneIndex) {
            return true;
        }

        var slotCount = parseInt(trackApi.getcount("clip_slots"), 10);
        if (sceneIndex < slotCount) {
            var slotApi = new LiveAPI(
                "live_set tracks " + t + " clip_slots " + sceneIndex
            );
            var triggered = parseInt(cleanValue(slotApi.get("is_triggered")), 10);
            if (triggered === 1) {
                return true;
            }
        }
    }

    return false;
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
    var setApi = new LiveAPI("live_set");
    var tempo = parseFloat(cleanValue(setApi.get("tempo")));
    if (isNaN(tempo) || tempo <= 0) {
        tempo = 120;
    }

    var trackCount = parseInt(setApi.getcount("tracks"), 10);
    var maxDuration = 0;

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
