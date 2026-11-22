class_name IAJefe
extends RefCounted
## Comportamiento de los jefes.
## Cada jefe tiene un tipo de movimiento acorde a su dificultad (ver Datos.JEFES):
##   barrido (CENTINELA) · ocho (MECÁNICO) · orbita (COLMENA) · acecho (OVERLORD) · salto (VACÍO)
## Todos se mueven con un resorte amortiguado (aceleran y frenan suave), se inclinan
## según su velocidad y flotan.
## Avisos: sin líneas. Antes de atacar el jefe frena, tiembla, brilla y las bocas
## de fuego absorben partículas; la embestida deja imágenes residuales y el salto
## marca con un brillo el punto donde va a reaparecer.

const TIEMPO_AVISO := {
	"anillo": 0.8, "rafaga": 0.85, "cruz": 0.75, "nova": 1.0, "espiral": 0.9,
	"abanico": 0.8, "misiles": 0.85, "embestida": 1.0, "barrera": 0.9,
	"lluvia": 0.8, "invocar": 0.9, "salto": 0.5,
}
const NOMBRE_PATRON := {
	"anillo": "ANILLO", "rafaga": "RÁFAGA", "cruz": "FUEGO CRUZADO", "nova": "NOVA",
	"espiral": "ESPIRAL", "abanico": "ABANICO", "misiles": "MISILES", "embestida": "EMBESTIDA",
	"barrera": "BARRERA", "lluvia": "LLUVIA ÁCIDA", "invocar": "¡ENJAMBRE!", "salto": "",
}

static func definicion(indice: int) -> Dictionary:
	return Datos.JEFES[(indice - 1) % Datos.JEFES.size()]

static func crear(j, indice: int, vida: float) -> Tipos.Jefe:
	var def := definicion(indice)
	var e := Tipos.Jefe.new()
	e.es_jefe = true
	e.tipo = "boss"
	e.def = def
	e.vuelta = int((indice - 1) / float(Datos.JEFES.size()))
	e.nombre = def.nombre if e.vuelta == 0 else "%s Ω%d" % [def.nombre, e.vuelta + 1]
	e.indice = indice
	e.textura = def.textura
	e.escala = def.escala
	e.radio = def.radio
	e.color = def.color
	e.vida = vida
	e.vida_max = vida
	e.nivel = 99 + indice
	e.masa = 999.0
	var ar: Dictionary = j.arena
	e.ancla = Vector2(ar.centro.x, ar.rect.position.y + ar.rect.size.y * 0.27)
	e.pos = Vector2(ar.centro.x, ar.rect.position.y - 150)
	e.desde = e.pos
	e.hasta = e.ancla
	e.salto_destino = e.ancla
	e.mov_t = 0.0
	e.mov_dur = 2.2
	e.estado = "entrada"
	e.cuenta = 1.0
	e.fase = -PI / 2
	return e

## Cada jefe es el doble de exigente que el anterior (ver Datos.ETAPA_*):
## más balas por ataque, menos pausa entre ataques y más vida.
static func etapa(e: Tipos.Jefe) -> int:
	return e.indice - 1

static func agresividad(e: Tipos.Jefe) -> float:
	return minf(2.6, pow(Datos.ETAPA_JEFE_RITMO, etapa(e)))

## "densidad" de cada jefe compensa que unos disparan más balas que otros por naturaleza.
static func densidad(e: Tipos.Jefe) -> float:
	return minf(8.0, pow(Datos.ETAPA_JEFE_DENSIDAD, etapa(e)) * float(e.def.get("densidad", 1.0)))

static func _n(e: Tipos.Jefe, n: int) -> int:
	return roundi(n * densidad(e))

static func boca(e: Tipos.Jefe, offset: Vector2) -> Vector2:
	return e.pos + (offset * e.escala).rotated(e.inclinacion)

static func _suave(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)

