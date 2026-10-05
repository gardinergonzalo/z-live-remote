# Test 03 — descartado: fire_as_selected

El comando experimental `fire_next` no implementa el flujo deseado de Z Live Remote.

La API de Live define `Scene.fire_as_selected()` como:

1. disparar la Scene seleccionada;
2. seleccionar inmediatamente la siguiente Scene.

Z Live Remote necesita otro comportamiento:

1. disparar la Scene preparada;
2. mantenerla como Scene activa mientras suena;
3. detectar que terminó;
4. recién entonces seleccionar la siguiente Scene válida;
5. no disparar la siguiente.

Por eso `fire_next` queda conservado sólo como prueba histórica y **no debe usarse para el flujo del show**.

El comportamiento correcto se prueba en `TEST-04-auto-prepare.md` mediante `fire_watch`.
