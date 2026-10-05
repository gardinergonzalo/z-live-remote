# Test 03 — Disparar y preparar la siguiente Scene

Este test valida el flujo real de escenario:

1. Hay una Scene seleccionada y preparada.
2. Se dispara esa Scene.
3. La canción empieza a reproducirse.
4. La siguiente Scene queda seleccionada/preparada.
5. La siguiente Scene **no** se dispara automáticamente.

## Comando

```
fire_next
```

Internamente usa la función de Live API `Scene.fire_as_selected()`, diseñada para lanzar la Scene seleccionada y luego seleccionar la siguiente.

## Prueba

Con `VAMPI +1` seleccionada:

1. Crear un message box `fire_next`.
2. Conectarlo al mismo inlet de `js zlr_scene_reader.js`.
3. Pulsarlo una vez.

Resultado esperado:

- `VAMPI +1` empieza a sonar.
- `INGREDIENTES` queda seleccionada.
- `INGREDIENTES` no empieza a sonar.

La consola debe mostrar `fired_and_prepared_next` y después un `selected_scene` correspondiente a la siguiente Scene.