static func vel_bala(j, e: Tipos.Jefe) -> float:
	return j.vel_bala_enemiga() * (1.02 if e.fase_jefe == 2 else 0.88) * float(e.def.bala_mult) * minf(1.45, pow(1.07, etapa(e)))

static func actualizar(j, e: Tipos.Jefe, dt: float) -> void:
	e.t += dt
	e.destello = maxf(0.0, e.destello - dt)
	for s in e.estelas:
		s.vida -= dt
	e.estelas = e.estelas.filter(func(s): return s.vida > 0.0)
	_danos_visibles(j, e, dt)
	# cambio de fase
	if e.fase_jefe == 1 and e.vida < e.vida_max * Datos.JEFE_FASE2_UMBRAL:
		e.fase_jefe = 2
		j.cambio_fase_jefe(e)
		e.estado = "patrulla"
		e.visibilidad = 1.0
		e.cuenta = 1.3
		e.carga_t = 0.0
	match e.estado:
		"entrada":
			e.mov_t += dt
			var u: float = minf(1.0, e.mov_t / e.mov_dur)
			e.pos = e.desde.lerp(e.hasta, 1.0 - pow(1.0 - u, 3.0))
			if u >= 1.0:
				e.estado = "patrulla"
				e.asentado = true
				e.vel = Vector2.ZERO
				j.anuncio(e.nombre, "PELIGRO %s · LEE SUS AVISOS" % "★".repeat(int(e.def.dificultad)), 2.0)
		"patrulla":
			_patrullar(j, e, dt, 1.0)
			if not j.N.muerta:
				e.cuenta -= dt
			if e.rafagas > 0:
				e.rafaga_t -= dt
				if e.rafaga_t <= 0.0:
					_tanda(j, e)
			elif e.cuenta <= 0.0:
				_iniciar_aviso(j, e)
		"carga":
			_patrullar(j, e, dt, 0.25)
			e.carga_t -= dt
			_efecto_carga(j, e, dt)
			# los ataques dirigidos fijan el blanco 0.25 s antes de disparar (justo y esquivable)
			if e.carga_t > 0.25:
				e.angulo_fijo = (j.N.pos - boca(e, e.def.nucleo)).angle()
				e.objetivo = j.N.pos
			if e.carga_t <= 0.0:
				_disparar(j, e)
		"salto":
			_actualizar_salto(j, e, dt)
		"embestida":
			e.mov_t += dt
			var u: float = minf(1.0, e.mov_t / e.mov_dur)
			var k := u * u * u if u < 0.5 else 1.0 - pow(-2.0 * u + 2.0, 3.0) / 2.0
			var antes := e.pos
			e.pos = e.desde.lerp(e.hasta, k)
			e.vel = (e.pos - antes) / maxf(dt, 0.0001)
			e.inclinacion = lerpf(e.inclinacion, clampf(e.vel.x * 0.0009, -0.35, 0.35), minf(1.0, dt * 10.0))
			if int(e.t * 60.0) % 2 == 0:
				e.estelas.append({"pos": e.pos, "rot": e.inclinacion, "vida": 0.3})
			if u >= 1.0:
				_impacto_embestida(j, e)
		"regreso":
			e.mov_t += dt
			var u: float = minf(1.0, e.mov_t / e.mov_dur)
			e.pos = e.desde.lerp(e.hasta, _suave(u))
			e.inclinacion = lerpf(e.inclinacion, 0.0, minf(1.0, dt * 4.0))
			if u >= 1.0:
				e.estado = "patrulla"
				e.vel = Vector2.ZERO
				e.cuenta = _pausa(e)

static func _pausa(e: Tipos.Jefe) -> float:
	return (0.9 if e.fase_jefe == 2 else 1.3) * float(e.def.pausa_mult) / agresividad(e)

