autowatch = 1;

inlets = 1;
outlets = 2;

/*
 Z Live Remote - Scene Reader Test
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
    } catch (e) {
        outlet(0, ["error_selected", String(e)]);
        post("Z Live Remote selected scene error: " + e + "\n");
    }
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
        var setApi = new LiveAPI("live_set");
        setApi.call("stop_all_clips");
        outlet(0, ["stop_all_clips"]);
    } catch (e) {
        outlet(0, ["stop_error", String(e)]);
        post("Z Live Remote stop error: " + e + "\n");
    }
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
