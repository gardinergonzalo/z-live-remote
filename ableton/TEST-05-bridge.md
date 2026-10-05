# Test 05 — Bridge Mac ↔ Max for Live

Este test agrega la capa local entre Max for Live y la app Bridge de macOS.

## Arquitectura

```
iPhone/iPad
    ⇅ BLE
Z Live Remote Bridge (Mac)
    ⇅ UDP localhost
node.script zlr_transport.js
    ⇅
js zlr_scene_reader.js
    ⇅
Ableton Live
```

La comunicación Max ↔ Bridge usa únicamente `127.0.0.1`, por lo que no depende de Wi‑Fi ni Internet.

Puertos:

- Bridge escucha eventos de Max en UDP `45454`.
- Max escucha órdenes del Bridge en UDP `45455`.

## Cambios en el patch de Max

Agregar un objeto:

```
node.script zlr_transport.js @autostart 1
```

Conexiones:

```
                 ┌──────────────────────────────┐
                 │                              │
                 ▼                              │
[js zlr_scene_reader.js] ── outlet 0 ──► [node.script zlr_transport.js]
          │
          └──────── outlet 1 ───────────► [node.script zlr_transport.js]

[node.script zlr_transport.js] ── outlet 0 ──► inlet de [js zlr_scene_reader.js]
```

Los dos outlets del lector pueden seguir conectados a los `print` usados para diagnóstico.

## Prueba local antes del iPhone

1. Ejecutar `ZLiveRemoteBridge` en la Mac.
2. Abrir el Set y el dispositivo Max.
3. Confirmar en Max Console: `Z Live Remote transport listening on UDP 45455`.
4. El Bridge debe imprimir `[Max → iOS] {"type":"max_transport_ready"}`.
5. Al conectarse el iPhone, el Bridge podrá reenviar `scan/select/fire/stop`.


## Resultado parcial

**Max transport: APROBADO**

La consola real de Max mostró:

`Z Live Remote transport listening on UDP 45455`

Esto confirma que `node.script zlr_transport.js` inició correctamente y está escuchando las órdenes locales del Bridge.

El aviso `Trying to set the process_id for a child process, but it already has one` no impidió que el listener quedara activo; se mantiene bajo observación durante las siguientes pruebas.


## Resultado Bridge ↔ Max

**Bridge ↔ Max: APROBADO**

Prueba real en macOS 15.7.7:

- `node.script zlr_transport.js` escucha en UDP 45455;
- Z Live Remote Bridge se inicia como app de barra de menú;
- el Bridge muestra `Ableton: Conectado`;
- Bluetooth queda en `Esperando iPhone/iPad`.

Con esto queda validado el tramo:

`Ableton ↔ Max for Live ↔ Z Live Remote Bridge`

El siguiente test es conectar la app iOS por BLE y recibir la setlist real.
