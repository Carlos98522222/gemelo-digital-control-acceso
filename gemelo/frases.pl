:- encoding(utf8).
/*  frases.pl — Presentacion: convierte terminos del gemelo en frases en espanol.

    Solo traduce lo que las reglas ya dedujeron; no decide nada.
*/

:- use_module(library(occurs)).

nombre(X, S) :- atom(X), !,
    atomic_list_concat(Ps, '_', X), atomic_list_concat(Ps, ' ', A), atom_string(A, S).
nombre(X, S) :- format(string(S), "~w", [X]).

hhmm(M, S) :- integer(M), !, H is (M mod 1440) // 60, Mi is M mod 60,
    format(string(S), "~|~`0t~d~2+:~|~`0t~d~2+", [H, Mi]).
hhmm(M, S) :- format(string(S), "~w", [M]).

f(Fmt, Args, S) :- maplist(arg_txt, Args, As), format(string(S), Fmt, As).
arg_txt(A, S) :- ( atom(A), \+ sub_atom(A, 0, _, _, t_) -> nombre(A, S) ; S = A ).

%% frase(+Termino, -Texto): la primera frase que aplique
frase(T, S) :- once(frase_(T, S)).

frase_(con_energia,                               "Con energía").
frase_(sin_energia(fail_secure, puerta_cerrada),  "Sin energía · fail-secure: la puerta queda cerrada").
frase_(sin_energia(fail_safe, puerta_liberada),   "Sin energía · fail-safe: la puerta queda liberada").
frase_(sin_lectura_de_energia,                    "No hay lectura de energía").
frase_(estado(E, servidor_en_linea), S) :- f("La puerta consultó al servidor en línea: ~w", [E], S).
frase_(estado(E, copia_local(sincronizada_en(M))), S) :-
    f("Servidor caído: la puerta usa su copia local (sincronizada en min ~w) → ~w", [M, E], S).
frase_(estado(E), S) :- f("Estado de la tarjeta: ~w", [E], S).
frase_(persona(P, _), S) :- f("Persona: ~w", [P], S).
frase_(tarjeta_sin_duenio(T), S) :- f("La tarjeta ~w no tiene dueño registrado", [T], S).
frase_(acceso_general(P), S) :- f("~w es acceso general: entra cualquier tarjeta activa", [P], S).
frase_(regla_general(R, _), S) :- frase_regla(R, S).
frase_(regla_general_niega(R, H), S) :-
    frase_regla(R, S1), ( H = fuera_de_horario(_, _, _) -> frase(H, S2), f("~w · ~w", [S1, S2], S) ; S = S1 ).
frase_(fuera_de_horario(Z, I, F), S) :- hhmm(I, A), hhmm(F, B), f("~w solo abre de ~w a ~w", [Z, A, B], S).
frase_(excepcion_aplica(exc(M, A, D, H), _), S) :-
    f("Excepción vigente: ~w, autorizada por ~w (min ~w–~w)", [M, A, D, H], S).
frase_(excepcion_no_valida(exc(M, A, _, _), fuera_de_vigencia(D, H)), S) :-
    f("La excepción «~w» de ~w no cuenta: solo valía del min ~w al ~w", [M, A, D, H], S).
frase_(excepcion_no_valida(exc(M, A, _, _), sin_facultad(_, Rol, Z)), S) :-
    f("La excepción «~w» no cuenta: ~w (~w) no tiene facultad en ~w", [M, A, Rol, Z], S).
frase_(regla(no_entrar_dos_veces_sin_salir), "Regla: no entrar dos veces sin salir").
frase_(posicion(P), S) :- f("Posición de la tarjeta: ~w", [P], S).
frase_(ultimo_evento(_, L, _, reloj_lector(M), llego(Ll)), S) :-
    ( Ll > M -> f("Último evento conocido: lector de ~w en min ~w (llegó tarde, en min ~w)", [L, M, Ll], S)
    ; f("Último evento conocido: lector de ~w en min ~w", [L, M], S) ).
frase_(ultimo_evento(P, L, reloj_lector(M), llego(_)), S) :- f("Último evento: ~w, lector de ~w, min ~w", [P, L, M], S).
frase_(lector_sin_reportar(_, L, al_corriente_hasta(H)), S) :-
    f("El lector de ~w solo ha reportado hasta el min ~w: pudo haber salido sin que se sepa", [L, H], S).
frase_(orden_incierto(L1-M1, L2-M2, desfase_tolerado(D)), S) :-
    f("Orden incierto: ~w (min ~w) y ~w (min ~w) caen dentro del desfase de ~w min", [L1, M1, L2, M2, D], S).
