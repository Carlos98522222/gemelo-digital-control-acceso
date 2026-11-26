:- encoding(utf8).
/*  Pruebas plunit del gemelo digital (proyecto #7)
    Ejecutar desde gemelo/:  swipl -g run_tests -t halt tests/reglas_tests.pl
*/

:- prolog_load_context(directory, D),
   atom_concat(D, '/../reglas.pl', R),
   consult(R).
:- use_module(library(plunit)).

abre(D) :- memberchk(D, [abrir, abrir_y_alertar]).

%% =================================================================
%% Criterio 1 — Derecho vigente (situacion 1)
%% =================================================================
:- begin_tests(s1_derecho_vigente).

test(misma_tarjeta_abre_en_su_turno) :-
    decide(intento(t_rosa, linea_produccion, entrada, 600), abrir, _).

test(misma_tarjeta_se_niega_fuera_de_turno) :-
    decide(intento(t_rosa, linea_produccion, entrada, 900), negar, E),
    memberchk(c(derecho, no, persona(rosa, Det)), E),
    memberchk(regla_general_niega(fuera_de_turno(operador, planta, matutino), _), Det).

test(excepcion_vigente_cambia_resultado_y_se_nombra) :-
    decide(intento(t_ivan, linea_produccion, entrada, 780), abrir, E),
    memberchk(c(derecho, si, persona(ivan, Det)), E),
    memberchk(excepcion_aplica(exc(cobertura_vacante, marta, 760, 900), _), Det),
    memberchk(choque(regla_general, _, gana(excepcion), _), Det).

test(sin_excepcion_ivan_se_niega) :-
    con_hipotesis([quita(excepcion(ivan, _, _, _, _, _))],
                  decide(intento(t_ivan, linea_produccion, entrada, 780), negar, _)).

test(excepcion_vencida_no_cuenta) :-
    con_hipotesis([quita(excepcion(ivan, _, _, _, _, _)),
                   agrega(excepcion(ivan, linea_produccion, cobertura_vacante, marta, 700, 770))],
                  decide(intento(t_ivan, linea_produccion, entrada, 780), negar, E)),
    memberchk(c(derecho, no, persona(ivan, Det)), E),
    memberchk(excepcion_no_valida(_, fuera_de_vigencia(700, 770)), Det).

test(excepcion_de_quien_no_tiene_facultad_no_cuenta) :-
    con_hipotesis([quita(excepcion(ivan, _, _, _, _, _)),
                   agrega(excepcion(ivan, linea_produccion, cobertura_vacante, rosa, 760, 900))],
                  decide(intento(t_ivan, linea_produccion, entrada, 780), negar, E)),
    memberchk(c(derecho, no, persona(ivan, Det)), E),
    memberchk(excepcion_no_valida(_, sin_facultad(rosa, operador, planta)), Det).

test(visitante_no_abre_oficinas) :-
    decide(intento(t_visit, oficinas, entrada, 600), negar, E),
    memberchk(c(derecho, no, persona(visitante, Det)), E),
    memberchk(regla_general_niega(rol_sin_permiso(visitante, oficinas), _), Det).

test(consulta_inversa_dice_que_cambiaria) :-
    que_falta(intento(t_visit, oficinas, entrada, 600), Cambios),
    % la vigilancia puede dar la excepcion; la supervisora no tiene facultad en oficinas
    memberchk(cambio([agrega(excepcion(visitante, oficinas, _, beto, _, _))], abrir), Cambios),
    \+ memberchk(cambio([agrega(excepcion(visitante, oficinas, _, marta, _, _))], _), Cambios).

test(quienes_podrian_pasar) :-
    podrian_pasar(linea_produccion, 780, Ps),
    memberchk(ivan, Ps), \+ memberchk(pedro, Ps), \+ memberchk(visitante, Ps).

:- end_tests(s1_derecho_vigente).

%% =================================================================
%% Criterio 2 — Orden de eventos y anti-passback (situacion 2)
%% =================================================================
:- begin_tests(s2_orden_de_eventos).

test(en_tiempo_real_rosa_es_no_se_sabe_y_aplica_politica) :-
    decide(intento(t_rosa, acceso_principal, entrada, 705), abrir_y_alertar, E),
    memberchk(c(antipassback, no_se_sabe, Det), E),
    memberchk(lector_sin_reportar(acceso_principal, salida, _), Det),
    memberchk(politica(acceso_principal, abrir_y_alertar), E).

