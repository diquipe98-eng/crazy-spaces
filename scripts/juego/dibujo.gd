class_name Dibujo
## Dibujo del mundo en tres capas:
##  "base"   mezcla normal: asteroides, botín, enemigos, jefe, nave, humo.
##  "brillo" mezcla aditiva: proyectiles, luces, halos, fuego, chispas, ondas.
##  "textos" textos cómic y números de daño.
## La nave NO lleva aro permanente: solo se ve una burbuja si tiene escudo.

const ALTO_NAVE := 46.0

static var _tex_proy := {}

static func tex_proyectil(tipo: String) -> Texture2D:
	if not _tex_proy.has(tipo):
		_tex_proy[tipo] = Generador.proyectil(tipo)
	return _tex_proy[tipo]

## Dibuja una textura de proyectil centrada en "pos", orientada a "ang".
static func _proy(ci: CanvasItem, tipo: String, pos: Vector2, ang: float, largo: float, ancho: float, color: Color) -> void:
	ci.draw_set_transform(pos, ang, Vector2.ONE)
	ci.draw_texture_rect(tex_proyectil(tipo), Rect2(-largo * 0.5, -ancho * 0.5, largo, ancho), false, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func capa(j, nombre: String, ci: CanvasItem) -> void:
	match nombre:
		"base": _base(j, ci)
		"brillo": _brillo(j, ci)
		"textos": j.ef.dibujar_textos(ci)

static func _sprite(ci: CanvasItem, tex: Texture2D, pos: Vector2, rot: float, escala: float, color := Color.WHITE) -> void:
	ci.draw_set_transform(pos, rot, Vector2(escala, escala))
	ci.draw_texture(tex, -tex.get_size() * 0.5, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _halo(ci: CanvasItem, pos: Vector2, radio: float, color: Color) -> void:
	ci.draw_texture_rect(Datos.tex_brillo, Rect2(pos - Vector2(radio, radio), Vector2(radio, radio) * 2.0), false, color)

## Halo estirado en la dirección de movimiento (proyectiles tipo "bolt").
static func _halo_largo(ci: CanvasItem, pos: Vector2, ang: float, largo: float, ancho: float, color: Color) -> void:
	ci.draw_set_transform(pos, ang, Vector2.ONE)
	ci.draw_texture_rect(Datos.tex_brillo, Rect2(-largo, -ancho, largo * 2.0, ancho * 2.0), false, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# =====================================================================
static func _base(j, ci: CanvasItem) -> void:
	var t: float = j.reloj
	var N: Nave = j.N
	# asteroides
	for a in j.asteroides:
		_sprite(ci, a.textura, a.pos, a.rot, 2.0)
	# arena del jefe
	if j.arena:
		var r: Rect2 = j.arena.rect
		var s: float = j.arena.sello
		var c := Color(1.0, 0.3, 0.42, 0.25 + 0.15 * sin(t * 4.0))
		var grow := (1.0 - s) * 220.0
		ci.draw_rect(r.grow(grow), Color(c, c.a * s), false, 2.0)
		# esquinas marcadas
		for k in 4:
			var p: Vector2 = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)][k]
			var sx := 1.0 if k == 0 or k == 3 else -1.0
			var sy := 1.0 if k < 2 else -1.0
			ci.draw_line(p, p + Vector2(26 * sx, 0), Color(1, 0.5, 0.6, s), 3.0)
			ci.draw_line(p, p + Vector2(0, 26 * sy), Color(1, 0.5, 0.6, s), 3.0)
	# recogibles: gemas de XP (rombo) y chatarra (engranaje)
	var engranaje := Datos.tex("res://art/hud/gear.png")
	for p in j.recogibles:
		var bob := sin(p.t * 5.0) * 1.5
		if p.tipo == "xp":
			var tam = 3.5 + min(5.0, p.valor * 0.6)
			var q = p.pos + Vector2(0, bob)
			var pts := PackedVector2Array([q + Vector2(0, -tam), q + Vector2(tam * 0.7, 0), q + Vector2(0, tam), q + Vector2(-tam * 0.7, 0)])
			ci.draw_colored_polygon(pts, Color("3fe0ff") if p.valor < 5 else Color("b98cff"))
			ci.draw_line(q + Vector2(0, -tam), q + Vector2(-tam * 0.7, 0), Color(1, 1, 1, 0.9), 1.0)
		else:
			_sprite(ci, engranaje, p.pos + Vector2(0, bob), p.t * 1.5, 0.3)
	# potenciadores
	for p in j.potenciadores:
		var def: Dictionary = Datos.POTENCIADORES[p.tipo]
		if p.vida < 3.0 and int(t * 10.0) % 2 == 0:
			continue   # parpadea al expirar
		var esc := 0.36 + sin(t * 4.0 + p.fase) * 0.025
		_sprite(ci, Datos.tex(def.icono), p.pos + Vector2(0, sin(t * 2.6 + p.fase) * 3.0), 0.0, esc)
	# enemigos
	for e in j.enemigos:
		if e.muerto:
			continue
		if e.es_jefe:
			_jefe(j, ci, e)
			continue
		var rot: float = (N.pos - e.pos).angle() - PI / 2.0
		if e.dash_t > 0.0:
			rot = e.vel.angle() - PI / 2.0
		var esc: float = e.escala * (1.15 if e.elite else 1.0)
		var tex := Datos.tex(e.textura)
		var pos: Vector2 = e.pos
		if e.aviso > 0.0:
			pos += Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
		if e.absorbido:
			esc *= 0.75
		_sprite(ci, tex, pos, rot, esc)
		if e.destello > 0.0:
			_sprite(ci, Datos.silueta(e.textura), pos, rot, esc, Color(1, 1, 1, clampf(e.destello / 0.09, 0, 1) * (0.55 if e.aviso > 0.0 else 0.85)))
		if e.elite and e.vida < e.vida_max:
			var w := 30.0
			var y: float = e.radio + 8.0
			ci.draw_rect(Rect2(e.pos + Vector2(-w / 2, y), Vector2(w, 3)), Color(0, 0, 0, 0.6))
			ci.draw_rect(Rect2(e.pos + Vector2(-w / 2, y), Vector2(w * e.vida / e.vida_max, 3)), Color("ffd34d"))
	# humo y escombros
	j.ef.dibujar_base(ci)
	# nave del jugador
	if not N.muerta:
		var tex := Datos.tex(N.textura)
		var esc := ALTO_NAVE / tex.get_height()
		var rot: float = N.apunte + PI / 2.0
		for s in N.estelas:
			_sprite(ci, tex, s.pos, s.rot + PI / 2.0, esc, Color(0.45, 0.9, 1.0, s.vida / 0.25 * 0.45))
		var parpadeo: bool = N.inv > 0.0 and N.dash_t <= 0.0 and int(t * 17.0) % 2 == 1
		if not parpadeo:
			_sprite(ci, tex, N.pos, rot, esc)
		# drones y satélites
		for i in N.drones:
			var p := N.posicion_dron(i)
			ci.draw_circle(p, 4.5, Color("1b3a2c"))
			ci.draw_circle(p, 3.2, Color("6dffa8"))
			ci.draw_circle(p + Vector2(-1, -1), 1.2, Color.WHITE)
		var tam_orbe := Nave.stat_orbita_tam(N.orbitas)
		for i in N.orbitas:
			var p := N.posicion_orbita(i)
			ci.draw_circle(p, tam_orbe + 1.5, Color("2a0f40"))
			ci.draw_circle(p, tam_orbe, Color("b56cff"))
			ci.draw_circle(p + Vector2(-0.3, -0.3) * tam_orbe, tam_orbe * 0.55, Color("f0d8ff"))
	# cuerpos de proyectiles con volumen (contorno oscuro = se leen sobre cualquier fondo)
	for b in j.balas:
		if b.tipo == "misil":
			var ang: float = b.vel.angle()
			ci.draw_set_transform(b.pos, ang, Vector2.ONE)
			ci.draw_rect(Rect2(-6, -2.5, 11, 5), Color("1a1420"))
			ci.draw_rect(Rect2(-5, -1.5, 9, 3), Color("d8d4e0"))
			ci.draw_rect(Rect2(-5, -1.5, 9, 1), Color.WHITE)
			ci.draw_rect(Rect2(3, -1.5, 2, 3), Color("ff4a3a"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-6, -2), Vector2(-9, -5), Vector2(-4, -2)]), Color("8a8696"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-6, 2), Vector2(-9, 5), Vector2(-4, 2)]), Color("8a8696"))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif b.tipo == "bomba":
			var u: float = minf(1.0, b.vuelo / b.vuelo_total)
			var alto := sin(u * PI) * 34.0
			ci.draw_circle(b.pos, 4.0 * (1.0 - u * 0.3), Color(0, 0, 0, 0.35))   # sombra
			var p: Vector2 = b.pos + Vector2(0, -alto)
			ci.draw_circle(p, 6.0, Color("1a1420"))
			ci.draw_circle(p, 5.0, Color("4a3a46"))
			ci.draw_circle(p + Vector2(-1.5, -1.5), 2.0, Color("9a8a96"))
			ci.draw_circle(p + Vector2(3, -4), 1.6, Color("ffb45f") if int(t * 20.0) % 2 == 0 else Color("ff4a3a"))
	for b in j.balas_enemigas:
		var r: float = b.radio
		ci.draw_circle(b.pos, r + 1.2, Color(0.08, 0.02, 0.06, 0.9))
		ci.draw_circle(b.pos, r, b.color.darkened(0.15))
		ci.draw_circle(b.pos + Vector2(-0.25, -0.25) * r, r * 0.62, b.color.lightened(0.35))
		ci.draw_circle(b.pos + Vector2(-0.35, -0.35) * r, r * 0.28, Color(1, 1, 1, 0.95))

