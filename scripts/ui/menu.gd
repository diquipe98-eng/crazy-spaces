extends Control
## Menú principal: inicio, hangar (nave girando sobre su plataforma) y ajustes.

var _vista := "inicio"
var _inicio: Control
var _hangar: Control
var _ajustes: Control
var _indice := 0
var _t := 0.0
var _boton_equipar: Boton
var _guia: Tutorial
var _posiciones: Posiciones
var _top: PanelTop10          ## top 10 global a la derecha del inicio
var _perfil: PerfilPiloto
var _bienvenida: Bienvenida
var _b_jugar: Boton
const ANCHO_TOP := 232.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Audio.musica("menu", 0.8)
	for i in Datos.NAVES.size():
		if Datos.NAVES[i].id == Progreso.nave_equipada:
			_indice = i
	_inicio = _vista_nueva()
	var v := _columna(_inicio)
	v.offset_right = -(ANCHO_TOP + 18.0)   # columna a la izquierda; a la derecha el top 10
	_espacio(v, 146)
	var jugar := _boton(v, "JUGAR", Color("ffe36b"), 190, 36, 12)
	jugar.pulsado.connect(_jugar)
	_b_jugar = jugar
	var f := _fila(v)
	_boton(f, "HANGAR", Color("5ad1ff"), 92, 28).pulsado.connect(func(): _ir("hangar"))
	var rec := _boton(f, "MARCADORES", Color("ffd23a"), 104, 28)
	rec.pulsado.connect(func(): _ir("records"))
	_boton(f, "AJUSTES", Color("c58cff"), 92, 28).pulsado.connect(func(): _ir("ajustes"))
	if Datos.URL_DONACIONES != "":
		var apoyar := _boton(v, "APOYAR", Color("ff7aa8"), 120, 24, 8)
		apoyar.icono = Datos.tex("res://art/hud/heart.png")
		apoyar.pulsado.connect(Datos.abrir_donaciones)

	_hangar = _vista_nueva()
	var hv := _columna(_hangar)
	_espacio(hv, 262)
	var hf := _fila(hv)
	_boton(hf, "<", Color("5ad1ff"), 40, 30).pulsado.connect(func(): _cambiar_nave(-1))
	_boton_equipar = _boton(hf, "EQUIPAR", Color("ffe36b"), 150, 30)
	_boton_equipar.pulsado.connect(_equipar)
	_boton(hf, ">", Color("5ad1ff"), 40, 30).pulsado.connect(func(): _cambiar_nave(1))
	_boton(hv, "VOLVER", Color("ff7892"), 120, 26).pulsado.connect(func(): _ir("inicio"))

	_ajustes = _vista_nueva()
	var av := _columna(_ajustes)
	_espacio(av, 20)
	var c := CenterContainer.new()
	c.add_child(PanelAjustes.new())
	av.add_child(c)
	var af := _fila(av)
	_boton(af, "CÓMO JUGAR", Color("19e6ff"), 130, 26, 8).pulsado.connect(func(): _guia.abrir_guia())
	_boton(af, "CAMBIAR NOMBRE", Color("ffe36b"), 150, 26, 8).pulsado.connect(func(): _bienvenida.abrir(false))
	_boton(af, "VOLVER", Color("ff7892"), 120, 26).pulsado.connect(func(): _ir("inicio"))
	_top = PanelTop10.new()
	_top.anchor_left = 1.0
	_top.anchor_right = 1.0
	_top.anchor_bottom = 1.0
	_top.offset_left = -ANCHO_TOP - 10.0
	_top.offset_right = -10.0
	_top.offset_top = 14.0
	_top.offset_bottom = -14.0
	_inicio.add_child(_top)
	_perfil = PerfilPiloto.new()
	add_child(_perfil)
	_top.ver_perfil.connect(func(id: String): _perfil.abrir(id))
	_posiciones = Posiciones.new()
	_posiciones.visible = false
	add_child(_posiciones)
	_posiciones.volver.connect(func(): _ir("inicio"))
	_guia = Tutorial.new()
	add_child(_guia)
	_guia.cerrado.connect(func(): _ir(_vista))
	_guia.repetir.connect(_jugar)
	_bienvenida = Bienvenida.new()
	add_child(_bienvenida)
	_bienvenida.cerrado.connect(func(): _ir(_vista))
	_ir("inicio")
	if "--jugar" in OS.get_cmdline_user_args():
		_jugar.call_deferred()
	elif Progreso.piloto == "" and not Red.conectado():
		_bienvenida.abrir(true)
	# enlace de "olvidé mi contraseña": pedir la nueva en MARCADORES
	Red.pide_clave_nueva.connect(func():
		_bienvenida.visible = false
		_ir("records")
		_posiciones._abrir_form("nueva_clave"))
	# si entra con su cuenta (p. ej. desde el enlace del correo) sobra la bienvenida
	Red.sesion_cambiada.connect(func():
		if Red.conectado() and _bienvenida.abierta():
			_bienvenida.visible = false
			_ir(_vista))

