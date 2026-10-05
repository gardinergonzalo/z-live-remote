# Test 04 — preparar siguiente al terminar

## Objetivo

Validar el flujo real del show:

```
PREPARADA
  ↓ fire_watch
REPRODUCIENDO
  ↓ termina naturalmente
SIGUIENTE PREPARADA
  ↓ espera
```

## Comando

```
fire_watch
```

Este comando:

- dispara únicamente la Scene seleccionada;
- vigila los `playing_slot_index` / `is_triggered` de esa fila;
- espera a que la Scene haya comenzado realmente;
- detecta cuando ya no queda ningún clip de esa Scene sonando/disparándose;
- busca la siguiente Scene válida, saltando filas vacías;
- la selecciona sin dispararla.

## STOP manual

El comando `stop` cancela el monitor antes de detener los clips, para que un STOP manual no sea confundido con el final natural de la canción.

## Resultado esperado

Con VAMPI +1 preparada:

1. `fire_watch` → suena VAMPI +1.
2. Mientras suena, VAMPI +1 sigue siendo la Scene preparada/seleccionada por nuestra lógica.
3. Al terminar realmente los clips de esa Scene, INGREDIENTES queda seleccionada.
4. INGREDIENTES no se reproduce.
5. Si entre ambas hubiera una Scene vacía, se salta automáticamente.

La consola debe mostrar, en orden aproximado:

```
fired_watching 4 ...
scene_started 4
scene_finished 4
prepared_next 5 ... INGREDIENTES ...
```


## Resultado de prueba real

**APROBADO**

En el Set real de Ableton Live 12 Suite:

- la Scene actual se dispara;
- al terminar naturalmente, la siguiente Scene válida queda seleccionada;
- la reproducción queda detenida;
- la siguiente Scene no se dispara automáticamente.

Este es el flujo objetivo de Z Live Remote para escenario.
