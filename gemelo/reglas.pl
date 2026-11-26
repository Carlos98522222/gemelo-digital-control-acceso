:- encoding(utf8).
/*  reglas.pl — Reglas del gemelo digital (proyecto #7, control de acceso)

    Contrato:
      decide(+Intento, -Decision, -Explicacion)
      situacion(?Entidad, ?Situacion, -Evidencia)

    Intento     = intento(Tarjeta, Puerta, Lector, Minuto)
    Decision    = abrir | negar | abrir_y_alertar
    Explicacion = lista de:
        c(Condicion, Valor, Detalle)        Valor = si | no | no_se_sabe
        choque(ReglaA, ReglaB, gana(R), se_le_falla(Quien))
        alerta(AQuien, Que)
        politica(Puerta, Decision)          cuando la duda decide

    Toda condicion tiene tres valores: si, no, no_se_sabe.
    Ninguna regla usa el reloj del sistema: el tiempo viene del intento o
    del hecho ahora/1.
*/

:- ensure_loaded(hechos).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(aggregate)).

%% ===============================================================
%% Logica de tres valores
%% ===============================================================

%% y3(+Valores, -V): conjuncion; un "no" decide, luego "no_se_sabe".
y3(Vs, no)         :- memberchk(no, Vs), !.
y3(Vs, no_se_sabe) :- memberchk(no_se_sabe, Vs), !.
y3(_,  si).

valor_de(c(_, V, _), V).

%% ===============================================================
%% Hipotesis: cambiar hechos temporalmente y responder con las mismas reglas
%% ===============================================================

%% con_hipotesis(+Cambios, :Meta). Cambios: agrega(Hecho) | quita(Patron)
con_hipotesis(Cambios, Meta) :-
    aplicar_cambios(Cambios, Deshacer),
    (   catch(once(Meta), E, (deshacer(Deshacer), throw(E)))
    ->  deshacer(Deshacer)
    ;   deshacer(Deshacer), fail
    ).

aplicar_cambios([], []).
aplicar_cambios([agrega(H)|Cs], [quitar(H)|Ds]) :-
    assertz(H), aplicar_cambios(Cs, Ds).
aplicar_cambios([quita(P)|Cs], [reponer(L)|Ds]) :-
    findall(P, P, L), forall(member(X, L), retract(X)),
    aplicar_cambios(Cs, Ds).

deshacer(Ds) :- reverse(Ds, Rs), maplist(deshacer1, Rs).
deshacer1(quitar(H))  :- ignore(retract(H)).
deshacer1(reponer(L)) :- forall(member(X, L), assertz(X)).

%% en_minuto(+T, :Meta): pregunta "como si ahora fuera T"
en_minuto(T, Meta) :- con_hipotesis([quita(ahora(_)), agrega(ahora(T))], Meta).

%% ===============================================================
%% Tiempo, sensores y energia
%% ===============================================================

en_turno(Turno, T) :-
    turno(Turno, Ini, Fin), umbral(tolerancia_turno, Tol),
    T >= Ini - Tol, T < Fin.

%% valor_sensor(+P, +Sensor, +T, -Valor): valor(V, Minuto) | no_se_sabe(Razon)
%% Usa la ultima lectura =< T; si esta fuera de rango, el sensor no es creible.
valor_sensor(P, S, T, Valor) :-
    (   aggregate_all(max(M, V), (lectura(P, S, V, M), M =< T), max(M, V))
    ->  (   rango(S, Min, Max), V >= Min, V =< Max
        ->  Valor = valor(V, M)
        ;   Valor = no_se_sabe(lectura_fuera_de_rango(S, V, M))
        )
    ;   Valor = no_se_sabe(sin_lectura(S))
    ).

%% energia(+P, +T, -V3)
energia(P, T, V) :-
    valor_sensor(P, energia, T, Val),
    (   Val = valor(1, _) -> V = si
    ;   Val = valor(0, _) -> V = no
    ;   V = no_se_sabe
    ).

alarma_activa(T) :-
    puerta(P, _, _, _, _), valor_sensor(P, alarma, T, valor(1, _)), !.

%% estado_contacto(+P, +T, -Estado): abierta | cerrada | no_se_sabe(Razon)
%% Una puerta sin sensor, o con lectura no creible, NO es "cerrada".
estado_contacto(P, _, no_se_sabe(sin_sensor_de_contacto)) :-
    \+ sensor(P, contacto), !.
