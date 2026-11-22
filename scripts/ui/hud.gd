extends Control
## HUD dibujado a mano, sin cajas:
##  arriba-izq: corazones, barra de escudo segmentada (cargas + recarga), nivel y XP.
##  arriba-centro: tiempo y puntaje (o barra del jefe).
##  arriba-der: chatarra.
##  arsenal: armas permanentes con su nivel (abajo-izq en PC, abajo-centro en teléfono).
##  fila de potenciadores temporales con cuenta atrás (SOBRECARGA, IMPULSO, IMÁN).
##  flechas en el borde hacia potenciadores fuera de pantalla.

var juego

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	juego = get_parent().get_parent()

func _draw() -> void:
	if juego == null or juego.N == null:
		return
	var t := get_viewport_rect().size
	var N = juego.N
	var tactil: bool = Ajustes.es_tactil()
	# ---------------------------------------------------------- vida
	var x := 10.0
	var y := 10.0
	var corazon := Datos.tex("res://art/hud/heart.png")
	var vacio := Datos.tex("res://art/hud/heart_empty.png")
	var tam := 14.0
	for i in N.vida_max:
		var tex := corazon if i < N.vida else vacio
		var late := 1.0
		if i == N.vida - 1 and N.vida <= 2:
			late = 1.0 + 0.12 * abs(sin(juego.reloj * 6.0))
		var s := tam * late
		draw_texture_rect(tex, Rect2(Vector2(x + i * (tam + 2) - (s - tam) * 0.5, y - (s - tam) * 0.5), Vector2(s, s * tex.get_height() / tex.get_width())), false)
	# ---------------------------------------------------------- escudo
	y += 18
	if N.escudo_max > 0:
		var ic := Datos.tex("res://art/hud/shield.png")
		draw_texture_rect(ic, Rect2(Vector2(x, y - 1), Vector2(10, 10 * ic.get_height() / ic.get_width())), false)
		var sx := x + 14
		var w := 16.0
		for i in N.escudo_max:
			var r := Rect2(Vector2(sx + i * (w + 2), y + 2), Vector2(w, 5))
			draw_rect(r, Color(0.05, 0.1, 0.2, 0.8))
			if i < N.escudo:
				draw_rect(r, Color("70dfff"))
			elif i == N.escudo:
				draw_rect(Rect2(r.position, Vector2(w * N.escudo_t / N.escudo_recarga, 5)), Color(0.44, 0.87, 1.0, 0.45))
			draw_rect(r, Color(0.6, 0.9, 1.0, 0.6), false, 1.0)
		y += 12
	# ---------------------------------------------------------- nivel + XP
	Texto.dibujar(self, Vector2(x, y + 8), "NV %d" % juego.nivel, 8, Color("ffe36b"))
	var bx := x + Texto.ancho("NV %d" % juego.nivel, 8) + 6
	var bw := 96.0
	draw_rect(Rect2(bx, y + 2, bw, 5), Color(0.05, 0.05, 0.15, 0.8))
	draw_rect(Rect2(bx, y + 2, bw * clampf(juego.xp / juego.xp_necesaria, 0, 1), 5), Color("3fe0ff"))
	draw_rect(Rect2(bx, y + 2, bw, 5), Color(0.6, 0.9, 1.0, 0.5), false, 1.0)
	y += 16
	# ---------------------------------------------------------- potenciadores temporales
	var activos := []
	if N.sobrecarga_t > 0.0: activos.append(["sobrecarga", N.sobrecarga_t])
	if N.impulso_t > 0.0: activos.append(["impulso", N.impulso_t])
	if juego.iman_t > 0.0: activos.append(["iman", juego.iman_t])
	for i in activos.size():
		var k: String = activos[i][0]
		var resto: float = activos[i][1]
		var def: Dictionary = Datos.POTENCIADORES[k]
		var c := Vector2(x + 11 + i * 30, y + 11)
		var parpadeo := resto < 2.0 and int(juego.reloj * 8.0) % 2 == 0
		draw_circle(c, 11, Color(0.03, 0.04, 0.1, 0.75))
		draw_arc(c, 11, -PI / 2, -PI / 2 + TAU * clampf(resto / float(def.tope), 0, 1), 28, def.color, 2.0, true)
		if not parpadeo:
			draw_texture_rect(Datos.tex(def.icono), Rect2(c - Vector2(8, 8), Vector2(16, 16)), false)
		Texto.dibujar(self, c + Vector2(0, 20), "%d" % ceili(resto), 6, def.color, HORIZONTAL_ALIGNMENT_CENTER)
	# ---------------------------------------------------------- centro: tiempo / jefe
	var cx := t.x * 0.5
	if juego.jefe and not juego.jefe.muerto:
		var e = juego.jefe
		var w = min(300.0, t.x * 0.46)
		var r := Rect2(cx - w * 0.5, 22, w, 7)
		Texto.dibujar(self, Vector2(cx, 17), e.nombre + ("  · FASE 2" if e.fase_jefe == 2 else ""), 8, Color("ff7892"), HORIZONTAL_ALIGNMENT_CENTER)
		draw_rect(r, Color(0.1, 0.02, 0.06, 0.85))
		var frac: float = clampf(e.vida / e.vida_max, 0, 1)
		draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), Color("ff3d5a") if e.fase_jefe == 1 else Color("ff8a3d"))
		var mx := r.position.x + r.size.x * Datos.JEFE_FASE2_UMBRAL
		draw_line(Vector2(mx, r.position.y - 2), Vector2(mx, r.end.y + 2), Color(1, 1, 1, 0.8), 1.0)
		draw_rect(r, Color(1, 0.6, 0.7, 0.8), false, 1.0)
		Texto.dibujar(self, Vector2(cx, 42), Progreso.formato_tiempo(juego.tiempo), 7, Color(0.85, 0.9, 1.0, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var reloj := Datos.tex("res://art/hud/clock.png")
		var ts := Progreso.formato_tiempo(juego.tiempo)
		var tw := Texto.ancho(ts, 10)
		draw_texture_rect(reloj, Rect2(cx - tw * 0.5 - 16, 8, 12, 12), false)
		Texto.dibujar(self, Vector2(cx - tw * 0.5, 19), ts, 10, Color.WHITE)
		Texto.dibujar(self, Vector2(cx, 32), "%d" % juego.puntaje, 7, Color("8ff6ff"), HORIZONTAL_ALIGNMENT_CENTER)
		var falta: float = juego.prox_jefe - juego.tiempo
		if falta > 0.0 and falta < 10.0 and juego.jefe == null:
			Texto.dibujar(self, Vector2(cx, 46), "JEFE EN %d" % ceili(falta), 7, Color(1, 0.45, 0.55, 0.6 + 0.4 * sin(juego.reloj * 8.0)), HORIZONTAL_ALIGNMENT_CENTER)
	# ---------------------------------------------------------- chatarra
	var coin := Datos.tex("res://art/hud/gear.png")
	var cs := "%d" % juego.chatarra
	var cw := Texto.ancho(cs, 9)
	draw_texture_rect(coin, Rect2(t.x - 12 - cw - 16, 9, 13, 13), false)
	Texto.dibujar(self, Vector2(t.x - 10 - cw, 20), cs, 9, Color("ffd34d"))
	if juego.puede_reparar() and not tactil:
		Texto.dibujar(self, Vector2(t.x - 10, 34), "R: REPARAR (%d)" % juego.costo_reparar, 6, Color(0.5, 1.0, 0.6, 0.6 + 0.4 * sin(juego.reloj * 5.0)), HORIZONTAL_ALIGNMENT_RIGHT)
	# ---------------------------------------------------------- arsenal
	var armas := []
	for a in Datos.ARSENAL:
		var n: int = N.nivel_arma(a.id)
		if n > 0:
			armas.append([a, n])
	var paso := 26.0
	var ax := 10.0
	var ay := t.y - 30.0
	if tactil:
		ax = cx - armas.size() * paso * 0.5
		ay = t.y - 28.0
	for i in armas.size():
		var a: Dictionary = armas[i][0]
		var n: int = armas[i][1]
		var p := Vector2(ax + i * paso, ay)
		draw_rect(Rect2(p, Vector2(22, 22)), Color(0.03, 0.04, 0.1, 0.65))
		draw_rect(Rect2(p, Vector2(22, 22)), Color(a.color, 0.9), false, 1.0)
		var ic := Datos.tex(a.icono)
		var h := 15.0
		var w := ic.get_width() * h / ic.get_height()
		draw_texture_rect(ic, Rect2(p + Vector2((22 - w) * 0.5, 3), Vector2(w, h)), false)
		Texto.dibujar(self, p + Vector2(21, 23), str(n), 6, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	# dash (solo PC; en el teléfono ya está en su botón)
	if not tactil:
		var dp := Vector2(10 + armas.size() * paso + 14, t.y - 19)
		var frac: float = 1.0 - N.dash_cd / max(0.01, N.dash_recarga)
		draw_arc(dp, 9, -PI / 2, -PI / 2 + TAU * frac, 24, Color(0.45, 0.95, 1.0, 0.9 if frac >= 1.0 else 0.5), 2.0, true)
		Texto.dibujar(self, dp + Vector2(13, 3), "DASH [ESPACIO]", 6, Color(0.7, 0.95, 1.0, 0.85 if frac >= 1.0 else 0.4))
		if N.bombas > 0:
			var bp := dp + Vector2(100, 0)
			var hay: bool = N.bomba_cargas > 0
			var fb: float = 1.0 if N.bomba_cargas >= N.bombas else N._t_bomba / Nave.stat_bomba_cd(N.bombas)
			draw_arc(bp, 9, -PI / 2, -PI / 2 + TAU * fb, 24, Color(1.0, 0.65, 0.3, 0.9 if hay else 0.5), 2.0, true)
			draw_texture_rect(Datos.tex("res://art/hud/bomb.png"), Rect2(bp - Vector2(6, 6), Vector2(12, 12)), false, Color(1, 1, 1, 1.0 if hay else 0.45))
			Texto.dibujar(self, bp + Vector2(13, 3), "BOMBA x%d [E]" % N.bomba_cargas, 6, Color(1.0, 0.8, 0.55, 0.9 if hay else 0.45))
	# ---------------------------------------------------------- flechas a potenciadores
	var cam: Camera2D = juego.camara
	var z: float = cam.zoom.x
	for p in juego.potenciadores:
		var sp: Vector2 = (p.pos - cam.get_screen_center_position()) * z + t * 0.5
		var margen := Rect2(Vector2(18, 56), t - Vector2(36, 96))
		if margen.has_point(sp):
			continue
		var c: Color = Datos.POTENCIADORES[p.tipo].color
		var borde := sp.clamp(margen.position, margen.end)
		var ang := (sp - t * 0.5).angle()
		var pts := PackedVector2Array([borde + Vector2.from_angle(ang) * 8, borde + Vector2.from_angle(ang + 2.4) * 6, borde + Vector2.from_angle(ang - 2.4) * 6])
		draw_colored_polygon(pts, Color(c, 0.6 + 0.3 * sin(juego.reloj * 6.0)))
		draw_texture_rect(Datos.tex(Datos.POTENCIADORES[p.tipo].icono), Rect2(borde - Vector2.from_angle(ang) * 12 - Vector2(7, 7), Vector2(14, 14)), false, Color(1, 1, 1, 0.85))
	# ---------------------------------------------------------- anuncio
	if juego.anuncio_actual:
		var an: Dictionary = juego.anuncio_actual
		var edad: float = an.max - an.t
		var alfa := clampf(min(edad / 0.2, an.t / 0.4), 0, 1)
		var esc = 1.0 + max(0.0, 0.25 - edad) * 1.6
		draw_set_transform(Vector2(cx, t.y * 0.36), 0, Vector2(esc, esc))
		Texto.dibujar(self, Vector2(0, 0), an.a, 18, Color(1, 0.88, 0.45, alfa), HORIZONTAL_ALIGNMENT_CENTER)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		Texto.dibujar(self, Vector2(cx, t.y * 0.36 + 18), an.b, 7, Color(0.85, 0.92, 1.0, alfa), HORIZONTAL_ALIGNMENT_CENTER)
	# fogonazo de las explosiones grandes
	if juego.ef.destello_pantalla > 0.0:
		draw_rect(Rect2(Vector2.ZERO, t), Color(1, 0.93, 0.8, juego.ef.destello_pantalla * 0.5))
	# viñeta roja con vida baja
	if N.vida == 1 and not N.muerta:
		var a := 0.12 + 0.08 * sin(juego.reloj * 5.0)
		for i in 6:
			draw_rect(Rect2(Vector2.ZERO, t).grow(-i * 3), Color(1, 0.1, 0.2, a * (1.0 - i / 6.0)), false, 3.0)
