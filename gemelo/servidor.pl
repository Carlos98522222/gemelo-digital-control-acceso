:- encoding(utf8).
/*  servidor.pl — Servidor web del gemelo digital (SWI-Prolog)

    Arranque:    swipl servidor.pl          (abre http://localhost:8080)
    Otro puerto: swipl servidor.pl 9000

    Toda decision vive en reglas.pl; aqui solo se traduce a JSON
    (con frases en espanol de frases.pl).
*/

:- prolog_load_context(directory, D), assertz(user:dir_gemelo(D)).
:- ensure_loaded(reglas).
:- ensure_loaded(frases).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_files)).
:- use_module(library(http/http_cors)).

:- http_handler(root(.),              http_redirect(moved, root('web/index.html')), []).
:- http_handler(root(web),            servir_web, [prefix]).
:- http_handler(root(api/catalogo),   api_catalogo,   []).
:- http_handler(root(api/estado),     api_estado,     []).
:- http_handler(root(api/dentro),     api_dentro,     []).
:- http_handler(root(api/decide),     api_decide,     []).
:- http_handler(root(api/que_falta),  api_que_falta,  []).
:- http_handler(root(api/alertas),    api_alertas,    []).
:- http_handler(root(api/emergencia), api_emergencia, []).
:- http_handler(root(api/tarjeta),    api_tarjeta,    []).

iniciar :-
    current_prolog_flag(argv, Argv),
    ( Argv = [PA|_], atom_number(PA, Puerto) -> true ; Puerto = 8080 ),
    http_server(http_dispatch, [port(Puerto)]),
    format("~nGemelo digital #7 en http://localhost:~w/~n", [Puerto]),
    format("API de ejemplo: http://localhost:~w/api/estado~n~n", [Puerto]).

:- initialization(iniciar).

%% Archivos estaticos de web/ (sin subir de directorio)
servir_web(Req) :-
    memberchk(path_info(PI0), Req),
    atom_string(PI0, PI1), split_string(PI1, "/", "/", Partes0),
    exclude(==(""), Partes0, Partes),
    \+ memberchk("..", Partes),
    ( Partes == [] -> Rel = "index.html" ; atomic_list_concat(Partes, '/', Rel) ),
    dir_gemelo(D), atomic_list_concat([D, '/web/', Rel], Ruta),
    (   exists_file(Ruta) -> http_reply_file(Ruta, [unsafe(true)], Req)
    ;   http_404([], Req)
    ).

%% ---------------------------------------------------------------
%% Utilidades
%% ---------------------------------------------------------------

minuto(Req, T) :-
    http_parameters(Req, [t(T0, [optional(true), integer])]),
    ( var(T0) -> ahora(T) ; T = T0 ).

responde(Dict) :- cors_enable, reply_json_dict(Dict).

tarjetas(Ts) :- setof(Tj, P^E^D^credencial(Tj, P, E, D), Ts).

%% ---------------------------------------------------------------
%% Endpoints
%% ---------------------------------------------------------------

api_catalogo(_) :-
    findall(_{tarjeta:Tj, persona:P, rol:R, turno:Tu},
            (tarjetas(Ts), member(Tj, Ts), duenio(Tj, P), persona(P, R, Tu)), Ts1),
    findall(_{puerta:P, lectores:Ls},
            (puerta(P, _, _, _, _), findall(L, lector(P, L, _), Ls)), Ps),
    ahora(A),
    responde(_{ahora:A, tarjetas:Ts1, puertas:Ps}).

