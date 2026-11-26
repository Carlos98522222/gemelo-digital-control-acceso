:- encoding(utf8).
/*  hechos.pl — Estado de la planta (gemelo digital, proyecto #7)

    Planta maquiladora reducida: 5 puertas, 8 personas, 4 zonas.
    El tiempo se mide en minutos desde el inicio del escenario
    (minuto 0 = 00:00 del dia 1). El "ahora" es un hecho, no el reloj.

    Convencion de puertas: puerta(P, LadoExterior, LadoInterior, Modo, Tipo).
    Un lector "entra" lleva del lado exterior al interior; uno "sale", al reves.
    (La salida de emergencia del almacen se modela como calle -> almacen
    para que su barra de salida lleve del almacen a la calle.)
*/

:- dynamic
    ahora/1, persona/3, turno/3, permiso/3, puerta/5, credencial/4,
    sincronizada/2, evento/6, lectura/4, rango/3, excepcion/6, traslado/3,
    % predicados propios (agregados al vocabulario base)
    acceso_general/1, lector/3, sensor/2, horario_zona/3, facultad/2,
    servidor_caido/2, retraso_lector/5, politica_duda/2, umbral/2.

:- discontiguous evento/6, lectura/4, credencial/4, sincronizada/2.

%% ---------------------------------------------------------------
%% Tiempo
%% ---------------------------------------------------------------

ahora(720).                       % 12:00 del dia 1

turno(matutino,    360,  840).    % 06:00 - 14:00
turno(vespertino,  840, 1320).    % 14:00 - 22:00
turno(nocturno,   1320, 1800).    % 22:00 - 06:00 (dia 2)

%% Umbrales (SUPUESTOS del estudiante, ver README)
umbral(tolerancia_turno, 15).     % se puede entrar 15 min antes del turno
umbral(desfase_relojes,   2).     % desfase tolerado entre lectores (min)
umbral(abierta_de_mas,    3).     % puerta abierta mas de 3 min es anomala
umbral(ventana_acceso,    1).     % un acceso explica una apertura si ocurrio <= 1 min antes

%% ---------------------------------------------------------------
%% Personas, roles y permisos
%% ---------------------------------------------------------------

persona(rosa,      operador,      matutino).
persona(ivan,      operador,      vespertino).
persona(pedro,     operador,      nocturno).
persona(marta,     supervisor,    matutino).
persona(luis,      almacenista,   matutino).
persona(jorge,     mantenimiento, matutino).
persona(beto,      vigilante,     matutino).
persona(visitante, visitante,     matutino).

%% permiso(Rol, Zona, Turno): Turno = su_turno | todos
permiso(operador,      planta,   su_turno).
permiso(supervisor,    planta,   todos).
permiso(supervisor,    oficinas, todos).
permiso(supervisor,    almacen,  su_turno).
permiso(almacenista,   planta,   su_turno).
permiso(almacenista,   almacen,  su_turno).
permiso(mantenimiento, planta,   su_turno).
permiso(vigilante,     planta,   todos).
permiso(vigilante,     almacen,  todos).
permiso(vigilante,     oficinas, todos).

%% Horario propio de una zona (ademas del turno)
horario_zona(oficinas, 480, 1080).   % 08:00 - 18:00

%% Quien puede dar excepciones y sobre que zona
facultad(supervisor, planta).
facultad(supervisor, almacen).
facultad(vigilante,  planta).
facultad(vigilante,  almacen).
facultad(vigilante,  oficinas).

%% ---------------------------------------------------------------
%% Puertas, lectores y sensores
%% ---------------------------------------------------------------

puerta(acceso_principal,   calle,  planta,   seguro,  normal).
puerta(linea_produccion,   planta, planta,   seguro,  normal).
puerta(almacen,            planta, almacen,  seguro,  normal).
puerta(oficinas,           planta, oficinas, abierto, normal).
puerta(emergencia_almacen, calle,  almacen,  abierto, salida_emergencia).

%% La entrada general a la planta: cualquier tarjeta activa (el turno se
%% controla en la linea, el almacen y las oficinas).
acceso_general(acceso_principal).

