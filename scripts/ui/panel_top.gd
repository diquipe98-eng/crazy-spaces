class_name PanelTop10
extends Control
## Panel del TOP 10 GLOBAL en la pantalla de inicio. Cada fila es tocable y abre
## el perfil del piloto. Sin servidor configurado muestra los récords de este equipo.

signal ver_perfil(id: String)

var _filas: Array = []
var _cargando := false
var _error := ""
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 10:
		var f := FilaTabla.new()
		f.indice = i
		f.dibujar = _dibujar_fila
		f.pulsado.connect(func():
			if Red.configurado() and i < Red.top.size():
				ver_perfil.emit(String(Red.top[i].jugador)))
		add_child(f)
		_filas.append(f)
	resized.connect(_colocar)
	Red.top_actualizado.connect(_colocar)
	Red.sesion_cambiada.connect(queue_redraw)
	_colocar()
	refrescar()

func refrescar() -> void:
	if not Red.configurado() or _cargando:
		return
	_cargando = true
	_error = ""
	queue_redraw()
	var r: Dictionary = await Red.cargar_top()
	_cargando = false
	_error = "" if r.ok else String(r.error)
	_colocar()

func _cantidad() -> int:
	return mini(10, Red.top.size()) if Red.configurado() else mini(10, Progreso.registros.size())

func _colocar() -> void:
	var alto := (size.y - 62.0) / 10.0
	for i in 10:
		var f: FilaTabla = _filas[i]
		f.position = Vector2(6, 40 + i * alto)
		f.size = Vector2(size.x - 12, alto - 1)
		f.visible = i < _cantidad()
		f.tocable = Red.configurado()
		f.focus_mode = Control.FOCUS_ALL if Red.configurado() else Control.FOCUS_NONE
		f.queue_redraw()
	queue_redraw()

func _process(d: float) -> void:
	_t += d
	if _cargando:
		queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	Neon.marco(self, r, Neon.AMARILLO, 10.0, Color(0.03, 0.04, 0.12, 0.88))
	var cx := size.x * 0.5
	Texto.dibujar(self, Vector2(cx, 18), "TOP 10 GLOBAL", 10, Neon.AMARILLO, HORIZONTAL_ALIGNMENT_CENTER)
	var sub := "TOCA UN PILOTO PARA VER SU PERFIL" if Ajustes.es_tactil() else "ELIGE UN PILOTO PARA VER SU PERFIL"
	if not Red.configurado():
		sub = "SIN SERVIDOR · RÉCORDS DE ESTE EQUIPO"
	elif _error != "" and not Red.top.is_empty():
		sub = "SIN CONEXIÓN · ÚLTIMA TABLA GUARDADA"
	Texto.dibujar(self, Vector2(cx, 30), sub, 5, Neon.ROSA if _error != "" else Neon.GRIS, HORIZONTAL_ALIGNMENT_CENTER)
	var medio := Vector2(cx, size.y * 0.5)
	if _cantidad() == 0:
		if _cargando:
			Neon.rueda(self, medio, Neon.AMARILLO, _t)
		elif _error != "":
			Texto.parrafo(self, medio - Vector2(0, 8), _error.to_upper(), 6, Neon.ROSA, size.x - 24)
		else:
			Texto.parrafo(self, medio - Vector2(0, 8), "AÚN NO HAY PILOTOS. ¡SÉ EL PRIMERO!" if Red.configurado() else "JUEGA UNA PARTIDA PARA ESTRENAR LA TABLA", 7, Neon.GRIS, size.x - 24)
	# pie: tu piloto
	var pie := "CREA TU PILOTO EN MARCADORES" if Red.configurado() and not Red.conectado() else ""
	if Red.conectado():
		pie = "PILOTO: " + Red.nombre
		for f in Red.top:
			if String(f.jugador) == Red.uid:
				pie += " · PUESTO #%d" % int(f.puesto)
	if pie != "":
		Texto.dibujar(self, Vector2(cx, size.y - 9), pie, 6, Neon.CIAN, HORIZONTAL_ALIGNMENT_CENTER)

func _dibujar_fila(f: FilaTabla) -> void:
	var i := f.indice
	var r := Rect2(Vector2.ZERO, f.size)
	var y := r.size.y * 0.5 + 4
	var d: Dictionary
	var puesto := i + 1
	var mio := false
	if Red.configurado():
		if i >= Red.top.size():
			return
		d = Red.top[i]
		puesto = int(d.get("puesto", i + 1))
		mio = String(d.jugador) == Red.uid
	else:
		if i >= Progreso.registros.size():
			return
		d = Progreso.registros[i]
	var fondo := Color(0.1, 0.2, 0.35, 0.6) if f.resaltada() else (Color(0.05, 0.25, 0.3, 0.45) if mio else Color(1, 1, 1, 0.035 if i % 2 == 0 else 0.0))
	f.draw_rect(r, fondo)
	if f.resaltada():
		f.draw_rect(r, Neon.CIAN, false, 1.0)
	Texto.dibujar(f, Vector2(14, y), "%d" % puesto, 8, Neon.color_puesto(puesto), HORIZONTAL_ALIGNMENT_RIGHT)
	if Red.configurado():
		Neon.sprite(f, Neon.ruta_nave(String(d.get("nave", "drift"))), Vector2(28, r.size.y * 0.5), r.size.y - 6)
		Texto.dibujar(f, Vector2(42, y), String(d.get("nombre", "?")), 7, Neon.CIAN if mio else Neon.BLANCO)
	else:
		Texto.dibujar(f, Vector2(24, y), "NIVEL %d · %s" % [int(d.get("nivel", 1)), Progreso.formato_tiempo(float(d.get("tiempo", 0)))], 7, Neon.BLANCO)
	Texto.dibujar(f, Vector2(r.size.x - 4, y), "%d" % int(d.get("puntaje", 0)), 7, Neon.AMARILLO, HORIZONTAL_ALIGNMENT_RIGHT)