api_estado(Req) :-
    minuto(Req, T),
    findall(Dp, estado_puerta(T, Dp), Puertas),
    findall(_{tarjeta:Tj, quien:QS, persona:P, rol:R, zona:Z, estado_servidor:ES, activa:Act},
            ( tarjetas(Ts), member(Tj, Ts),
              ubicacion(Tj, T, T, Z, _), quien(Tj, T, Q), quien_txt(Q, QS),
              duenio(Tj, P), persona(P, R, _),
              estado_servidor(Tj, T, ES), ( ES == activa -> Act = true ; Act = false ) ),
            Personas),
    ( alarma_activa(T) -> Al = true ; Al = false ),
    ( servidor_disponible(T) -> Sv = true ; Sv = false ),
    aggregate_all(count, (alerta_relevante(_, S, _, T), functor(S, F, _), severidad(F, critica)), NCrit),
    responde(_{minuto:T, alarma:Al, servidor_disponible:Sv, criticas:NCrit,
               puertas:Puertas, personas:Personas}).

estado_puerta(T, _{puerta:P, de:Z1, a:Z2, modo:M, tipo:Ti, energia:E,
                   contacto:CE, contacto_texto:CS, sincronizada:S, desactualizada_para:Des,
                   transitable:TV, transitable_texto:TR, lectores:Ls}) :-
    puerta(P, Z1, Z2, M, Ti),
    energia(P, T, E),
    estado_contacto(P, T, C),
    ( C = abierta(_) -> CE = abierta ; C = cerrada(_) -> CE = cerrada ; CE = no_se_sabe ),
    contacto_txt(C, CS),
    ultima_sincronizacion(P, T, S),
    findall(Tj, situacion(puerta(P), desactualizada(Tj), _, T), Des),
    transitable(P, T, TV, R), frase(R, TR),
    findall(L, lector(P, L, _), Ls).

contacto_txt(abierta(desde(M)), S) :- !, format(string(S), "abierta desde min ~w", [M]).
contacto_txt(cerrada(desde(M)), S) :- !, format(string(S), "cerrada desde min ~w", [M]).
contacto_txt(no_se_sabe(R), S) :- frase(R, S0), format(string(S), "no se sabe · ~w", [S0]).

api_dentro(Req) :-
    minuto(Req, T),
    http_parameters(Req, [zona(Z0, [optional(true), atom])]),
    findall(_{zona:Z, quien:QS},
            ( dentro(Z, Q, T), ( var(Z0) -> true ; Z == Z0 ), quien_txt(Q, QS) ),
            L),
    responde(_{minuto:T, dentro:L}).

intento_de(Req, intento(Tj, P, L, T), Modo) :-
    http_parameters(Req, [tarjeta(Tj, [atom]), puerta(P, [atom]),
                          lector(L, [atom, default(entrada)]),
                          t(T0, [optional(true), integer]),
                          modo(Modo, [oneof([tiempo_real, auditoria]), default(tiempo_real)])]),
    ( var(T0) -> ahora(T) ; T = T0 ).

api_decide(Req) :-
    intento_de(Req, I, Modo),
    (   Modo == auditoria -> auditar(I, D, E) ; decide(I, D, E) ),
    findall(_{condicion:N, valor:V, detalle:Fs},
            (member(c(N, V, Det), E), detalle_frases(Det, Fs)), Conds),
    findall(S, (member(X, E), X \= c(_, _, _), X \= choque(_, _, _, _), frase(X, S)), Notas),
    choques_en(E, Ch),
    I = intento(Tj, P, L, T),
    ( duenio(Tj, Per), persona(Per, Rol, Tu) -> true ; Per = desconocida, Rol = '-', Tu = '-' ),
    responde(_{tarjeta:Tj, puerta:P, lector:L, minuto:T, modo:Modo, decision:D,
               persona:Per, rol:Rol, turno:Tu,
               condiciones:Conds, notas:Notas, choques:Ch}).

api_que_falta(Req) :-
    intento_de(Req, I, _),
    que_falta(I, Cs),
    (   Cs = ya_abre(D)
    ->  responde(_{ya_abre:D, cambios:[]})
    ;   findall(_{cambio:S, decision:D}, (member(cambio([C], D), Cs), frase(C, S)), L),
        responde(_{ya_abre:null, cambios:L})
    ).

