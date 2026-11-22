class_name Bienvenida
extends Control
## Ventanita para elegir el nombre del piloto. Sale sola la primera vez que se abre
## el juego y también desde AJUSTES > CAMBIAR NOMBRE.
## Propone el nombre de la cuenta con la que entró (o el del usuario del sistema);
## si no hay ninguno, ofrece uno al azar.

signal cerrado

var _primera := true
var _sugerido := ""
var _error := ""
var _campo: LineEdit
var _ok: Boton
var _otro: Boton

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_meta("modal", true)
	_campo = LineEdit.new()
	_campo.placeholder_text = "TU NOMBRE"
	_campo.max_length = 14
	_campo.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_campo.add_theme_font_override("font", Datos.fuente)
	_campo.add_theme_font_size_override("font_size", 12)
	_campo.add_theme_color_override("font_color", Neon.AMARILLO)
	_campo.add_theme_color_override("font_placeholder_color", Color(0.5, 0.55, 0.75))
	_campo.add_theme_color_override("caret_color", Neon.CIAN)
	for estado in ["normal", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.02, 0.04, 0.12, 0.95)
		sb.border_color = Neon.CIAN if estado == "focus" else Color(0.3, 0.45, 0.7)
		sb.set_border_width_all(2 if estado == "focus" else 1)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		_campo.add_theme_stylebox_override(estado, sb)
	_campo.text_changed.connect(_al_escribir)
	_campo.text_submitted.connect(func(_t): _aceptar())
	add_child(_campo)
	_ok = Boton.new("LISTO", Neon.AMARILLO, 9)
	_ok.pulsado.connect(_aceptar)
	add_child(_ok)
	_otro = Boton.new("", Neon.CIAN, 7)
	_otro.pulsado.connect(_accion_otro)
	add_child(_otro)
	resized.connect(_colocar)

## primera = true: bienvenida inicial (no se puede cerrar sin nombre).
func abrir(primera: bool) -> void:
	_primera = primera
	_error = ""
	_sugerido = Progreso.nombre_sugerido()
	if primera:
		_campo.text = _sugerido if _sugerido != "" else ""
		_otro.texto = ("USAR " + _sugerido) if _sugerido != "" else "NOMBRE AL AZAR"
	else:
		_campo.text = Progreso.piloto
		_otro.texto = "CANCELAR"
	_otro.color = Neon.CIAN if primera else Neon.ROSA
	_campo.caret_column = _campo.text.length()
	visible = true
	_colocar()
	_campo.grab_focus.call_deferred()
	queue_redraw()

func abierta() -> bool:
	return visible

func _al_escribir(t: String) -> void:
	var limpio := Progreso.limpiar_nombre(t)
	if limpio != t:
		var col := _campo.caret_column
		_campo.text = limpio
		_campo.caret_column = mini(col, limpio.length())
	_error = ""
	queue_redraw()

func _aceptar() -> void:
	var n := Progreso.limpiar_nombre(_campo.text)
	if n.length() < 3:
		_error = "EL NOMBRE DEBE TENER ENTRE 3 Y 14 LETRAS"
		Audio.sfx("ui_error")
		queue_redraw()
		return
	Progreso.cambiar_piloto(n)
	Audio.sfx("mejora")
	_cerrar()

func _accion_otro() -> void:
	if not _primera:
		_cerrar()
	elif _sugerido != "":
		_campo.text = _sugerido
		_aceptar()
	else:
		_campo.text = Progreso.nombre_al_azar()
		_campo.caret_column = _campo.text.length()
		_error = ""
		queue_redraw()

func _cerrar() -> void:
	visible = false
	_campo.release_focus()
	DisplayServer.virtual_keyboard_hide()
	cerrado.emit()

func _unhandled_input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev.is_action_pressed("ui_cancel"):
		if _primera:
			if _sugerido != "":
				_accion_otro()
			else:
				_aceptar_o_azar()
		else:
			_cerrar()
		get_viewport().set_input_as_handled()

## Escape la primera vez: acepta lo escrito o, si no sirve, pone uno al azar.
func _aceptar_o_azar() -> void:
	if Progreso.limpiar_nombre(_campo.text).length() < 3:
		_campo.text = Progreso.nombre_al_azar()
	_aceptar()

func _rect() -> Rect2:
	var t := get_viewport_rect().size
	var s := Vector2(minf(330.0, t.x - 20.0), 196.0)
	return Rect2((t - s) * 0.5 - Vector2(0, 40 if Ajustes.es_tactil() else 0), s)   # deja sitio al teclado

func _colocar() -> void:
	var r := _rect()
	_campo.position = Vector2(r.position.x + 30, r.position.y + 72)
	_campo.size = Vector2(r.size.x - 60, 30)
	_ok.size = Vector2(r.size.x * 0.5 - 26, 28)
	_ok.position = Vector2(r.position.x + 20, r.end.y - 44)
	_otro.size = Vector2(r.size.x * 0.5 - 26, 28)
	_otro.position = Vector2(r.get_center().x + 6, r.end.y - 44)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.01, 0.01, 0.05, 0.82))
	var r := _rect()
	Neon.marco(self, r, Neon.AMARILLO, 12.0, Color(0.03, 0.04, 0.13, 0.98))
	var cx := r.get_center().x
	Texto.dibujar(self, Vector2(cx, r.position.y + 28), "¡BIENVENIDO, PILOTO!" if _primera else "CAMBIAR NOMBRE", 11, Neon.AMARILLO, HORIZONTAL_ALIGNMENT_CENTER)
	Texto.dibujar(self, Vector2(cx, r.position.y + 50), "¿CÓMO QUIERES QUE TE LLAMEN?", 7, Neon.BLANCO, HORIZONTAL_ALIGNMENT_CENTER)
	Texto.dibujar(self, Vector2(cx, r.position.y + 64), "3-14 LETRAS, NÚMEROS O _", 5, Neon.GRIS, HORIZONTAL_ALIGNMENT_CENTER)
	var nota := ""
	if _error != "":
		nota = _error
	elif Red.conectado() and Progreso.limpiar_nombre(_campo.text) != Red.nombre:
		nota = "EN LA TABLA GLOBAL SEGUIRÁS COMO " + Red.nombre
	elif _primera:
		nota = "PUEDES CAMBIARLO DESPUÉS EN AJUSTES"
	if nota != "":
		Texto.parrafo(self, Vector2(cx, r.position.y + 120), nota, 6, Neon.ROSA if _error != "" else Neon.GRIS, r.size.x - 30)
