# Arquitectura inicial — Z Live Remote

## Flujo funcional

```
iPhone / iPad
      ⇅
comunicación local
      ⇅
Bridge macOS
      ⇅
Max for Live
      ⇅
Ableton Live 12 Suite
```

## Estados principales

- **SIN CONEXIÓN**
- **PREPARADA**
- **REPRODUCIENDO**

## Reglas de navegación

- Anterior/Siguiente solo seleccionan.
- DISPARAR ejecuta la Scene preparada.
- STOP queda separado de la acción principal.
- Al finalizar una canción, se busca la siguiente Scene válida.
- Scenes vacías se omiten.
- La siguiente canción queda PREPARADA, nunca se dispara automáticamente.

## Datos de Scene

Formato esperado:

```
CANCIÓN | Sonido 1 | Sonido 2 | Sonido 3
```

Interpretación:

- Primer segmento: nombre de canción.
- Segmentos restantes: sonidos/referencias.
- Sin límite lógico de referencias.
- La interfaz adapta el título a una o dos líneas antes de recurrir a desplazamiento.

## Prioridad de interfaz

Diseño primero para iPhone 14 y adaptación responsive a iPad Pro.