estado_contacto(P, T, E) :-
    valor_sensor(P, contacto, T, Val),
    (   Val = valor(1, M) -> E = abierta(desde(M))
    ;   Val = valor(0, M) -> E = cerrada(desde(M))
    ;   Val = no_se_sabe(R), E = no_se_sabe(R)
    ).

%% ===============================================================
%% Credenciales: verdad del servidor vs. verdad de cada puerta
%% ===============================================================

duenio(Tarjeta, Persona) :- credencial(Tarjeta, Persona, _, _), !.

estado_servidor(Tarjeta, T, E) :-
    aggregate_all(max(D, E0), (credencial(Tarjeta, _, E0, D), D =< T), max(_, E)), !.
estado_servidor(_, _, desconocida).

servidor_disponible(T) :- \+ ( servidor_caido(I, F), T >= I, T < F ).

ultima_sincronizacion(P, T, S) :-
    aggregate_all(max(M), (sincronizada(P, M), M =< T), S), !.
ultima_sincronizacion(_, _, nunca).

%% estado_en_puerta(+P, +Tarjeta, +T, -Estado, -Fuente)
%% Con servidor, la puerta pregunta en linea; sin servidor, usa su copia local.
estado_en_puerta(_, Tarjeta, T, E, servidor_en_linea) :-
    servidor_disponible(T), !,
    estado_servidor(Tarjeta, T, E).
estado_en_puerta(P, Tarjeta, T, E, copia_local(sincronizada_en(S))) :-
    ultima_sincronizacion(P, T, S),
    (   S == nunca -> E = desconocida ; estado_servidor(Tarjeta, S, E) ).

%% ===============================================================
%% Derecho: rol + turno + zona + horario + excepcion (con facultad)
%% ===============================================================

zona_destino(P, Z) :- puerta(P, _, Z, _, _).

permiso_por_regla(Per, Z, _, si, por_rol(Rol, Z, todos)) :-
    persona(Per, Rol, _), permiso(Rol, Z, todos), !.
permiso_por_regla(Per, Z, T, si, por_turno(Rol, Z, Turno)) :-
    persona(Per, Rol, Turno), permiso(Rol, Z, su_turno), en_turno(Turno, T), !.
permiso_por_regla(Per, Z, _, no, fuera_de_turno(Rol, Z, Turno)) :-
    persona(Per, Rol, Turno), permiso(Rol, Z, su_turno), !.
permiso_por_regla(Per, Z, _, no, rol_sin_permiso(Rol, Z)) :-
    persona(Per, Rol, _), !.
permiso_por_regla(Per, _, _, no_se_sabe, persona_desconocida(Per)).

horario_zona_ok(Z, T, si, dentro_de_horario(Z)) :-
    horario_zona(Z, I, F), T >= I, T < F, !.
horario_zona_ok(Z, _, no, fuera_de_horario(Z, I, F)) :-
    horario_zona(Z, I, F), !.
horario_zona_ok(Z, _, si, zona_sin_horario_propio(Z)).

%% evalua_excepcion(+Per, +Puerta, +T, -Excepcion, -Valor, -Razon)
evalua_excepcion(Per, Puerta, T, exc(Motivo, DadaPor, Desde, Hasta), V, Razon) :-
    excepcion(Per, Puerta, Motivo, DadaPor, Desde, Hasta),
    zona_destino(Puerta, Z),
    (   \+ (T >= Desde, T =< Hasta)
    ->  V = no, Razon = fuera_de_vigencia(Desde, Hasta)
    ;   persona(DadaPor, RolD, _), facultad(RolD, Z)
    ->  V = si, Razon = vigente_y_con_facultad(DadaPor, RolD, Z)
    ;   persona(DadaPor, RolD, _)
    ->  V = no, Razon = sin_facultad(DadaPor, RolD, Z)
    ;   V = no_se_sabe, Razon = autorizante_desconocido(DadaPor)
    ).

%% derecho(+Persona, +Puerta, +T, -V3, -Detalle)
derecho(Per, Puerta, _, si, [acceso_general(Puerta)]) :-
    acceso_general(Puerta), persona(Per, _, _), !.
