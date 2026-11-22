class_name Tutorial
extends Control
## Ventanas de tutorial (estilo "guía neón" de referencias/):
##   cabecera con etiqueta, título en dos colores y subtítulo en cápsula,
##   2-4 tarjetas numeradas (01, 02, 03) con una ilustración animada y una frase.
## Cada ventana aparece una sola vez, en el momento en que esa mecánica entra en juego:
##   controles  → al empezar la primera partida
##   mecanicas  → a los pocos segundos (cristales, chatarra, reparar, potenciadores)
##   nivel      → la primera vez que subes de nivel
##   jefe       → cuando aparece el primer jefe
## Desde el menú se pueden repasar todas con ANTERIOR / SIGUIENTE.

signal cerrado
signal repetir   ## el jugador pidió volver a jugar con el tutorial (desde la guía)

const ORDEN := ["controles", "mecanicas", "nivel", "jefe"]

const CIAN := Color("19e6ff")
const AZUL := Color("2f5bff")
const VIOLETA := Color("9b4dff")
const NARANJA := Color("ff8a1a")
const AMARILLO := Color("ffd23a")
const VERDE := Color("5dff8f")
const ROSA := Color("ff5c8a")
const BLANCO := Color("eef0ff")

## t = título (blanco), t2 = palabra destacada (color), sub = cápsula.
## En las tarjetas "tx" es el texto para teclado y "tt" (si existe) para pantalla táctil.
const VENTANAS := {
	"controles": {"t": "APRENDE A", "t2": "VOLAR", "c2": NARANJA, "sub": "CONTROLES BÁSICOS", "tarjetas": [
		{"n": "MUEVE", "c": CIAN, "d": "mover",
			"tx": "Usa WASD o las flechas para mover tu nave.",
			"tt": "Arrastra el dedo en la mitad izquierda de la pantalla."},
		{"n": "DISPARA", "c": VIOLETA, "d": "disparar",
			"tx": "No hace falta apuntar: tu nave dispara sola al enemigo más cercano."},
		{"n": "ESQUIVA", "c": NARANJA, "d": "dash",
			"tx": "Pulsa ESPACIO para hacer un dash y atravesar las balas sin daño.",
			"tt": "Toca DASH para hacer un impulso y atravesar las balas sin daño."},
	]},
	"mecanicas": {"t": "CRECE Y", "t2": "SOBREVIVE", "c2": AMARILLO, "sub": "MECÁNICAS DE JUEGO", "tarjetas": [
		{"n": "CRISTALES", "c": CIAN, "d": "xp",
			"tx": "Los enemigos sueltan cristales. Recógelos para subir de nivel."},
		{"n": "CHATARRA", "c": AMARILLO, "d": "chatarra",
			"tx": "Los engranajes son tu moneda. Guárdalos para reparar y mejorar."},
		{"n": "REPARA", "c": VERDE, "d": "reparar",
			"tx": "Pulsa R para recuperar 1 vida con chatarra. Cada vez cuesta un poco más.",
			"tt": "Toca el botón + junto a DASH para recuperar 1 vida con chatarra."},
		{"n": "CÁPSULAS", "c": VIOLETA, "d": "potenciadores",
			"tx": "Recoge las cápsulas: escudo, imán y más. Las flechas del borde te guían."},
	]},
	"nivel": {"t": "ELIGE TU", "t2": "MEJORA", "c2": AMARILLO, "sub": "SUBIR DE NIVEL", "tarjetas": [
		{"n": "ELIGE", "c": AMARILLO, "d": "elegir",
			"tx": "Escoge 1 de las 3 tarjetas. El color del borde indica su rareza."},
		{"n": "POTENCIA", "c": CIAN, "d": "niveles",
			"tx": "Repetir una mejora la sube de nivel. La tarjeta muestra el cambio exacto."},
		{"n": "DECIDE", "c": VIOLETA, "d": "reroll",
			"tx": "REROLL cambia las opciones y REPARAR te devuelve 1 vida. Ambos usan chatarra."},
	]},
	"jefe": {"t": "¡JEFE A LA", "t2": "VISTA!", "c2": ROSA, "sub": "COMBATE DE JEFE", "tarjetas": [
		{"n": "ARENA", "c": ROSA, "d": "arena",
			"tx": "Quedas encerrado en la arena hasta que uno de los dos caiga."},
		{"n": "LEE", "c": NARANJA, "d": "patrones",
			"tx": "El nombre de cada ataque aparece bajo el jefe. Léelo y esquiva a tiempo."},
		{"n": "FASE 2", "c": VIOLETA, "d": "fase2",
			"tx": "Con media vida se enfurece. Si lo vences ganas una mejora especial."},
	]},
}

