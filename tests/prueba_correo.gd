extends Node
## Registro con "Confirm email" activado (servidor falso con --confirmar):
##   python3 tests/servidor_falso.py 8791 --confirmar &
##   godot --path . res://tests/prueba_correo.tscn -- --servidor=http://127.0.0.1:8791 --clave=clave-falsa

var fallos := 0

func _ok(c: bool, que: String) -> void:
	print(("  ✓ " if c else "  ✗ ") + que)
	if not c:
		fallos += 1

func _ready() -> void:
	Progreso.guardado_activo = false
	Progreso.saltar_tutorial()
	Progreso.registros = []     # no subir los récords reales de este equipo
	Red.salir()
	var r := await Red.registrar("ana@test.com", "ANA_STAR", "secreta1")
	_ok(r.ok and r.datos.confirmar and not Red.conectado(), "registro pide confirmar el correo")
	r = await Red.entrar("ana@test.com", "secreta1")
	_ok(not r.ok and "confirma" in r.error, "sin confirmar no deja entrar: " + r.error)
	# abrir el enlace del correo deja la sesión abierta
	var h := HTTPRequest.new()
	add_child(h)
	h.request(Red.url + "/falso/confirmar", ["apikey: " + Red.clave, "Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"email": "ana@test.com"}))
	var res: Array = await h.request_completed
	var enlace: Dictionary = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	enlace["type"] = "signup"
	await Red.aplicar_enlace(enlace)
	_ok(Red.conectado() and Red.nombre == "ANA_STAR" and Progreso.piloto == "ANA_STAR", "el enlace de confirmación entra con la cuenta")
	Red.salir()
	r = await Red.entrar("ana@test.com", "secreta1")
	_ok(r.ok, "ya confirmada, entra normal")
	# formulario: tras registrarse muestra el aviso y pasa a ENTRAR
	Red.salir()
	var menu = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	menu._ir("records")
	var pos: Posiciones = menu._posiciones
	pos._abrir_form("registro")
	pos._campo_correo.text = "beto@test.com"
	pos._campo_nombre.text = "BETO"
	pos._campo_clave.text = "secreta2"
	await pos._enviar_form()
	_ok(pos._form.visible and pos._form_modo == "entrar" and "CORREO" in pos._form_aviso, "el formulario avisa de revisar el correo")
	if not DisplayServer.get_name() == "headless":
		for i in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://capturas")
		get_viewport().get_texture().get_image().save_png("user://capturas/red_revisa_correo.png")
	print("RESULTADO: ", "OK" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