api_alertas(Req) :-
    minuto(Req, T),
    findall(_{entidad:ES, situacion:SS, tipo:F, severidad:Sev, minuto:M, aviso:Av, evidencia:EvS},
            ( alerta_relevante(Ent, S, Ev, T),
              entidad_txt(Ent, ES), frase(S, SS),
              functor(S, F, _), severidad(F, Sev),
              ( compound(S), arg(1, S, M0), integer(M0) -> M = M0 ; S = uso_incompatible(uso(M, _), _) -> true ; M = null ),
              ( memberchk(aviso(A), Ev) -> nombre(A, Av) ; Av = null ),
              exclude([X]>>(X = aviso(_)), Ev, Ev1),
              maplist(frase, Ev1, EvS) ),
            L),
    responde(_{minuto:T, alertas:L}).

entidad_txt(puerta(P), S) :- !, format(string(S0), "Puerta ~w", [P]), nombre_s(S0, S).
entidad_txt(tarjeta(T), S) :- !, format(string(S), "Tarjeta ~w", [T]).
entidad_txt(Q, S) :- quien_txt(Q, S).
nombre_s(S0, S) :- split_string(S0, "_", "", Ps), atomic_list_concat(Ps, ' ', A), atom_string(A, S).

alerta_relevante(Ent, S, Ev, T) :-
    situacion(Ent, S, Ev, T),
    functor(S, F, _),
    severidad(F, _).

api_emergencia(Req) :-
    minuto(Req, T),
    plan_emergencia(T, plan(alarma(A), puertas(Ps), personas(Pe), alertas(Al)), Ch0),
    findall(_{quien:QS, zona:Z, ruta:RS, sin_salida:false, tarjeta_activa:Act},
            ( member(sale(Q, desde(Z), por(R)), Pe), quien_txt(Q, QS), maplist(frase, R, RS),
              ( Q = persona(_) -> Act = true ; Act = false ) ), L1),
    findall(_{quien:QS, zona:Z, ruta:[], sin_salida:true, tarjeta_activa:true},
            ( member(sin_salida(Q, en(Z)), Pe), quien_txt(Q, QS) ), L2),
    append(L1, L2, Personas),
    findall(_{puerta:P, transitable:V, razon:RS},
            (member(puerta(P, V, R), Ps), frase(R, RS)), JP),
    maplist(frase, Al, JA),
    choques_en(Ch0, Ch),
    ( energia(acceso_principal, T, E) -> true ; E = no_se_sabe ),
    responde(_{minuto:T, alarma:A, energia:E, puertas:JP, personas:Personas, alertas:JA, choques:Ch}).

api_tarjeta(Req) :-
    http_parameters(Req, [tarjeta(Tj, [atom]), t(T0, [optional(true), integer]),
                          reporte(MR, [optional(true), integer])]),
    ( var(T0) -> ahora(T) ; T = T0 ),
    duenio(Tj, Per), persona(Per, Rol, Tu),
    estado_servidor(Tj, T, ES),
    findall(_{estado:E, desde:D}, credencial(Tj, _, E, D), Hist),
    puertas_expuestas(Tj, T, Exp),
    usos(Tj, T, Us),
    findall(_{minuto:M, puerta:P, clase:C, texto:CS},
            (member(uso(M, P), Us), clasifica_uso(Tj, uso(M, P), C, _), frase(C, CS)), JUs),
    findall(_{a:_{minuto:M1, puerta:P1}, b:_{minuto:M2, puerta:P2}, evidencia:EvS},
            ( uso_incompatible(Tj, T, uso(M1, P1), uso(M2, P2), Ev), maplist(frase, Ev, EvS) ), Inc),
    (   integer(MR)
    ->  hipotesis_reporte(Tj, MR, Cmp),
        findall(_{minuto:M, puerta:P, real:R, hipotesis:H},
                member(cmp(uso(M, P), real(R), hipotesis(H)), Cmp), JH)
    ;   JH = []
    ),
    responde(_{tarjeta:Tj, persona:Per, rol:Rol, turno:Tu, minuto:T, servidor:ES, historial:Hist,
               puertas_expuestas:Exp, usos:JUs, usos_incompatibles:Inc, hipotesis:JH}).
