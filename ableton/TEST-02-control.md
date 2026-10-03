# Test 02 — Control de Scene

Objetivo: comprobar que Z Live Remote puede controlar una Scene real desde Max for Live.

## Comandos agregados

El mismo objeto:

```
js zlr_scene_reader.js
```

acepta ahora:

```
select 4
fire
stop
```

### select N

Selecciona la Scene por índice interno de Live, comenzando en 0.

Ejemplo:

```
select 4
```

debe seleccionar la quinta Scene del Set (en el Set actual: VAMPI +1), pero **no reproducirla**.

### fire

Dispara la Scene actualmente seleccionada usando la función oficial `Scene.fire()`.

### stop

Ejecuta `Song.stop_all_clips()`.

## Prueba recomendada

1. Agregar tres message boxes al patch: `select 4`, `fire`, `stop`.
2. Conectar las tres al inlet del objeto `js zlr_scene_reader.js`.
3. Pulsar primero `select 4`.
4. Confirmar visualmente que Live selecciona VAMPI +1 sin reproducir.
5. Con salida de audio controlada, pulsar `fire`.
6. Confirmar que la Scene se dispara.
7. Pulsar `stop` para detener todos los clips.

## Resultado esperado en Max Console

```
ZLR_STATUS: selected_by_zlr 4 ... "VAMPI +1 | ..."
ZLR_STATUS: fired_scene 4 ... "VAMPI +1 | ..."
ZLR_STATUS: stop_all_clips
```
