extends Control
## Controles para teléfono (horizontal).
##  Mitad izquierda: joystick flotante (aparece donde apoyas el pulgar) o
##  arrastre relativo (la nave copia el movimiento del dedo), según Ajustes.
##  Derecha: botón grande de DASH con su recarga, REPARAR con costo y pausa.
## Disparo automático con autoapuntado: no hace falta un botón de fuego.

var juego
var _dedo_mov := -1
var _base := Vector2.ZERO
var _punta := Vector2.ZERO
var _ultimo := Vector2.ZERO
var _arrastre := Vector2.ZERO
var _dedos_boton := {}    ## índice -> nombre del botón
var _pulso := {}          ## animación de pulsación por botón

const RADIO_JOY := 42.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	juego = get_parent().get_parent()
	visible = activo()

func activo() -> bool:
	return Ajustes.es_tactil()

func vector_movimiento() -> Vector2:
	if Ajustes.modo_control != "joystick" or _dedo_mov < 0:
		return Vector2.ZERO
	var r := RADIO_JOY * Ajustes.tamano_joystick
	var v := (_punta - _base) / r
	# zona muerta pequeña y respuesta un poco curva para precisión
	var l := v.length()
	if l < 0.12:
		return Vector2.ZERO
	return v.normalized() * pow(min(1.0, (l - 0.12) / 0.88), 0.85)

func consumir_arrastre() -> Vector2:
	var a := _arrastre
	_arrastre = Vector2.ZERO
	return a * Ajustes.sensibilidad_arrastre

func _rects() -> Dictionary:
	var t := get_viewport_rect().size
	var m := 14.0
	var dash_r := 34.0
	return {
		"dash": {"c": Vector2(t.x - m - dash_r - 6, t.y - m - dash_r - 4), "r": dash_r},
		"reparar": {"c": Vector2(t.x - m - dash_r * 2 - 46, t.y - m - 24), "r": 21.0},
		"pausa": {"c": Vector2(t.x - 18, 50), "r": 13.0},
	}

func _boton_en(p: Vector2) -> String:
	var rs := _rects()
	for k in rs:
		if p.distance_to(rs[k].c) <= rs[k].r + 10.0:
			return k
	return ""

func _input(ev: InputEvent) -> void:
	if not activo() or juego == null or juego.estado != "jugando":
		if ev is InputEventScreenTouch and not ev.pressed:
			_soltar(ev.index)
		return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			var b := _boton_en(ev.position)
			if b != "":
				_dedos_boton[ev.index] = b
				_pulso[b] = 0.15
				_accion(b)
			elif _dedo_mov < 0 and (ev.position.x < get_viewport_rect().size.x * 0.62 or Ajustes.modo_control == "arrastre"):
				_dedo_mov = ev.index
				_base = ev.position
				_punta = ev.position
				_ultimo = ev.position
		else:
			_soltar(ev.index)
		get_viewport().set_input_as_handled()
	elif ev is InputEventScreenDrag and ev.index == _dedo_mov:
		_punta = ev.position
		_arrastre += ev.position - _ultimo
		_ultimo = ev.position
		# el joystick "sigue" al pulgar si se aleja demasiado de la base
		var r := RADIO_JOY * Ajustes.tamano_joystick
		if _base.distance_to(_punta) > r * 1.35:
			_base = _punta + (_base - _punta).normalized() * r * 1.35
		get_viewport().set_input_as_handled()

func _soltar(i: int) -> void:
	if i == _dedo_mov:
		_dedo_mov = -1
		_arrastre = Vector2.ZERO
	_dedos_boton.erase(i)

func _accion(b: String) -> void:
	match b:
		"dash":
			if juego.N.intentar_dash():
				pass
			else:
				Audio.sfx("ui_error", -6.0)
		"reparar":
			juego.reparar()
		"pausa":
			juego.pausar()

func _process(delta: float) -> void:
	visible = activo()
	for k in _pulso.keys():
		_pulso[k] = max(0.0, _pulso[k] - delta)
	if visible:
		queue_redraw()