static func _jefe(j, ci: CanvasItem, e: Tipos.Jefe) -> void:
	var tex := Datos.tex(e.textura)
	var t: float = j.reloj
	var bob := sin(e.t * 1.8) * 3.0
	var pos := e.pos + Vector2(0, bob)
	var tinte := Color(1, 0.82, 0.86) if e.fase_jefe == 2 else Color.WHITE
	for s in e.estelas:
		_sprite(ci, tex, s.pos, s.rot, e.escala, Color(1, 0.4, 0.55, s.vida / 0.3 * 0.35))
	if e.estado == "carga":
		var u = 1.0 - e.carga_t / max(0.01, e.carga_total)
		pos += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (1.0 + u * 2.5)
	tinte.a = e.visibilidad
	if e.visibilidad < 1.0:
		# se deforma al desvanecerse
		var es := e.escala * (1.0 + (1.0 - e.visibilidad) * 0.25)
		_sprite(ci, tex, pos, e.inclinacion, es, tinte)
	else:
		_sprite(ci, tex, pos, e.inclinacion, e.escala, tinte)
	var blanco := 0.0
	if e.destello > 0.0:
		blanco = 0.22 * e.destello / 0.05
	if e.estado == "carga":
		var u = 1.0 - e.carga_t / max(0.01, e.carga_total)
		blanco = max(blanco, (0.15 + 0.25 * u) * (0.6 + 0.4 * sin(t * 30.0)))
	if blanco > 0.0:
		_sprite(ci, Datos.silueta(e.textura), pos, e.inclinacion, e.escala, Color(1, 0.92, 0.9, blanco))