test(ordenando_por_el_lector_rosa_si_salio) :-
    auditar(intento(t_rosa, acceso_principal, entrada, 705), abrir, E),
    memberchk(c(antipassback, si, Det), E),
    memberchk(ultimo_evento(acceso_principal, salida, sale, reloj_lector(700), llego(712)), Det).

test(reuso_de_tarjeta_se_niega) :-
    decide(intento(t_luis, acceso_principal, entrada, 620), negar, E),
    memberchk(c(antipassback, no, Det), E),
    memberchk(posicion(dentro), Det).

test(orden_incierto_da_no_se_sabe_nunca_si_o_no_silencioso) :-
    con_hipotesis([agrega(evento(acceso_principal, entrada, t_rosa, concedido, 701, 701))],
                  auditar(intento(t_rosa, acceso_principal, entrada, 705), D, E)),
    D == abrir_y_alertar,
    memberchk(c(antipassback, no_se_sabe, Det), E),
    memberchk(orden_incierto(_, _, _), Det).

test(politica_en_puerta_protegida_es_negar) :-
    politica_de(almacen, negar_y_alertar).

test(quien_esta_dentro_de_la_planta) :-
    findall(Q, dentro(planta, Q, 720), Qs),
    msort(Qs, S),
    S == [persona(beto), persona(jorge), persona(rosa), persona(visitante)].

:- end_tests(s2_orden_de_eventos).

%% =================================================================
%% Criterio 3 — Revocacion y puertas sin conexion (situacion 3)
%% =================================================================
:- begin_tests(s3_tarjeta_robada).

test(servidor_y_puerta_saben_cosas_distintas) :-
    estado_servidor(t_marta, 610, revocada),
    estado_en_puerta(almacen, t_marta, 610, activa, copia_local(sincronizada_en(598))).

test(puertas_que_aun_la_aceptan) :-
    puertas_expuestas(t_marta, 611, Ps),
    msort(Ps, [acceso_principal, almacen, linea_produccion]),
    \+ memberchk(oficinas, Ps).          % oficinas se sincronizo en 602

test(despues_de_sincronizar_ninguna_la_acepta) :-
    puertas_expuestas(t_marta, 640, []).

test(usos_incompatibles_con_una_sola_persona) :-
    findall(U1-U2, uso_incompatible(t_marta, 720, U1, U2, _), Ps),
    memberchk(uso(610, acceso_principal)-uso(610, linea_produccion), Ps),
    memberchk(uso(610, linea_produccion)-uso(611, almacen), Ps).

test(usos_clasificados) :-
    clasifica_uso(t_marta, uso(593, acceso_principal), antes_del_reporte_probable_duenio, _),
    clasifica_uso(t_marta, uso(611, almacen), la_puerta_no_lo_sabia, _).

test(la_puerta_abrio_pero_se_alerta) :-
    decide(intento(t_marta, almacen, entrada, 611), abrir_y_alertar, E),
    memberchk(alerta(vigilancia, puerta_desactualizada(almacen, t_marta, servidor_dice(revocada))), E).

test(hipotesis_reporte_antes_del_primer_uso) :-
    hipotesis_reporte(t_marta, 595, C),
    memberchk(cmp(uso(610, acceso_principal), real(abrir_y_alertar), hipotesis(negar)), C),
    memberchk(cmp(uso(611, almacen),          real(abrir_y_alertar), hipotesis(negar)), C),
    memberchk(cmp(uso(593, acceso_principal), real(abrir), hipotesis(abrir)), C).

test(hipotesis_reporte_con_servidor_caido_no_alcanza) :-
    % reportar en 605 no sirve: el servidor ya estaba caido y nadie se sincroniza
    hipotesis_reporte(t_marta, 605, C),
    memberchk(cmp(uso(611, almacen), _, hipotesis(abrir_y_alertar)), C).

:- end_tests(s3_tarjeta_robada).

%% =================================================================
%% Criterio 4 — Emergencia (situacion 4)
%% =================================================================
:- begin_tests(s4_emergencia).

test(cada_quien_tiene_ruta_o_aviso) :-
    plan_emergencia(645, plan(alarma(si), _, personas(Ps), _), _),
    findall(Q, dentro(_, Q, 645), Dentro),
    forall(member(Q, Dentro),
           ( memberchk(sale(Q, _, _), Ps) ; memberchk(sin_salida(Q, _), Ps) )).

test(luis_sale_por_emergencia) :-
    plan_emergencia(645, plan(_, _, personas(Ps), _), _),
    memberchk(sale(persona(luis), desde(almacen), por([paso(emergencia_almacen, calle)])), Ps).