derecho(Per, Puerta, T, V, Detalle) :-
    zona_destino(Puerta, Z),
    permiso_por_regla(Per, Z, T, VR, RR),
    horario_zona_ok(Z, T, VH, RH),
    y3([VR, VH], VG),
    findall(E-VE-RE, evalua_excepcion(Per, Puerta, T, E, VE, RE), Excs),
    findall(excepcion_no_valida(E, RE), member(E-no-RE, Excs), Invalidas),
    (   VG == si
    ->  V = si, Detalle = [regla_general(RR, RH)|Invalidas]
    ;   member(E-si-RE, Excs)
    ->  V = si,
        Detalle = [regla_general_niega(RR, RH), excepcion_aplica(E, RE),
                   choque(regla_general, excepcion(E), gana(excepcion), se_le_falla(nadie))
                  |Invalidas]
    ;   V = VG, Detalle = [regla_general_niega(RR, RH)|Invalidas]
    ).

%% ===============================================================
%% Bitacora: orden de eventos, anti-passback y ubicacion
%% ===============================================================

%% horizonte(+P, +Lector, +K, -H): hasta que minuto (reloj del lector)
%% esta al corriente la bitacora con lo recibido hasta K.
horizonte(P, L, K, H) :-
    (   retraso_lector(P, L, Desde, _, Llega), Desde =< K, K < Llega
    ->  H is Desde - 1
    ;   H = K
    ).

%% eventos_conocidos(+Tarjeta, +Puertas, +T, +K, -Lista)
%% Accesos concedidos antes de T, recibidos hasta K, ordenados por el
%% instante del LECTOR (no por el de llegada).
eventos_conocidos(Tarjeta, Puertas, T, K, Ordenados) :-
    findall(ML-ev(P, L, Sentido, Lleg),
            ( evento(P, L, Tarjeta, concedido, ML, Lleg),
              member(P, Puertas), ML < T, Lleg =< K,
              lector(P, L, Sentido) ),
            Es),
    msort(Es, Ordenados).

lado(P, entra, Z) :- puerta(P, _, Z, _, _).
lado(P, sale,  Z) :- puerta(P, Z, _, _, _).

%% posicion_en_puerta(+Tarjeta, +P, +T, +K, -Pos, -Evidencia)
%% Pos = dentro | fuera | no_se_sabe, respecto del lado interior de P.
posicion_en_puerta(Tarjeta, P, T, K, Pos, Ev) :-
    eventos_conocidos(Tarjeta, [P], T, K, Es),
    umbral(desfase_relojes, Desf),
    (   Es == []
    ->  Base = fuera, Ev0 = [sin_registros_previos(P)]
    ;   last(Es, ML-ev(P, L, Sentido, Lleg)),
        ( Sentido == entra -> Base = dentro ; Base = fuera ),
        Ev0 = [ultimo_evento(P, L, Sentido, reloj_lector(ML), llego(Lleg))]
    ),
    (   % orden incierto entre los dos ultimos eventos de sentido opuesto
        append(_, [M1-ev(_, L1, S1, _), M2-ev(_, L2, S2, _)], Es),
        S1 \== S2, abs(M2 - M1) =< Desf
    ->  Pos = no_se_sabe,
        Ev = [orden_incierto(L1-M1, L2-M2, desfase_tolerado(Desf))|Ev0]
    ;   % el lector que podria cambiar la posicion no esta al corriente
        ( Base == dentro -> Opuesto = sale ; Opuesto = entra ),
        lector(P, LO, Opuesto),
        horizonte(P, LO, K, H), H < T - Desf
    ->  Pos = no_se_sabe,
        Ev = [lector_sin_reportar(P, LO, al_corriente_hasta(H))|Ev0]
    ;   Pos = Base, Ev = Ev0
    ).

%% antipassback(+Tarjeta, +P, +Lector, +T, +K, -V3, -Detalle)
antipassback(Tarjeta, P, Lector, T, K, V, [regla(no_entrar_dos_veces_sin_salir), posicion(Pos)|Ev]) :-
    lector(P, _, entra), lector(P, _, sale), !,
    lector(P, Lector, Sentido),
    posicion_en_puerta(Tarjeta, P, T, K, Pos, Ev),
    (   Pos == no_se_sabe            -> V = no_se_sabe
    ;   Sentido == entra, Pos == fuera -> V = si
    ;   Sentido == sale,  Pos == dentro -> V = si
    ;   V = no
    ).
antipassback(_, P, _, _, _, si, [sin_antipassback(P)]).

