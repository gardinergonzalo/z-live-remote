# TEST 08 — Robustez v0.4.0 Beta

Objetivo: comprobar que Z Live Remote se recupera de cortes sin ejecutar acciones falsas ni perder la Scene preparada en Ableton.

## Estado base

- Ableton Live abierto con el dispositivo Z Live Remote.
- Bridge v0.4.0 abierto.
- App v0.4.0 abierta.
- Estado visible: CONECTADO.
- Una Scene válida preparada.

## Pruebas

### 1. Cerrar y abrir la app
Esperado: reconecta sola, vuelve a leer la Setlist y muestra la misma Scene seleccionada en Ableton.

### 2. Cerrar y abrir el Bridge
Esperado: pasa a SIN CONEXIÓN, reconecta sola al abrir el Bridge y vuelve a sincronizar la Scene preparada.

### 3. Max for Live temporalmente no disponible
Esperado: después de unos 5 segundos, Bridge muestra Esperando Max for Live y la app SIN CONEXIÓN. DISPARAR y navegación no simulan acciones locales. Al volver Max, hace scan automático.

### 4. Bluetooth
Esperado: al apagar Bluetooth pasa a SIN CONEXIÓN. Al encenderlo, reconecta sin reiniciar la app.

### 5. Reconexión durante reproducción
Esperado: al volver la conexión detecta la Scene que sigue sonando, muestra REPRODUCIENDO, recupera la línea de tiempo y conserva el auto-preparado de la siguiente Scene al terminar.

### 6. STOP protegido
Esperado: mantener STOP aproximadamente 0,8 s detiene clips, queda PREPARADA y reinicia el progreso sin avanzar automáticamente.

## Criterio de aprobación

La Beta v0.4.0 queda aprobada para ensayo/show si las seis pruebas pasan sin disparos fantasma, cambios locales de Scene durante desconexión ni necesidad de reiniciar manualmente la app.