%% lector(Puerta, Lector, Sentido)
lector(acceso_principal,   entrada, entra).
lector(acceso_principal,   salida,  sale).
lector(linea_produccion,   entrada, entra).
lector(almacen,            entrada, entra).
lector(almacen,            salida,  sale).
lector(oficinas,           entrada, entra).
lector(emergencia_almacen, barra,   sale).

%% sensor(Puerta, Sensor): que puertas tienen contacto o contador de paso
sensor(almacen,          contacto).
sensor(almacen,          paso).
sensor(linea_produccion, contacto).

rango(contacto, 0, 1).     % 1 = abierta, 0 = cerrada
rango(paso,     0, 5).     % personas que cruzan en una apertura
rango(energia,  0, 1).
rango(alarma,   0, 1).

%% Politica ante la duda (SUPUESTO). Por defecto: negar_y_alertar.
politica_duda(acceso_principal, abrir_y_alertar).

%% Tiempo minimo a pie entre puertas (min), simetrico (SUPUESTO)
traslado(acceso_principal, linea_produccion,   2).
traslado(acceso_principal, almacen,            3).
traslado(acceso_principal, oficinas,           2).
traslado(acceso_principal, emergencia_almacen, 4).
traslado(linea_produccion, almacen,            2).
traslado(linea_produccion, oficinas,           2).
traslado(linea_produccion, emergencia_almacen, 3).
traslado(almacen,          oficinas,           3).
traslado(almacen,          emergencia_almacen, 1).
traslado(oficinas,         emergencia_almacen, 4).

%% ---------------------------------------------------------------
%% Credenciales (historial: el estado vigente es el ultimo con Desde =< T)
%% ---------------------------------------------------------------

credencial(t_rosa,  rosa,      activa, 0).
credencial(t_ivan,  ivan,      activa, 0).
credencial(t_pedro, pedro,     activa, 0).
credencial(t_marta, marta,     activa, 0).
credencial(t_luis,  luis,      activa, 0).
credencial(t_jorge, jorge,     activa, 0).
credencial(t_beto,  beto,      activa, 0).
credencial(t_visit, visitante, activa, 0).

%% Situacion 3: Marta reporta su tarjeta robada y el servidor la revoca
credencial(t_marta, marta, reportada, 600).
credencial(t_marta, marta, revocada,  601).

%% ---------------------------------------------------------------
%% Servidor y sincronizacion
%% ---------------------------------------------------------------

servidor_caido(603, 633).          % 30 minutos incomunicado

sincronizada(acceso_principal,   0).
sincronizada(linea_produccion,   0).
sincronizada(almacen,            0).
sincronizada(oficinas,           0).
sincronizada(emergencia_almacen, 0).
sincronizada(acceso_principal,   597).
sincronizada(linea_produccion,   596).
sincronizada(almacen,            598).
sincronizada(oficinas,           602).   % alcanzo a recibir la revocacion
sincronizada(acceso_principal,   634).
sincronizada(linea_produccion,   634).
sincronizada(almacen,            634).
sincronizada(oficinas,           634).
sincronizada(emergencia_almacen, 634).

%% El lector de salida del acceso principal se atrasa: lo que leyo entre
%% 691 y 711 (su reloj) llega a la bitacora hasta el minuto 712.
retraso_lector(acceso_principal, salida, 691, 711, 712).

%% ---------------------------------------------------------------
%% Excepciones
%% ---------------------------------------------------------------

%% Situacion 1: Marta pide a Ivan llegar antes para cubrir una vacante
excepcion(ivan,  linea_produccion, cobertura_vacante, marta, 760, 900).
%% Situacion 5: orden de trabajo de mantenimiento en el almacen
excepcion(jorge, almacen,          orden_trabajo,     marta, 440, 480).

%% ---------------------------------------------------------------
%% Bitacora: evento(Puerta, Lector, Tarjeta, Resultado, MinLector, MinLlegada)
%% ---------------------------------------------------------------

