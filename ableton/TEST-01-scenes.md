# Test 01 — Scene Reader

Estado: listo para prueba manual.

## Resultado esperado

Sobre el Set real:

- Las canciones deben salir con su nombre completo.
- Una fila con clips debe marcar `valida=1`.
- Una fila completamente vacía debe marcar `valida=0`.
- `selected_scene` debe coincidir con la Scene resaltada en Live.

## Criterio para Scene válida

La prueba considera válida una Scene si:

1. contiene al menos un clip en cualquier pista, o
2. tiene un nombre personalizado no vacío/no puramente numérico.

Esto permite conservar Scenes útiles aunque algún tema no tenga clips en todas las pistas y omitir separadores completamente vacíos.
