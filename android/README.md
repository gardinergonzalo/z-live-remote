# Z Live Remote Android

Android client for the same BLE protocol used by the iPhone/iPad app.

## Runtime architecture

Ableton Live + Max for Live -> Z Live Remote Bridge on macOS -> BLE -> iOS and/or Android.

The Android app does not require Wi-Fi or Internet during the show.

## Requirements

- Android 8.0 (API 26) or newer.
- Bluetooth LE.
- Z Live Remote Bridge v0.6.0 or newer for simultaneous iOS + Android clients.
- Max Component v0.5.4 or newer.

## Current beta features

- BLE auto-connect/reconnect.
- Scene setlist from Ableton.
- Scene BPM and references.
- Local timeline animation with one real sync point from Live.
- Immediate FIRE and STOP.
- Previous/Next locked while a Scene is playing.
- Natural end -> prepare next Scene without autoplay.
- FIN Scene marker ends the active show.
- Setlist auto-refresh after Scene reorder.
- Connection watchdog and visible alerts.
- Show Info: duration, BPM average/range and BPM energy bars.
- Recovers current playing Scene after reopening the app.

## Multi-device

Bridge v0.6.0 supports multiple subscribed BLE centrals. iPhone/iPad and Android may remain connected at the same time. Events from Ableton are broadcast to all connected mobiles; a valid control command from either device controls the same Ableton session.

For live safety, use one device as the primary controller and the second as a synchronized backup rather than pressing controls on both simultaneously.
