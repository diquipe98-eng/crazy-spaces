extends Node
## Mando en los menús de un dispositivo táctil (teléfono con mando): sin foco inicial,
## el primer botón del mando debe enfocar algo visible y A debe pulsarlo.

var fallos := 0

func _ok(c: bool, que: String) -> void:
	print(("  ✓ " if c else "  ✗ ") + que)
	if not c:
		fallos += 1

func _boton(b: JoyButton, pulsado := true) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = b
	ev.pressed = pulsado
	Input.parse_input_event(ev)

func _tocar(b: JoyButton) -> void:
	_boton(b, true)
	await get_tree().process_frame
	_boton(b, false)
	for i in 3:
		await get_tree().process_frame

func _ready() -> void:
	Progreso.guardado_activo = false
	Progreso.saltar_tutorial()
	Ajustes.forzar_tactil(true)
	Progreso.piloto = ""           # para que salga la bienvenida
	var menu = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	get_tree().current_scene = menu
	for i in 10:
		await get_tree().process_frame
	var vp := get_viewport()
	# bienvenida (modal): el mando enfoca su botón, no lo de atrás
	await _tocar(JOY_BUTTON_DPAD_DOWN)
	var f := vp.gui_get_focus_owner()
	_ok(f != null and menu._bienvenida.is_ancestor_of(f) and f is Boton, "en la bienvenida el mando enfoca un botón de la ventana: %s" % (f.texto if f is Boton else str(f)))
	await _tocar(JOY_BUTTON_DPAD_RIGHT)
	await _tocar(JOY_BUTTON_A)
	_ok(not menu._bienvenida.visible and Progreso.piloto != "", "A pulsa el botón y cierra la bienvenida (%s)" % Progreso.piloto)
	# inicio sin foco (táctil): primer botón del mando enfoca JUGAR
	vp.gui_release_focus()
	await _tocar(JOY_BUTTON_DPAD_DOWN)
	f = vp.gui_get_focus_owner()
	_ok(f is Boton and f.texto == "JUGAR", "en el inicio el mando enfoca JUGAR (%s)" % (f.texto if f is Boton else str(f)))
	await _tocar(JOY_BUTTON_DPAD_DOWN)
	f = vp.gui_get_focus_owner()
	_ok(f is Boton and f.texto != "JUGAR", "abajo mueve el foco (%s)" % (f.texto if f is Boton else str(f)))
	# ir a AJUSTES con el mando
	for i in 4:
		f = vp.gui_get_focus_owner()
		if f is Boton and f.texto == "AJUSTES":
			break
		await _tocar(JOY_BUTTON_DPAD_RIGHT)
	_ok(vp.gui_get_focus_owner() is Boton and vp.gui_get_focus_owner().texto == "AJUSTES", "llega a AJUSTES con las flechas")
	await _tocar(JOY_BUTTON_A)
	_ok(menu._vista == "ajustes", "A abre AJUSTES")
	# el foco quedó en un botón oculto del inicio: el mando debe saltar a uno visible
	await _tocar(JOY_BUTTON_DPAD_DOWN)
	f = vp.gui_get_focus_owner()
	_ok(f != null and f.is_visible_in_tree(), "en AJUSTES el foco está en algo visible (%s)" % (f.texto if f is Boton else str(f)))
	await _tocar(JOY_BUTTON_B)
	_ok(menu._vista == "inicio", "B vuelve al inicio")
	# en plena partida no debe haber botones que roben el A (dash)
	menu.queue_free()
	var juego = load("res://scenes/juego.tscn").instantiate()
	add_child(juego)
	get_tree().current_scene = juego
	for i in 60:
		await get_tree().process_frame
	var pb = Mando.primer_boton()
	_ok(juego.estado != "jugando" or pb == null, "jugando: el mando no enfoca botones (estado %s, %s)" % [juego.estado, str(pb)])
	Ajustes.forzar_tactil(false)
	print("RESULTADO: ", "OK" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
