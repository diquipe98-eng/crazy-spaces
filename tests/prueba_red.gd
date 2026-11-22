extends Node
## Prueba la tabla global contra tests/servidor_falso.py (imitación de Supabase):
##   python3 tests/servidor_falso.py 8790 &
##   godot --path . res://tests/prueba_red.tscn --resolution 1280x720 -- --servidor=http://127.0.0.1:8790 --clave=clave-falsa
## Con ventana guarda capturas de la tabla, el formulario y un perfil.

var fallos := 0

func _ok(cond: bool, texto: String) -> void:
	print(("  ✓ " if cond else "  ✗ ") + texto)
	if not cond:
		fallos += 1

func _foto(nombre: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in 20:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("user://capturas")
	get_viewport().get_texture().get_image().save_png("user://capturas/red_%s.png" % nombre)

## Imita abrir el enlace del correo (el servidor falso devuelve la sesión).
func _falso_confirmar(correo: String) -> Dictionary:
	var h := HTTPRequest.new()
	add_child(h)
	h.request(Red.url + "/falso/confirmar", ["apikey: " + Red.clave, "Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"email": correo}))
	var r: Array = await h.request_completed
	h.queue_free()
	return JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())

func _ready() -> void:
	Progreso.guardado_activo = false
	Progreso.saltar_tutorial()
	Progreso.registros = []     # no subir los récords reales de este equipo
	Red.salir()
	Red.top = []
	print("TABLA GLOBAL (", Red.url, ")")
	_ok(Red.configurado(), "configurada por línea de comandos")
	var r := await Red.registrar("uno@test.com", "ab", "123456")
	_ok(not r.ok and "entre 3 y 14" in r.error, "rechaza nombres cortos: " + r.error)
	r = await Red.registrar("uno@test.com", "PILOTO_UNO", "123")
	_ok(not r.ok and "6" in r.error, "rechaza contraseñas cortas: " + r.error)
	r = await Red.registrar("Uno@Test.com", "piloto_uno", "secreta1")
	_ok(r.ok and Red.conectado() and Red.nombre == "PILOTO_UNO", "registro correcto (nombre en mayúsculas)")
	var yo := Red.uid
	r = await Red.registrar("otro@test.com", "PILOTO_UNO", "otra123")
	_ok(not r.ok and "en uso" in r.error, "nombre repetido: " + r.error)
	r = await Red.registrar("sin-arroba", "OTRO", "otra123")
	_ok(not r.ok and "correo" in r.error, "correo inválido: " + r.error)
	Red.salir()
	_ok(not Red.conectado(), "cerrar sesión")
	r = await Red.entrar("uno@test.com", "mala123")
	_ok(not r.ok and "incorrectos" in r.error, "contraseña mala: " + r.error)
	r = await Red.entrar("UNO@test.com ", "secreta1")
	_ok(r.ok and Red.uid == yo, "entrar con la cuenta")
	r = await Red.enviar_partida(999999, 30.0, 5, 3, "drift")
	_ok(not r.ok and "verificación" in r.error, "rechaza puntajes imposibles: " + r.error)
	r = await Red.enviar_partida(5400, 300.0, 9, 2, "comet")
	_ok(r.ok and int(r.datos.puesto) == 1, "envía la partida y devuelve el puesto")
	# token vencido: debe renovarse solo
	Red.expira = 0.0
	r = await Red.enviar_partida(6100, 320.0, 10, 2, "comet")
	_ok(r.ok, "renueva la sesión vencida sin pedir contraseña")
	# más pilotos para llenar la tabla
	for i in 11:
		Red.salir()
		await Red.registrar("rival%d@test.com" % i, "RIVAL_%d" % i, "clave%d00" % i)
		await Red.enviar_partida(1000 + i * 900, 200.0 + i * 20, 5 + i, i % 4, ["drift", "comet", "spectra", "vortex"][i % 4])
	Red.salir()
	await Red.entrar("uno@test.com", "secreta1")
	r = await Red.cargar_top()
	_ok(r.ok and Red.top.size() == 10, "el top tiene 10 pilotos (hay 12)")
	var orden := true
	for i in range(1, Red.top.size()):
		if int(Red.top[i].puntaje) > int(Red.top[i - 1].puntaje):
			orden = false
	_ok(orden, "ordenado de mayor a menor puntaje")
	_ok(Red.top.filter(func(f): return f.nombre == "PILOTO_UNO").size() == 1, "cada piloto aparece una vez con su mejor partida")
	r = await Red.perfil(yo)
	_ok(r.ok and int(r.datos.partidas) == 2 and int(r.datos.mejor_puntaje) == 6100 and r.datos.ultimas.size() == 2, "perfil con estadísticas y últimas partidas")
	_ok(r.ok and r.datos.nave_favorita == "comet", "nave favorita = la más usada")
	# marcadores: todos los registrados, también los que no han jugado
	Red.salir()
	await Red.registrar("novato@test.com", "NOVATO", "novato1")
	r = await Red.cargar_ranking(0, 10)
	_ok(r.ok and int(r.datos.total) == 13 and r.datos.filas.size() == 10, "marcadores: 13 pilotos registrados, página de 10")
	r = await Red.cargar_ranking(10, 10)
	_ok(r.ok and r.datos.filas.size() == 3 and r.datos.filas[-1].nombre == "NOVATO" and r.datos.filas[-1].puntaje == null, "página 2: el que no ha jugado va al final, sin puntaje")
	_ok(await Red.posicion_de(Red.uid) == 13, "posición de un piloto para saltar a su página")
	Red.salir()
	await Red.entrar("uno@test.com", "secreta1")
	# interfaz: inicio con el top 10 a la derecha
	var menu = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	for i in 30:
		await get_tree().process_frame
	var top: PanelTop10 = menu._top
	_ok(top.visible and top._filas[9].visible, "el inicio muestra el TOP 10 GLOBAL")
	await _foto("inicio")
	top._filas[0].pulsado.emit()
	for i in 30:
		await get_tree().process_frame
	_ok(menu._perfil.visible and menu._perfil._datos != null and menu._perfil._datos.nombre == Red.top[0].nombre, "tocar un piloto del top abre su perfil")
	await _foto("inicio_perfil")
	menu._perfil.cerrar()
	menu._ir("records")
	for i in 30:
		await get_tree().process_frame
	var pos: Posiciones = menu._posiciones
	_ok(pos.visible and pos._filas[9].visible and pos._total == 13, "MARCADORES muestra a los 13 pilotos por páginas")
	await _foto("tabla")
	pos._ir_pagina(1)
	for i in 30:
		await get_tree().process_frame
	_ok(pos._pagina == 1 and pos._filas_datos.size() == 3, "pasar a la página 2")
	await _foto("tabla_p2")
	pos._ir_pagina(0)
	for i in 20:
		await get_tree().process_frame
	pos._pulsar_fila(0)
	for i in 30:
		await get_tree().process_frame
	_ok(pos._perfil.visible and pos._perfil._datos != null, "tocar una fila abre el perfil del piloto")
	await _foto("perfil")
	pos._perfil.cerrar()
	Red.salir()
	pos._abrir_form("registro")
	pos._campo_correo.text = "nuevo@test.com"
	pos._campo_nombre.text = "NUEVO_PILOTO"
	pos._campo_clave.text = "1"
	await pos._enviar_form()
	_ok(pos._form.visible and pos._form_error != "", "el formulario muestra el error")
	await _foto("formulario")
	pos._campo_clave.text = "123456"
	await pos._enviar_form()
	_ok(not pos._form.visible and Red.nombre == "NUEVO_PILOTO", "registrarse desde el formulario")
	for i in 30:
		await get_tree().process_frame
	_ok(pos._pagina == 1, "al registrarse salta a su página")
	await _foto("conectado")
	# olvidé mi contraseña + enlace del correo (type=recovery) + contraseña nueva
	Red.salir()
	pos._abrir_form("entrar")
	_ok(pos._form_olvide.visible, "ENTRAR ofrece OLVIDÉ MI CONTRASEÑA")
	pos._abrir_form("recuperar")
	pos._campo_correo.text = "nuevo@test.com"
	await pos._enviar_form()
	_ok(pos._form_modo == "entrar" and pos._form_aviso != "", "pedir el correo de recuperación")
	await _foto("recuperar")
	var enlace := await _falso_confirmar("nuevo@test.com")
	enlace["type"] = "recovery"
	await Red.aplicar_enlace(enlace)
	for i in 5:
		await get_tree().process_frame
	_ok(Red.conectado() and pos._form.visible and pos._form_modo == "nueva_clave", "el enlace abre el formulario de contraseña nueva")
	await _foto("nueva_clave")
	pos._campo_clave.text = "nueva_secreta"
	await pos._enviar_form()
	_ok(not pos._form.visible and not Red.recuperando, "guardar la contraseña nueva")
	Red.salir()
	r = await Red.entrar("nuevo@test.com", "nueva_secreta")
	_ok(r.ok, "entrar con la contraseña nueva")
	# récord jugado sin cuenta: al registrarse se sube a la tabla global
	Red.salir()
	Progreso.registros = [{"puntaje": 3000, "tiempo": 200.0, "nivel": 8, "jefes": 2, "nave": "spectra"},
		{"puntaje": 900, "tiempo": 90.0, "nivel": 3, "jefes": 0}]
	r = await Red.registrar("local@test.com", "LOCAL_REC", "secreta9")
	r = await Red.perfil(Red.uid)
	_ok(r.ok and int(r.datos.partidas) == 1 and int(r.datos.mejor_puntaje) == 3000 and r.datos.nave_favorita == "spectra", "al registrarse sube su mejor récord offline")
	_ok(Progreso.record_sin_subir().is_empty(), "el récord queda marcado como subido")
	Red.salir()
	r = await Red.entrar("local@test.com", "secreta9")
	r = await Red.perfil(Red.uid)
	_ok(r.ok and int(r.datos.partidas) == 1, "no lo vuelve a subir al entrar otra vez")
	print("RESULTADO: ", "OK" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