# =====================================================================
static func _brillo(j, ci: CanvasItem) -> void:
	var t: float = j.reloj
	var N: Nave = j.N
	# halos del botín
	for p in j.recogibles:
		if p.tipo == "xp":
			_halo(ci, p.pos, 9.0, Color(0.2, 0.8, 1.0, 0.35))
	for p in j.potenciadores:
		var col: Color = Datos.POTENCIADORES[p.tipo].color
		var pulso := 0.35 + sin(t * 4.0 + p.fase) * 0.12
		_halo(ci, p.pos, 32.0, Color(col, pulso))
		ci.draw_arc(p.pos, 21.0 + sin(t * 3.0 + p.fase) * 1.5, t * 1.4, t * 1.4 + TAU * clampf(p.vida / Datos.POT_VIDA_SEG, 0.0, 1.0), 32, Color(col, 0.7), 1.5, true)
	# luces de enemigos (élite dorada, aviso de tajo)
	for e in j.enemigos:
		if e.muerto or e.es_jefe:
			if e.es_jefe and not e.muerto:
				_brillo_jefe(j, ci, e)
			continue
		if e.elite:
			_halo(ci, e.pos, e.radio * 2.4, Color(1, 0.8, 0.3, 0.28 + 0.08 * sin(t * 5.0)))
		if e.aviso > 0.0:
			_halo(ci, e.pos, e.radio * 2.0, Color(e.color, 0.5))
	# nave: motor, burbuja de escudo y potenciadores activos
	if not N.muerta:
		var atras := Vector2.from_angle(N.apunte + PI)
		var fuerza := 1.3 if N.impulso_t > 0.0 else 1.0
		_halo(ci, N.pos + atras * 15.0, 9.0 * fuerza + sin(t * 40.0) * 1.0, Color(1.0, 0.7, 0.35, 0.75))
		_halo(ci, N.pos, 26.0, Color(Datos.nave(N.id).color, 0.16))
		_escudo_plasma(j, ci)
		if N.sobrecarga_t > 0.0:
			_halo(ci, N.pos + Vector2.from_angle(N.apunte) * 16.0, 10.0, Color(1, 0.9, 0.4, 0.4 + 0.2 * sin(t * 20.0)))
		if j.iman_t > 0.0:
			var r := 52.0 + sin(t * 8.0) * 4.0
			for k in 12:
				var a := t * 1.5 + k * TAU / 12.0
				ci.draw_arc(N.pos, r, a, a + 0.22, 6, Color(0.45, 0.92, 1.0, 0.55), 1.6, true)
		if N.destello_canon() > 0.0:
			_halo(ci, N.pos + Vector2.from_angle(N.apunte) * 16.0, 11.0, Color(0.6, 0.95, 1.0, 0.8))
		for i in N.drones:
			_halo(ci, N.posicion_dron(i), 9.0, Color(0.4, 1.0, 0.6, 0.45))
		_orbes(j, ci)
	# proyectiles del jugador: estela + halo + núcleo blanco + punta brillante
	for b in j.balas:
		var ang: float = b.vel.angle()
		var dir := Vector2.from_angle(ang)
		match b.tipo:
			"misil":
				_proy(ci, "estela", b.pos - dir * 16.0, ang, 26.0, 7.0, Color(1, 0.5, 0.2, 0.7))
				_halo(ci, b.pos - dir * 7.0, 9.0 + sin(t * 50.0) * 1.5, Color(1, 0.6, 0.25, 0.9))
				_halo(ci, b.pos - dir * 7.0, 4.0, Color(1, 1, 0.8, 0.9))
			"bomba":
				var u: float = minf(1.0, b.vuelo / b.vuelo_total)
				var p: Vector2 = b.pos + Vector2(0, -sin(u * PI) * 34.0)
				_halo(ci, p, 10.0, Color(1, 0.6, 0.3, 0.35))
				# marca de impacto en el suelo
				ci.draw_arc(b.destino, b.area * (0.3 + 0.7 * u), 0, TAU, 32, Color(1, 0.55, 0.3, 0.25 + 0.35 * u), 1.5, true)
			"dron":
				_proy(ci, "estela", b.pos - dir * 9.0, ang, 18.0, 5.0, Color(b.color, 0.55))
				_proy(ci, "halo", b.pos, ang, 18.0, 9.0, Color(b.color, 0.85))
				_proy(ci, "nucleo", b.pos, ang, 11.0, 3.0, Color(0.92, 1.0, 0.94))
			_:
				var grande := 1.35 if b.critico else 1.0
				var recorrido: float = minf(b.pos.distance_to(b.origen), 46.0 * grande)
				_proy(ci, "estela", b.pos - dir * recorrido * 0.5, ang, recorrido, 9.0 * grande, Color(b.color, 0.5))
				_proy(ci, "halo", b.pos, ang, 30.0 * grande, 14.0 * grande, Color(b.color, 0.95))
				_proy(ci, "nucleo", b.pos, ang, 20.0 * grande, 4.0 * grande, b.color.lerp(Color.WHITE, 0.55))
				_proy(ci, "nucleo", b.pos + dir * 2.0, ang, 12.0 * grande, 2.5 * grande, Color.WHITE)
				_halo(ci, b.pos + dir * 8.0 * grande, 5.0 * grande, Color(1, 1, 1, 0.55 + 0.25 * sin(t * 60.0 + b.origen.x)))
	# proyectiles enemigos: solo el resplandor (el cuerpo se dibuja en la capa base)
	for b in j.balas_enemigas:
		_halo(ci, b.pos, b.radio * 3.2, Color(b.color, 0.5))
		if b.guiada > 0.0:
			var d: Vector2 = b.vel.normalized()
			_proy(ci, "estela", b.pos - d * 10.0, d.angle(), 20.0, 6.0, Color(1, 0.6, 0.3, 0.6))
	j.ef.dibujar_brillo(ci)