## Con la vida baja el casco echa humo y suelta pequeñas explosiones.
static func _danos_visibles(j, e: Tipos.Jefe, dt: float) -> void:
	var frac := e.vida / e.vida_max
	if frac > 0.7 or e.visibilidad < 0.5:
		return
	e.humo_t -= dt
	if e.humo_t <= 0.0:
		e.humo_t = lerpf(0.12, 0.6, frac)
		var tam := Datos.tex(e.textura).get_size() * e.escala * 0.4
		var p := e.pos + Vector2(randf_range(-tam.x, tam.x), randf_range(-tam.y, tam.y))
		j.ef.humo(p, 6.0, 0.9)
		if randf() < 0.45 - frac * 0.4:
			j.ef.explosion(p, 9.0, e.color)
			Audio.sfx("explosion", -10.0)

## Movimiento según el tipo de jefe. "intensidad" baja mientras carga un ataque.
static func _patrullar(j, e: Tipos.Jefe, dt: float, intensidad: float) -> void:
	var ar: Dictionary = j.arena
	var f2 := e.fase_jefe == 2
	var vm: float = float(e.def.vel_mov) * agresividad(e) * (1.25 if f2 else 1.0)
	var c: Vector2 = ar.centro
	var ancho: float = ar.rect.size.x
	var obj := e.ancla
	var k := 6.0
	var amort := 4.6
	match String(e.def.movimiento):
		"barrido":
			# vaivén lento de lado a lado: fácil de leer
			obj = Vector2(c.x + sin(e.t * 0.35 * vm) * ancho * 0.3, e.ancla.y + sin(e.t * 0.7) * 10.0)
			k = 4.0
			amort = 4.0
		"ocho":
			var w := 0.45 * vm
			obj = Vector2(c.x + sin(e.t * w) * ancho * 0.28, e.ancla.y + sin(e.t * w * 2.0) * 26.0)
			obj.x = lerpf(obj.x, j.N.pos.x, 0.18)
		"orbita":
			# rodea la mitad alta de la arena y cambia de sentido de vez en cuando
			e.fase += dt * 0.55 * vm * e.sentido_orbita
			if randf() < dt * 0.12:
				e.sentido_orbita *= -1.0
			obj = Vector2(c.x + cos(e.fase) * ancho * 0.33, e.ancla.y + 30.0 + sin(e.fase) * 48.0)
			k = 7.0
		"acecho":
			# persigue la posición horizontal del jugador con decisión
			obj = Vector2(lerpf(c.x + sin(e.t * 0.5) * ancho * 0.12, j.N.pos.x, 0.65), e.ancla.y + sin(e.t * 1.1) * 20.0)
			k = 9.0
			amort = 5.2
		"salto":
			# flota casi quieto donde apareció; su peligro está en reaparecer
			obj = e.salto_destino + Vector2(cos(e.t * 1.3), sin(e.t * 1.7)) * 14.0
			k = 5.0
	if e.estado == "carga" and e.patron == "embestida":
		obj = Vector2(e.pos.x, e.ancla.y - 26.0)   # toma impulso hacia atrás
	k *= intensidad * vm
	e.vel += ((obj - e.pos) * k - e.vel * amort) * dt
	e.pos += e.vel * dt
	var limite: Rect2 = ar.rect.grow(-e.radio * 0.6)
	e.pos = e.pos.clamp(limite.position, limite.end)
	e.inclinacion = lerpf(e.inclinacion, clampf(e.vel.x * 0.0016, -0.2, 0.2), minf(1.0, dt * 6.0))

static func _iniciar_aviso(j, e: Tipos.Jefe) -> void:
	var lista: Array = e.def.patrones_f2 if e.fase_jefe == 2 else e.def.patrones_f1
	e.patron_i = (e.patron_i + 1) % lista.size()
	e.patron = lista[e.patron_i]
	if e.patron == "invocar" and j.esbirros_vivos() >= 8:
		e.patron = "anillo"
	e.carga_total = TIEMPO_AVISO.get(e.patron, 0.85) * (0.85 if e.fase_jefe == 2 else 1.0) / minf(1.6, agresividad(e))
	e.carga_t = e.carga_total
	e.estado = "carga"
	var nombre: String = NOMBRE_PATRON.get(e.patron, "")
	if nombre != "":
		j.ef.comic(e.pos + Vector2(0, e.radio * 0.6 + 22), nombre, Color("ffe29a"), 8, 0.9)

