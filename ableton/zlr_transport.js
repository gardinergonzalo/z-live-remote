// Z Live Remote v0.5.4 - Node for Max transport
const maxApi = require("max-api");
const dgram = require("dgram");

const BRIDGE_HOST = "127.0.0.1";
const BRIDGE_PORT = 45454;
const MAX_PORT = 45455;

const outbound = dgram.createSocket("udp4");
const inbound = dgram.createSocket("udp4");

function send(payload) {
    try {
        const data = Buffer.from(JSON.stringify(payload), "utf8");
        outbound.send(data, BRIDGE_PORT, BRIDGE_HOST);
    } catch (error) {
        maxApi.post(`Z Live Remote transport send error: ${error}`, maxApi.POST_LEVELS.ERROR);
    }
}

function cleanArgs(args) {
    return args.map(value => {
        if (typeof value === "number") return value;
        return String(value);
    });
}

maxApi.addHandler("scan_begin", count => {
    send({ type: "scan_begin", count: Number(count) });
});

maxApi.addHandler("scan_end", () => {
    send({ type: "scan_end" });
});

maxApi.addHandler("scene", (index, valid, hasClips, liveId, bpm, ...nameParts) => {
    send({
        type: "scene",
        index: Number(index),
        valid: Number(valid),
        hasClips: Number(hasClips),
        liveId: Number(liveId),
        bpm: Number(bpm),
        name: nameParts.join(" ")
    });
});

maxApi.addHandler("selected_scene", (index, liveId, ...nameParts) => {
    send({
        type: "selected_scene",
        index: Number(index),
        liveId: Number(liveId),
        name: nameParts.join(" ")
    });
});

maxApi.addHandler("selected_by_zlr", (index, liveId, ...nameParts) => {
    send({
        type: "selected_scene",
        index: Number(index),
        liveId: Number(liveId),
        name: nameParts.join(" ")
    });
});

maxApi.addHandler("fired_watching", (index, liveId, ...nameParts) => {
    send({
        type: "fired_watching",
        index: Number(index),
        liveId: Number(liveId),
        name: nameParts.join(" ")
    });
});

maxApi.addHandler("scene_started", index => {
    send({ type: "scene_started", index: Number(index) });
});

maxApi.addHandler("scene_finished", (...args) => {
    send({ type: "scene_finished", args: cleanArgs(args) });
});

maxApi.addHandler("scene_bpm", (index, bpm) => {
    send({
        type: "scene_bpm",
        index: Number(index),
        bpm: Number(bpm)
    });
});

maxApi.addHandler("scene_duration", (index, duration) => {
    send({
        type: "scene_duration",
        index: Number(index),
        duration: Number(duration)
    });
});

maxApi.addHandler("timeline", (index, elapsed, duration, progress) => {
    send({
        type: "timeline",
        index: Number(index),
        elapsed: Number(elapsed),
        duration: Number(duration),
        progress: Number(progress)
    });
});

maxApi.addHandler("timeline_reset", () => {
    send({ type: "timeline_reset" });
});

maxApi.addHandler("setlist_change_pending", () => {
    send({ type: "setlist_change_pending" });
});


maxApi.addHandler("prepared_next", (index, liveId, ...nameParts) => {
    send({
        type: "prepared_next",
        index: Number(index),
        liveId: Number(liveId),
        name: nameParts.join(" ")
    });
});

maxApi.addHandler("stop_all_clips", () => {
    send({ type: "stop_all_clips" });
});

function forwardMaxError(kind, args) {
    send({
        type: "max_error",
        message: [kind, ...cleanArgs(args)].join(" ")
    });
}

maxApi.addHandler("error", (...args) => {
    forwardMaxError("error", args);
});

[
    "error_selected",
    "select_error",
    "fire_error",
    "fire_watch_error",
    "stop_error",
    "monitor_error",
    "timeline_error"
].forEach(kind => {
    maxApi.addHandler(kind, (...args) => {
        forwardMaxError(kind, args);
    });
});

inbound.on("message", message => {
    try {
        const command = JSON.parse(message.toString("utf8"));

        switch (command.type) {
            case "scan":
                maxApi.outlet("scan");
                break;
            case "select":
                maxApi.outlet("select", Number(command.index));
                break;
            case "fire":
                maxApi.outlet("fire_watch");
                break;
            case "stop":
                maxApi.outlet("stop");
                break;
            case "ping":
                send({ type: "pong" });
                break;
            default:
                maxApi.post(
                    `Z Live Remote unknown command: ${JSON.stringify(command)}`,
                    maxApi.POST_LEVELS.WARN
                );
        }
    } catch (error) {
        maxApi.post(`Z Live Remote transport receive error: ${error}`, maxApi.POST_LEVELS.ERROR);
    }
});

inbound.on("listening", () => {
    const address = inbound.address();
    maxApi.post(`Z Live Remote transport listening on UDP ${address.port}`);
    send({ type: "max_transport_ready" });
});

inbound.bind(MAX_PORT, "127.0.0.1");

process.on("exit", () => {
    try { inbound.close(); } catch (_) {}
    try { outbound.close(); } catch (_) {}
});
