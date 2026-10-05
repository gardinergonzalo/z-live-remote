# Ableton — Z Live Remote v0.4.0 Beta

Integración de Z Live Remote con Ableton Live 12 Suite mediante Max for Live.

## Archivos activos del dispositivo

El dispositivo Max for Live usa estos dos archivos, que deben quedar en la misma carpeta del .amxd:

- zlr_scene_reader.js
- zlr_transport.js

La versión v0.4.0 mantiene el flujo aprobado de vivo:

PREPARADA → DISPARAR → REPRODUCIENDO → final natural → siguiente PREPARADA

Además agrega recuperación de monitoreo: si la app, el Bridge o Node for Max se reconectan mientras una canción sigue sonando, un nuevo scan vuelve a detectar la Scene activa, restaura la línea de tiempo y retoma el monitor que prepara la siguiente Scene al finalizar.

## Conexión

- Bridge → Max: UDP localhost 45455
- Max → Bridge: UDP localhost 45454
- Bridge ↔ iPhone/iPad: Bluetooth LE

La app sólo muestra CONECTADO cuando existen las dos partes del enlace: Bluetooth con el Bridge y respuesta reciente de Max for Live/Ableton.

## Instalación

1. Mantener el .amxd actual de Z Live Remote en una pista MIDI del Set.
2. Reemplazar en su carpeta los dos JS por las versiones v0.4.0.
3. Recargar el dispositivo o volver a abrir el Set.
4. Abrir Z Live Remote Bridge v0.4.0.
5. Abrir Z Live Remote v0.4.0 en iPhone/iPad.

En Max Console debe aparecer:

node.script • Z Live Remote transport listening on UDP 45455

## Convención de Scenes

Nombre de canción | Referencia 1 | Referencia 2 | ...

Las Scenes completamente vacías se omiten de la Setlist.