test(salida_de_emergencia_abre_aun_revocada_y_se_alerta) :-
    decide(intento(t_marta, emergencia_almacen, barra, 645), abrir_y_alertar, E),
    memberchk(alerta(vigilancia, salida_por_emergencia(t_marta, revocada)), E),
    memberchk(choque(salida_de_emergencia_abre_siempre, credencial_no_activa_no_abre,
                     gana(salida_de_emergencia_abre_siempre),
                     se_le_falla(seguridad_patrimonial)), E).

test(entrada_protegida_sigue_cerrada) :-
    decide(intento(t_marta, almacen, entrada, 645), negar, E),
    memberchk(c(energia, no, sin_energia(fail_secure, puerta_cerrada)), E),
    transitable(almacen, 645, no, _).

test(quien_queda_sin_salida_y_a_quien_se_le_falla) :-
    plan_emergencia(645, plan(_, _, personas(Ps), alertas(Al)), Ch),
    memberchk(sin_salida(persona(rosa), en(planta)), Ps),
    memberchk(alerta(vigilancia, liberar_manualmente_para(persona(rosa), planta)), Al),
    member(choque(fail_secure_protege_la_entrada, evacuacion, _, se_le_falla(F)), Ch),
    is_list(F), memberchk(persona(rosa), F), !.

:- end_tests(s4_emergencia).

%% =================================================================
%% Criterio 5 — Puerta anomala (situacion 5)
%% =================================================================
:- begin_tests(s5_puerta_anomala).

test(cuatro_veredictos_distintos) :-
    clasifica_apertura(almacen, 500, 720, forzada, _),
    clasifica_apertura(almacen, 520, 720, tailgating, _),
    clasifica_apertura(almacen, 540, 720, abierta_de_mas, _),
    clasifica_apertura(almacen, 450, 720, apertura_con_excepcion, _).

test(acceso_normal_no_es_anomalia) :-
    clasifica_apertura(almacen, 400, 720, normal, _).

test(a_quien_despertar, [nondet]) :-
    situacion(puerta(almacen), forzada(500), [aviso(despertar_vigilante)|_]),
    situacion(puerta(almacen), apertura_con_excepcion(450), [aviso(solo_registro)|_]).

test(sin_orden_de_trabajo_la_apertura_es_forzada) :-
    con_hipotesis([quita(excepcion(jorge, _, _, _, _, _))],
                  clasifica_apertura(almacen, 450, 720, forzada, _)).

test(sin_lectura_de_contacto_es_no_se_sabe_no_cerrada) :-
    estado_contacto(linea_produccion, 720, no_se_sabe(lectura_fuera_de_rango(contacto, 7, 470))),
    estado_contacto(oficinas, 720, no_se_sabe(sin_sensor_de_contacto)),
    \+ estado_contacto(linea_produccion, 720, cerrada(_)).

test(sin_contacto_no_hay_alerta_falsa_de_forzada) :-
    \+ situacion(puerta(linea_produccion), forzada(_), _),
    \+ situacion(puerta(oficinas), forzada(_), _).

:- end_tests(s5_puerta_anomala).

%% =================================================================
%% Criterio 6 — Las cinco preguntas, con las mismas reglas
%% =================================================================
:- begin_tests(c6_cinco_preguntas).

test(decision) :-
    decide(intento(t_ivan, linea_produccion, entrada, 780), D, _), D == abrir.

test(explicacion) :-
    % ¿Por que se nego la entrada que uso la tarjeta de Luis? (y no la de Rosa)
    decide(intento(t_luis, acceso_principal, entrada, 620), negar, E),
    memberchk(c(antipassback, no, _), E).

test(todas_las_respuestas) :-
    findall(Q, situacion(Q, dentro(almacen), _), Qs),
    memberchk(persona(luis), Qs),
    memberchk(portador(t_marta, revocada, de(marta)), Qs).

test(pregunta_al_reves) :-
    que_falta(intento(t_visit, oficinas, entrada, 600), Cs), Cs \== [].

test(hipotesis) :-
    con_hipotesis([quita(credencial(t_marta, _, reportada, _)),
                   quita(credencial(t_marta, _, revocada, _)),
                   agrega(credencial(t_marta, marta, revocada, 590))],
                  decide(intento(t_marta, almacen, entrada, 611), negar, _)).

test(hipotesis_no_deja_rastro) :-
    findall(x, credencial(t_marta, _, _, _), L), length(L, 3).

:- end_tests(c6_cinco_preguntas).
