extends Node
## Comprueba el flujo del tutorial de primera vez y, con ventana, guarda capturas:
##   godot --path . res://tests/prueba_tutorial.tscn --resolution 1280x720 [-- --tactil]

var fallos := 0

func _ok(cond: bool, texto: String) -> void:
	print(("  ✓ " if cond else "  ✗ ") + texto)
	if not cond:
		fallos += 1

func _foto(nombre: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in 40:   # deja terminar la animación de entrada
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("user://capturas")
	var sufijo := "_tactil" if Ajustes.es_tactil() else ""
	get_viewport().get_texture().get_image().save_png("user://capturas/tutorial_%s%s.png" % [nombre, sufijo])

func _cerrar(tut: Tutorial) -> void:
	tut._t = 1.0
	tut._siguiente()
	await get_tree().process_frame

func _ready() -> void:
	Progreso.guardado_activo = false
	Progreso.tutorial = {}
	var juego = load("res://scenes/juego.tscn").instantiate()
	add_child(juego)
	await get_tree().process_frame
	await get_tree().process_frame
	var tut: Tutorial = juego.pantallas.tutorial
	print("TUTORIAL")
	_ok(juego.estado == "tutorial" and tut.abierto(), "la primera partida abre CONTROLES y congela el juego")
	var t0: float = juego.tiempo
	await get_tree().process_frame
	_ok(juego.tiempo == t0, "el tiempo no corre con la ventana abierta")
	await _foto("controles")
	await _cerrar(tut)
	_ok(juego.estado == "jugando" and not tut.abierto(), "al cerrarla se vuelve a jugar")
	juego.tiempo = 13.0
	await get_tree().process_frame
	_ok(tut.abierto() and juego.estado == "tutorial", "a los 12 s aparece MECÁNICAS")
	await _foto("mecanicas")
	await _cerrar(tut)
	juego.abrir_mejoras(false)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(tut.abierto() and juego.estado == "mejora", "al subir de nivel aparece SUBIR DE NIVEL sobre las tarjetas")
	await _foto("nivel")
	await _cerrar(tut)
	_ok(juego.estado == "mejora", "al cerrarla siguen las tarjetas para elegir")
	juego.elegir_mejora("dmg")
	juego._iniciar_jefe()
	juego.jefe.asentado = true
	await get_tree().process_frame
	_ok(tut.abierto(), "con el primer jefe aparece COMBATE DE JEFE")
	await _foto("jefe")
	await _cerrar(tut)
	_ok(Progreso.tutorial.size() == 4, "las 4 ventanas quedan marcadas como vistas")
	juego.nueva_partida()
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(not tut.abierto() and juego.estado == "jugando", "en la segunda partida ya no sale")
	# SALTAR marca todo
	Progreso.tutorial = {}
	juego.nueva_partida()
	await get_tree().process_frame
	await get_tree().process_frame
	tut._saltar()
	await get_tree().process_frame
	_ok(Progreso.tutorial.size() == 4 and juego.estado == "jugando", "SALTAR TUTORIAL lo cierra y no vuelve a salir")
	# la segunda partida (aunque sea con REINICIAR) ya no muestra ventanas
	Progreso.tutorial = {}
	juego.nueva_partida()
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(tut.abierto(), "con el progreso de tutorial borrado vuelve a salir (JUGAR CON TUTORIAL)")
	await _cerrar(tut)
	juego.nueva_partida()
	await get_tree().process_frame
	juego.abrir_mejoras(false)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(not tut.abierto(), "tras la primera partida no vuelve a salir ninguna ventana")
	print("RESULTADO: ", "OK" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