func _draw() -> void:
	if juego == null or juego.N == null or juego.estado != "jugando":
		return
	var op := Ajustes.opacidad_controles
	var N = juego.N
	# joystick / zona de arrastre
	if Ajustes.modo_control == "joystick":
		if _dedo_mov >= 0:
			var r := RADIO_JOY * Ajustes.tamano_joystick
			draw_circle(_base, r, Color(0.05, 0.08, 0.2, 0.35 * op))
			draw_arc(_base, r, 0, TAU, 40, Color(0.45, 0.85, 1.0, 0.6 * op), 2.0, true)
			var punta := _base + (_punta - _base).limit_length(r)
			draw_circle(punta, r * 0.42, Color(0.45, 0.85, 1.0, 0.55 * op))
			draw_circle(punta, r * 0.42, Color(0.8, 0.95, 1.0, 0.8 * op), false, 1.5)
		elif juego.tiempo < 6.0:
			var t := get_viewport_rect().size
			Texto.dibujar(self, Vector2(t.x * 0.24, t.y - 26), "TOCA Y DESLIZA PARA MOVERTE", 7, Color(0.8, 0.95, 1.0, 0.75 * op), HORIZONTAL_ALIGNMENT_CENTER)
	elif _dedo_mov >= 0:
		draw_circle(_punta, 16.0, Color(0.45, 0.85, 1.0, 0.25 * op))
		draw_arc(_punta, 16.0, 0, TAU, 24, Color(0.6, 0.9, 1.0, 0.5 * op), 1.5, true)
	var rs := _rects()
	# DASH con su recarga en el borde
	var d: Dictionary = rs.dash
	var listo: bool = N.dash_cd <= 0.0
	var esc = 1.0 - _pulso.get("dash", 0.0) * 0.6
	var rr: float = d.r * esc
	draw_circle(d.c, rr, Color(0.04, 0.1, 0.2, 0.55 * op))
	draw_arc(d.c, rr, 0, TAU, 40, Color(0.3, 0.5, 0.7, 0.6 * op), 3.0, true)
	var frac: float = 1.0 - N.dash_cd / max(0.01, N.dash_recarga)
	draw_arc(d.c, rr, -PI / 2, -PI / 2 + TAU * frac, 40, Color(0.45, 0.95, 1.0, (0.95 if listo else 0.6) * op), 3.0, true)
	Texto.dibujar(self, d.c + Vector2(0, 4), "DASH", 9, Color(1, 1, 1, (1.0 if listo else 0.5) * op), HORIZONTAL_ALIGNMENT_CENTER)
	if not listo:
		Texto.dibujar(self, d.c + Vector2(0, 16), "%.1f" % N.dash_cd, 6, Color(0.7, 0.9, 1.0, 0.7 * op), HORIZONTAL_ALIGNMENT_CENTER)
	# REPARAR: solo se ilumina cuando hace falta y alcanza la chatarra
	var rp: Dictionary = rs.reparar
	var puede: bool = juego.puede_reparar()
	var herido: bool = N.vida < N.vida_max
	var a := (0.95 if puede else (0.45 if herido else 0.25)) * op
	var rr2: float = rp.r * (1.0 - _pulso.get("reparar", 0.0) * 0.6)
	draw_circle(rp.c, rr2, Color(0.04, 0.16, 0.08, 0.5 * op))
	draw_arc(rp.c, rr2, 0, TAU, 32, Color(0.5, 1.0, 0.6, a), 2.0, true)
	var ic := Datos.tex("res://art/hud/plus.png")
	draw_texture_rect(ic, Rect2(rp.c - Vector2(8, 13), Vector2(16, 16)), false, Color(1, 1, 1, a))
	Texto.dibujar(self, rp.c + Vector2(0, 13), str(juego.costo_reparar), 6, Color(1, 0.85, 0.3, a), HORIZONTAL_ALIGNMENT_CENTER)
	# pausa
	var pz: Dictionary = rs.pausa
	draw_texture_rect(Datos.tex("res://art/hud/pause.png"), Rect2(pz.c - Vector2(9, 9), Vector2(18, 18)), false, Color(1, 1, 1, 0.85 * op))