var _cola: Array = []        ## ids pendientes (modo automático) o todas (modo guía)
var _indice := 0
var _guia := false           ## true = abierto desde el menú, con páginas
var _t := 0.0                ## tiempo desde que se abrió la ventana actual
var _primario: Boton
var _secundario: Boton
var _anterior: Boton
var _xf := Transform2D.IDENTITY   ## escala de entrada del panel

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_meta("modal", true)
	_primario = _crear_boton("ENTENDIDO", CIAN, 9)
	_primario.pulsado.connect(_siguiente)
	_secundario = _crear_boton("SALTAR TUTORIAL", Color("8a93b8"), 7)
	_secundario.pulsado.connect(_pulsar_secundario)
	_anterior = _crear_boton("< ANTERIOR", CIAN, 8)
	_anterior.pulsado.connect(_atras)
	resized.connect(_colocar)

func _crear_boton(texto: String, color: Color, tam: int) -> Boton:
	var b := Boton.new(texto, color, tam)
	add_child(b)
	return b

## Abre las ventanas indicadas que el jugador todavía no ha visto.
## Devuelve false si no había nada que mostrar.
func abrir(ids: Array) -> bool:
	_cola = ids.filter(func(i): return not Progreso.tutorial_visto(i))
	if _cola.is_empty():
		return false
	_guia = false
	_mostrar(0)
	return true

## Modo guía (menú): todas las ventanas, navegables.
func abrir_guia() -> void:
	_cola = ORDEN.duplicate()
	_guia = true
	_mostrar(0)

func abierto() -> bool:
	return visible

func _mostrar(i: int) -> void:
	_indice = i
	_t = 0.0
	visible = true
	Audio.sfx("ui_click")
	_colocar()
	queue_redraw()
	if not Ajustes.es_tactil():
		_primario.grab_focus.call_deferred()

func _siguiente() -> void:
	if _t < 0.45:
		return   # evita cerrarlo sin querer con el mismo toque que lo abrió
	if not _guia:
		Progreso.marcar_tutorial(_cola[_indice])
	if _indice + 1 < _cola.size():
		_mostrar(_indice + 1)
	else:
		_cerrar()

func _pulsar_secundario() -> void:
	if not _guia:
		_saltar()
		return
	Progreso.reiniciar_tutorial()
	visible = false
	repetir.emit()

func _atras() -> void:
	if _indice > 0:
		_mostrar(_indice - 1)

func _saltar() -> void:
	if _guia:
		_cerrar()
		return
	for id in ORDEN:
		Progreso.marcar_tutorial(id)
	_cerrar()

func _cerrar() -> void:
	visible = false
	Audio.sfx("ui_atras")
	cerrado.emit()

func _unhandled_input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev.is_action_pressed("ui_cancel"):
		_saltar()
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("ui_accept") or ev.is_action_pressed("dash"):
		_siguiente()
		get_viewport().set_input_as_handled()
	elif _guia and ev.is_action_pressed("ui_left"):
		_atras()
	elif _guia and ev.is_action_pressed("ui_right"):
		_siguiente()

func _process(d: float) -> void:
	if visible:
		_t += d
		queue_redraw()

# ---------------------------------------------------------------- geometría
func _panel() -> Rect2:
	var t := get_viewport_rect().size
	var w := minf(t.x - 20.0, 620.0)
	var h := minf(t.y - 14.0, 346.0)
	return Rect2((t - Vector2(w, h)) * 0.5, Vector2(w, h))

func _colocar() -> void:
	if _cola.is_empty():
		return
	var p := _panel()
	var y := p.end.y - 34.0
	var ultimo := _indice == _cola.size() - 1
	_primario.texto = ("CERRAR" if ultimo else "SIGUIENTE >") if _guia else ("¡A JUGAR!" if _cola[_indice] == "controles" else "ENTENDIDO")
	_primario.size = Vector2(134, 26)
	_primario.position = Vector2(p.end.x - 14 - 134, y)
	_secundario.visible = not _guia or ultimo
	_secundario.texto = "SALTAR TUTORIAL" if not _guia else "JUGAR CON TUTORIAL"
	_secundario.color = Color("8a93b8") if not _guia else NARANJA
	_secundario.size = Vector2(118, 22)
	_secundario.position = Vector2(p.position.x + 14, y + 2)
	_anterior.visible = _guia and _indice > 0
	if _guia:
		_secundario.size = Vector2(150, 22)
		_secundario.position = Vector2(p.position.x + 14 + (118 if _indice > 0 else 0), y + 2)
	_anterior.size = Vector2(110, 22)
	_anterior.position = Vector2(p.position.x + 14, y + 2)
	for b in [_primario, _secundario, _anterior]:
		b.queue_redraw()