func _vista_nueva() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	return c

func _columna(c: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	c.add_child(v)
	return v

func _fila(p: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	return h

func _espacio(p: Control, alto: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, alto)
	p.add_child(s)

func _boton(p: Control, texto: String, color: Color, ancho: float, alto: float, tam := 9) -> Boton:
	var b := Boton.new(texto, color, tam)
	b.custom_minimum_size = Vector2(ancho, alto)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.add_child(b)
	return b

func _ir(v: String) -> void:
	_vista = v
	_inicio.visible = v == "inicio"
	_hangar.visible = v == "hangar"
	_ajustes.visible = v == "ajustes"
	_posiciones.visible = v == "records"
	if v == "inicio" and _top:
		_top.refrescar()
	if v == "records":
		_posiciones.abrir()
		if not Ajustes.es_tactil():
			await get_tree().process_frame
			_posiciones._b_global.grab_focus()
		return
	if v == "hangar":
		_refrescar_hangar()
	if not Ajustes.es_tactil() and not _bienvenida.abierta():
		await get_tree().process_frame
		var bs := (_inicio if v == "inicio" else (_hangar if v == "hangar" else _ajustes)).find_children("*", "Boton", true, false)
		if bs.size() > 0:
			bs[0].grab_focus()

func _jugar() -> void:
	Audio.sfx("sector")
	get_tree().change_scene_to_file("res://scenes/juego.tscn")

func _cambiar_nave(d: int) -> void:
	_indice = posmod(_indice + d, Datos.NAVES.size())
	_refrescar_hangar()

func _equipar() -> void:
	var n: Dictionary = Datos.NAVES[_indice]
	if Progreso.nave_desbloqueada(n.id):
		Progreso.nave_equipada = n.id
		Progreso.guardar()
		Audio.sfx("mejora")
		_refrescar_hangar()

func _refrescar_hangar() -> void:
	var n: Dictionary = Datos.NAVES[_indice]
	var libre := Progreso.nave_desbloqueada(n.id)
	_boton_equipar.desactivado = not libre or Progreso.nave_equipada == n.id
	_boton_equipar.texto = "EQUIPADA" if Progreso.nave_equipada == n.id else ("EQUIPAR" if libre else "BLOQUEADA")
	_boton_equipar.queue_redraw()

func _unhandled_input(ev: InputEvent) -> void:
	if _vista == "hangar":
		if ev.is_action_pressed("ui_left"): _cambiar_nave(-1)
		elif ev.is_action_pressed("ui_right"): _cambiar_nave(1)
	if _guia.abierto() or _vista == "records" or _perfil.visible or _bienvenida.abierta():
		return
	if ev.is_action_pressed("ui_cancel") and _vista != "inicio":
		Audio.sfx("ui_atras")
		_ir("inicio")

func _process(d: float) -> void:
	_t += d
	queue_redraw()

func _draw() -> void:
	var t := get_viewport_rect().size
	var cx := t.x * 0.5
	match _vista:
		"inicio":
			var logo := Datos.tex("res://art/menu/logo.png")
			var izq := (t.x - ANCHO_TOP - 18.0) * 0.5   # centro de la columna izquierda
			var w = min(270.0, t.x - ANCHO_TOP - 40.0)
			var h = w * logo.get_height() / logo.get_width()
			var flota := sin(_t * 1.6) * 3.0
			draw_texture_rect(logo, Rect2(Vector2(izq - w * 0.5, 8 + flota), Vector2(w, h)), false)
			if Progreso.piloto != "":
				var y := _b_jugar.global_position.y - global_position.y - 7.0   # justo encima de JUGAR
				var et := "PILOTO  "
				var ancho := Texto.ancho(et, 6) + Texto.ancho(Progreso.piloto, 8)
				Texto.dibujar(self, Vector2(izq - ancho * 0.5, y), et, 6, Color(0.7, 0.8, 1.0, 0.85))
				Texto.dibujar(self, Vector2(izq - ancho * 0.5 + Texto.ancho(et, 6), y + 1), Progreso.piloto, 8, Color("ffe36b"))
		"hangar":
			var n: Dictionary = Datos.NAVES[_indice]
			var libre := Progreso.nave_desbloqueada(n.id)
			Texto.dibujar(self, Vector2(cx, 30), "HANGAR", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
			var plat := Datos.tex("res://art/menu/plataforma.png")
			var pw := 160.0
			var ph := pw * plat.get_height() / plat.get_width()
			var base_y := t.y * 0.5 + 6
			var sx := cx - 120.0   # la nave a la izquierda, sus estadísticas a la derecha
			draw_texture_rect(plat, Rect2(Vector2(sx - pw * 0.5, base_y - ph * 0.42), Vector2(pw, ph)), false, Color(1, 1, 1, 0.9))
			var hoja := Datos.tex("res://art/naves/%s_giro.png" % n.id)
			var cel: Vector2i = Datos.GIRO_TAM[n.id]
			var cuadro := int(_t * 12.0) % Datos.GIRO_CUADROS
			var src := Rect2(Vector2((cuadro % Datos.GIRO_COLUMNAS) * cel.x, (cuadro / Datos.GIRO_COLUMNAS) * cel.y), Vector2(cel))
			var esc := 1.15
			var dst := Rect2(Vector2(sx, base_y - 40 + sin(_t * 2.0) * 3.0) - Vector2(cel) * esc * 0.5, Vector2(cel) * esc)
			draw_texture_rect_region(hoja, dst, src, Color.WHITE if libre else Color(0.1, 0.1, 0.18, 0.95))
			Texto.dibujar(self, Vector2(sx, base_y + 70), n.nombre, 12, n.color if libre else Color(0.6, 0.6, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
			var info := "%d / %d" % [_indice + 1, Datos.NAVES.size()]
			if not libre:
				info = "NECESITAS %d PUNTOS (RÉCORD %d)" % [n.puntaje, Progreso.mejor_puntaje]
			_estadisticas(n, Vector2(cx + 10, 62), libre)
			Texto.dibujar(self, Vector2(sx, base_y + 84), info, 6, Color(0.75, 0.85, 1.0, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
		"ajustes":
			Texto.dibujar(self, Vector2(cx, 30), "AJUSTES", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

## Ficha de la nave: barras comparables entre naves, rasgo y armas iniciales.
func _estadisticas(n: Dictionary, o: Vector2, libre: bool) -> void:
	var m: Dictionary = n.get("mod", {})
	var base: Dictionary = Datos.JUGADOR_BASE
	var filas := [
		["VIDA", float(base.vida + int(m.get("vida", 0))), 10.0, "%d"],
		["DAÑO", base.dano * float(m.get("dano", 1.0)), base.dano * 1.5, "%.0f"],
		["CADENCIA", base.cadencia * float(m.get("cadencia", 1.0)), base.cadencia * 1.25, "%.1f/s"],
		["VELOCIDAD", base.vel_max * float(m.get("vel", 1.0)), base.vel_max * 1.2, "%.0f"],
		["DASH", base.dash_recarga * float(m.get("dash", 1.0)), base.dash_recarga, "%.1f s"],
		["ESCUDO", float(m.get("escudo", 0)), 2.0, "%d"],
	]
	var a := 1.0 if libre else 0.55
	var ancho := 120.0
	for i in filas.size():
		var f: Array = filas[i]
		var y := o.y + i * 17.0
		Texto.dibujar(self, Vector2(o.x, y + 6), f[0], 6, Color(0.75, 0.85, 1.0, a))
		var frac := clampf(f[1] / f[2], 0.0, 1.0)
		if f[0] == "DASH":
			frac = clampf(1.6 - f[1] / f[2], 0.0, 1.0)   # menos recarga = mejor
		var r := Rect2(o.x + 62, y, ancho, 6)
		draw_rect(r, Color(0.05, 0.06, 0.15, 0.85))
		draw_rect(Rect2(r.position, Vector2(ancho * frac, 6)), Color(n.color, a))
		draw_rect(Rect2(r.position, Vector2(ancho * frac, 2)), Color(1, 1, 1, 0.35 * a))
		draw_rect(r, Color(0.6, 0.8, 1.0, 0.4), false, 1.0)
		Texto.dibujar(self, Vector2(r.end.x + 6, y + 6), f[3] % f[1], 6, Color(1, 1, 1, a))
	var y2 := o.y + filas.size() * 17.0 + 8
	Texto.dibujar(self, Vector2(o.x, y2 + 6), "RASGO", 6, Color(1, 0.88, 0.45, a))
	var lineas := _partir(String(n.get("rasgo", "")).to_upper(), 6, 190.0)
	for i in lineas.size():
		Texto.dibujar(self, Vector2(o.x + 62, y2 + 6 + i * 10), lineas[i], 6, Color(1, 1, 1, a))
	y2 += (lineas.size() - 1) * 10
	var inicio: Array = n.get("inicio", [])
	if not inicio.is_empty():
		var nombres := inicio.map(func(id): return String(Datos.mejora(id).n).to_upper())
		Texto.dibujar(self, Vector2(o.x, y2 + 22), "INICIA CON", 6, Color(1, 0.88, 0.45, a))
		var l2 := _partir(" + ".join(nombres), 6, 190.0)
		for i in l2.size():
			Texto.dibujar(self, Vector2(o.x + 62, y2 + 22 + i * 10), l2[i], 6, Color(1, 1, 1, a))

func _partir(s: String, tam: int, ancho: float) -> Array:
	var out := []
	var actual := ""
	for w in s.split(" "):
		var prueba := w if actual == "" else actual + " " + w
		if Texto.ancho(prueba, tam) > ancho and actual != "":
			out.append(actual)
			actual = w
		else:
			actual = prueba
	if actual != "":
		out.append(actual)
	return out