%% ubicacion(+Tarjeta, +T, +K, -Zona, -Evidencia). Zona puede ser no_se_sabe.
ubicacion(Tarjeta, T, K, Zona, Ev) :-
    findall(P, puerta(P, _, _, _, _), Ps),
    eventos_conocidos(Tarjeta, Ps, T, K, Es),
    (   Es == []
    ->  Zona = calle, Ev = [sin_registros]
    ;   last(Es, ML-ev(P, L, Sentido, Lleg)),
        lado(P, Sentido, Z0),
        posicion_en_puerta(Tarjeta, P, T, K, Pos, EvP),
        (   Pos == no_se_sabe
        ->  Zona = no_se_sabe, Ev = EvP
        ;   Zona = Z0, Ev = [ultimo_evento(P, L, reloj_lector(ML), llego(Lleg))]
        )
    ).

%% quien(+Tarjeta, +T, -Quien): la persona, o "portador" si la tarjeta no esta activa
quien(Tarjeta, T, Quien) :-
    duenio(Tarjeta, Per),
    estado_servidor(Tarjeta, T, E),
    ( E == activa -> Quien = persona(Per) ; Quien = portador(Tarjeta, E, de(Per)) ).

%% dentro(?Zona, -Quien, +T): quien esta en una zona (no calle) en T,
%% con lo que la bitacora sabia en T.
dentro(Zona, Quien, T) :- dentro(Zona, Quien, T, _).
dentro(Zona, Quien, T, Ev) :-
    setof(Tj, P^E^D^credencial(Tj, P, E, D), Tarjetas),
    member(Tj, Tarjetas),
    ubicacion(Tj, T, T, Z, Ev),
    Z \== calle,
    Zona = Z,
    quien(Tj, T, Quien).

%% ===============================================================
%% decide/3 y decide/4
%% ===============================================================

%% decide(+Intento, -Decision, -Explicacion): con lo que se sabia en el
%% instante del intento (tiempo real).
decide(intento(Tj, P, L, T), D, E) :- decide(intento(Tj, P, L, T), T, D, E).

%% decide/4 es determinista: una decision por intento.
decide(I, K, D, E) :- once(decide_(I, K, D0, E0)), D = D0, E = E0.

%% auditar(+Intento, -Decision, -Explicacion): la misma decision con lo
%% que la bitacora sabe "ahora" (eventos que llegaron tarde incluidos).
auditar(intento(Tj, P, L, T), D, E) :-
    ahora(A), K is max(A, T), decide(intento(Tj, P, L, T), K, D, E).

%% decide(+Intento, +K, -Decision, -Explicacion): K = hasta que minuto se
%% considera recibida la bitacora.
decide_(intento(Tj, P, L, T), _, D, E) :-
    puerta(P, _, _, _, salida_emergencia), !,
    decide_salida_emergencia(Tj, P, L, T, D, E).
decide_(intento(Tj, P, L, T), K, D, E) :-
    puerta(P, _, _, Modo, _),
    % 1. energia
    energia(P, T, VE),
    cond_energia(VE, Modo, CE),
    % 2. credencial segun lo que sabe la puerta
    estado_en_puerta(P, Tj, T, EP, Fuente),
    ( EP == activa -> VC = si ; EP == desconocida -> VC = no_se_sabe ; VC = no ),
    CC = c(credencial_en_puerta, VC, estado(EP, Fuente)),
    % 3. derecho de la persona
    (   duenio(Tj, Per)
    ->  derecho(Per, P, T, VD, DetD), CD = c(derecho, VD, persona(Per, DetD))
    ;   CD = c(derecho, no, tarjeta_sin_duenio(Tj))
    ),
    % 4. anti-passback
    antipassback(Tj, P, L, T, K, VA, DetA),
    CA = c(antipassback, VA, DetA),
    Conds = [CE, CC, CD, CA],
    % alertas: el servidor sabe algo que la puerta no
    estado_servidor(Tj, T, ES),
    (   ES \== activa, EP == activa
    ->  Alertas = [alerta(vigilancia, puerta_desactualizada(P, Tj, servidor_dice(ES)))]
    ;   Alertas = []
    ),
    combina(P, Modo, VE, Conds, Alertas, D, Extra),
    append([Conds, Extra, Alertas], E).

cond_energia(si, _, c(energia, si, con_energia)).
cond_energia(no_se_sabe, _, c(energia, no_se_sabe, sin_lectura_de_energia)).
cond_energia(no, seguro,  c(energia, no, sin_energia(fail_secure, puerta_cerrada))).
cond_energia(no, abierto, c(energia, no, sin_energia(fail_safe, puerta_liberada))).

