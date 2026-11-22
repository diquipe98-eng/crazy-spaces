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

func _ready() -> void:
	Progreso.guardado_activo = false
	Progreso.saltar_tutorial()
	Red.salir()
	Red.top = []
	print("TABLA GLOBAL (", Red.url, ")")
	_ok(Red.configurado(), "configurada por línea de comandos")
	var r := await Red.registrar("ab", "123456")
	_ok(not r.ok and "entre 3 y 14" in r.error, "rechaza nombres cortos: " + r.error)
	r = await Red.registrar("PILOTO_UNO", "123")
	_ok(not r.ok and "6" in r.error, "rechaza contraseñas cortas: " + r.error)
	r = await Red.registrar("piloto_uno", "secreta1")
	_ok(r.ok and Red.conectado() and Red.nombre == "PILOTO_UNO", "registro correcto (nombre en mayúsculas)")
	var yo := Red.uid
	r = await Red.registrar("PILOTO_UNO", "otra123")
	_ok(not r.ok and "en uso" in r.error, "nombre repetido: " + r.error)
	Red.salir()
	_ok(not Red.conectado(), "cerrar sesión")
	r = await Red.entrar("PILOTO_UNO", "mala123")
	_ok(not r.ok and "incorrectos" in r.error, "contraseña mala: " + r.error)
	r = await Red.entrar("piloto_uno", "secreta1")
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
		await Red.registrar("RIVAL_%d" % i, "clave%d00" % i)
		await Red.enviar_partida(1000 + i * 900, 200.0 + i * 20, 5 + i, i % 4, ["drift", "comet", "spectra", "vortex"][i % 4])
	Red.salir()
	await Red.entrar("PILOTO_UNO", "secreta1")
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
	await Red.registrar("NOVATO", "novato1")
	r = await Red.cargar_ranking(0, 10)
	_ok(r.ok and int(r.datos.total) == 13 and r.datos.filas.size() == 10, "marcadores: 13 pilotos registrados, página de 10")
	r = await Red.cargar_ranking(10, 10)
	_ok(r.ok and r.datos.filas.size() == 3 and r.datos.filas[-1].nombre == "NOVATO" and r.datos.filas[-1].puntaje == null, "página 2: el que no ha jugado va al final, sin puntaje")
	_ok(await Red.posicion_de(Red.uid) == 13, "posición de un piloto para saltar a su página")
	Red.salir()
	await Red.entrar("PILOTO_UNO", "secreta1")
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
	print("RESULTADO: ", "OK" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
