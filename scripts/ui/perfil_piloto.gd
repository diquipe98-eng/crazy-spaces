class_name PerfilPiloto
extends Control
## Ventana con el perfil público de un piloto: nave favorita, puesto,
## estadísticas y sus últimas 5 partidas. Se abre desde el top 10 y los marcadores.

signal cerrado

var _datos = null
var _cargando := false
var _error := ""
var _t := 0.0
var _cerrar: Boton
var _pedido := 0     ## evita que una respuesta vieja pise a la nueva

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_meta("modal", true)
	_cerrar = Boton.new("CERRAR", Neon.ROSA, 9)
	_cerrar.pulsado.connect(cerrar)
	add_child(_cerrar)
	resized.connect(_colocar)

func abrir(id: String) -> void:
	visible = true
	_datos = null
	_error = ""
	_cargando = true
	_colocar()
	if not Ajustes.es_tactil():
		_cerrar.grab_focus.call_deferred()
	_pedido += 1
	var mio := _pedido
	var r: Dictionary = await Red.perfil(id)
	if mio != _pedido:
		return
	_cargando = false
	if r.ok and typeof(r.datos) == TYPE_DICTIONARY:
		_datos = r.datos
	else:
		_error = String(r.get("error", "No se encontró el piloto"))
	queue_redraw()

func cerrar() -> void:
	visible = false
	cerrado.emit()

func _unhandled_input(ev: InputEvent) -> void:
	if visible and ev.is_action_pressed("ui_cancel"):
		Audio.sfx("ui_atras")
		cerrar()
		get_viewport().set_input_as_handled()

func _process(d: float) -> void:
	if visible:
		_t += d
		if _cargando:
			queue_redraw()

func _rect() -> Rect2:
	var t := get_viewport_rect().size
	var s := Vector2(minf(420.0, t.x - 20.0), minf(300.0, t.y - 20.0))
	return Rect2((t - s) * 0.5, s)

func _colocar() -> void:
	var r := _rect()
	_cerrar.size = Vector2(110, 24)
	_cerrar.position = Vector2(r.get_center().x - 55, r.end.y - 32)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.01, 0.01, 0.05, 0.8))
	var r := _rect()
	Neon.marco(self, r, Neon.CIAN, 14.0, Color(0.03, 0.04, 0.13, 0.98))
	if _cargando:
		Neon.rueda(self, r.get_center(), Neon.CIAN, _t)
		return
	if _datos == null:
		Texto.parrafo(self, r.get_center() - Vector2(0, 10), _error.to_upper(), 8, Neon.ROSA, r.size.x - 40)
		return
	var d: Dictionary = _datos
	var favorita := String(d.get("nave_favorita", "drift"))
	Neon.sprite(self, Neon.ruta_nave(favorita), Vector2(r.position.x + 44, r.position.y + 42), 50)
	Texto.dibujar(self, Vector2(r.position.x + 82, r.position.y + 30), "PILOTO", 6, Neon.GRIS)
	Texto.dibujar(self, Vector2(r.position.x + 82, r.position.y + 48), String(d.get("nombre", "?")), 14, Neon.AMARILLO)
	Texto.dibujar(self, Vector2(r.position.x + 82, r.position.y + 62), "EN SERVICIO DESDE %s · NAVE FAVORITA: %s" % [Neon.fecha(String(d.get("creado", ""))), String(Datos.nave(favorita).nombre)], 6, Neon.GRIS)
	var puesto = d.get("puesto")
	Texto.dibujar(self, Vector2(r.end.x - 16, r.position.y + 30), "PUESTO", 6, Neon.GRIS, HORIZONTAL_ALIGNMENT_RIGHT)
	Texto.dibujar(self, Vector2(r.end.x - 16, r.position.y + 50), ("#%d" % int(puesto)) if puesto != null else "—", 16, Neon.color_puesto(int(puesto)) if puesto != null else Neon.GRIS, HORIZONTAL_ALIGNMENT_RIGHT)
	var stats := [
		["MEJOR PUNTAJE", "%d" % int(d.get("mejor_puntaje", 0)), Neon.AMARILLO],
		["PARTIDAS", "%d" % int(d.get("partidas", 0)), Neon.BLANCO],
		["MEJOR TIEMPO", Progreso.formato_tiempo(float(d.get("mejor_tiempo", 0))), Neon.BLANCO],
		["JEFES (MÁX)", "%d" % int(d.get("max_jefes", 0)), Neon.ROSA],
		["NIVEL (MÁX)", "%d" % int(d.get("max_nivel", 0)), Neon.CIAN],
	]
	var sw := (r.size.x - 32) / stats.size()
	for k in stats.size():
		var sr := Rect2(r.position.x + 16 + k * sw, r.position.y + 76, sw - 6, 38)
		draw_rect(sr, Color(0.06, 0.08, 0.2, 0.9))
		draw_rect(sr, Color(stats[k][2], 0.5), false, 1.0)
		Texto.dibujar(self, Vector2(sr.get_center().x, sr.position.y + 12), stats[k][0], 5, Neon.GRIS, HORIZONTAL_ALIGNMENT_CENTER)
		Texto.dibujar(self, Vector2(sr.get_center().x, sr.position.y + 30), stats[k][1], 10, stats[k][2], HORIZONTAL_ALIGNMENT_CENTER)
	var y := r.position.y + 132
	Texto.dibujar(self, Vector2(r.position.x + 16, y), "ÚLTIMAS PARTIDAS", 7, Neon.BLANCO)
	var ultimas: Array = d.get("ultimas", [])
	if ultimas.is_empty():
		Texto.dibujar(self, Vector2(r.get_center().x, y + 30), "TODAVÍA NO HA JUGADO EN LÍNEA", 7, Neon.GRIS, HORIZONTAL_ALIGNMENT_CENTER)
	for k in ultimas.size():
		var u: Dictionary = ultimas[k]
		var fy := y + 18 + k * 18
		draw_rect(Rect2(r.position.x + 14, fy - 11, r.size.x - 28, 16), Color(1, 1, 1, 0.04 if k % 2 == 0 else 0.0))
		Neon.sprite(self, Neon.ruta_nave(String(u.get("nave", "drift"))), Vector2(r.position.x + 26, fy - 3), 13)
		Texto.dibujar(self, Vector2(r.position.x + 40, fy), Neon.fecha(String(u.get("creado", ""))), 6, Neon.GRIS)
		Texto.dibujar(self, Vector2(r.position.x + r.size.x * 0.48, fy), "%d" % int(u.get("puntaje", 0)), 8, Neon.AMARILLO, HORIZONTAL_ALIGNMENT_RIGHT)
		Texto.dibujar(self, Vector2(r.position.x + r.size.x * 0.64, fy), Progreso.formato_tiempo(float(u.get("tiempo", 0))), 7, Neon.BLANCO, HORIZONTAL_ALIGNMENT_RIGHT)
		Texto.dibujar(self, Vector2(r.position.x + r.size.x * 0.8, fy), "NV %d" % int(u.get("nivel", 1)), 7, Neon.CIAN, HORIZONTAL_ALIGNMENT_RIGHT)
		Texto.dibujar(self, Vector2(r.end.x - 18, fy), "%d JEFES" % int(u.get("jefes", 0)), 7, Neon.ROSA, HORIZONTAL_ALIGNMENT_RIGHT)