%% combina(+Puerta, +Modo, +VEnergia, +Conds, +Alertas, -Decision, -Extra)
combina(_, seguro, no, _, _, negar, [nota(sin_energia_la_puerta_no_decide)]) :- !.
combina(_, abierto, no, Conds, _, abrir_y_alertar,
        [nota(sin_energia_la_puerta_queda_abierta), alerta(vigilancia, puerta_sin_control(Fallan))]) :- !,
    findall(N, (member(c(N, V, _), Conds), N \== energia, V \== si), Fallan).
combina(P, _, _, Conds, Alertas, D, Extra) :-
    maplist(valor_de, Conds, Vs),
    y3(Vs, V),
    (   V == no
    ->  D = negar, Extra = []
    ;   V == no_se_sabe
    ->  politica_de(P, Pol), D = Pol,
        findall(N, member(c(N, no_se_sabe, _), Conds), Dudas),
        Extra = [politica(P, Pol), alerta(vigilancia, duda_resuelta_por_politica(Dudas))]
    ;   Alertas \== []
    ->  D = abrir_y_alertar, Extra = []
    ;   D = abrir, Extra = []
    ).

politica_de(P, Pol) :- politica_duda(P, Pol), !.
politica_de(_, negar_y_alertar).

%% Salida de emergencia: la vida va primero (NOM-002-STPS-2010).
decide_salida_emergencia(Tj, P, _, T, D, E) :-
    Base = [c(salida_de_emergencia, si, puerta(P, abre_siempre))],
    (   Tj == sin_tarjeta -> ES = sin_tarjeta ; estado_servidor(Tj, T, ES) ),
    (   memberchk(ES, [activa, sin_tarjeta])
    ->  D = abrir, E = Base
    ;   D = abrir_y_alertar,
        append([c(credencial, no, estado(ES))|Base],
               [choque(salida_de_emergencia_abre_siempre, credencial_no_activa_no_abre,
                       gana(salida_de_emergencia_abre_siempre),
                       se_le_falla(seguridad_patrimonial)),
                alerta(vigilancia, salida_por_emergencia(Tj, ES))],
               E)
    ).

%% ===============================================================
%% Consultas al reves: que tendria que cambiar
%% ===============================================================

%% que_falta(+Intento, -Cambios): cambios de UN hecho que voltean la
%% decision a abrir; cada cambio se verifica con las mismas reglas.
que_falta(Intento, Cambios) :-
    decide(Intento, D0, E0),
    (   memberchk(D0, [abrir, abrir_y_alertar])
    ->  Cambios = ya_abre(D0)
    ;   findall(cambio(C, D1),
                ( candidato(Intento, E0, C),
                  con_hipotesis(C, decide(Intento, D1, _)),
                  memberchk(D1, [abrir, abrir_y_alertar]) ),
                Cs0),
        list_to_set(Cs0, Cambios)
    ).

candidato(intento(Tj, P, _, T), E, [agrega(excepcion(Per, P, propuesta, Aut, T, Hasta))]) :-
    memberchk(c(derecho, no, _), E),
    duenio(Tj, Per), Hasta is T + 60,
    persona(Aut, _, _), Aut \== Per.
candidato(intento(Tj, P, _, _), E, [agrega(permiso(Rol, Z, todos))]) :-
    memberchk(c(derecho, no, _), E),
    duenio(Tj, Per), persona(Per, Rol, _), zona_destino(P, Z).
candidato(intento(Tj, _, _, T), E, [agrega(credencial(Tj, Per, activa, T))]) :-
    memberchk(c(credencial_en_puerta, no, _), E), duenio(Tj, Per).
candidato(intento(Tj, P, _, T), E, [agrega(evento(P, LS, Tj, concedido, M, M))]) :-
    memberchk(c(antipassback, no, _), E),
    lector(P, LS, sale), M is T - 5.
candidato(intento(_, P, _, T), E, [agrega(lectura(P, energia, 1, T))]) :-
    memberchk(c(energia, no, _), E).

%% ===============================================================
%% Situacion 3: tarjeta robada y puertas sin conexion
%% ===============================================================

puertas_con_lector(Ps) :-
    setof(P, L^S^T^(lector(P, L, S), puerta(P, _, _, _, T), T \== salida_emergencia), Ps).

