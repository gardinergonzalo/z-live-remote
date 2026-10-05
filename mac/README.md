# Z Live Remote Bridge — macOS

Bridge local entre Ableton Live y la app Z Live Remote para iPhone/iPad.

## Compatibilidad objetivo

- macOS 13 o superior.
- Intel x86_64 validado por GitHub Actions sobre `macos-13`.
- El equipo de prueba actual usa macOS 15.7.7.

## Qué hace

- Anuncia por Bluetooth LE un servicio llamado **Z Live Remote**.
- Recibe desde iPhone/iPad: `scan`, `select`, `fire`, `stop`.
- Reenvía esas órdenes a Max for Live por UDP local.
- Recibe eventos/setlist desde Max y los devuelve al iPhone/iPad por BLE.

## Red local

No usa la red Wi‑Fi del lugar.

Max ↔ Bridge usa sólo:

```
127.0.0.1
```

## Puertos

- `45454/UDP`: eventos Max → Bridge.
- `45455/UDP`: órdenes Bridge → Max.

## Build

```
swift build -c release --package-path mac/bridge
```

GitHub Actions genera además un artifact Intel llamado:

`ZLiveRemoteBridge-macOS-Intel`