static func _brillo_jefe(j, ci: CanvasItem, e: Tipos.Jefe) -> void:
	var t: float = j.reloj
	if e.estado == "salto":
		# brillo creciente donde va a reaparecer (sin líneas)
		var u := clampf(e.saltando / 0.8, 0.0, 1.0)
		_halo(ci, e.salto_destino, 20.0 + u * 70.0, Color(e.color, 0.15 + u * 0.35))
		ci.draw_arc(e.salto_destino, 70.0 * (1.0 - u) + 20.0, 0, TAU, 40, Color(e.color, u), 2.0, true)
	if e.visibilidad < 0.5:
		return
	var pulso := 0.5 + 0.5 * sin(t * 3.0)
	var col := Color(1, 0.3, 0.4) if e.fase_jefe == 2 else Color(1, 0.55, 0.35)
	_halo(ci, IAJefe.boca(e, e.def.nucleo), 26.0 + pulso * 6.0, Color(col, 0.35 + 0.2 * pulso))
	if e.estado == "carga":
		var u = 1.0 - e.carga_t / max(0.01, e.carga_total)
		for o in IAJefe.bocas_patron(e):
			var p := IAJefe.boca(e, o)
			_halo(ci, p, 6.0 + u * 16.0, Color(1, 0.85, 0.6, 0.35 + u * 0.55))
		_halo(ci, e.pos, 60.0 + u * 30.0, Color(col, 0.08 + u * 0.12))