# ---------------------------------------------------------------- dibujo
func _draw() -> void:
	if _cola.is_empty():
		return
	var t := get_viewport_rect().size
	var v: Dictionary = VENTANAS[_cola[_indice]]
	var entra := _suave(clampf(_t / 0.35, 0.0, 1.0))
	draw_rect(Rect2(Vector2.ZERO, t), Color(0.01, 0.01, 0.05, 0.78 * entra))
	var p := _panel()
	# el panel aparece creciendo un poco desde el centro
	var esc := 0.94 + 0.06 * entra
	_xf = Transform2D(0.0, Vector2(esc, esc), 0.0, p.get_center() * (1.0 - esc))
	draw_set_transform_matrix(_xf)
	_marco(p, CIAN, 14.0, Color(0.03, 0.04, 0.12, 0.97 * entra), entra)
	_estrellas(p.grow(-6), 70, entra * 0.6, 7)
	# etiqueta de la esquina: "TUTORIAL 1/4" (o "GUÍA" en el menú)
	var pos_global := ORDEN.find(_cola[_indice]) + 1
	var etiqueta := "GUÍA  %d / %d" % [_indice + 1, _cola.size()] if _guia else "TUTORIAL  %d / %d" % [pos_global, ORDEN.size()]
	_chip(Vector2(p.position.x + 16, p.position.y + 9), etiqueta, CIAN, entra)
	# título en dos colores
	var cx := p.get_center().x
	var a := String(v.t) + " "
	var b := String(v.t2)
	var tam := 18
	var ancho_total := Texto.ancho(a, tam) + Texto.ancho(b, tam)
	var tx := cx - ancho_total * 0.5
	var ty := p.position.y + 46
	Texto.dibujar(self, Vector2(tx, ty), a, tam, Color(BLANCO, entra))
	Texto.dibujar(self, Vector2(tx + Texto.ancho(a, tam), ty), b, tam, Color(v.c2, entra))
	# subtítulo en cápsula
	var sub := String(v.sub)
	var sw := Texto.ancho(sub, 8) + 30
	var sr := Rect2(cx - sw * 0.5, ty + 7, sw, 17)
	_marco(sr, CIAN, 5.0, Color(0.02, 0.05, 0.14, 0.95 * entra), entra * 0.9)
	Texto.dibujar(self, Vector2(cx, sr.position.y + 12), sub, 8, Color(BLANCO, entra), HORIZONTAL_ALIGNMENT_CENTER)
	# tarjetas
	var tarjetas: Array = v.tarjetas
	var n := tarjetas.size()
	var sep := 10.0
	var zona := Rect2(p.position.x + 14, sr.end.y + 10, p.size.x - 28, p.end.y - 44 - (sr.end.y + 10))
	var cw := (zona.size.x - sep * (n - 1)) / n
	for i in n:
		var k := _suave(clampf((_t - 0.12 - i * 0.12) / 0.4, 0.0, 1.0))
		var r := Rect2(zona.position.x + i * (cw + sep), zona.position.y + (1.0 - k) * 18.0, cw, zona.size.y)
		_tarjeta(r, i + 1, tarjetas[i], k, n)
	# puntos de progreso entre los botones
	if _cola.size() > 1:
		var py := p.end.y - 21
		for i in _cola.size():
			var c := CIAN if i == _indice else Color(0.35, 0.4, 0.6)
			var pc := Vector2(cx + (i - (_cola.size() - 1) * 0.5) * 14.0, py)
			if i == _indice:
				draw_rect(Rect2(pc - Vector2(5, 2), Vector2(10, 4)), Color(c, entra))
			else:
				draw_rect(Rect2(pc - Vector2(2, 2), Vector2(4, 4)), Color(c, entra * 0.8))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _tarjeta(r: Rect2, num: int, d: Dictionary, alfa: float, n: int) -> void:
	if alfa <= 0.0:
		return
	var c: Color = d.c
	_marco(r, c, 9.0, Color(0.03, 0.04, 0.13, 0.96 * alfa), alfa)
	# cabecera: número grande + nombre
	var cab := 28.0
	Texto.dibujar(self, Vector2(r.position.x + 10, r.position.y + 22), "%02d" % num, 16, Color(c, alfa))
	var nombre := String(d.n)
	var tam_n := 11 if n <= 3 else 9
	Texto.dibujar(self, Vector2(r.position.x + 12 + Texto.ancho("00", 16) + 6, r.position.y + 20), nombre, tam_n, Color(BLANCO, alfa))
	draw_line(Vector2(r.position.x + 6, r.position.y + cab + 2), Vector2(r.end.x - 6, r.position.y + cab + 2), Color(c, 0.55 * alfa), 1.0)
	# texto (abajo) y la ilustración ocupa lo que queda
	var tam_t := 8 if n <= 3 else 7
	var texto := String(d.get("tt", d.tx)) if Ajustes.es_tactil() else String(d.tx)
	var lineas := _lineas(texto, tam_t, r.size.x - 18)
	var alto_texto := lineas.size() * tam_t * 1.55 + 12
	var ilus := Rect2(r.position.x + 6, r.position.y + cab + 6, r.size.x - 12, r.size.y - cab - 12 - alto_texto)
	draw_rect(ilus, Color(0.02, 0.03, 0.1, 0.9 * alfa))
	_estrellas(ilus, int(ilus.size.x * ilus.size.y / 500.0), alfa, num * 13)
	draw_rect(ilus, Color(c, 0.25 * alfa), false, 1.0)
	call("_d_" + String(d.d), ilus, c, alfa)
	draw_line(Vector2(r.position.x + 6, ilus.end.y + 4), Vector2(r.end.x - 6, ilus.end.y + 4), Color(c, 0.35 * alfa), 1.0)
	var y := ilus.end.y + 6 + tam_t * 1.35
	for l in lineas:
		Texto.dibujar(self, Vector2(r.get_center().x, y), l, tam_t, Color(BLANCO, alfa), HORIZONTAL_ALIGNMENT_CENTER)
		y += tam_t * 1.55