## Las bocas que usará el patrón absorben chispas y se encienden.
static func _efecto_carga(j, e: Tipos.Jefe, dt: float) -> void:
	if randf() > dt * 60.0 * 0.6:
		return
	for o in bocas_patron(e):
		var p := boca(e, o)
		var a := randf() * TAU
		var r := randf_range(26, 44)
		var desde := p + Vector2.from_angle(a) * r
		j.ef._particula(desde, (p - desde) / 0.22, 0.22, Color(1.0, 0.55, 0.45) if e.fase_jefe == 2 else Color(1.0, 0.86, 0.5), 1.6, Efectos.CHISPA, 1.0)

static func bocas_patron(e: Tipos.Jefe) -> Array:
	match e.patron:
		"rafaga", "misiles": return e.def.canones
		"cruz", "abanico", "lluvia": return e.def.alas
		"embestida": return [e.def.nucleo] + e.def.canones
		"barrera": return e.def.canones + e.def.alas
	return [e.def.nucleo]

static func _disparar(j, e: Tipos.Jefe) -> void:
	e.estado = "patrulla"
	var f2 := e.fase_jefe == 2
	e.cuenta = _pausa(e) * 0.85 + randf_range(0.0, 0.3)
	match e.patron:
		"anillo": e.rafagas = 3
		"rafaga": e.rafagas = 3 if f2 else 2
		"cruz": e.rafagas = 4 if f2 else 3
		"nova": e.rafagas = 2 if f2 else 1
		"espiral": e.rafagas = 26 if f2 else 20
		"abanico": e.rafagas = 6 if f2 else 5
		"misiles": e.rafagas = 2 if f2 else 1
		"barrera": e.rafagas = 2 if f2 else 1
		"lluvia": e.rafagas = 9 if f2 else 7
		"invocar":
			j.invocar_esbirros(e, _n(e, 5 if f2 else 3))
			j.ef.anillo(e.pos, 90, e.color, 0.5, 4)
			Audio.sfx("elite")
			return
		"salto":
			_iniciar_salto(j, e)
			return
		"embestida":
			e.estado = "embestida"
			e.desde = e.pos
			var ar: Dictionary = j.arena
			var limite: Rect2 = ar.rect.grow(-e.radio * 0.5)
			e.hasta = (e.objetivo + (e.objetivo - e.pos).normalized() * 30.0).clamp(limite.position, limite.end)
			e.mov_t = 0.0
			e.mov_dur = (0.42 if f2 else 0.52) / agresividad(e)
			j.ef.comic(e.pos + Vector2(0, e.radio * 0.6 + 22), "¡VRUUM!", Color("ff7892"), 12, 0.5)
			Audio.sfx("dash", 2.0)
			return
	e.rafaga_t = 0.0
	_tanda(j, e)

# ------------------------------------------------------------------ salto (VACÍO)
static func _iniciar_salto(j, e: Tipos.Jefe) -> void:
	var ar: Dictionary = j.arena
	var zona: Rect2 = ar.rect.grow(-e.radio * 1.1)
	zona.size.y *= 0.55
	var mejor := e.pos
	for i in 12:
		var p := Vector2(randf_range(zona.position.x, zona.end.x), randf_range(zona.position.y, zona.end.y))
		if p.distance_to(j.N.pos) > 170.0 and p.distance_to(e.pos) > 120.0:
			mejor = p
			break
	e.salto_destino = mejor
	e.estado = "salto"
	e.saltando = 0.0
	j.ef.anillo(e.pos, 80, e.color, 0.4, 3)
	Audio.sfx("dash", -2.0)

