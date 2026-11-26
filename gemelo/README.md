# #7 — Control de acceso: gemelo digital en SWI-Prolog

Modelo lógico de una planta maquiladora (5 puertas, 8 personas, 4 zonas) que decide,
explica y desempata. Todo vive en Prolog: hechos, reglas, explicaciones y servidor web.
La interfaz solo consulta `/api/` y muestra.

## Cómo correrlo

Requisito: [SWI-Prolog](https://www.swi-prolog.org/download/stable) 9.x en el PATH.

```bash
cd gemelo
swipl -g run_tests -t halt tests/reglas_tests.pl   # 40 pruebas plunit
swipl servidor.pl                                   # http://localhost:8080
```

Otro puerto: `swipl servidor.pl 9000`. Para detener el servidor: `halt.` en la consola de Prolog.

## Archivos

| Archivo | Contenido |
|---|---|
| `hechos.pl` | Estado de la planta: personas, turnos, permisos, puertas, credenciales, sincronizaciones, bitácora, sensores, excepciones, traslados y umbrales |
| `reglas.pl` | Reglas: `decide/3`, `situacion/3`, lógica de tres valores, hipótesis, consulta inversa, rutas de evacuación, puertas anómalas |
| `servidor.pl` | Servidor HTTP (`library(http/...)`) con respuestas JSON bajo `/api/` y archivos estáticos de `web/` |
| `frases.pl` | Presentación: traduce los términos que deducen las reglas a frases en español para la interfaz (no decide nada) |
| `tests/reglas_tests.pl` | Pruebas plunit: una suite por situación y una por las cinco preguntas |
| `web/index.html` | Interfaz responsiva (celular y escritorio) basada en el diseño de Google Stitch (`../design/`). Cinco vistas: plano, intento, alertas, emergencia y tarjeta. Sin reglas ni umbrales; no necesita internet |

## Contrato

- `decide(intento(Tarjeta, Puerta, Lector, Minuto), Decision, Explicacion)`. Decide con lo que se sabía en ese instante. `Decision` ∈ `abrir | negar | abrir_y_alertar | negar_y_alertar`.
- `auditar/3`: el mismo intento con todo lo que la bitácora ha recibido hasta `ahora` (incluye eventos que llegaron tarde).
- `situacion(?Entidad, ?Situacion, -Evidencia)`: situaciones deducidas, consultables en cualquier dirección. Por ejemplo `situacion(Q, dentro(almacen), _)` o `situacion(puerta(almacen), S, E)`.
- La explicación es una lista de:
  - `c(Condicion, si|no|no_se_sabe, Detalle)`;
  - `choque(ReglaA, ReglaB, gana(R), se_le_falla(Quien))`;
  - `alerta(AQuien, Que)`;
  - `politica(Puerta, Decision)`, cuando la duda la resuelve la política.
- `con_hipotesis(Cambios, Meta)`: cambia hechos temporalmente (`agrega/1`, `quita/1`) y responde con las mismas reglas.
- `que_falta(Intento, Cambios)`: cambios de un solo hecho que voltean una negación. Cada uno se verifica volviendo a llamar a `decide/3`.

### API

| Ruta | Qué responde |
|---|---|
| `GET /api/estado?t=` | Puertas (energía, contacto, sincronización, desactualizada, evacuable) y personas con su zona |
| `GET /api/dentro?zona=&t=` | Quién está dentro |
| `GET /api/decide?tarjeta=&puerta=&lector=&t=&modo=tiempo_real\|auditoria` | Decisión con explicación |
| `GET /api/que_falta?tarjeta=&puerta=&lector=&t=` | Qué tendría que cambiar |
| `GET /api/alertas?t=` | Situaciones anómalas con evidencia |
| `GET /api/emergencia?t=` | Rutas de salida, quién no tiene salida, choques y avisos |
| `GET /api/tarjeta?tarjeta=&t=&reporte=` | Puertas expuestas, usos clasificados e incompatibles, hipótesis de reporte |

## Cómo responde a cada situación

1. **¿Le toca entrar a esta hora?** Iván (vespertino) entra a la línea a las 13:00. La regla de turno lo niega, pero la excepción vigente de Marta (supervisora, con facultad en planta) gana, y la explicación nombra el choque. Una excepción vencida o dada por alguien sin facultad no cuenta. Al visitante se le niegan las oficinas; `que_falta` responde que bastaría una excepción de la vigilancia (Marta no tiene facultad en oficinas) o un permiso de rol.
2. **Entró, salió y el sistema no se enteró.** En el minuto 705 el lector de salida está atrasado: la posición de Rosa es `no_se_sabe` y la política del acceso principal (abrir y alertar) decide. En auditoría, ordenando por el reloj del lector, Rosa sí salió en el 700 y la decisión es abrir. Quien reusa la tarjeta de Luis se niega, porque Luis sigue dentro y el lector de salida está al corriente. Si dos eventos opuestos quedan dentro del desfase tolerado, el resultado es `orden_incierto`, nunca un sí o un no silencioso.
3. **La tarjeta robada.** El servidor la revoca en el 601 y se cae del 603 al 633. Acceso principal, línea y almacén aún la aceptan (su última sincronización fue antes de la revocación); oficinas no, porque se sincronizó en el 602. Los tres usos del 610–611 son incompatibles con una sola persona según `traslado/3`. Hipótesis: con el reporte en el 595 se niegan los tres usos. Con el reporte en el 605 no cambia nada, porque el servidor ya estaba caído.
4. **Fuego, sin luz y una tarjeta revocada dentro.** Luis y el portador de la tarjeta revocada salen por la salida de emergencia del almacén, que abre aun con tarjeta revocada: se registra y se alerta. Gana la vida y se le falla a seguridad patrimonial. La entrada del almacén sigue cerrada (fail-secure). Hallazgo: quienes están en la planta quedan **sin salida**, porque el acceso principal también es fail-secure. El gemelo avisa a vigilancia que hay que liberarlo a mano.
5. **La puerta que se abrió sola.** El almacén da cuatro veredictos distintos:

   | Veredicto | Minuto | Por qué |
   |---|---|---|
   | Apertura con excepción | 450 | Orden de trabajo de Jorge; solo se registra |
   | Forzada | 500 | Se despierta al vigilante |
   | Tailgating | 520 | Un acceso, dos personas |
   | Abierta de más | 540 | 8 minutos abierta |

   La línea de producción solo envió una lectura fuera de rango, así que su contacto es `no_se_sabe`, no "cerrada", y no se dispara una alerta falsa.

Las cinco preguntas de «Por qué no basta un script» se contestan en `tests/reglas_tests.pl` (suite `c6_cinco_preguntas`) con los mismos predicados. No hay ningún predicado por pregunta.

## Supuestos

- Minuto 0 = 00:00 del día 1; `ahora(720)` = 12:00.
- Turnos: matutino 06:00–14:00, vespertino 14:00–22:00, nocturno 22:00–06:00. Tolerancia de 15 minutos antes del turno.
- El acceso principal es de **acceso general**: entra cualquier tarjeta activa. El turno se controla en la línea, el almacén y las oficinas.
- Permisos por rol: ver `permiso/3` en `hechos.pl`. Las oficinas tienen horario propio, de 08:00 a 18:00.
- Pueden dar excepciones la supervisora (en planta y almacén) y la vigilancia (en planta, almacén y oficinas).
- Desfase tolerado entre relojes de lectores: 2 minutos. "Abierta de más": más de 3 minutos. Un acceso explica una apertura si ocurrió a lo más 1 minuto antes.
- **Política ante la duda:** en el acceso principal, abrir y alertar, para no dejar atrapada afuera a una trabajadora con tarjeta activa; la zona es general. En las demás puertas, negar y alertar.
- Una tarjeta reportada o revocada no está activa. Con servidor disponible, la puerta consulta en línea; sin servidor, usa la copia de su última sincronización.
- Con energía y alarma, las puertas se liberan para salir. Sin energía, fail-secure queda cerrada y fail-safe queda abierta. La salida de emergencia abre siempre.
- Las distancias a pie entre puertas (`traslado/3`) son inventadas para el escenario reducido.
- La posición de cada persona sale de la bitácora: no hay sensor que la mida. Quien entra con llave mecánica no queda registrado.

## Cifras del documento (a verificar con la fuente vigente antes de citarlas)

| Cifra | Origen | Estado |
|---|---|---|
| 3 usos en 1 minuto, 30 min de servidor incomunicado | Escenario del problema original | Usadas tal cual |
| Salidas de emergencia deben abrir siempre (NOM-002-STPS-2010) | Problema original | Pendiente verificar en el DOF |
| 40 puertas, 2,000 personas, 150 lecturas/min, decisión en ~0.5–1 s | Problema original | No se evalúan en esta extensión |

## Erlang y Prolog: qué va en cada lado

En Erlang/OTP se resuelve lo que **pasa**: muchas puertas concurrentes, cada una un proceso que decide en menos de un segundo, sigue funcionando aunque el servidor caiga y se reinicia bajo supervisión. A eso se suma una bitácora que no pierde eventos bajo carga. Es un problema de concurrencia, tolerancia a fallas y tiempo real. En Prolog se resuelve lo que **debía pasar y por qué**: el permiso se deduce de rol, turno, zona, excepción y facultad, y cada decisión se explica. Prolog distingue "no salió" de "no me enteré", razona con lo que sabe cada puerta frente a lo que sabe el servidor, desempata reglas válidas que chocan (emergencia contra revocación) y responde con las mismas reglas la decisión, la explicación, todas las respuestas, la pregunta al revés y la hipótesis. Erlang no es bueno para deducir y justificar, y Prolog no es bueno para atender 150 lecturas por minuto con procesos que se caen. Por eso cada cosa va en su lugar.

## Diseño

Las pantallas se diseñaron en Google Stitch (versión de escritorio y de celular). El export completo
(`DESIGN.md`, `code.html` y `screen.png` de cada pantalla) está en `../design/`. La interfaz real en
`web/` sigue su paleta, tipografía y estructura, pero solo muestra lo que responde el gemelo.