# ---------------------------------------------------------------- piezas
## Marco neón con esquinas cortadas (arriba-izquierda y abajo-derecha).
func _marco(r: Rect2, c: Color, corte: float, fondo: Color, alfa: float) -> void:
	var pts := PackedVector2Array([
		r.position + Vector2(corte, 0), Vector2(r.end.x, r.position.y),
		r.end - Vector2(0, corte), r.end - Vector2(corte, 0),
		Vector2(r.position.x, r.end.y), r.position + Vector2(0, corte),
	])
	draw_colored_polygon(pts, fondo)
	var cerrado_pts := pts.duplicate()
	cerrado_pts.append(pts[0])
	draw_polyline(cerrado_pts, Color(c, 0.12 * alfa), 6.0)
	draw_polyline(cerrado_pts, Color(c, 0.3 * alfa), 3.0)
	draw_polyline(cerrado_pts, Color(c.lerp(Color.WHITE, 0.35), 0.95 * alfa), 1.2)

func _chip(o: Vector2, s: String, c: Color, alfa: float) -> void:
	var w := Texto.ancho(s, 7) + 18
	var r := Rect2(o, Vector2(w, 14))
	_marco(r, c, 4.0, Color(0.02, 0.05, 0.14, 0.95 * alfa), alfa)
	Texto.dibujar(self, Vector2(o.x + 9, o.y + 10), s, 7, Color(BLANCO, alfa))

func _estrellas(r: Rect2, n: int, alfa: float, semilla: int) -> void:
	for i in n:
		var h := _hash(i * 7 + semilla)
		var p := r.position + Vector2(h * r.size.x, _hash(i * 13 + semilla * 3) * r.size.y)
		var brillo := 0.25 + 0.5 * absf(sin(_t * (0.6 + h) + i))
		draw_rect(Rect2(p.floor(), Vector2.ONE), Color(0.8, 0.85, 1.0, brillo * alfa * 0.7))

func _hash(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)

func _suave(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)

func _lineas(s: String, tam: int, ancho: float) -> Array:
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

func _sprite(ruta: String, centro: Vector2, alto: float, alfa: float, rot := 0.0, tinte := Color.WHITE) -> void:
	var tex := Datos.tex(ruta)
	var w := tex.get_width() * alto / tex.get_height()
	draw_set_transform_matrix(_xf * Transform2D(rot, centro))
	draw_texture_rect(tex, Rect2(Vector2(-w, -alto) * 0.5, Vector2(w, alto)), false, Color(tinte, alfa * tinte.a))
	draw_set_transform_matrix(_xf)

func _nave() -> String:
	return "res://art/naves/%s.png" % Progreso.nave_equipada

func _tecla(centro: Vector2, s: String, activa: bool, alfa: float, c := CIAN) -> void:
	var w := maxf(16.0, Texto.ancho(s, 8) + 10.0)
	var hundida := 1.0 if activa else 0.0
	var r := Rect2(centro - Vector2(w * 0.5, 8 - hundida), Vector2(w, 16))
	draw_rect(Rect2(r.position + Vector2(0, 2 - hundida), r.size), Color(0, 0, 0, 0.5 * alfa))
	draw_rect(r, Color(c, 0.35 * alfa) if activa else Color(0.06, 0.08, 0.2, alfa))
	draw_rect(r, Color(c.lerp(Color.WHITE, 0.3), alfa), false, 1.0)
	Texto.dibujar(self, Vector2(centro.x, r.position.y + 12), s, 8, Color(BLANCO, alfa), HORIZONTAL_ALIGNMENT_CENTER)

func _flecha(p: Vector2, dir: Vector2, c: Color, alfa: float) -> void:
	var a := dir.angle()
	var pts := PackedVector2Array([p + Vector2.from_angle(a) * 7, p + Vector2.from_angle(a + 2.3) * 6, p + Vector2.from_angle(a - 2.3) * 6])
	draw_colored_polygon(pts, Color(c, alfa))
	draw_line(p - dir * 7, p, Color(c, alfa), 3.0)