%% aceptaria(+Tarjeta, +P, +T, -Evidencia): la puerta abriria por credencial
%% aunque el servidor ya no la tenga activa.
aceptaria(Tj, P, T, Ev) :-
    puertas_con_lector(Ps), member(P, Ps),
    estado_en_puerta(P, Tj, T, activa, Fuente),
    estado_servidor(Tj, T, ES), ES \== activa,
    Ev = [servidor(ES), puerta_cree(activa), Fuente].

puertas_expuestas(Tj, T, Ps) :- findall(P, aceptaria(Tj, P, T, _), Ps).

usos(Tj, T, Us) :-
    findall(uso(M, P), (evento(P, _, Tj, concedido, M, _), M =< T), Us0),
    msort(Us0, Us).

traslado_min(P, P, 0) :- !.
traslado_min(P1, P2, M) :- ( traslado(P1, P2, M) -> true ; traslado(P2, P1, M) ).

%% uso_incompatible(+Tj, +T, -U1, -U2, -Evidencia)
uso_incompatible(Tj, T, uso(M1, P1), uso(M2, P2), Ev) :-
    usos(Tj, T, Us),
    append(_, [uso(M1, P1)|Resto], Us),
    member(uso(M2, P2), Resto),
    P1 \== P2,
    traslado_min(P1, P2, Min),
    Dif is M2 - M1, Dif < Min,
    Ev = [separados(Dif, min), traslado_minimo(Min, min)].

%% clasifica_uso(+Tj, +Uso, -Clase, -Evidencia)
clasifica_uso(Tj, uso(M, P), Clase, Ev) :-
    ( credencial(Tj, _, reportada, R) -> true ; R = inf ),
    estado_en_puerta(P, Tj, M, EP, Fuente),
    estado_servidor(Tj, M, ES),
    (   R \== inf, M < R
    ->  Clase = antes_del_reporte_probable_duenio
    ;   ES \== activa, EP == activa
    ->  Clase = la_puerta_no_lo_sabia
    ;   ES \== activa
    ->  Clase = la_puerta_ya_lo_sabia
    ;   Clase = normal
    ),
    Ev = [servidor(ES), puerta(EP, Fuente)].

%% hipotesis_reporte(+Tj, +MinutoReporte, -Comparacion)
%% "Que habria pasado si el reporte (y la revocacion) llegan en MinutoReporte"
hipotesis_reporte(Tj, MR, Comparacion) :-
    duenio(Tj, Per), MRev is MR + 1, ahora(A),
    usos(Tj, A, Us),
    findall(U-D, (member(U, Us), U = uso(M, P), lector_del_uso(Tj, P, M, L),
                  decide(intento(Tj, P, L, M), D, _)), Real),
    Cambios = [quita(credencial(Tj, _, reportada, _)), quita(credencial(Tj, _, revocada, _)),
               agrega(credencial(Tj, Per, reportada, MR)), agrega(credencial(Tj, Per, revocada, MRev))],
    con_hipotesis(Cambios,
        findall(U-D, (member(U, Us), U = uso(M, P), lector_del_uso(Tj, P, M, L),
                      decide(intento(Tj, P, L, M), D, _)), Hipo)),
    findall(cmp(U, real(DR), hipotesis(DH)), (member(U-DR, Real), member(U-DH, Hipo)), Comparacion).

lector_del_uso(Tj, P, M, L) :- evento(P, L, Tj, concedido, M, _), !.

%% ===============================================================
%% Situacion 4: emergencia, energia y rutas de salida
%% ===============================================================

%% transitable(+P, +T, -V3, -Razon) para evacuar
transitable(P, _, si, salida_de_emergencia_abre_siempre) :-
    puerta(P, _, _, _, salida_emergencia), !.
transitable(P, T, V, R) :-
    puerta(P, _, _, Modo, _),
    energia(P, T, VE),
    (   VE == si         -> V = si, R = con_energia_se_libera_para_salir
    ;   VE == no_se_sabe -> V = no_se_sabe, R = energia_desconocida
    ;   Modo == abierto  -> V = si, R = sin_energia_fail_safe_abierta
    ;   V = no, R = sin_energia_fail_secure_cerrada
    ).

conecta(Z1, Z2, P) :- puerta(P, Z1, Z2, _, _), Z1 \== Z2.
conecta(Z1, Z2, P) :- puerta(P, Z2, Z1, _, _), Z1 \== Z2.

