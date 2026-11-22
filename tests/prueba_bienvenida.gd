extends Node
## Bienvenida de la primera vez: sale sola, propone nombre, valida y guarda.
## Con `-- --capturas` guarda imágenes en user://capturas/.

func _ready() -> void:
	Progreso.guardado_activo = false
	Progreso.saltar_tutorial()
	Progreso.piloto = ""          # simula primera vez
	var fallos := 0
	assert(Progreso.limpiar_nombre("  José niño ") == "JOSE_NINO")
	assert(Progreso.limpiar_nombre("a-b.c!d") == "ABCD")
	assert(Progreso.limpiar_nombre("x".repeat(30)).length() == 14)
	var menu = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	for i in 30:
		await get_tree().process_frame
	var b: Bienvenida = menu._bienvenida
	if not b.visible:
		push_error("la bienvenida no salió la primera vez"); fallos += 1
	await _captura("bienvenida")
	# nombre muy corto -> error y sigue abierta
	b._campo.text = "AB"
	b._aceptar()
	if not b.visible or b._error == "":
		push_error("aceptó un nombre corto"); fallos += 1
	b._campo.text = "nova_kid"
	b._al_escribir(b._campo.text)
	b._aceptar()
	if b.visible or Progreso.piloto != "NOVA_KID":
		push_error("no guardó el nombre: %s" % Progreso.piloto); fallos += 1
	for i in 5:
		await get_tree().process_frame
	await _captura("menu_con_nombre")
	menu._ir("ajustes")
	for i in 5:
		await get_tree().process_frame
	await _captura("ajustes")
	menu._ir("inicio")
	# cambiar desde ajustes
	b.abrir(false)
	if b._campo.text != "NOVA_KID":
		push_error("cambiar nombre no muestra el actual"); fallos += 1
	b._accion_otro()   # cancelar
	if b.visible or Progreso.piloto != "NOVA_KID":
		push_error("cancelar cambió el nombre"); fallos += 1
	# segunda vez: ya no sale
	menu.queue_free()
	await get_tree().process_frame
	var menu2 = load("res://scenes/menu.tscn").instantiate()
	add_child(menu2)
	await get_tree().process_frame
	if menu2._bienvenida.visible:
		push_error("la bienvenida salió con nombre ya elegido"); fallos += 1
	print("PRUEBA BIENVENIDA: ", "OK" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(1 if fallos else 0)

func _captura(n: String) -> void:
	if not "--capturas" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://capturas")
	get_viewport().get_texture().get_image().save_png("user://capturas/%s.png" % n)