func _bala(p: Vector2, c: Color, alfa: float, r := 2.5) -> void:
	draw_circle(p, r + 2.5, Color(c, 0.25 * alfa))
	draw_circle(p, r, Color(c, alfa))
	draw_circle(p - Vector2(0.7, 0.7), r * 0.45, Color(1, 1, 1, 0.8 * alfa))

func _rayo(desde: Vector2, hasta: Vector2, alfa: float) -> void:
	draw_line(desde, hasta, Color(0.35, 0.9, 1.0, 0.3 * alfa), 4.0)
	draw_line(desde, hasta, Color(0.85, 1.0, 1.0, alfa), 1.5)

func _gema(p: Vector2, tam: float, alfa: float, c := Color("3fe0ff")) -> void:
	var pts := PackedVector2Array([p + Vector2(0, -tam), p + Vector2(tam * 0.7, 0), p + Vector2(0, tam), p + Vector2(-tam * 0.7, 0)])
	draw_colored_polygon(pts, Color(c, alfa))
	draw_line(p + Vector2(0, -tam), p + Vector2(-tam * 0.7, 0), Color(1, 1, 1, 0.9 * alfa), 1.0)

# ---------------------------------------------------------------- ilustraciones
func _d_mover(r: Rect2, c: Color, a: float) -> void:
	var ciclo := fmod(_t * 0.5, 4.0)
	var dirs := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
	var di := int(ciclo)
	var dir: Vector2 = dirs[di]
	var centro := r.position + Vector2(r.size.x * 0.5, r.size.y * 0.38)
	var paso := sin(fmod(ciclo, 1.0) * PI)
	var nave := centro + dir * paso * 10.0
	for k in 4:
		var d2: Vector2 = dirs[k]
		var activa: bool = k == di and paso > 0.2
		_flecha(centro + d2 * 26.0, d2, c if activa else Color(c, 0.35), a)
	_sprite(_nave(), nave, 26, a)
	var abajo := r.end.y - 16
	if Ajustes.es_tactil():
		var base := Vector2(r.get_center().x, abajo - 2)
		draw_arc(base, 13, 0, TAU, 32, Color(c, 0.6 * a), 2.0, true)
		var punta := base + dir * paso * 8.0
		draw_circle(punta, 6, Color(c, 0.85 * a))
		draw_circle(punta, 3, Color(1, 1, 1, 0.8 * a))
	else:
		var x := r.get_center().x
		var teclas := ["W", "D", "S", "A"]
		var posiciones := [Vector2(0, -17), Vector2(19, 0), Vector2(0, 0), Vector2(-19, 0)]
		for k in 4:
			_tecla(Vector2(x, abajo + 4) + posiciones[k], teclas[k], k == di and paso > 0.2, a, c)

func _d_disparar(r: Rect2, c: Color, a: float) -> void:
	var nave := Vector2(r.get_center().x, r.end.y - 18)
	var enemigo := Vector2(r.get_center().x + sin(_t * 1.3) * r.size.x * 0.3, r.position.y + 22)
	# mira de fijación girando sobre el enemigo
	for k in 4:
		var ang := _t * 2.0 + k * PI * 0.5
		var p := enemigo + Vector2.from_angle(ang) * 15.0
		draw_line(p, p + Vector2.from_angle(ang) * 5.0, Color(c, 0.9 * a), 2.0)
	var golpe := false
	for k in 3:
		var f := fmod(_t * 2.6 + k / 3.0, 1.0)
		var b := nave.lerp(enemigo, f)
		var dir := (enemigo - nave).normalized()
		_rayo(b - dir * 7.0, b + dir * 3.0, a)
		if f > 0.9:
			golpe = true
	_sprite("res://art/enemigos/grunt_0.png", enemigo, 22, a, PI, Color(1, 1, 1) if not golpe else Color(2, 2, 2))
	var dir_n := (enemigo - nave).normalized()
	_sprite(_nave(), nave, 24, a, dir_n.angle() + PI * 0.5)
	Texto.dibujar(self, Vector2(r.end.x - 6, r.end.y - 5), "AUTO", 6, Color(c, 0.8 * a), HORIZONTAL_ALIGNMENT_RIGHT)