%% ruta_salida(+Zona, +T, -Ruta): Ruta = lista de pasos(Puerta, Hacia)
ruta_salida(calle, _, []) :- !.
ruta_salida(Z, T, Ruta) :- ruta(Z, T, [Z], Ruta), !.

ruta(calle, _, _, []).
ruta(Z, T, Visit, [paso(P, Z2)|R]) :-
    conecta(Z, Z2, P), \+ memberchk(Z2, Visit),
    transitable(P, T, si, _),
    ruta(Z2, T, [Z2|Visit], R).

%% evacuacion(+T, -Plan): por cada quien dentro, su ruta o sin_salida
evacuacion(T, Plan) :-
    findall(Item,
            ( dentro(Z, Q, T),
              (   ruta_salida(Z, T, R) -> Item = sale(Q, desde(Z), por(R))
              ;   Item = sin_salida(Q, en(Z))
              ) ),
            Plan).

estado_puertas_emergencia(T, Estados) :-
    findall(puerta(P, V, R), (puerta(P, _, _, _, _), transitable(P, T, V, R)), Estados).

%% plan_emergencia(+T, -Plan, -Explicacion)
plan_emergencia(T, plan(alarma(A), puertas(Ps), personas(Ev), alertas(Al)), Expl) :-
    ( alarma_activa(T) -> A = si ; A = no ),
    estado_puertas_emergencia(T, Ps),
    evacuacion(T, Ev),
    findall(alerta(vigilancia, liberar_manualmente_para(Q, Z)), member(sin_salida(Q, en(Z)), Ev), Al1),
    findall(alerta(vigilancia, tarjeta_no_activa_evacuando(Tj, E, Z)),
            member(sale(portador(Tj, E, _), desde(Z), _), Ev), Al2),
    append(Al1, Al2, Al),
    findall(Ch, choque_emergencia(T, Ev, Ch), Expl).

choque_emergencia(_, Ev, choque(salida_de_emergencia_abre_siempre, credencial_no_activa_no_abre,
                                gana(salida_de_emergencia_abre_siempre),
                                se_le_falla(seguridad_patrimonial))) :-
    memberchk(sale(portador(_, _, _), _, _), Ev).
choque_emergencia(T, _, choque(fail_secure_protege_la_entrada, evacuacion,
                               gana(fail_secure_protege_la_entrada),
                               se_le_falla(nadie_porque_el_almacen_tiene_salida_de_emergencia))) :-
    puerta(almacen, _, _, seguro, _), transitable(almacen, T, no, _).
choque_emergencia(_, Ev, choque(fail_secure_protege_la_entrada, evacuacion,
                                gana(evacuacion_si_se_libera_manualmente),
                                se_le_falla(Atrapados))) :-
    findall(Q, member(sin_salida(Q, _), Ev), Atrapados), Atrapados \== [].

%% ===============================================================
%% Situacion 5: puerta anomala (lector + contacto + paso)
%% ===============================================================

aperturas(P, T, Ms) :-
    findall(M, (lectura(P, contacto, 1, M), M =< T, rango(contacto, _, Max), 1 =< Max), Ms0),
    msort(Ms0, Ms).

%% clasifica_apertura(+P, +M, +T, -Veredicto, -Evidencia)
%% Veredicto: normal | forzada | tailgating | abierta_de_mas | apertura_con_excepcion
clasifica_apertura(P, M, T, Ver, Ev) :-
    umbral(ventana_acceso, W), umbral(abierta_de_mas, Umb),
    (   evento(P, L, Tj, concedido, ML, _), ML >= M - W, ML =< M
    ->  Acceso = si(Tj, L, ML) ; Acceso = no ),
    (   aggregate_all(min(C), (lectura(P, contacto, 0, C), C > M, C =< T), Cierre)
    ->  Dur is Cierre - M, Abierta = cerro(Cierre)
    ;   Dur is T - M, Abierta = sigue_abierta
    ),
    (   lectura(P, paso, N, MP), MP >= M, MP =< M + W -> Paso = N ; Paso = no_se_sabe ),
    (   Acceso == no,
        excepcion(Per, P, Mot, Aut, D, H), M >= D, M =< H,
        persona(Aut, RolA, _), zona_destino(P, Z), facultad(RolA, Z)
    ->  Ver = apertura_con_excepcion, Motivo = excepcion(Per, Mot, Aut)
    ;   Acceso == no
    ->  Ver = forzada, Motivo = sin_acceso_ni_excepcion
    ;   integer(Paso), Paso > 1
    ->  Ver = tailgating, Motivo = cruzaron(Paso)
    ;   Dur > Umb
    ->  Ver = abierta_de_mas, Motivo = abierta(Dur, min, umbral(Umb))
    ;   Ver = normal, Motivo = acceso_normal
    ),
    Ev = [apertura(M), acceso(Acceso), Abierta, duracion(Dur), paso(Paso), Motivo].