## Escudo de plasma: burbuja hexagonal que gira, celdas que titilan, una placa
## brillante por carga y una onda que se propaga desde el punto del impacto.
static func _escudo_plasma(j, ci: CanvasItem) -> void:
	var N: Nave = j.N
	var t: float = j.reloj
	var onda: float = j.escudo_onda
	if N.escudo <= 0 and onda <= 0.0:
		# recargando: un arco tenue muestra el progreso de la primera carga
		if N.escudo_max > 0:
			ci.draw_arc(N.pos, 27.0, -PI / 2, -PI / 2 + TAU * N.escudo_t / N.escudo_recarga, 32, Color(0.45, 0.8, 1.0, 0.3), 1.0, true)
		return
	var r := 28.0 + sin(t * 4.0) * 0.8 + onda * 4.0
	var col := Color(0.42, 0.8, 1.0)
	var debil := N.escudo == 1 and N.escudo_max > 1
	var parpadeo := 0.6 + 0.4 * sin(t * 25.0) if debil else 1.0
	# relleno de plasma
	_halo(ci, N.pos, r + 10.0, Color(col, 0.16 * parpadeo + onda * 0.25))
	# panal hexagonal girando (dos capas en sentidos opuestos)
	for capa in 2:
		var giro := t * (0.6 if capa == 0 else -0.4)
		var rr := r if capa == 0 else r - 4.0
		var pts := PackedVector2Array()
		for k in 7:
			pts.append(N.pos + Vector2.from_angle(giro + k * TAU / 6.0) * rr)
		ci.draw_polyline(pts, Color(col, (0.5 if capa == 0 else 0.22) * parpadeo), 1.4 if capa == 0 else 1.0, true)
	# celdas que titilan en los vértices
	for k in 6:
		var a := t * 0.6 + k * TAU / 6.0
		var brillo := 0.3 + 0.7 * maxf(0.0, sin(t * 3.0 + k * 1.7))
		_halo(ci, N.pos + Vector2.from_angle(a) * r, 4.0, Color(0.7, 0.95, 1.0, brillo * 0.6 * parpadeo))
	# placas de carga
	for k in N.escudo:
		var a := -t * 1.1 + k * TAU / maxi(1, N.escudo)
		ci.draw_arc(N.pos, r + 2.0, a - 0.32, a + 0.32, 10, Color(0.8, 0.97, 1.0, 0.95 * parpadeo), 3.0, true)
		_halo(ci, N.pos + Vector2.from_angle(a) * (r + 2.0), 6.0, Color(col, 0.5))
	# onda de impacto
	if onda > 0.0:
		var a0: float = j.escudo_onda_dir.angle()
		var abertura := (1.0 - onda) * PI + 0.3
		ci.draw_arc(N.pos, r + 1.0, a0 - abertura, a0 + abertura, 32, Color(1, 1, 1, onda), 2.5 + onda * 2.0, true)
		_halo(ci, N.pos + j.escudo_onda_dir * r, 14.0 * onda + 4.0, Color(0.8, 0.95, 1.0, onda))

## Orbes del Satélite de defensa: bolas de plasma con estela curva sobre su órbita.
static func _orbes(j, ci: CanvasItem) -> void:
	var N: Nave = j.N
	if N.orbitas <= 0:
		return
	var t: float = j.reloj
	var radio := Nave.stat_orbita_radio(N.orbitas)
	var tam := Nave.stat_orbita_tam(N.orbitas)
	var col := Color(0.8, 0.45, 1.0)
	ci.draw_arc(N.pos, radio, 0, TAU, 48, Color(col, 0.12), 1.0, true)
	var vel_ang := 2.4 + 0.3 * N.orbitas
	for i in N.orbitas:
		var a: float = t * vel_ang + i * TAU / N.orbitas
		ci.draw_arc(N.pos, radio, a - 0.8, a, 12, Color(col, 0.35), tam * 0.9, true)
		ci.draw_arc(N.pos, radio, a - 0.35, a, 8, Color(1, 0.8, 1.0, 0.5), tam * 0.5, true)
		var p := N.posicion_orbita(i)
		_halo(ci, p, tam * 3.2 + sin(t * 12.0 + i) * 1.5, Color(col, 0.6))
		_halo(ci, p, tam * 1.3, Color(1, 0.92, 1.0, 0.9))