frase_(sin_antipassback(_), "Esta puerta no aplica anti-passback").
frase_(sin_registros_previos(_), "Sin registros previos en esta puerta").
frase_(sin_registros, "Sin registros").
frase_(puerta(P, abre_siempre), S) :- f("~w abre siempre (NOM-002-STPS-2010)", [P], S).
frase_(nota(N), S) :- frase(N, S).
frase_(sin_energia_la_puerta_no_decide, "Sin energía la puerta no puede decidir").
frase_(sin_energia_la_puerta_queda_abierta, "Sin energía la puerta queda abierta").
frase_(politica(P, D), S) :- f("Política ante la duda en ~w: ~w", [P, D], S).
frase_(alerta(A, Q), S) :- frase(Q, S0), f("Avisar a ~w: ~w", [A, S0], S).
frase_(puerta_desactualizada(P, T, servidor_dice(E)), S) :-
    f("~w abrió con ~w, pero el servidor la tiene ~w", [P, T, E], S).
frase_(duda_resuelta_por_politica(Ds), S) :- atomic_list_concat(Ds, ', ', A), f("la duda (~w) se resolvió por política", [A], S).
frase_(salida_por_emergencia(T, E), S) :- f("la tarjeta ~w (~w) salió por emergencia", [T, E], S).
frase_(puerta_sin_control(_), "puerta sin control por falta de energía").
frase_(liberar_manualmente_para(Q, Z), S) :- quien_txt(Q, QS), f("liberar a mano una salida para ~w (en ~w)", [QS, Z], S).
frase_(tarjeta_no_activa_evacuando(T, E, Z), S) :- f("la tarjeta ~w (~w) evacúa desde ~w: identificar al portador", [T, E, Z], S).
%% situaciones
frase_(forzada(M), S) :- hhmm(M, H), f("Puerta forzada · ~w", [H], S).
frase_(tailgating(M), S) :- hhmm(M, H), f("Tailgating: un acceso, varias personas · ~w", [H], S).
frase_(abierta_de_mas(M), S) :- hhmm(M, H), f("Puerta abierta de más · ~w", [H], S).
frase_(apertura_con_excepcion(M), S) :- hhmm(M, H), f("Apertura con orden de trabajo · ~w", [H], S).
frase_(uso_incompatible(uso(M1, P1), uso(M2, P2)), S) :-
    f("Uso incompatible: ~w (min ~w) ↔ ~w (min ~w)", [P1, M1, P2, M2], S).
frase_(desactualizada(T), S) :- f("Aún acepta la tarjeta ~w", [T], S).
frase_(contacto_no_se_sabe, "Estado del contacto: no se sabe").
frase_(ubicacion_incierta, "Ubicación incierta").
frase_(sin_salida(Z), S) :- f("Sin salida desde ~w", [Z], S).
%% evidencia
frase_(apertura(M), S) :- f("Se abrió en min ~w", [M], S).
frase_(acceso(no), "Sin acceso concedido").
frase_(acceso(si(T, L, M)), S) :- f("Acceso concedido a ~w (~w, min ~w)", [T, L, M], S).
frase_(cerro(C), S) :- f("Cerró en min ~w", [C], S).
frase_(sigue_abierta, "Sigue abierta").
frase_(duracion(D), S) :- f("Abierta ~w min", [D], S).
frase_(paso(no_se_sabe), "Contador de paso: no se sabe").
frase_(paso(N), S) :- f("Cruzaron ~w", [N], S).
frase_(excepcion(P, M, A), S) :- f("~w de ~w, autorizada por ~w", [M, P, A], S).
frase_(sin_acceso_ni_excepcion, "Sin acceso ni excepción que la explique").
frase_(cruzaron(N), S) :- f("~w personas con un solo acceso", [N], S).
frase_(abierta(D, min, umbral(U)), S) :- f("~w min abierta (umbral ~w min)", [D, U], S).
frase_(acceso_normal, "Acceso normal").
frase_(separados(D, min), S) :- f("Separados ~w min", [D], S).
frase_(traslado_minimo(M, min), S) :- f("Traslado mínimo ~w min", [M], S).
frase_(servidor(E), S) :- f("Servidor: ~w", [E], S).
frase_(puerta_cree(E), S) :- f("La puerta cree: ~w", [E], S).
frase_(copia_local(sincronizada_en(M)), S) :- f("Copia local de min ~w", [M], S).
frase_(servidor_en_linea, "Consulta en línea").
frase_(puerta(E, F), S) :- frase(E, S1), frase(F, S2), f("Puerta: ~w · ~w", [S1, S2], S).
frase_(lectura_fuera_de_rango(Se, V, M), S) :- f("Lectura de ~w fuera de rango (~w) en min ~w", [Se, V, M], S).
frase_(sin_sensor_de_contacto, "Sin sensor de contacto").
frase_(sin_lectura(Se), S) :- f("Sin lectura de ~w", [Se], S).
frase_(alarma_y_sin_ruta, "Alarma activa y ninguna ruta transitable").
frase_(alarma_activa, "Alarma activa").
frase_(aviso(A), S) :- f("Aviso: ~w", [A], S).
%% emergencia
frase_(salida_de_emergencia_abre_siempre, "Salida de emergencia: abre siempre").
frase_(con_energia_se_libera_para_salir, "Con energía: se libera para salir").
frase_(sin_energia_fail_safe_abierta, "Sin energía · fail-safe: abierta").
frase_(sin_energia_fail_secure_cerrada, "Sin energía · fail-secure: cerrada").
frase_(energia_desconocida, "Energía desconocida").
frase_(paso(P, Z), S) :- f("~w → ~w", [P, Z], S).
%% clases de uso
frase_(antes_del_reporte_probable_duenio, "Antes del reporte: probablemente la dueña").
frase_(la_puerta_no_lo_sabia, "La puerta aún no sabía de la revocación").
frase_(la_puerta_ya_lo_sabia, "La puerta ya lo sabía").
frase_(normal, "Normal").
%% cambios propuestos
frase_(agrega(excepcion(Per, P, _, A, D, H)), S) :- f("Excepción para ~w en ~w, dada por ~w (min ~w–~w)", [Per, P, A, D, H], S).
frase_(agrega(permiso(R, Z, todos)), S) :- f("Dar al rol ~w permiso en ~w a toda hora", [R, Z], S).
frase_(agrega(credencial(T, _, activa, _)), S) :- f("Reactivar la tarjeta ~w", [T], S).
frase_(agrega(evento(P, _, T, _, M, _)), S) :- f("Que la bitácora tenga la salida de ~w por ~w (min ~w)", [T, P, M], S).
frase_(agrega(lectura(P, energia, 1, _)), S) :- f("Restablecer la energía en ~w", [P], S).
%% respaldo
frase_(T, S) :- format(string(S0), "~w", [T]),
    split_string(S0, "_", "", Ps), atomic_list_concat(Ps, ' ', A), atom_string(A, S).

