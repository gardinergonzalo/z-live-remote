# Ableton — Z Live Remote

Integración de Z Live Remote con Ableton Live 12 Suite mediante Max for Live.

## Test 01 — leer Scenes

El primer objetivo es validar, sobre el Set real, que LiveAPI puede:

- enumerar todas las Scenes;
- leer sus nombres completos;
- detectar qué filas tienen clips;
- ignorar filas realmente vacías;
- detectar qué Scene está seleccionada.

Archivo:

`zlr_scene_reader.js`

## Cómo probarlo

1. En Live, cargá un **Max MIDI Effect** vacío en cualquier pista MIDI. Es sólo un dispositivo de prueba.
2. Pulsá el botón de edición del dispositivo para abrir Max.
3. En Max, creá un objeto escribiendo:

```
js zlr_scene_reader.js
```

4. Asegurate de que `zlr_scene_reader.js` esté guardado en la misma carpeta que el dispositivo de prueba, o agregá su carpeta al File Preferences/Search Path de Max.
5. Creá dos objetos `print`:
   - `print ZLR_STATUS`
   - `print ZLR_SCENES`
6. Conectá:
   - outlet izquierdo del objeto `js` → `print ZLR_STATUS`
   - outlet derecho del objeto `js` → `print ZLR_SCENES`
7. Creá un mensaje con el texto `scan` y conectalo a la entrada del objeto `js`.
8. Bloqueá el patch si hace falta y pulsá `scan`.
9. Abrí **Window → Max Console**.

Deberías ver filas parecidas a:

```
ZLR_STATUS: scan_begin 22
ZLR_SCENES: scene 0 1 1 123 PUESTO | ...
ZLR_SCENES: scene 1 1 1 124 RISA | ...
...
ZLR_STATUS: selected_scene 4 127 VAMPI +1 | ...
ZLR_STATUS: scan_end
```

Columnas de `scene`:

```
scene <indice_desde_0> <valida_1_0> <tiene_clips_1_0> <live_id> <nombre>
```

## Qué necesito de la prueba

Mandar captura o copiar el bloque de Max Console donde se vean:

- 3–5 canciones reales;
- una de las filas vacías (por ejemplo las equivalentes a 16/18 del Set);
- `selected_scene`.

No hace falta todavía probar Bluetooth ni disparar una Scene.