evento(acceso_principal, entrada, t_rosa,  concedido, 355, 355).
evento(acceso_principal, entrada, t_marta, concedido, 356, 356).
evento(acceso_principal, entrada, t_beto,  concedido, 358, 358).
evento(acceso_principal, entrada, t_jorge, concedido, 362, 362).
evento(acceso_principal, entrada, t_luis,  concedido, 395, 395).
evento(almacen,          entrada, t_luis,  concedido, 400, 400).
evento(almacen,          entrada, t_beto,  concedido, 520, 520).
evento(almacen,          salida,  t_beto,  concedido, 530, 530).
evento(almacen,          entrada, t_beto,  concedido, 540, 540).
evento(almacen,          salida,  t_beto,  concedido, 549, 549).
evento(acceso_principal, entrada, t_visit, concedido, 590, 590).
evento(acceso_principal, salida,  t_marta, concedido, 593, 593).  % Marta sale y pierde la tarjeta
evento(oficinas,         entrada, t_visit, negado,    600, 600).
%% Situacion 3: la tarjeta robada, 3 usos en 1 minuto con el servidor caido
evento(acceso_principal, entrada, t_marta, concedido, 610, 610).
evento(linea_produccion, entrada, t_marta, concedido, 610, 610).
evento(almacen,          entrada, t_marta, concedido, 611, 611).
%% Situacion 2: alguien reusa la tarjeta de Luis (que sigue dentro)
evento(acceso_principal, entrada, t_luis,  negado,    620, 620).
%% Situacion 2: Rosa sale por su chamarra; su salida llega tarde
evento(acceso_principal, salida,  t_rosa,  concedido, 700, 712).
evento(acceso_principal, entrada, t_rosa,  concedido, 705, 705).
%% Situacion 1: Ivan llega antes de su turno
evento(acceso_principal, entrada, t_ivan,  concedido, 775, 775).
evento(linea_produccion, entrada, t_ivan,  concedido, 780, 780).

%% ---------------------------------------------------------------
%% Sensores: lectura(Puerta, Sensor, Valor, Minuto)
%% ---------------------------------------------------------------

%% Energia: se va en el minuto 640 y regresa en el 660
lectura(acceso_principal,   energia, 1,   0).
lectura(linea_produccion,   energia, 1,   0).
lectura(almacen,            energia, 1,   0).
lectura(oficinas,           energia, 1,   0).
lectura(emergencia_almacen, energia, 1,   0).
lectura(acceso_principal,   energia, 0, 640).
lectura(linea_produccion,   energia, 0, 640).
lectura(almacen,            energia, 0, 640).
lectura(oficinas,           energia, 0, 640).
lectura(emergencia_almacen, energia, 0, 640).
lectura(acceso_principal,   energia, 1, 660).
lectura(linea_produccion,   energia, 1, 660).
lectura(almacen,            energia, 1, 660).
lectura(oficinas,           energia, 1, 660).
lectura(emergencia_almacen, energia, 1, 660).

%% Alarma de incendio: suena en el 640, se apaga en el 700
lectura(acceso_principal,   alarma, 0,   0).
lectura(acceso_principal,   alarma, 1, 640).
lectura(acceso_principal,   alarma, 0, 700).

%% Situacion 5: puerta del almacen (contacto y contador de paso)
lectura(almacen, contacto, 1, 400). lectura(almacen, paso, 1, 400). lectura(almacen, contacto, 0, 401).
lectura(almacen, contacto, 1, 450). lectura(almacen, paso, 1, 450). lectura(almacen, contacto, 0, 452).  % llave mecanica (orden de trabajo)
lectura(almacen, contacto, 1, 500). lectura(almacen, paso, 1, 500). lectura(almacen, contacto, 0, 501).  % nadie paso tarjeta
lectura(almacen, contacto, 1, 520). lectura(almacen, paso, 2, 520). lectura(almacen, contacto, 0, 521).  % un acceso, dos personas
lectura(almacen, contacto, 1, 530). lectura(almacen, paso, 1, 530). lectura(almacen, contacto, 0, 531).
lectura(almacen, contacto, 1, 540). lectura(almacen, paso, 1, 540). lectura(almacen, contacto, 0, 548).  % abierta 8 min
lectura(almacen, contacto, 1, 549). lectura(almacen, paso, 1, 549). lectura(almacen, contacto, 0, 550).
lectura(almacen, contacto, 1, 611). lectura(almacen, paso, 1, 611). lectura(almacen, contacto, 0, 612).

%% La linea de produccion tiene sensor de contacto, pero solo envio una
%% lectura fuera de rango: su estado real no se sabe.
lectura(linea_produccion, contacto, 7, 470).