static func _actualizar_salto(j, e: Tipos.Jefe, dt: float) -> void:
	e.saltando += dt
	var salida := 0.35
	var espera := 0.45 / agresividad(e)
	var entrada := 0.3
	if e.saltando < salida:
		e.visibilidad = 1.0 - e.saltando / salida
	elif e.saltando < salida + espera:
		e.visibilidad = 0.0
		e.pos = e.salto_destino
		e.vel = Vector2.ZERO
		if randf() < dt * 60.0 * 0.5:
			var a := randf() * TAU
			var desde := e.salto_destino + Vector2.from_angle(a) * 60.0
			j.ef._particula(desde, (e.salto_destino - desde) / 0.25, 0.25, e.color, 1.8, Efectos.CHISPA, 1.0)
	elif e.saltando < salida + espera + entrada:
		e.visibilidad = (e.saltando - salida - espera) / entrada
	else:
		e.visibilidad = 1.0
		e.estado = "patrulla"
		e.cuenta = _pausa(e) * 0.6
		# reaparece con un estallido de balas
		var n := _n(e, 18 if e.fase_jefe == 2 else 12)
		for k in n:
			j.bala_enemiga(e.pos, k * TAU / n + e.t, vel_bala(j, e) * 0.55, e.color, 4.6)
		j.ef.anillo(e.pos, 120, e.color, 0.5, 5)
		j.ef.destello(e.pos, 70, e.color, 0.25)
		j.sacudir(7)
		Audio.sfx("nova", -3.0)

