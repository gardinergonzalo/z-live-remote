package com.zliveremote.android

import org.json.JSONObject

data class Song(
    val id: Int,
    val name: String,
    val sounds: List<String>
) {
    companion object {
        fun parseSceneName(rawName: String, sceneIndex: Int): Song? {
            val parts = rawName.split("|").map { it.trim() }
            val name = parts.firstOrNull().orEmpty()
            if (name.isBlank()) return null

            return Song(
                id = sceneIndex,
                name = name,
                sounds = parts.drop(1).filter { it.isNotBlank() }
            )
        }
    }
}

enum class PlaybackState(val label: String) {
    DISCONNECTED("SIN CONEXIÓN"),
    READY("PREPARADA"),
    PLAYING("REPRODUCIENDO")
}

data class BridgeEvent(
    val type: String,
    val version: Int? = null,
    val device: String? = null,
    val count: Int? = null,
    val index: Int? = null,
    val valid: Int? = null,
    val hasClips: Int? = null,
    val liveId: Int? = null,
    val name: String? = null,
    val message: String? = null,
    val elapsed: Double? = null,
    val duration: Double? = null,
    val progress: Double? = null,
    val bpm: Double? = null,
    val maxConnected: Boolean? = null
) {
    companion object {
        fun fromJson(line: String): BridgeEvent? {
            return try {
                val json = JSONObject(line)
                BridgeEvent(
                    type = json.optString("type"),
                    version = json.optIntOrNull("version"),
                    device = json.optStringOrNull("device"),
                    count = json.optIntOrNull("count"),
                    index = json.optIntOrNull("index"),
                    valid = json.optIntOrNull("valid"),
                    hasClips = json.optIntOrNull("hasClips"),
                    liveId = json.optIntOrNull("liveId"),
                    name = json.optStringOrNull("name"),
                    message = json.optStringOrNull("message"),
                    elapsed = json.optDoubleOrNull("elapsed"),
                    duration = json.optDoubleOrNull("duration"),
                    progress = json.optDoubleOrNull("progress"),
                    bpm = json.optDoubleOrNull("bpm"),
                    maxConnected = json.optBooleanOrNull("maxConnected")
                )
            } catch (_: Throwable) {
                null
            }
        }
    }
}

private fun JSONObject.optStringOrNull(key: String): String? =
    if (has(key) && !isNull(key)) optString(key) else null

private fun JSONObject.optIntOrNull(key: String): Int? =
    if (has(key) && !isNull(key)) optInt(key) else null

private fun JSONObject.optDoubleOrNull(key: String): Double? =
    if (has(key) && !isNull(key)) optDouble(key) else null

private fun JSONObject.optBooleanOrNull(key: String): Boolean? =
    if (has(key) && !isNull(key)) optBoolean(key) else null

sealed interface BridgeCommand {
    fun json(): String

    data object Scan : BridgeCommand {
        override fun json() = """{"type":"scan"}"""
    }

    data object Fire : BridgeCommand {
        override fun json() = """{"type":"fire"}"""
    }

    data object Stop : BridgeCommand {
        override fun json() = """{"type":"stop"}"""
    }

    data object Ping : BridgeCommand {
        override fun json() = """{"type":"ping"}"""
    }

    data class Select(val sceneIndex: Int) : BridgeCommand {
        override fun json() = """{"type":"select","index":$sceneIndex}"""
    }
}
