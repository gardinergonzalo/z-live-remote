# Test 06 — iPhone ↔ Bridge ↔ Ableton

**APROBADO**

Prueba real completada con:

- iPhone con Z Live Remote instalado vía Sideloadly;
- conexión Bluetooth LE directa con Z Live Remote Bridge;
- macOS 15.7.7 Intel;
- Ableton Live 12 Suite + Max for Live;
- Bridge mostrando simultáneamente:
  - `Bluetooth: Conectado`
  - `Ableton: Conectado`

Resultado:

- la app iOS se conecta correctamente por BLE;
- recibe la setlist real de Ableton;
- deja de mostrar el estado de desconexión;
- el tramo completo queda validado:

`iPhone ↔ Bluetooth LE ↔ Z Live Remote Bridge ↔ UDP localhost ↔ Max for Live ↔ Ableton Live`

Este test valida la arquitectura base de Z Live Remote.