frase_regla(por_rol(R, Z, todos), S) :- f("El rol ~w tiene permiso en ~w a toda hora", [R, Z], S).
frase_regla(por_turno(R, Z, T), S) :- f("El rol ~w entra a ~w en su turno (~w)", [R, Z, T], S).
frase_regla(fuera_de_turno(R, Z, T), S) :- f("Fuera de su turno ~w (rol ~w en ~w)", [T, R, Z], S).
frase_regla(rol_sin_permiso(R, Z), S) :- f("El rol ~w no tiene permiso en ~w", [R, Z], S).
frase_regla(persona_desconocida(P), S) :- f("~w no está registrada", [P], S).

quien_txt(persona(P), S) :- !, nombre(P, S).
quien_txt(portador(T, E, de(P)), S) :- !, f("portador de ~w (~w, de ~w)", [T, E, P], S).
quien_txt(Q, S) :- frase(Q, S).

%% detalle_frases(+Detalle, -Frases): lista de frases sin los choques
detalle_frases(persona(P, Det), [S|Fs]) :- !, frase(persona(P, Det), S), detalle_frases(Det, Fs).
detalle_frases(L, Fs) :- is_list(L), !,
    exclude([X]>>(X = choque(_, _, _, _)), L, L1), maplist(frase, L1, Fs).
detalle_frases(T, [S]) :- frase(T, S).

%% choques_en(+Termino, -Choques): todos los choque/4 dentro de un termino, como dicts
choques_en(T, Cs) :-
    findall(C, sub_term(C, T), Sub),
    include([X]>>(nonvar(X), X = choque(_, _, _, _)), Sub, Ch0),
    list_to_set(Ch0, Ch),
    maplist(choque_dict, Ch, Cs).

choque_dict(choque(A, B, gana(G), se_le_falla(F)), _{a:SA, b:SB, gana:SG, falla:SF}) :-
    regla_txt(A, SA), regla_txt(B, SB), regla_txt(G, SG),
    (   is_list(F) -> maplist(quien_txt, F, Ls), atomic_list_concat(Ls, ', ', A1), atom_string(A1, SF)
    ;   regla_txt(F, SF) ).

regla_txt(excepcion(exc(M, A, _, _)), S) :- !, f("excepción «~w» de ~w", [M, A], S).
regla_txt(excepcion, "la excepción") :- !.
regla_txt(regla_general, "regla de turno y rol") :- !.
regla_txt(X, S) :- nombre(X, S).
