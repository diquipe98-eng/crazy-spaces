extends Node
## Navegación con mando (o teclado) en los menús, también en teléfonos y en la web.
## Las pantallas no dan foco a ningún botón en dispositivos táctiles; al usar el mando
## sin nada enfocado (o con el foco en algo oculto) se enfoca el primer botón visible de
## la ventana que esté encima (bienvenida, formulario, perfil, tutorial...) o de la escena.
## Las ventanas modales se marcan con set_meta("modal", true).

var usando_mando := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Godot no trae botones de mando para aceptar/atrás: sin esto el mando movía el
	# foco pero no podía elegir nada. A = aceptar, B = atrás (en partida A es dash,
	# pero ahí no hay botones enfocados).
	_asignar("ui_accept", JOY_BUTTON_A)
	_asignar("ui_cancel", JOY_BUTTON_B)

func _asignar(accion: String, boton: JoyButton) -> void:
	for e in InputMap.action_get_events(accion):
		if e is InputEventJoypadButton and e.button_index == boton:
			return
	var ev := InputEventJoypadButton.new()
	ev.button_index = boton
	InputMap.action_add_event(accion, ev)

func _input(ev: InputEvent) -> void:
	var de_mando: bool = ev is InputEventJoypadButton or (ev is InputEventJoypadMotion and absf(ev.axis_value) > 0.5)
	var de_navegacion: bool = de_mando or (ev is InputEventKey and ev.pressed and ev.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_TAB])
	if de_mando:
		usando_mando = true
	elif ev is InputEventScreenTouch or ev is InputEventMouseButton:
		usando_mando = false
	if not de_navegacion or not ev.is_pressed():
		return
	var vp := get_viewport()
	var foco := vp.gui_get_focus_owner()
	if foco != null and foco.is_visible_in_tree() and _dentro_de_modal_activo(foco):
		return
	var b := primer_boton()
	if b != null:
		b.grab_focus()
		vp.set_input_as_handled()   # este primer toque solo muestra dónde está el foco

## Primer control enfocable de la ventana superior visible (o de la escena).
func primer_boton() -> Control:
	var raiz: Node = _modal_activo()
	if raiz == null:
		raiz = get_tree().current_scene   # puede no ser un Control (la partida es Node2D)
	if raiz == null:
		return null
	for n in raiz.find_children("*", "Control", true, false):
		var c := n as Control
		if c.is_visible_in_tree() and c.focus_mode == Control.FOCUS_ALL and _dentro_de_modal_activo(c):
			if c is LineEdit and usando_mando:
				continue   # con mando no se escribe: mejor un botón
			if "desactivado" in c and c.desactivado:
				continue
			return c
	return null

func _modal_activo() -> Control:
	var escena := get_tree().current_scene
	if escena == null:
		return null
	var ultimo: Control = null
	for n in escena.find_children("*", "Control", true, false):
		if n.has_meta("modal") and (n as Control).is_visible_in_tree():
			ultimo = n
	return ultimo

func _dentro_de_modal_activo(c: Control) -> bool:
	var m := _modal_activo()
	return m == null or m == c or m.is_ancestor_of(c)