func _d_dash(r: Rect2, c: Color, a: float) -> void:
	var f := fmod(_t * 0.55, 1.0)
	var y := r.position.y + r.size.y * 0.45
	var x0 := r.position.x + 18
	var x1 := r.end.x - 18
	# balas enemigas cayendo en una columna en el centro
	for k in 5:
		var by := r.position.y + fmod(_t * 40.0 + k * 22.0, r.size.y - 30.0) + 6
		_bala(Vector2(r.get_center().x + (k % 2) * 6 - 3, by), Color("ff5a3c"), a)
	var dashing := f > 0.35 and f < 0.6
	var k2 := clampf((f - 0.35) / 0.25, 0.0, 1.0)
	var x := lerpf(x0, x1, _suave(k2)) if f < 0.85 else lerpf(x1, x0, (f - 0.85) / 0.15)
	if dashing:
		for e in 4:
			var xe := lerpf(x0, x1, _suave(maxf(0.0, k2 - e * 0.09)))
			_sprite(_nave(), Vector2(xe, y), 24, a * (0.5 - e * 0.11), PI * 0.5, Color(0.5, 0.9, 1.0))
	_sprite(_nave(), Vector2(x, y), 24, a, PI * 0.5 if f < 0.85 else -PI * 0.5)
	if dashing:
		Texto.dibujar(self, Vector2(r.get_center().x, y - 18), "¡INVULNERABLE!", 6, Color(c, a), HORIZONTAL_ALIGNMENT_CENTER)
	var abajo := r.end.y - 13
	if Ajustes.es_tactil():
		var bc := Vector2(r.get_center().x, abajo - 2)
		draw_arc(bc, 11, 0, TAU, 32, Color(0.45, 0.95, 1.0, a), 2.0, true)
		Texto.dibujar(self, bc + Vector2(0, 3), "DASH", 6, Color(BLANCO, a), HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_tecla(Vector2(r.get_center().x, abajo), "ESPACIO", f > 0.3 and f < 0.4, a, c)

func _d_xp(r: Rect2, c: Color, a: float) -> void:
	var f := fmod(_t * 0.5, 1.0)
	var nave := Vector2(r.get_center().x, r.end.y - 26)
	var origen := Vector2(r.get_center().x, r.position.y + 22)
	if f < 0.2:
		_sprite("res://art/enemigos/grunt_0.png", origen, 22, a, PI)
	else:
		var k := clampf((f - 0.2) / 0.08, 0.0, 1.0)
		draw_circle(origen, 6 + 12 * k, Color(1, 0.7, 0.3, (1.0 - k) * a))
	for i in 6:
		var ang := i * TAU / 6.0
		var salida := origen + Vector2.from_angle(ang) * 16.0
		var g := clampf((f - 0.25) / 0.6, 0.0, 1.0)
		if f >= 0.2 and g < 1.0:
			var p := salida.lerp(nave, _suave(maxf(0.0, g * 1.2 - i * 0.05)))
			_gema(p, 4.0, a, Color("3fe0ff") if i % 3 else Color("b98cff"))
	_sprite(_nave(), nave, 22, a)
	# barra de experiencia
	var bw := r.size.x - 30
	var bx := r.position.x + 15
	var by := r.end.y - 9
	var lleno := clampf((f - 0.3) / 0.6, 0.0, 1.0)
	draw_rect(Rect2(bx, by, bw, 4), Color(0.05, 0.05, 0.15, a))
	draw_rect(Rect2(bx, by, bw * lleno, 4), Color("3fe0ff", a))
	draw_rect(Rect2(bx, by, bw, 4), Color(c, 0.6 * a), false, 1.0)
	if lleno >= 1.0:
		Texto.dibujar(self, Vector2(r.get_center().x, by - 26), "¡NIVEL!", 8, Color(AMARILLO, a), HORIZONTAL_ALIGNMENT_CENTER)

func _d_chatarra(r: Rect2, c: Color, a: float) -> void:
	var cuenta := int(fmod(_t * 0.6, 1.0) * 5.0)
	for i in 5:
		var f := fmod(_t * 0.6 + i * 0.2, 1.0)
		var p := Vector2(r.position.x + 14 + _hash(i * 3) * (r.size.x - 28), r.position.y + 8 + f * (r.size.y - 40))
		_sprite("res://art/hud/gear.png", p, 12, a * (1.0 - f * 0.5), _t * 2.0 + i)
	var bx := r.get_center().x
	var by := r.end.y - 12
	_sprite("res://art/hud/gear.png", Vector2(bx - 18, by - 3), 14, a, _t)
	Texto.dibujar(self, Vector2(bx - 8, by + 2), "%d" % (20 + cuenta * 3), 10, Color(AMARILLO, a))

func _d_reparar(r: Rect2, c: Color, a: float) -> void:
	var f := fmod(_t * 0.45, 1.0)
	var lleno := f > 0.45
	var cx := r.get_center().x
	var y := r.position.y + 22
	for i in 5:
		var tex := "res://art/hud/heart.png" if i < 4 or lleno else "res://art/hud/heart_empty.png"
		var late := 1.0 + (0.3 * (1.0 - clampf((f - 0.45) / 0.2, 0.0, 1.0)) if i == 4 and lleno else 0.0)
		_sprite(tex, Vector2(cx + (i - 2) * 17, y), 13 * late, a)
	if lleno:
		var k := clampf((f - 0.45) / 0.4, 0.0, 1.0)
		draw_arc(Vector2(cx + 34, y), 8 + 16 * k, 0, TAU, 28, Color(c, (1.0 - k) * a), 2.0, true)
		Texto.dibujar(self, Vector2(cx, y + 24 - k * 6), "+1 VIDA", 8, Color(c, a * (1.0 - k * 0.5)), HORIZONTAL_ALIGNMENT_CENTER)
		_sprite("res://art/hud/gear.png", Vector2(cx - 12, y + 38), 10, a * (1.0 - k))
		Texto.dibujar(self, Vector2(cx - 4, y + 42), "-18", 7, Color(AMARILLO, a * (1.0 - k)))
	var abajo := r.end.y - 13
	var pulsa := f > 0.38 and f < 0.5
	if Ajustes.es_tactil():
		var bc := Vector2(cx, abajo - 2)
		draw_arc(bc, 10 * (0.85 if pulsa else 1.0), 0, TAU, 28, Color(c, a), 2.0, true)
		_sprite("res://art/hud/plus.png", bc, 11, a)
	else:
		_tecla(Vector2(cx, abajo), "R", pulsa, a, c)

func _d_potenciadores(r: Rect2, c: Color, a: float) -> void:
	var ids := ["escudo", "iman", "sobrecarga", "impulso", "nova", "reparacion"]
	for i in ids.size():
		var def: Dictionary = Datos.POTENCIADORES[ids[i]]
		var col := i % 3
		var fila := i / 3
		var p := r.position + Vector2(r.size.x * (0.2 + col * 0.3), r.size.y * (0.3 + fila * 0.42))
		p.y += sin(_t * 3.0 + i) * 2.0
		var dc: Color = def.color
		draw_circle(p, 13, Color(dc, 0.14 * a))
		draw_arc(p, 11 + sin(_t * 4.0 + i) * 1.0, 0, TAU, 24, Color(dc, 0.7 * a), 1.5, true)
		_sprite(String(def.icono), p, 16, a)

func _d_elegir(r: Rect2, c: Color, a: float) -> void:
	var sel := int(fmod(_t * 0.8, 3.0))
	var w := (r.size.x - 24) / 3.0
	for i in 3:
		var col: Color = Datos.RAREZAS[i].color
		var alto := r.size.y - 26
		var sube := 5.0 if i == sel else 0.0
		var cr := Rect2(r.position.x + 6 + i * (w + 6), r.position.y + 10 - sube, w, alto)
		draw_rect(cr, Color(0.04, 0.05, 0.14, a))
		draw_rect(cr, Color(col, a), false, 2.0 if i == sel else 1.0)
		draw_rect(Rect2(cr.position + Vector2(4, 6), Vector2(cr.size.x - 8, 3)), Color(col, 0.6 * a))
		for k in 3:
			draw_rect(Rect2(cr.position + Vector2(4, 16 + k * 7), Vector2((cr.size.x - 8) * (1.0 - k * 0.25), 2)), Color(0.6, 0.65, 0.8, 0.5 * a))
		Texto.dibujar(self, Vector2(cr.get_center().x, cr.end.y + 11 + sube), Datos.RAREZAS[i].nombre, 5, Color(col, a), HORIZONTAL_ALIGNMENT_CENTER)
	# cursor / dedo sobre la elegida
	var px := r.position.x + 6 + sel * (w + 6) + w * 0.5
	_flecha(Vector2(px, r.position.y + 10 + (r.size.y - 26) * 0.6 + sin(_t * 6.0) * 2.0), Vector2.UP, BLANCO, a)

func _d_niveles(r: Rect2, c: Color, a: float) -> void:
	var nv := int(fmod(_t * 0.7, 5.0)) + 1
	var cx := r.get_center().x
	var y := r.position.y + r.size.y * 0.32
	var antes := 18 + (nv - 1) * 3
	Texto.dibujar(self, Vector2(cx, y), "DAÑO %d → %d" % [antes, antes + 3], 9, Color(AMARILLO, a), HORIZONTAL_ALIGNMENT_CENTER)
	var pw := 14.0
	var x0 := cx - (5 * pw + 4 * 4) * 0.5
	for i in 5:
		var pr := Rect2(x0 + i * (pw + 4), y + 14, pw, 7)
		draw_rect(pr, Color(c, a) if i < nv else Color(0.08, 0.1, 0.25, a))
		draw_rect(pr, Color(c, 0.7 * a), false, 1.0)
	Texto.dibujar(self, Vector2(cx, y + 36), "NV %d / 5" % nv, 7, Color(BLANCO, a), HORIZONTAL_ALIGNMENT_CENTER)

func _d_reroll(r: Rect2, c: Color, a: float) -> void:
	var cual := int(fmod(_t * 0.7, 2.0))
	var cx := r.get_center().x
	var datos := [["REROLL", Color("c58cff"), "res://art/hud/gear.png", "10"], ["REPARAR", Color("7dff9b"), "res://art/hud/heart.png", "18"]]
	for i in 2:
		var br := Rect2(cx - 52, r.position.y + 12 + i * 32, 104, 24)
		var on := i == cual
		var col: Color = datos[i][1]
		draw_rect(br, Color(col.r * 0.25, col.g * 0.25, col.b * 0.3, a) if on else Color(0.05, 0.06, 0.14, a))
		draw_rect(br, Color(col, a), false, 2.0 if on else 1.0)
		_sprite(String(datos[i][2]), br.position + Vector2(14, 12), 13, a)
		Texto.dibujar(self, br.position + Vector2(26, 11), String(datos[i][0]), 8, Color(BLANCO, a))
		Texto.dibujar(self, br.position + Vector2(26, 20), String(datos[i][3]) + " CHATARRA", 5, Color(col, a))

func _d_arena(r: Rect2, c: Color, a: float) -> void:
	var ar := r.grow(-12)
	var l := 12.0
	for k in 4:
		var p := Vector2(ar.position.x if k == 0 or k == 3 else ar.end.x, ar.position.y if k < 2 else ar.end.y)
		var sx := 1.0 if k == 0 or k == 3 else -1.0
		var sy := 1.0 if k < 2 else -1.0
		draw_line(p, p + Vector2(l * sx, 0), Color(c, a), 2.0)
		draw_line(p, p + Vector2(0, l * sy), Color(c, a), 2.0)
	draw_rect(ar, Color(c, 0.18 * a), false, 1.0)
	# la nave rebota en el borde
	var f := fmod(_t * 0.7, 1.0)
	var x := ar.position.x + 12 + absf(sin(f * PI)) * (ar.size.x - 24)
	var p := Vector2(x, ar.get_center().y + 10)
	_sprite(_nave(), p, 20, a, PI * 0.5 if f < 0.5 else -PI * 0.5)
	if absf(x - (ar.end.x - 12)) < 4.0:
		for k in 5:
			draw_line(Vector2(ar.end.x, p.y), Vector2(ar.end.x, p.y) + Vector2.from_angle(PI + (k - 2) * 0.4) * 8.0, Color(c, a), 1.5)
	_sprite("res://art/jefes/centinela.png", Vector2(ar.get_center().x, ar.position.y + 14), 20, a * 0.9)

func _d_patrones(r: Rect2, c: Color, a: float) -> void:
	var jefe := Vector2(r.get_center().x, r.position.y + 22)
	var f := fmod(_t * 0.5, 1.0)
	for i in 12:
		var ang := i * TAU / 12.0 + 0.2
		var p := jefe + Vector2.from_angle(ang) * (14.0 + f * r.size.x * 0.55)
		if r.grow(-2).has_point(p):
			_bala(p, Color("ff8a3d"), a * (1.0 - f * 0.4), 2.0)
	_sprite("res://art/jefes/centinela.png", jefe, 24, a)
	Texto.dibujar(self, jefe + Vector2(0, 22), "ANILLO", 6, Color(c, a), HORIZONTAL_ALIGNMENT_CENTER)
	var nave := Vector2(r.get_center().x + sin(_t * 2.2) * 26.0, r.end.y - 14)
	_sprite(_nave(), nave, 18, a)

func _d_fase2(r: Rect2, c: Color, a: float) -> void:
	var f := fmod(_t * 0.4, 1.0)
	var vida := 1.0 - f * 0.9
	var bw := r.size.x - 24
	var bx := r.position.x + 12
	var by := r.position.y + 16
	var fase2 := vida < Datos.JEFE_FASE2_UMBRAL
	draw_rect(Rect2(bx, by, bw, 6), Color(0.1, 0.02, 0.06, a))
	draw_rect(Rect2(bx, by, bw * vida, 6), Color("ff8a3d", a) if fase2 else Color("ff3d5a", a))
	var mx := bx + bw * Datos.JEFE_FASE2_UMBRAL
	draw_line(Vector2(mx, by - 3), Vector2(mx, by + 9), Color(1, 1, 1, 0.9 * a), 1.0)
	draw_rect(Rect2(bx, by, bw, 6), Color(1, 0.6, 0.7, 0.8 * a), false, 1.0)
	var jefe := Vector2(r.get_center().x, r.get_center().y + 4)
	var temblor := Vector2(sin(_t * 40.0), cos(_t * 37.0)) * (1.5 if fase2 else 0.0)
	if fase2:
		draw_circle(jefe, 22 + sin(_t * 8.0) * 2.0, Color(1, 0.35, 0.2, 0.18 * a))
	_sprite("res://art/jefes/centinela.png", jefe + temblor, 26, a, 0.0, Color(1.4, 0.8, 0.7) if fase2 else Color.WHITE)
	if fase2:
		Texto.dibujar(self, Vector2(r.get_center().x, r.end.y - 8), "¡FASE 2!", 9, Color("ff8a3d", a), HORIZONTAL_ALIGNMENT_CENTER)