%% A quien despertar
aviso(forzada,                despertar_vigilante).
aviso(tailgating,             alerta_a_vigilancia).
aviso(abierta_de_mas,         alerta_a_vigilancia).
aviso(apertura_con_excepcion, solo_registro).
aviso(normal,                 nada).

%% ===============================================================
%% situacion/3: situaciones deducidas, consultables en cualquier direccion
%% ===============================================================

situacion(Entidad, Situacion, Evidencia) :-
    ahora(T), situacion(Entidad, Situacion, Evidencia, T).

situacion(persona(Per), derecho_vigente(P), Ev, T) :-
    persona(Per, _, _), puerta(P, _, _, _, normal),
    derecho(Per, P, T, si, Ev).
situacion(Quien, dentro(Z), Ev, T) :-
    dentro(Z, Quien, T, Ev).
situacion(tarjeta(Tj), ubicacion_incierta, Ev, T) :-
    setof(X, P^E^D^credencial(X, P, E, D), Ts), member(Tj, Ts),
    ubicacion(Tj, T, T, no_se_sabe, Ev).
situacion(puerta(P), desactualizada(Tj), Ev, T) :-
    setof(X, Pe^E^D^credencial(X, Pe, E, D), Ts), member(Tj, Ts),
    aceptaria(Tj, P, T, Ev).
situacion(tarjeta(Tj), aun_la_aceptaria(P), Ev, T) :-
    setof(X, Pe^E^D^credencial(X, Pe, E, D), Ts), member(Tj, Ts),
    aceptaria(Tj, P, T, Ev).
situacion(tarjeta(Tj), uso_incompatible(U1, U2), Ev, T) :-
    setof(X, Pe^E^D^credencial(X, Pe, E, D), Ts), member(Tj, Ts),
    uso_incompatible(Tj, T, U1, U2, Ev).
situacion(tarjeta(Tj), uso(U, Clase), Ev, T) :-
    setof(X, Pe^E^D^credencial(X, Pe, E, D), Ts), member(Tj, Ts),
    credencial(Tj, _, reportada, _),
    usos(Tj, T, Us), member(U, Us),
    clasifica_uso(Tj, U, Clase, Ev).
situacion(puerta(P), Ver, [aviso(A)|Ev], T) :-
    puerta(P, _, _, _, _), sensor(P, contacto),
    aperturas(P, T, Ms), member(M, Ms),
    clasifica_apertura(P, M, T, V0, Ev), V0 \== normal,
    Ver =.. [V0, M], aviso(V0, A).
situacion(puerta(P), contacto_no_se_sabe, [R], T) :-
    sensor(P, contacto),
    estado_contacto(P, T, no_se_sabe(R)).
situacion(Quien, sin_salida(Z), [alarma_y_sin_ruta], T) :-
    alarma_activa(T),
    dentro(Z, Quien, T), \+ ruta_salida(Z, T, _).
situacion(Quien, ruta_salida(Z, R), [alarma_activa], T) :-
    alarma_activa(T),
    dentro(Z, Quien, T), ruta_salida(Z, T, R).

%% Pregunta "quienes podrian pasar por esa puerta ahora"
podrian_pasar(P, T, Personas) :-
    findall(Per, (persona(Per, _, _), derecho(Per, P, T, si, _)), Personas).

%% Severidad de cada situacion (para ordenar y colorear alertas)
severidad(forzada,                critica).
severidad(sin_salida,             critica).
severidad(uso_incompatible,       critica).
severidad(desactualizada,         critica).
severidad(tailgating,             advertencia).
severidad(abierta_de_mas,         advertencia).
severidad(apertura_con_excepcion, registro).
severidad(contacto_no_se_sabe,    indeterminado).
severidad(ubicacion_incierta,     indeterminado).
