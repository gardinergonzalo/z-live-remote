# Z Live Remote

Control remoto de escenario para Ableton Live 12 Suite, pensado para iPhone y iPad.

## Objetivo

Permitir seleccionar y disparar canciones desde iPhone/iPad manteniendo la Mac fuera del centro de la escena.

Flujo principal:

1. Ableton tiene una canción preparada.
2. La app muestra nombre, sonidos/referencias y la siguiente canción.
3. **DISPARAR** lanza la escena preparada.
4. Al terminar la canción, la siguiente escena válida queda seleccionada automáticamente, pero **no se reproduce** hasta volver a pulsar DISPARAR.

## Convención de nombres

Cada Scene de Ableton puede usar:

```
Nombre de canción | Sonido 1 | Sonido 2 | Sonido 3 | ...
```

La app interpreta el primer bloque como título y los siguientes como referencias/sonidos.

## Componentes previstos

- `ios/` — app universal iPhone + iPad.
- `ableton/` — integración con Ableton Live / Max for Live.
- `mac/` — bridge local de comunicación.
- `prototype/` — prototipos de interfaz.
- `docs/` — arquitectura y decisiones técnicas.

## Estado

Prototipo visual v0.1 en desarrollo.