## Una tanda de un patrón de varias tandas.
static func _tanda(j, e: Tipos.Jefe) -> void:
	var f2 := e.fase_jefe == 2
	var sp := vel_bala(j, e)
	var nuc := boca(e, e.def.nucleo)
	e.rafagas -= 1
	match e.patron:
		"anillo":
			var n := _n(e, 18 if f2 else 14)
			var hueco := 0.3 if f2 else 0.42
			e.giro += 0.22
			for k in n:
				var a := e.giro + k * TAU / n
				if absf(angle_difference(a, e.angulo_fijo)) < hueco:
					continue
				j.bala_enemiga(nuc, a, sp * 0.62, Color("ff627b"), 4.6)
			e.rafaga_t = 0.3
		"rafaga":
			var n := _n(e, 7 if f2 else 5)
			for c in e.def.canones:
				var p := boca(e, c)
				var a := (e.objetivo - p).angle()
				for k in n:
					j.bala_enemiga(p, a + (k - (n - 1) / 2.0) * (0.12 if f2 else 0.15), sp * 1.05, Color("ffe066"), 4.2)
				j.ef.destello(p, 14, Color(1, 0.8, 0.4), 0.1)
			e.rafaga_t = 0.24
		"cruz":
			for i in 2:
				var p := boca(e, e.def.alas[i])
				var lado := -1.0 if i == 0 else 1.0
				var a = (j.N.pos - p).angle() + lado * (0.24 if f2 else 0.31)
				var m := _n(e, 3)
				for k in m:
					j.bala_enemiga(p, a + (k - (m - 1) / 2.0) * 0.075, sp * 0.9, Color("ff9a72") if i == 0 else Color("9ff0ff"), 4.2)
				j.ef.destello(p, 12, Color(1, 0.7, 0.5), 0.08)
			e.rafaga_t = 0.2
		"nova":
			var n := _n(e, 26 if f2 else 22)
			var hueco := 0.38 if f2 else 0.5
			e.giro += 0.13
			for k in n:
				var a := e.giro + k * TAU / n
				if absf(angle_difference(a, e.angulo_fijo)) < hueco:
					continue
				j.bala_enemiga(nuc, a, sp * 0.55, Color("c86bff"), 5.0)
			j.ef.anillo(nuc, 60, Color("c86bff"), 0.4, 3)
			e.rafaga_t = 0.45
		"espiral":
			e.giro += 0.33 if f2 else 0.28
			var brazos := mini(6, roundi((3 if f2 else 2) * densidad(e)))
			for brazo in brazos:
				var a: float = e.giro + brazo * TAU / brazos
				j.bala_enemiga(nuc, a, sp * 0.6, e.color.lerp(Color("ff6fb0"), 0.5), 4.0)
			e.rafaga_t = 0.075
		"abanico":
			var paso := 1.0 - float(e.rafagas) / (6.0 if f2 else 5.0)
			for i in 2:
				var p := boca(e, e.def.alas[i])
				var base := PI / 2 + (0.9 - paso * 1.8) * (1.0 if i == 0 else -1.0)
				var m := _n(e, 5)
				for k in m:
					j.bala_enemiga(p, base + (k - (m - 1) / 2.0) * 0.16 * 5.0 / m, sp * 0.8, Color("ffb35c"), 4.0)
			e.rafaga_t = 0.22
		"misiles":
			for c in e.def.canones:
				var p := boca(e, c)
				for k in _n(e, 2):
					var b = j.bala_enemiga(p, -PI / 2 + randf_range(-0.9, 0.9), 135.0, Color("ff8a3d"), 5.0)
					b.guiada = 1.7 if f2 else 1.4
					b.vida = 4.6
				j.ef.destello(p, 16, Color(1, 0.6, 0.3), 0.12)
			e.rafaga_t = 0.5
		"barrera":
			# muro de balas que baja por toda la arena con un hueco para pasar
			var ar: Dictionary = j.arena
			var x0: float = ar.rect.position.x + 14.0
			var x1: float = ar.rect.end.x - 14.0
			var hueco_x := clampf(j.N.pos.x + randf_range(-90, 90), x0 + 50, x1 - 50)
			var ancho_hueco := 62.0 if f2 else 78.0
			var x := x0
			while x <= x1:
				if absf(x - hueco_x) > ancho_hueco * 0.5:
					j.bala_enemiga(Vector2(x, e.pos.y + 20.0), PI / 2, sp * 0.48, e.color.lerp(Color.WHITE, 0.2), 4.2)
				x += maxf(15.0, 24.0 / densidad(e))
			e.rafaga_t = 0.9
		"lluvia":
			for c in e.def.alas:
				var p := boca(e, c)
				for k in _n(e, 2 if f2 else 1):
					var b = j.bala_enemiga(p, PI / 2 + randf_range(-0.55, 0.55), sp * randf_range(0.5, 0.75), Color("9dff6a"), 4.4)
					b.vida = 6.0
			j.bala_enemiga(nuc, (j.N.pos - nuc).angle(), sp * 0.8, Color("9dff6a"), 5.0)
			e.rafaga_t = 0.18
	Audio.sfx("jefe_disparo")

static func _impacto_embestida(j, e: Tipos.Jefe) -> void:
	var f2 := e.fase_jefe == 2
	j.ef.explosion(e.pos + Vector2(0, e.radio * 0.4), 28.0, Color("ff7892"))
	j.ef.anillo(e.pos, 110, Color("ff7892"), 0.5, 5)
	j.ef.chispas(e.pos, 30, Color("ffb0c0"), 260, 0.45)
	j.ef.comic(e.pos + Vector2(0, -30), "¡CRASH!", Color("ff7892"), 16, 0.7)
	j.sacudir(14.0)
	Audio.sfx("bomba", -4.0)
	var n := _n(e, 12 if f2 else 8)
	for k in n:
		j.bala_enemiga(e.pos, k * TAU / n + e.t, vel_bala(j, e) * 0.55, Color("ff7892"), 4.4)
	e.estado = "regreso"
	e.desde = e.pos
	e.hasta = Vector2(clampf(e.pos.x, j.arena.rect.position.x + 120, j.arena.rect.end.x - 120), e.ancla.y)
	e.mov_t = 0.0
	e.mov_dur = 0.8
