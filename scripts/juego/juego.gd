extends Node2D
## Partida de Crazy Space's: oleadas, dificultad, colisiones, recompensas,
## potenciadores y jefes. Las entidades son objetos ligeros (Tipos.*) y se
## dibujan desde las capas de Mundo (mundo.gd).

signal estado_cambiado(nuevo: String)

@onready var camara: Camera2D = $Camara
@onready var capa_base: Node2D = $Mundo/Base
@onready var capa_brillo: Node2D = $Mundo/Brillo
@onready var capa_textos: Node2D = $Mundo/Textos
@onready var fondo: Node2D = $CapaFondo/Fondo
@onready var hud: Control = $HUD/Panel
@onready var tactil: Control = $Tactil/Controles
@onready var pantallas: Control = $Pantallas/Raiz

var estado := "jugando"       ## jugando | mejora | pausa | fin
var N: Nave
var ef := Efectos.new()

var enemigos: Array = []
var balas: Array = []
var balas_enemigas: Array = []
var recogibles: Array = []
var potenciadores: Array = []
var asteroides: Array = []

var tiempo := 0.0
var reloj := 0.0               ## tiempo visual (no se congela con el hitstop)
var amenaza := 1.0
var puntaje := 0
var bajas := 0
var chatarra := 0
var xp := 0.0
var nivel := 1
var xp_necesaria := Datos.XP_INICIAL
var mejoras_pendientes := 0
var mejoras_tomadas := {}
var costo_reparar := Datos.REPARAR_COSTO_INICIAL
var costo_reroll := Datos.REROLL_COSTO_INICIAL

var iman_t := 0.0              ## potenciador IMÁN activo
var jefe: Tipos.Jefe = null
var jefes_derrotados := 0
var arena := {}                ## {centro, rect, sello}
var singularidad := 0.0        ## absorción de la oleada al entrar el jefe
var prox_jefe := Datos.PRIMER_JEFE_SEG
var espera_jefe_hasta := Datos.PRIMER_JEFE_SEG + Datos.JEFE_ESPERA_MAX_SEG
var recompensa_jefe := false

var _t_oleada := 0.45
var _t_pot := Datos.POT_PRIMERO_SEG
var _bonus_minuto := 60.0
var _t_puntos := 0.0
var _oleada_critica := false
var sacudida := 0.0              ## "trauma" de cámara 0..1 (se eleva al cuadrado)
var _ruido := FastNoiseLite.new()
var _t_ruido := 0.0
var escudo_onda := 0.0          ## onda en la burbuja de escudo al bloquear un golpe
var escudo_onda_dir := Vector2.UP
var _cadena: Array = []          ## explosiones encadenadas pendientes (Núcleo inestable)
var hitstop := 0.0
## contadores para medir la dificultad en las pruebas
var balas_disparadas := 0
var enemigos_generados := 0
var vida_generada := 0.0
var _anuncio_etapa_t := 0.0   ## cuenta atrás para anunciar la etapa nueva tras el jefe
var anuncio_actual := {}        ## {a, b, t, max}
var _tex_asteroides: Array = []
var _muerte_t := 0.0
var _explosiones_jefe := []     ## secuencia de explosiones al morir el jefe

func _ready() -> void:
	randomize()
	_ruido.seed = randi()
	_ruido.frequency = 0.12
	camara.zoom = Vector2(Datos.ZOOM_CAMARA, Datos.ZOOM_CAMARA)
	for i in 8:
		_tex_asteroides.append(Generador.asteroide(randi_range(8, 15), randi(), i % 4 == 3, i % 3 == 0))
	_registrar_accion_bomba()
	if "--tactil" in OS.get_cmdline_user_args():
		Ajustes.forzar_tactil(true)
	nueva_partida()

static func _registrar_accion_bomba() -> void:
	if InputMap.has_action("bomba"):
		return
	InputMap.add_action("bomba")
	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_E
	InputMap.action_add_event("bomba", tecla)
	var raton := InputEventMouseButton.new()
	raton.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("bomba", raton)
	var mando := InputEventJoypadButton.new()
	mando.button_index = JOY_BUTTON_Y
	InputMap.action_add_event("bomba", mando)

func nueva_partida() -> void:
	_terminar_tutorial()
	N = Nave.new(self, Progreso.nave_equipada)
	N.pos = Vector2.ZERO
	enemigos.clear(); balas.clear(); balas_enemigas.clear(); recogibles.clear(); potenciadores.clear()
	ef.limpiar()
	_cadena.clear()
	sacudida = 0.0
	tiempo = 0.0; amenaza = 1.0; puntaje = 0; bajas = 0; chatarra = 0; xp = 0.0; nivel = 1
	xp_necesaria = Datos.XP_INICIAL; mejoras_pendientes = 0; mejoras_tomadas = {}
	costo_reparar = Datos.REPARAR_COSTO_INICIAL; costo_reroll = Datos.REROLL_COSTO_INICIAL
	iman_t = 0.0; jefe = null; jefes_derrotados = 0; arena = {}; singularidad = 0.0
	prox_jefe = Datos.PRIMER_JEFE_SEG; espera_jefe_hasta = prox_jefe + Datos.JEFE_ESPERA_MAX_SEG
	_t_oleada = 0.45; _t_pot = Datos.POT_PRIMERO_SEG; _bonus_minuto = 60.0; _oleada_critica = false
	_muerte_t = 0.0; _explosiones_jefe.clear(); recompensa_jefe = false; _anuncio_etapa_t = 0.0
	# las naves avanzadas empiezan con armas: cuentan como nivel de esa mejora
	for m in Datos.nave(N.id).get("inicio", []):
		mejoras_tomadas[m] = int(mejoras_tomadas.get(m, 0)) + 1
		N.aplicar_mejora(m)
	_sembrar_asteroides()
	Audio.sector = 0
	Audio.musica("sector")
	camara.position = N.pos
	camara.reset_smoothing()
	cambiar_estado("jugando")
	# el tutorial solo acompaña la primera partida del jugador
	_partida_tutorial = not Progreso.tutorial_visto("controles")
	_tutorial.call_deferred("controles")

# ---------------------------------------------------------------- tutorial
## Muestra una ventana del tutorial si el jugador no la ha visto. Mientras está
## abierta la partida se congela; al cerrarla vuelve al estado anterior.
var _estado_antes_tutorial := ""
var _partida_tutorial := false   ## true solo en la primera partida del jugador

func _tutorial(id: String) -> void:
	if not _partida_tutorial:
		return
	if estado == "tutorial" or pantallas.tutorial.abierto():
		return
	if estado != "jugando" and estado != "mejora":
		return
	var previo := estado
	if not pantallas.tutorial.abrir([id]):
		return
	_estado_antes_tutorial = previo
	if previo == "jugando":
		cambiar_estado("tutorial")

func _tutorial_cerrado() -> void:
	if Progreso.tutorial.size() >= Tutorial.ORDEN.size():
		_partida_tutorial = false   # saltado o completo
	if estado == "tutorial":
		cambiar_estado(_estado_antes_tutorial)
	elif estado == "mejora":
		pantallas.enfocar_mejora()

## Al terminar la primera partida el tutorial se da por hecho: no vuelve a salir solo.
func _terminar_tutorial() -> void:
	if _partida_tutorial:
		_partida_tutorial = false
		Progreso.saltar_tutorial()
		Progreso.guardar()

func _revisar_tutorial() -> void:
	if not _partida_tutorial:
		return
	if tiempo > 12.0 and not Progreso.tutorial_visto("mecanicas"):
		_tutorial("mecanicas")
	elif jefe != null and jefe.asentado and not Progreso.tutorial_visto("jefe"):
		_tutorial("jefe")

func cambiar_estado(nuevo: String) -> void:
	estado = nuevo
	Audio.pausa_musical(nuevo == "pausa" or nuevo == "mejora" or nuevo == "tutorial")
	estado_cambiado.emit(nuevo)
	pantallas.mostrar(nuevo)

# =====================================================================
# Bucle
# =====================================================================
func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0)
	reloj += delta
	if estado == "jugando":
		var dt := delta
		if hitstop > 0.0:
			hitstop -= delta
			dt = delta * 0.08
		actualizar(dt)
		if estado == "jugando":
			_revisar_tutorial()
	# cada explosión pide sacudida según su tamaño
	if ef.sacudida_pedida > 0.0:
		sacudir(minf(ef.sacudida_pedida, 30.0))
		ef.sacudida_pedida = 0.0
	_camara(delta)
	capa_base.queue_redraw()
	capa_brillo.queue_redraw()
	capa_textos.queue_redraw()
	hud.queue_redraw()

func actualizar(dt: float) -> void:
	tiempo += dt
	amenaza = 1.0 + tiempo / Datos.SEGUNDOS_POR_AMENAZA
	iman_t = max(0.0, iman_t - dt)
	_t_puntos += dt
	if _t_puntos >= 1.0:
		_t_puntos -= 1.0
		puntaje += 2
	# entrada
	var entrada := Input.get_vector("mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo")
	var arrastre := Vector2.ZERO
	if tactil.activo():
		entrada += tactil.vector_movimiento()
		arrastre = tactil.consumir_arrastre() / camara.zoom.x
	if not N.muerta:
		N.actualizar(dt, entrada, arrastre)
	# oleadas (no durante el jefe)
	if jefe == null and singularidad <= 0.0:
		_t_oleada -= dt
		if _t_oleada <= 0.0:
			_generar_grupo()
			_t_oleada = _intervalo_oleada() * randf_range(0.78, 1.16)
	_programar_jefe()
	if tiempo >= 240.0 and not _oleada_critica:
		_oleada_critica = true
		anuncio("¡OLEADA CRÍTICA!", "LA ARENA SE DESBORDA", 3.0)
		ef.comic(N.pos + Vector2(0, -100), "MAYHEM!", Color("ffe36b"), 20, 0.95)
		sacudir(7)
		Audio.sfx("alarma_jefe")
	_actualizar_enemigos(dt)
	_actualizar_singularidad(dt)
	_actualizar_asteroides(dt)
	_actualizar_balas(dt)
	_actualizar_balas_enemigas(dt)
	_actualizar_recogibles(dt)
	_actualizar_potenciadores(dt)
	_actualizar_explosiones_jefe(dt)
	if _anuncio_etapa_t > 0.0:
		_anuncio_etapa_t -= dt
		if _anuncio_etapa_t <= 0.0:
			_anunciar_etapa()

	_actualizar_cadena(dt)
	ef.actualizar(dt)
	if arena and arena.sello < 1.0:
		arena.sello = min(1.0, arena.sello + dt / 1.2)
	enemigos = enemigos.filter(func(e): return not e.muerto)
	balas = balas.filter(func(b): return not b.muerta)
	balas_enemigas = balas_enemigas.filter(func(b): return not b.muerta)
	recogibles = recogibles.filter(func(p): return not p.muerto)
	potenciadores = potenciadores.filter(func(p): return not p.muerto)
	if anuncio_actual:
		anuncio_actual.t -= dt
		if anuncio_actual.t <= 0.0:
			anuncio_actual = {}
	if int(tiempo) >= _bonus_minuto:
		_bonus_minuto += 60.0
		chatarra += 2
		puntaje += 100
		ef.comic(N.pos + Vector2(0, -70), "+ TIME!", Color("ffe36b"), 12, 0.7)
	if N.muerta:
		_muerte_t -= dt
		if _muerte_t <= 0.0:
			_fin_partida()
	elif mejoras_pendientes > 0 and jefe == null:
		mejoras_pendientes -= 1
		abrir_mejoras(false)

## Sacudida por "trauma": se suma con cada impacto, se eleva al cuadrado (los golpes
## pequeños apenas mueven, los grandes sacuden fuerte) y usa ruido suave + giro.
func _camara(delta: float) -> void:
	var obj := N.pos
	if arena:
		obj = arena.centro.lerp(N.pos, 0.18)
	camara.position = camara.position.lerp(obj, minf(1.0, delta * 7.0))
	sacudida = maxf(0.0, sacudida - delta * 1.15)
	_t_ruido += delta * 60.0
	var k := sacudida * sacudida * Ajustes.sacudida
	camara.offset = Vector2(_ruido.get_noise_2d(_t_ruido, 0.0), _ruido.get_noise_2d(0.0, _t_ruido)) * 26.0 * k
	camara.rotation = _ruido.get_noise_2d(_t_ruido, 100.0) * 0.045 * k
	escudo_onda = maxf(0.0, escudo_onda - delta * 2.2)

## v en la escala antigua (píxeles): 3 = baja normal, 12 = élite, 30 = jefe.
func sacudir(v: float) -> void:
	sacudida = minf(1.0, sacudida + v / 26.0)

func anuncio(a: String, b: String, t := 2.5) -> void:
	anuncio_actual = {"a": a, "b": b, "t": t, "max": t}

func media_vista() -> Vector2:
	return get_viewport_rect().size / (2.0 * camara.zoom.x)

## Al empezar una etapa: anuncia la raza nueva (si la hay) y la dureza.
func _anunciar_etapa() -> void:
	var nueva := ""
	for t in Datos.ENEMIGOS:
		if int(Datos.ENEMIGOS[t].etapa) == etapa():
			nueva = t
	var titulo := "ETAPA %d" % (etapa() + 1)
	if nueva != "":
		anuncio("¡NUEVA AMENAZA: %s!" % String(Datos.ENEMIGOS[nueva].nombre).to_upper(), "%s · ETAPA %d" % [Datos.DESC_RAZA.get(nueva, ""), etapa() + 1], 3.4)
	else:
		anuncio(titulo, "LAS OLEADAS SE DUPLICAN", 3.0)
	ef.comic(N.pos + Vector2(0, -90), "x%d" % roundi(pow(2.0, etapa())), Color("ff7892"), 18, 0.9)
	Audio.sfx("alarma_jefe")

# =====================================================================
# Dificultad y oleadas
# =====================================================================
## Etapa actual = jefes derrotados. Cada etapa multiplica la presión de las oleadas.
func etapa() -> int:
	return jefes_derrotados

func _mult_vida() -> float:
	var base: float = 1.0 + min(5.0, pow(max(0.0, amenaza - 1.0), 1.08) * 0.07 + min(0.24, tiempo / 180.0 * 0.24))
	return base * pow(Datos.ETAPA_VIDA, etapa())

func _mult_vel() -> float:
	return 0.97 * (1.0 + min(0.55, (amenaza - 1.0) * 0.07) + min(0.24, tiempo / 180.0 * 0.24))

func _intervalo_oleada() -> float:
	var base: float = max(0.5, 1.3 - min(0.8, (amenaza - 1.0) * 0.12 + min(0.25, tiempo / 180.0 * 0.25)))
	return maxf(0.12, base / pow(Datos.ETAPA_APARICION, etapa()))

func _prob_elite() -> float:
	return min(0.4, 0.02 + tiempo / 180.0 * 0.12 + max(0.0, amenaza - 1.0) * 0.008 + etapa() * 0.04)

func vel_bala_enemiga() -> float:
	return min(250.0, 132.0 + amenaza * 3.65)

func _elegir_tipo() -> String:
	var total := 0.0
	var tipos := []
	var pesos := {}
	for t in Datos.ENEMIGOS:
		var et: int = Datos.ENEMIGOS[t].etapa
		if et <= etapa():
			tipos.append(t)
			# la raza recién llegada sale más en su etapa de estreno
			pesos[t] = float(Datos.ENEMIGOS[t].peso) * (2.2 if et == etapa() and et > 0 else 1.0)
			total += pesos[t]
	var v := randf() * total
	for t in tipos:
		v -= pesos[t]
		if v <= 0.0:
			return t
	return "grunt"

func _posicion_aparicion() -> Vector2:
	var m := media_vista() + Vector2(40, 40)
	match randi() % 4:
		0: return N.pos + Vector2(randf_range(-m.x, m.x), -m.y)
		1: return N.pos + Vector2(m.x, randf_range(-m.y, m.y))
		2: return N.pos + Vector2(randf_range(-m.x, m.x), m.y)
	return N.pos + Vector2(-m.x, randf_range(-m.y, m.y))

func _generar_grupo() -> void:
	if enemigos.size() >= Datos.MAX_ENEMIGOS:
		return
	var tipo := _elegir_tipo()
	var n := 1
	if randf() < min(0.8, 0.2 + min(0.36, tiempo / 180.0 * 0.36) + max(0.0, amenaza - 1.0) * 0.05):
		n += 1
	if n < 3 and randf() < clampf((tiempo - 150.0) / 70.0 * 0.3, 0.0, 0.3):
		n += 1
	n = min(n, Datos.MAX_ENEMIGOS - enemigos.size())
	var elite := randf() < _prob_elite()
	for i in n:
		_generar_enemigo(tipo, elite and i == 0)

func _generar_enemigo(tipo: String, elite: bool) -> void:
	var d: Dictionary = Datos.ENEMIGOS[tipo]
	var e := Tipos.Enemigo.new()
	e.tipo = tipo
	e.pos = _posicion_aparicion()
	e.elite = elite
	var mult := 2.25 if elite else 1.0
	e.vida = d.vida * _mult_vida() * mult
	e.vida_max = e.vida
	enemigos_generados += 1
	vida_generada += e.vida
	e.rapidez = d.vel * _mult_vel() * (1.09 if elite else 1.0)
	e.xp = d.xp * (3 if elite else 1)
	e.pts = d.pts * (3 if elite else 1)
	e.nivel = ["grunt", "weaver", "gunner", "diver", "tank"].find(tipo) + 1 + (3 if elite else 0)
	# cada etapa estrena un modelo nuevo de cada raza (mezclado con los anteriores)
	var modelo := mini(etapa(), 4) if randf() < 0.7 else randi() % (mini(etapa(), 4) + 1)
	e.textura = "res://art/enemigos/%s_%d.png" % [tipo, modelo]
	e.escala = d.escala
	e.color = d.color
	e.radio = max(11.0, 84.0 * d.escala * 0.35)
	e.disparo = randf_range(0.6, 1.8)
	e.dash_cd = randf_range(1.8, 3.4)
	e.contacto = randf_range(0.15, 0.65)
	e.fase = randf() * TAU
	e.sentido = -1.0 if randf() < 0.5 else 1.0
	e.masa = {"tank": 3.0, "gunner": 1.6}.get(tipo, 1.0) * (2.0 if elite else 1.0)
	enemigos.append(e)
	if elite:
		ef.chispas(e.pos, 12, Color("ffd34d"), 95, 0.7)
		Audio.sfx("elite")

# =====================================================================
# Enemigos
# =====================================================================
func _actualizar_enemigos(dt: float) -> void:
	var lejos := media_vista().length() * 2.2
	for e in enemigos:
		if e.muerto or e.absorbido:
			continue
		e.t += dt
		e.disparo -= dt
		e.destello = max(0.0, e.destello - dt)
		e.golpe = max(0.0, e.golpe - dt)
		e.contacto = max(0.0, e.contacto - dt)
		if e.es_jefe:
			IAJefe.actualizar(self, e, dt)
		else:
			if e.pos.distance_to(N.pos) > lejos:
				e.pos = _posicion_aparicion()   # recicla rezagados por delante del jugador
			match e.tipo:
				"weaver": _ia_tejedora(e, dt)
				_: _ia_general(e, dt)
			# retroceso por impactos
			if e.empuje != Vector2.ZERO:
				e.pos += e.empuje * dt
				e.empuje *= pow(0.004, dt)
				if e.empuje.length_squared() < 4.0:
					e.empuje = Vector2.ZERO
		_contacto_jugador(e)

func _mover_hacia(e: Tipos.Enemigo, dt: float, rapidez: float) -> Dictionary:
	var dvec := N.pos - e.pos
	var d = max(dvec.length(), 0.001)
	var n = dvec / d
	var sep := Vector2.ZERO
	for o in enemigos:
		if o == e or o.muerto or o.es_jefe:
			continue
		var od = e.pos - o.pos
		var l = od.length()
		if l < 68.0 and l > 0.001:
			sep += od / l * (68.0 - l) / 68.0
	var carril: float = {"grunt": 0.54, "gunner": 0.72, "diver": 0.28, "tank": 0.12}.get(e.tipo, 0.5)
	var vaiven := sin(e.t * 1.3 + e.fase) * carril
	var v = (n + Vector2(-n.y, n.x) * vaiven + sep * 0.92).normalized()
	e.pos += v * rapidez * dt
	return {"n": n, "d": d}

func _ia_general(e: Tipos.Enemigo, dt: float) -> void:
	if e.tipo == "diver" and e.dash_t > 0.0:
		e.dash_t -= dt
		e.pos += e.vel * dt
		return
	var r := _mover_hacia(e, dt, e.rapidez)
	var n: Vector2 = r.n
	var d: float = r.d
	match e.tipo:
		"gunner":
			if d < 132.0:
				e.pos -= n * e.rapidez * 0.7 * dt
			elif d < 205.0:
				e.pos += Vector2(-n.y, n.x) * sin(e.t * 1.3) * e.rapidez * 0.55 * dt
			if e.disparo <= 0.0:
				e.disparo = randf_range(1.6, 2.2)
				var a := n.angle()
				var k := 3 if amenaza >= 6.0 else 1
				e.ataca_t = tiempo
				for i in k:
					bala_enemiga(e.pos, a + (i - (k - 1) / 2.0) * 0.18, vel_bala_enemiga(), Color("ff9a3c"), 4.0)
				ef.destello(e.pos + n * 10, 8, Color(1, 0.7, 0.35), 0.08)
		"diver":
			e.dash_cd -= dt
			if e.aviso > 0.0:
				e.aviso -= dt
				if e.aviso <= 0.0:
					e.dash_t = 0.42
					e.dash_cd = 3.4
					e.vel = (e.objetivo - e.pos).normalized() * e.rapidez * 3.5
			elif e.dash_cd <= 0.0 and d < 260.0:
				e.aviso = 0.32
				e.ataca_t = tiempo
				e.objetivo = N.pos
				e.destello = 0.3
		"tank":
			if e.disparo <= 0.0:
				e.disparo = 2.8
				var o := randf() * TAU
				var k := 12 if amenaza >= 6.0 else 9
				e.ataca_t = tiempo
				for i in k:
					bala_enemiga(e.pos, o + i * TAU / k, vel_bala_enemiga() * 0.68, Color("9b8aff"), 5.0)
				ef.anillo(e.pos, 30, Color("9b8aff"), 0.32, 3)

## La tejedora orbita a media distancia y lanza un tajo rápido al lugar marcado.
func _ia_tejedora(e: Tipos.Enemigo, dt: float) -> void:
	e.dash_cd -= dt
	if e.dash_t > 0.0:
		e.dash_t = max(0.0, e.dash_t - dt)
		e.pos += e.vel * dt
		return
	if e.aviso > 0.0:
		e.aviso -= dt
		if e.aviso <= 0.0:
			e.vel = (e.objetivo - e.pos).normalized() * e.rapidez * 2.45
			e.dash_t = 0.27
		return
	var dvec := N.pos - e.pos
	var d = max(dvec.length(), 0.001)
	var n = dvec / d
	var radial := clampf((d - 138.0) * 1.45, -128.0, 118.0)
	var v = n * radial + Vector2(-n.y, n.x) * 92.0 * e.sentido
	e.pos += v.limit_length(e.rapidez) * dt
	if e.dash_cd <= 0.0 and d < 235.0 and d > 94.0:
		e.objetivo = N.pos
		e.ataca_t = tiempo
		e.aviso = 0.44
		e.dash_cd = randf_range(3.8, 4.8)
		e.destello = 0.44

func _contacto_jugador(e: Tipos.Enemigo) -> void:
	if N.muerta or singularidad > 0.0 or e.contacto > 0.0 or not golpeable(e):
		return
	var rr := e.radio * 0.7 + 12.0 if e.es_jefe else e.radio * 0.72 + 10.0
	var dv := N.pos - e.pos
	var d := dv.length()
	if d < rr:
		e.ataca_t = tiempo
		golpear_jugador()
		e.contacto = 1.05 if e.es_jefe else 1.4
		var n = dv / max(d, 0.001)
		if not e.es_jefe:
			e.pos -= n * 34.0
			if e.golpe <= 0.0:
				e.golpe = 0.3
				danar_enemigo(e, 28.0, false, true)
		N.pos += n * (18.0 if e.es_jefe else 13.0)
		limitar_jugador()

func enemigo_mas_cercano(p: Vector2) -> Tipos.Enemigo:
	var mejor: Tipos.Enemigo = null
	var bd := INF
	for e in enemigos:
		if e.muerto or e.absorbido:
			continue
		var d = e.pos.distance_squared_to(p)
		if d < bd:
			bd = d
			mejor = e
	return mejor

func golpeable(e) -> bool:
	return not e.muerto and not e.absorbido and (not e.es_jefe or e.visibilidad > 0.4)

func enemigo_cercano_excepto(p: Vector2, excluir: Array, alcance: float) -> Tipos.Enemigo:
	var mejor: Tipos.Enemigo = null
	var bd := alcance * alcance
	for e in enemigos:
		if not golpeable(e) or excluir.has(e):
			continue
		var d = e.pos.distance_squared_to(p)
		if d < bd:
			bd = d
			mejor = e
	return mejor

## Para los drones: enemigos que te atacaron hace poco y vienen de un lado
## distinto al que apunta el cañón principal (flancos y retaguardia).
func atacante_de_flanco(p: Vector2, apunte: float, excluir: Array) -> Tipos.Enemigo:
	var mejor: Tipos.Enemigo = null
	var mejor_v := -1e9
	for e in enemigos:
		if not golpeable(e) or excluir.has(e) or e.es_jefe or tiempo - e.ataca_t > 3.5:
			continue
		var dv: Vector2 = e.pos - p
		var d := dv.length()
		if d > 360.0:
			continue
		var desvio := absf(angle_difference(dv.angle(), apunte))
		if desvio < 0.75:
			continue   # ese ya lo cubre el cañón
		var v := desvio * 120.0 - d + (80.0 if tiempo - e.ataca_t < 1.0 else 0.0)
		if v > mejor_v:
			mejor_v = v
			mejor = e
	return mejor

## Blancos distintos para una salva de misiles: jefe/élites primero, luego los más cercanos.
func blancos_prioritarios(p: Vector2, n: int) -> Array:
	var lista := enemigos.filter(func(e): return golpeable(e) and e.pos.distance_to(p) < 480.0)
	lista.sort_custom(func(a, b): return a.nivel * 1000.0 - a.pos.distance_to(p) > b.nivel * 1000.0 - b.pos.distance_to(p))
	return lista.slice(0, n)

## Punto con más enemigos alrededor (para lanzar bombas). k: el k-ésimo mejor.
func punto_mas_denso(p: Vector2, k := 0) -> Vector2:
	var cands := enemigos.filter(func(e): return golpeable(e) and e.pos.distance_to(p) < 380.0)
	if cands.is_empty():
		return p + Vector2.from_angle(N.apunte) * 140.0
	var puntuados := []
	for e in cands.slice(0, 40):
		var n := 0
		for o in cands:
			if o.pos.distance_squared_to(e.pos) < 75.0 * 75.0:
				n += 1
		puntuados.append([n + (6 if e.es_jefe else 0), e.pos])
	puntuados.sort_custom(func(a, b): return a[0] > b[0])
	return puntuados[mini(k, puntuados.size() - 1)][1]

func empujar(e, dir: Vector2, fuerza: float) -> void:
	if e.es_jefe or e.muerto:
		return
	e.empuje += dir * fuerza / e.masa
	e.empuje = e.empuje.limit_length(420.0)

func esbirros_vivos() -> int:
	return enemigos.filter(func(e): return not e.es_jefe and not e.muerto).size()

## La REINA COLMENA llama refuerzos alrededor suyo.
func invocar_esbirros(j: Tipos.Jefe, n: int) -> void:
	for i in n:
		var tipo: String = ["grunt", "weaver", "diver"][i % 3]
		_generar_enemigo(tipo, false)
		var e: Tipos.Enemigo = enemigos[-1]
		e.pos = j.pos + Vector2.from_angle(i * TAU / n + randf()) * (j.radio + 20.0)
		e.vida *= 0.7
		e.vida_max = e.vida
		ef.chispas(e.pos, 8, j.color, 90, 0.35)

## Blanco del autoapuntado: el jefe si está, si no el enemigo de mayor nivel cercano.
func objetivo_combate(p: Vector2) -> Tipos.Enemigo:
	if singularidad > 0.0:
		return null
	if jefe and not jefe.muerto and jefe.asentado and jefe.visibilidad > 0.4:
		return jefe
	var alcance := 440.0 * 440.0
	var mejor: Tipos.Enemigo = null
	var mejor_nivel := -1
	var mejor_d := INF
	for e in enemigos:
		if e.muerto or e.absorbido:
			continue
		var d = e.pos.distance_squared_to(p)
		if d > alcance:
			continue
		if e.nivel > mejor_nivel or (e.nivel == mejor_nivel and d < mejor_d):
			mejor = e
			mejor_nivel = e.nivel
			mejor_d = d
	return mejor

# =====================================================================
# Daño y recompensas
# =====================================================================
func danar_enemigo(e: Tipos.Enemigo, d: float, crit: bool, sin_cadena := false) -> void:
	if e.muerto:
		return
	e.vida -= d
	e.destello = 0.05 if e.es_jefe else 0.09
	ef.numero(e.pos + Vector2(0, -e.radio - 4), d, crit)
	if crit:
		ef.comic(e.pos + Vector2(0, -e.radio - 10), "CRIT!", Color("fff078"), 12, 0.6)
	elif not sin_cadena and randf() < 0.05:
		ef.comic(e.pos + Vector2(0, -e.radio - 6), ["ZAP!", "TAK!", "PAM!"].pick_random(), Color("8ff6ff"), 11, 0.55)
	if e.vida <= 0.0:
		matar_enemigo(e, sin_cadena)

func matar_enemigo(e: Tipos.Enemigo, sin_cadena := false) -> void:
	if e.muerto:
		return
	e.muerto = true
	bajas += 1
	puntaje += roundi(e.pts * (1.0 + maxf(0.0, amenaza - 1.0) * 0.07))
	if e.es_jefe:
		_jefe_derrotado(e)
		return
	var grande: bool = e.elite or e.tipo == "tank"
	var tam := 34.0 if e.elite else (26.0 if e.tipo == "tank" else 19.0)
	ef.explosion(e.pos, tam, e.color, grande)
	var rot: float = (N.pos - e.pos).angle() - PI / 2.0
	ef.fragmentos(e.textura, e.pos, rot, e.escala * (1.15 if e.elite else 1.0), 150.0 if grande else 110.0)
	ef.comic(e.pos + Vector2(0, -e.radio - 6), "CRASH!" if e.elite else ["PAM!", "POW!", "PUM!", "BOOM!"].pick_random(),
		Color("ffe36b") if e.elite else [Color("8ff6ff"), Color("ffbd66"), Color("e6a0ff")].pick_random(), 16 if e.elite else 13, 0.8)
	if grande:
		hitstop = maxf(hitstop, 0.035)
		Ajustes.vibrar(30)
	_soltar("xp", e.pos, e.xp)
	if e.elite:
		_soltar("chatarra", e.pos + Vector2(8, -5), 3)
	elif randf() < 0.08:
		_soltar("chatarra", e.pos, 1)
	if N.robo_vida > 0.0 and N.vida < N.vida_max and randf() < N.robo_vida:
		N.vida += 1
		ef.comic(N.pos + Vector2(0, -30), "+1 VIDA", Color("7dff8a"), 10, 0.7)
		Audio.sfx("reparar")
	# Núcleo inestable: la explosión sale un instante después y puede encadenar otras
	if N.explosivo > 0:
		_cadena.append({"t": 0.07 if not sin_cadena else 0.12, "pos": e.pos, "vida_max": e.vida_max, "eslabon": 0 if not sin_cadena else 1})
	Audio.sfx("explosion")

func _actualizar_cadena(dt: float) -> void:
	if _cadena.is_empty():
		return
	var listas := []
	for c in _cadena:
		c.t -= dt
		if c.t <= 0.0:
			listas.append(c)
	_cadena = _cadena.filter(func(c): return c.t > 0.0)
	for c in listas:
		var rad := Nave.stat_explosivo_radio(N.explosivo)
		var dano := maxf(N.dano * 0.6 * N.explosivo, float(c.vida_max) * 0.3 * N.explosivo)
		ef.explosion(c.pos, rad * 0.35, Color("ff9d42"), false)
		ef.anillo(c.pos, rad, Color("ff9d42"), 0.38, 3)
		for o in enemigos:
			if golpeable(o) and o.pos.distance_to(c.pos) < rad + o.radio:
				empujar(o, (o.pos - c.pos).normalized(), 180.0)
				# los eslabones lejanos de la cadena pierden fuerza para no vaciar la pantalla
				danar_enemigo(o, dano * pow(0.75, c.eslabon), false, c.eslabon >= 4)
		_borrar_balas(c.pos, rad)

func _soltar(tipo: String, p: Vector2, valor: int) -> void:
	var r := Tipos.Recogible.new()
	r.tipo = tipo
	r.pos = p + Vector2(randf_range(-7, 7), randf_range(-7, 7))
	r.vel = Vector2(randf_range(-60, 60), randf_range(-60, 60))
	r.valor = valor
	r.t = randf() * TAU
	recogibles.append(r)

func ganar_xp(v: float) -> void:
	xp += v * N.xp_mult
	while xp >= xp_necesaria:
		xp -= xp_necesaria
		nivel += 1
		mejoras_pendientes += 1
		xp_necesaria = Datos.xp_para_nivel(nivel)
		ef.comic(N.pos + Vector2(0, -48), "LEVEL UP!", Color("ffe36b"), 16, 0.9)
		ef.anillo(N.pos, 70, Color("ffe36b"), 0.5, 3)
		Audio.sfx("nivel")

func golpear_jugador(desde := Vector2.ZERO) -> void:
	if N.inv > 0.0 or N.muerta:
		return
	if N.escudo > 0:
		N.escudo -= 1
		N.inv = 0.9
		N.escudo_t = 0.0
		escudo_onda = 1.0
		escudo_onda_dir = (desde - N.pos).normalized() if desde != Vector2.ZERO else Vector2.UP
		var punto := N.pos + escudo_onda_dir * 27.0
		ef.comic(N.pos + Vector2(0, -27), "CLANG!", Color("8edbff"), 14, 0.7)
		ef.chispas(punto, 30, Color("7cc8ff"), 220, 0.55, escudo_onda_dir, 1.2)
		ef.destello(punto, 22, Color(0.5, 0.85, 1.0), 0.2)
		ef.anillo(N.pos, 64, Color("7cc8ff"), 0.45, 4)
		_borrar_balas(N.pos, 70.0)
		for e in enemigos:
			if golpeable(e) and e.pos.distance_to(N.pos) < 80.0:
				empujar(e, (e.pos - N.pos).normalized(), 260.0)
		sacudir(6)
		Audio.sfx("escudo_golpe")
		Ajustes.vibrar(25)
		return
	N.vida -= 1
	N.inv = 1.25
	sacudir(15)
	hitstop = 0.06
	ef.comic(N.pos + Vector2(0, -30), "OUCH!", Color("ff7189"), 15, 0.78)
	ef.chispas(N.pos, 40, Color("5ad1ff"), 240, 0.72)
	ef.anillo(N.pos, 62, Color("ff647b"), 0.42, 4)
	Audio.sfx("dano")
	Ajustes.vibrar(60)
	_borrar_balas(N.pos, 105.0)
	if N.vida <= 0:
		if N.revivir > 0:
			# FÉNIX: renace una vez
			N.revivir -= 1
			N.vida = mini(3, N.vida_max)
			N.inv = 2.5
			ef.explosion(N.pos, 40, Color("ff806d"), true)
			ef.comic(N.pos + Vector2(0, -44), "¡RENACE!", Color("ffb36b"), 18, 1.2)
			pulso_nova(260.0, N.dano * 4.0, Color("ff9d59"))
			anuncio("¡FÉNIX!", "UNA SEGUNDA OPORTUNIDAD", 1.8)
			return
		N.muerta = true
		ef.explosion(N.pos, 46, Color("5ad1ff"), true)
		ef.fragmentos(N.textura, N.pos, N.apunte + PI / 2.0, 46.0 / Datos.tex(N.textura).get_height(), 170.0)
		Audio.sfx("explosion_grande")
		_muerte_t = 1.3

func _borrar_balas(p: Vector2, r: float) -> void:
	for b in balas_enemigas:
		if not b.muerta and b.pos.distance_to(p) < r + 8.0:
			b.muerta = true
			ef.chispas(b.pos, 2, b.color, 50, 0.2)

func pulso_nova(radio: float, dano: float, color: Color) -> void:
	ef.comic(N.pos + Vector2(0, -34), "NOVA!", Color("91f5ff"), 17, 0.85)
	ef.anillo(N.pos, radio, color, 0.65, 6)
	ef.anillo(N.pos, radio * 0.72, Color("e4ffff"), 0.35, 3)
	ef.anillo(N.pos, radio * 0.9, color, 0.4, 0.0, true)
	ef.destello(N.pos, radio * 0.5, color, 0.25)
	ef.chispas(N.pos, 36, color, 230, 0.5)
	for e in enemigos:
		if golpeable(e) and e.pos.distance_to(N.pos) < radio + e.radio:
			danar_enemigo(e, dano, false, true)
			empujar(e, (e.pos - N.pos).normalized(), 280.0)
	_borrar_balas(N.pos, radio)
	sacudir(5.0 + N.nova * 1.5)
	Audio.sfx("nova")

## Bomba: vuela en arco hasta el grupo más denso y explota al llegar.
## Habilidad BOMBA. "apuntado": dirección (y fuerza 0..1 en su longitud) del
## arrastre táctil; "destino" fijo (clic derecho). Sin nada: hacia donde te mueves
## o, si estás quieto, al grupo de enemigos más denso.
const BOMBA_ALCANCE := 250.0

func arrojar_bomba(apuntado := Vector2.ZERO, destino := Vector2.INF) -> bool:
	if N.muerta or N.bombas <= 0 or N.bomba_cargas <= 0:
		return false
	var fin: Vector2
	if destino != Vector2.INF:
		fin = N.pos + (destino - N.pos).limit_length(BOMBA_ALCANCE)
	elif apuntado != Vector2.ZERO:
		fin = N.pos + apuntado.normalized() * lerpf(90.0, BOMBA_ALCANCE, clampf(apuntado.length(), 0.0, 1.0))
	else:
		fin = destino_bomba_auto()
	N.bomba_cargas -= 1
	lanzar_bomba(N.pos, fin, Nave.stat_bomba_radio(N.bombas), N.dano * Nave.stat_bomba_dano(N.bombas))
	ef.comic(N.pos + Vector2(0, -26), "¡BOMBA!", Color("ff9b4d"), 9, 0.5)
	return true

func destino_bomba_auto() -> Vector2:
	if N.pos.distance_to(N.pos_prev) > 0.6:
		return N.pos + N.ultima_dir.normalized() * 170.0
	var p := punto_mas_denso(N.pos)
	return N.pos + (p - N.pos).limit_length(BOMBA_ALCANCE)

func lanzar_bomba(desde: Vector2, destino: Vector2, radio: float, dano: float) -> void:
	var b := Tipos.Bala.new()
	b.tipo = "bomba"
	b.pos = desde
	b.origen = desde
	b.destino = destino
	b.vuelo_total = clampf(desde.distance_to(destino) / 420.0, 0.3, 0.6)
	b.area = radio
	b.dano = dano
	b.color = Color("ff9b4d")
	b.empuje = 240.0
	b.vida = 5.0
	balas.append(b)
	Audio.sfx("misil", -3.0)

func _explotar_bomba(b: Tipos.Bala) -> void:
	var c := b.destino
	ef.explosion(c, 20.0 + b.area * 0.12, Color("ff9b4d"), true)
	ef.anillo(c, b.area, Color("ffb45f"), 0.52, 5)
	for e in enemigos:
		if golpeable(e) and e.pos.distance_to(c) < b.area + e.radio:
			danar_enemigo(e, b.dano, false, true)
			empujar(e, (e.pos - c).normalized(), b.empuje)
	_borrar_balas(c, b.area)
	ef.comic(c + Vector2(0, -20), "KABOOM!", Color("ffbd69"), 16, 0.78)
	Audio.sfx("bomba")

# =====================================================================
# Balas
# =====================================================================
func agregar_bala(p: Vector2, a: float, rapidez: float, dano: float, color: Color, tipo: String) -> Tipos.Bala:
	var b := Tipos.Bala.new()
	b.pos = p
	b.origen = p
	b.vel = Vector2.from_angle(a) * rapidez
	b.critico = randf() < N.critico
	b.dano = dano * (N.crit_mult if b.critico else 1.0)
	b.color = Color("fff078") if b.critico else color
	b.tipo = tipo
	b.guiada = tipo == "misil"
	b.radio = 6.0 if b.guiada else 4.5
	b.vida = 3.8 if b.guiada else 2.6
	b.perfora = 0 if b.guiada else N.perforacion
	b.empuje = 60.0 if b.critico else 40.0
	balas.append(b)
	return b

func bala_enemiga(p: Vector2, a: float, rapidez: float, color: Color, radio := 4.0) -> Tipos.BalaEnemiga:
	balas_disparadas += 1
	var b := Tipos.BalaEnemiga.new()
	b.pos = p
	b.vel = Vector2.from_angle(a) * rapidez
	b.color = color
	b.radio = radio
	if balas_enemigas.size() < Datos.MAX_BALAS_ENEMIGAS:
		balas_enemigas.append(b)
	return b

func _actualizar_balas(dt: float) -> void:
	var lim := media_vista() * 1.4
	for b in balas:
		if b.muerta:
			continue
		b.vida -= dt
		if b.tipo == "bomba":
			b.vuelo += dt
			var u := minf(1.0, b.vuelo / b.vuelo_total)
			b.pos = b.origen.lerp(b.destino, u)
			if randf() < 0.6:
				ef.humo(b.pos, 3.0, 0.4)
			if u >= 1.0:
				b.muerta = true
				_explotar_bomba(b)
			continue
		if b.guiada:
			if b.objetivo == null or not golpeable(b.objetivo):
				b.objetivo = objetivo_combate(b.pos)
			if b.objetivo:
				var cur = b.vel.angle()
				var quiere = (b.objetivo.pos - b.pos).angle()
				var na = cur + clampf(angle_difference(cur, quiere), -5.5 * dt, 5.5 * dt)
				b.vel = Vector2.from_angle(na) * minf(560.0, b.vel.length() + 300.0 * dt)
			ef.estela(b.pos, b.vel, Color(1, 0.6, 0.25), 0.7)
			if randf() < 0.5:
				ef.humo(b.pos - b.vel.normalized() * 5.0, 2.5, 0.45)
		var desde = b.pos
		var hasta = b.pos + b.vel * dt
		b.pos = hasta
		if b.vida <= 0.0 or absf(hasta.x - N.pos.x) > lim.x or absf(hasta.y - N.pos.y) > lim.y:
			b.muerta = true
			continue
		# misiles del jefe: se pueden derribar
		for eb in balas_enemigas:
			if eb.guiada > 0.0 and not eb.muerta and Geometry2D.segment_intersects_circle(desde, hasta, eb.pos, eb.radio + b.radio) >= 0.0:
				eb.muerta = true
				ef.explosion(eb.pos, 10, Color("ff8a3d"))
				Audio.sfx("explosion", -6.0)
		var golpes := []
		for e in enemigos:
			if not golpeable(e) or b.golpeados.has(e):
				continue
			var radio: float = (e.radio * 1.15 if e.es_jefe else e.radio) + b.radio
			var t := Geometry2D.segment_intersects_circle(desde, hasta, e.pos, radio)
			if t >= 0.0 or desde.distance_to(e.pos) < radio:
				golpes.append([maxf(t, 0.0), e])
		golpes.sort_custom(func(x, y): return x[0] < y[0])
		for g in golpes:
			var e: Tipos.Enemigo = g[1]
			var punto = desde.lerp(hasta, g[0])
			b.golpeados.append(e)
			danar_enemigo(e, b.dano, b.critico)
			empujar(e, b.vel.normalized(), b.empuje)
			ef.chispas(punto, 6 if b.tipo == "laser" else 8, b.color, 140, 0.24, -b.vel, 0.8)
			ef.destello(punto, 9 if not b.critico else 16, b.color.lerp(Color.WHITE, 0.5), 0.07)
			Audio.sfx("impacto")
			if b.tipo == "misil":
				_explosion_misil(punto, b)
				b.muerta = true
				break
			if b.perfora <= 0:
				b.muerta = true
				break
			b.perfora -= 1

func _explosion_misil(p: Vector2, b: Tipos.Bala) -> void:
	ef.explosion(p, 10.0 + b.area * 0.18, Color("ff9b45"))
	for e in enemigos:
		if golpeable(e) and e.pos.distance_to(p) < b.area + e.radio:
			danar_enemigo(e, b.dano * 0.45, false, true)
			empujar(e, (e.pos - p).normalized(), b.empuje)
	_borrar_balas(p, b.area * 0.8)

func _actualizar_balas_enemigas(dt: float) -> void:
	var lim := media_vista().length() * 1.6
	for b in balas_enemigas:
		if b.muerta:
			continue
		b.vida -= dt
		if b.guiada > 0.0 and not N.muerta:
			var cur = b.vel.angle()
			var quiere = (N.pos - b.pos).angle()
			b.vel = Vector2.from_angle(cur + clampf(angle_difference(cur, quiere), -b.guiada * dt, b.guiada * dt)) * b.vel.length()
			if randf() < 0.5:
				ef.estela(b.pos, b.vel, Color(1, 0.45, 0.2), 0.6)
		b.pos += b.vel * dt
		if b.vida <= 0.0 or b.pos.distance_to(N.pos) > lim:
			b.muerta = true
			continue
		if arena and not arena.rect.grow(30).has_point(b.pos):
			b.muerta = true
			continue
		if not N.muerta and N.inv <= 0.0 and b.pos.distance_to(N.pos) < b.radio + 5.0:
			b.muerta = true
			golpear_jugador(b.pos)

# =====================================================================
# Recogibles y potenciadores
# =====================================================================
func _actualizar_recogibles(dt: float) -> void:
	var amplio := iman_t > 0.0 and not N.muerta
	for p in recogibles:
		p.t += dt
		var dv = N.pos - p.pos
		var d = max(dv.length(), 0.001)
		if not N.muerta and (amplio or d < N.iman + 48.0):
			var rapidez = min(1050.0, 620.0 + d * 0.42) if amplio else 500.0 * (1.0 + max(0.0, 1.0 - d / (N.iman + 48.0)))
			p.vel = p.vel.lerp(dv / d * rapidez, min(1.0, dt * (4.2 if amplio else 5.8)))
		else:
			p.vel *= pow(0.91, dt * 60.0)
		p.pos += p.vel * dt
		if not N.muerta and p.pos.distance_to(N.pos) < 28.0:
			p.muerto = true
			if p.tipo == "xp":
				ganar_xp(p.valor)
				Audio.sfx("xp")
			else:
				chatarra += p.valor
				ef.comic(N.pos + Vector2(0, -24), "+%d" % p.valor, Color("ffd34d"), 8, 0.5)
				Audio.sfx("chatarra")

func _intervalo_potenciador() -> float:
	var u := clampf((amenaza - 1.0) / 5.0, 0.0, 1.0)
	var r: Vector2 = Datos.POT_INTERVALO_INICIAL.lerp(Datos.POT_INTERVALO_FINAL, u)
	return randf_range(r.x, r.y)

func _actualizar_potenciadores(dt: float) -> void:
	_t_pot -= dt
	if _t_pot <= 0.0 and singularidad <= 0.0:
		if potenciadores.size() < Datos.POT_MAX_EN_CAMPO:
			generar_potenciador()
		_t_pot = Datos.POT_EN_JEFE_CADA_SEG if jefe else _intervalo_potenciador()
	for p in potenciadores:
		p.t += dt
		p.vida -= dt
		if p.vida <= 0.0:
			p.muerto = true
			continue
		if iman_t > 0.0 and not N.muerta:
			p.pos = p.pos.lerp(N.pos, min(1.0, dt * 4.8))
		if not N.muerta and (p.pos.distance_to(N.pos) < 34.0 or Geometry2D.segment_intersects_circle(N.pos_prev, N.pos, p.pos, 34.0) >= 0.0):
			p.muerto = true
			activar_potenciador(p.tipo)

## Elige qué potenciador aparece según lo que el jugador necesita.
func _elegir_potenciador() -> String:
	var pesos := {
		"reparacion": 26.0 if N.vida < N.vida_max else 6.0,
		"escudo": 20.0 if N.escudo < 3 else 6.0,
		"sobrecarga": 24.0, "impulso": 16.0, "iman": 13.0 if recogibles.size() > 6 else 6.0,
		"nova": 15.0 if amenaza >= 5.0 else 7.0,
	}
	if jefe:
		for k in pesos.keys():
			if not Datos.POT_EN_JEFE.has(k):
				pesos[k] = 0.0
	var total := 0.0
	for k in pesos:
		total += pesos[k]
	var v := randf() * total
	for k in pesos:
		v -= pesos[k]
		if v <= 0.0:
			return k
	return "sobrecarga"

func generar_potenciador(tipo := "") -> void:
	if tipo == "":
		tipo = _elegir_potenciador()
	var p := Tipos.Potenciador.new()
	p.tipo = tipo
	p.vida = Datos.POT_VIDA_SEG
	p.fase = randf() * TAU
	var m := media_vista() * 0.8
	var zona := Rect2(N.pos - m, m * 2.0)
	if arena:
		zona = arena.rect.grow(-50)
	for i in 18:
		p.pos = Vector2(randf_range(zona.position.x, zona.end.x), randf_range(zona.position.y, zona.end.y))
		if p.pos.distance_to(N.pos) > 88.0:
			break
	potenciadores.append(p)
	var col: Color = Datos.POTENCIADORES[tipo].color
	ef.anillo(p.pos, 34, col, 0.45, 3)
	ef.chispas(p.pos, 13, col, 80, 0.5)
	ef.comic(p.pos + Vector2(0, -24), "BONUS!", col, 9, 0.6)
	Audio.sfx("potenciador_aparece")

func activar_potenciador(tipo: String) -> void:
	var def: Dictionary = Datos.POTENCIADORES[tipo]
	var msg: String = def.nombre
	match tipo:
		"reparacion":
			if N.vida < N.vida_max:
				N.vida += 1
				msg = "+1 VIDA"
			elif N.escudo < N.escudo_max:
				N.escudo += 1
				msg = "+1 ESCUDO"
			else:
				chatarra += 15
				msg = "+15 CHATARRA"
			Audio.sfx("reparar")
		"escudo":
			if N.escudo < N.escudo_max:
				N.escudo += 1
			elif N.escudo_max < int(def.tope_capacidad):
				N.escudo_max += 1
				N.escudo += 1
			else:
				chatarra += 10
				msg = "ESCUDO LLENO · +10 CHATARRA"
			if msg == def.nombre:
				msg = "+1 ESCUDO"
			ef.anillo(N.pos, 62, def.color, 0.55, 4)
			Audio.sfx("escudo_listo")
		"sobrecarga":
			N.sobrecarga_t = min(float(def.tope), N.sobrecarga_t + float(def.dur))
			msg = "CADENCIA x1.75 · %ds" % ceili(N.sobrecarga_t)
			Audio.sfx("sobrecarga")
		"impulso":
			N.impulso_t = min(float(def.tope), N.impulso_t + float(def.dur))
			msg = "VELOCIDAD x1.4 · %ds" % ceili(N.impulso_t)
			Audio.sfx("impulso")
		"iman":
			iman_t = min(float(def.tope), iman_t + float(def.dur))
			msg = "IMÁN · %ds" % ceili(iman_t)
			ef.anillo(N.pos, 92, def.color, 0.58, 4)
			Audio.sfx("iman")
		"nova":
			pulso_nova(176.0 + min(36.0, amenaza * 2.0), N.dano * (2.15 + min(0.8, amenaza * 0.035)), def.color)
			msg = "PULSO NOVA"
	ef.comic(N.pos + Vector2(0, -40), msg, def.color, 9, 1.0)
	ef.chispas(N.pos, 22, def.color, 145, 0.55)
	Ajustes.vibrar(15)

# =====================================================================
# Jefes
# =====================================================================
func _programar_jefe() -> void:
	if jefe or tiempo < prox_jefe or N.muerta:
		return
	var bi := jefes_derrotados + 1
	var listo = nivel >= min(9, 3 + bi - 1) and bajas >= 22 + (bi - 1) * 14
	if listo or tiempo >= espera_jefe_hasta:
		_iniciar_jefe()
	else:
		prox_jefe = tiempo + 4.0

## Vida del jefe según el daño real que el jugador construyó en esta partida
## y la dificultad de ese jefe.
func vida_jefe(bi: int) -> float:
	var def := IAJefe.definicion(bi)
	var dps := maxf(45.0, N.dps_estimado())
	# cada jefe dura x1.35 más que el anterior frente al mismo daño (tope x3)
	var segundos := Datos.JEFE_SEGUNDOS_OBJETIVO * minf(3.0, pow(Datos.ETAPA_JEFE_DURACION, bi - 1))
	return clampf(dps * segundos * float(def.vida_mult), Datos.JEFE_VIDA_MIN, Datos.JEFE_VIDA_MAX)

func _iniciar_jefe() -> void:
	var bi := jefes_derrotados + 1
	var m := Vector2(433, 228)
	var c := N.pos
	arena = {"centro": c, "rect": Rect2(c - m, m * 2.0), "sello": 0.0}
	limitar_jugador()
	jefe = IAJefe.crear(self, bi, vida_jefe(bi))
	enemigos.append(jefe)
	singularidad = 1.6
	for e in enemigos:
		if e != jefe:
			e.absorbido = true
	# la XP que quedaba en el mapa se recoge sola: no se pierde progreso
	for p in recogibles:
		if p.tipo == "xp":
			ganar_xp(p.valor)
		else:
			chatarra += p.valor
	recogibles.clear()
	potenciadores = potenciadores.filter(func(p): return arena.rect.has_point(p.pos))
	asteroides = asteroides.filter(func(a): return not arena.rect.grow(a.radio * 2).has_point(a.pos))
	_t_pot = Datos.POT_EN_JEFE_CADA_SEG
	anuncio("¡JEFE!", "PROTOCOLO DE CONTENCIÓN", 2.6)
	sacudir(8)
	Audio.sfx("alarma_jefe")
	Audio.musica("jefe1", 0.6)
	Ajustes.vibrar(80)

func _actualizar_singularidad(dt: float) -> void:
	if singularidad <= 0.0:
		return
	singularidad -= dt
	var centro: Vector2 = arena.centro + Vector2(0, -arena.rect.size.y * 0.5 - 40) if arena else N.pos
	for e in enemigos:
		if not e.absorbido or e.muerto:
			continue
		e.t += dt
		var dv: Vector2 = centro - e.pos
		e.pos += dv * min(1.0, dt * 3.2) + Vector2(-dv.y, dv.x).normalized() * 120.0 * dt
		if dv.length() < 30.0 or singularidad <= 0.0:
			e.muerto = true
			ef.chispas(e.pos, 8, e.color, 90, 0.3)
	_borrar_balas(N.pos, 2000.0)

func cambio_fase_jefe(e: Tipos.Jefe) -> void:
	hitstop = 0.18
	sacudir(20)
	for i in 4:
		ef.retardadas.append({"t": i * 0.1, "pos": e.pos + Vector2(randf_range(-70, 70), randf_range(-25, 25)), "tam": 18.0, "color": e.color})
	ef.destello(e.pos, 160, Color(1, 0.4, 0.5), 0.4)
	ef.anillo(e.pos, 150, Color("ff5878"), 0.6, 6)
	ef.comic(e.pos, "ENRAGE!", Color("ff7892"), 20, 1.0)
	anuncio("¡FASE 2!", "EL NÚCLEO SE DESATA", 2.0)
	_borrar_balas(e.pos, 2000.0)
	Audio.sfx("jefe_fase")
	Audio.musica("jefe2", 0.5)
	Ajustes.vibrar(70)

func _jefe_derrotado(e: Tipos.Jefe) -> void:
	jefes_derrotados += 1
	chatarra += 15 + 5 * int(e.def.dificultad)
	ef.fragmentos(e.textura, e.pos, e.inclinacion, e.escala, 90.0)
	puntaje += 500 + jefes_derrotados * 100
	hitstop = 0.25
	sacudir(30)
	_borrar_balas(e.pos, 3000.0)
	for i in 10:
		_explosiones_jefe.append({"t": i * 0.16, "pos": e.pos + Vector2(randf_range(-90, 90), randf_range(-30, 30)) * e.escala * 4.0, "tam": randf_range(26, 40)})
	_explosiones_jefe.append({"t": 1.2, "pos": e.pos, "tam": 70.0, "final": true})
	_soltar("xp", e.pos, 18)
	_soltar("xp", e.pos + Vector2(20, -14), 8)
	ef.comic(e.pos + Vector2(0, -50), "KABOOM!", Color("ff647b"), 26, 1.3)
	Audio.sfx("explosion_grande")
	Ajustes.vibrar(120)
	jefe = null
	_anuncio_etapa_t = 2.6
	prox_jefe = tiempo + Datos.JEFE_CADA_SEG
	espera_jefe_hasta = prox_jefe + Datos.JEFE_ESPERA_MAX_SEG
	_t_oleada = 3.2
	_t_pot = 6.0

func _actualizar_explosiones_jefe(dt: float) -> void:
	if _explosiones_jefe.is_empty():
		return
	for x in _explosiones_jefe:
		x.t -= dt
		if x.t <= 0.0:
			ef.explosion(x.pos, x.tam, [Color("ff3d5a"), Color("ffe066"), Color("c86bff")].pick_random(), true)
			Audio.sfx("explosion")
			sacudir(14 if not x.get("final", false) else 30)
			if x.get("final", false):
				arena = {}
				Audio.siguiente_sector()
				Audio.musica("sector", 1.2)
				Audio.sfx("sector")
				anuncio("JEFE DERROTADO", "SECTOR %d · ELIGE TU RECOMPENSA" % (jefes_derrotados + 1), 2.6)
				recompensa_jefe = true
				abrir_mejoras(true)
	_explosiones_jefe = _explosiones_jefe.filter(func(x): return x.t > 0.0)

func limitar_jugador() -> void:
	if arena:
		var r: Rect2 = arena.rect.grow(-24)
		N.pos = N.pos.clamp(r.position, r.end)
		return
	for a in asteroides:
		if not a.solido:
			continue
		var minimo: float = a.radio * 1.1 + 12.0
		var dv: Vector2 = N.pos - a.pos
		if dv.length() < minimo:
			N.pos = a.pos + dv.normalized() * minimo if dv.length() > 0.001 else a.pos + Vector2(minimo, 0)

# =====================================================================
# Asteroides
# =====================================================================
func _nuevo_asteroide(cerca: bool) -> Tipos.Asteroide:
	var a := Tipos.Asteroide.new()
	var i := randi() % _tex_asteroides.size()
	a.textura = _tex_asteroides[i]
	a.solido = i % 3 == 0
	a.radio = a.textura.get_width() * 0.5 * 2.0 * 0.85
	a.rot = randf() * TAU
	a.giro = randf_range(-0.3, 0.3)
	var m := media_vista()
	if cerca:
		a.pos = N.pos + Vector2(randf_range(-m.x * 1.4, m.x * 1.4), randf_range(-m.y * 1.4, m.y * 1.4))
	else:
		a.pos = _posicion_aparicion() + Vector2(randf_range(-60, 60), randf_range(-60, 60))
	return a

func _sembrar_asteroides() -> void:
	asteroides.clear()
	for i in 22:
		var a := _nuevo_asteroide(true)
		if a.pos.distance_to(N.pos) < 140.0:
			a.pos += (a.pos - N.pos).normalized() * 160.0 + Vector2(160, 0)
		asteroides.append(a)

func _actualizar_asteroides(dt: float) -> void:
	var m := media_vista() * 1.6
	for i in asteroides.size():
		var a: Tipos.Asteroide = asteroides[i]
		a.rot += a.giro * dt
		if abs(a.pos.x - N.pos.x) > m.x or abs(a.pos.y - N.pos.y) > m.y:
			if not arena:
				asteroides[i] = _nuevo_asteroide(false)

# =====================================================================
# Mejoras, reparación y fin
# =====================================================================
func mejoras_elegibles() -> Array:
	return Datos.MEJORAS.filter(func(m): return int(mejoras_tomadas.get(m.id, 0)) < int(m.max) and (not m.has("cond") or N.cumple_condicion(m.cond)))

func tirar_opciones(es_jefe: bool) -> Array:
	var pool := mejoras_elegibles()
	var pesos: Array = (Datos.PROB_RAREZA_JEFE if es_jefe else Datos.PROB_RAREZA_NORMAL).duplicate()
	var out := []
	while out.size() < 3 and not pool.is_empty():
		var activos := [0, 1, 2].filter(func(r): return pool.any(func(m): return int(m.rar) == r))
		var total := 0.0
		for r in activos:
			total += pesos[r]
		var v := randf() * total
		var rar: int = activos[-1]
		for r in activos:
			v -= pesos[r]
			if v <= 0.0:
				rar = r
				break
		var grupo := pool.filter(func(m): return int(m.rar) == rar)
		var elegida = grupo.pick_random()
		out.append(elegida)
		pool.erase(elegida)
	return out

func abrir_mejoras(es_jefe: bool) -> void:
	recompensa_jefe = es_jefe
	cambiar_estado("mejora")
	pantallas.preparar_mejoras(tirar_opciones(es_jefe), es_jefe)
	Audio.sfx("nivel" if not es_jefe else "sector")
	_tutorial.call_deferred("nivel")

func elegir_mejora(id: String) -> void:
	mejoras_tomadas[id] = int(mejoras_tomadas.get(id, 0)) + 1
	N.aplicar_mejora(id)
	if id == "bomb" and N.bombas == 1:
		anuncio("¡BOMBA LISTA!", "ARRASTRA EL BOTÓN BOMBA PARA APUNTAR" if Ajustes.es_tactil() else "PULSA E (O CLIC DERECHO) PARA LANZARLA", 3.5)
	ef.chispas(N.pos, 24, Color("ffe36b"), 150, 0.5)
	ef.anillo(N.pos, 54, Color("ffe36b"), 0.45, 3)
	Audio.sfx("mejora")
	recompensa_jefe = false
	if mejoras_pendientes > 0:
		mejoras_pendientes -= 1
		abrir_mejoras(false)
	else:
		cambiar_estado("jugando")

func reroll() -> bool:
	if chatarra < costo_reroll:
		Audio.sfx("ui_error")
		return false
	chatarra -= costo_reroll
	costo_reroll += Datos.REROLL_COSTO_SUBE
	pantallas.preparar_mejoras(tirar_opciones(recompensa_jefe), recompensa_jefe)
	Audio.sfx("ui_click")
	return true

func puede_reparar() -> bool:
	return not N.muerta and N.vida < N.vida_max and chatarra >= costo_reparar

func reparar() -> bool:
	if not puede_reparar():
		Audio.sfx("ui_error")
		return false
	chatarra -= costo_reparar
	costo_reparar += Datos.REPARAR_COSTO_SUBE
	N.vida += 1
	ef.comic(N.pos + Vector2(0, -32), "+1 VIDA", Color("7dff9b"), 11, 0.8)
	ef.anillo(N.pos, 48, Color("7dff9b"), 0.45, 3)
	Audio.sfx("reparar")
	return true

func pausar() -> void:
	if estado == "jugando":
		cambiar_estado("pausa")

func continuar() -> void:
	if estado == "pausa":
		cambiar_estado("jugando")

func _fin_partida() -> void:
	if estado == "fin":
		return
	_terminar_tutorial()
	var record := Progreso.registrar(puntaje, tiempo, nivel, jefes_derrotados)
	cambiar_estado("fin")
	pantallas.preparar_fin(record)
	_enviar_a_la_tabla()
	Audio.musica("derrota", 0.6)
	Audio.sfx("derrota")

## Sube la partida a la tabla global (si hay cuenta) y deja el resultado para la pantalla de fin.
func _enviar_a_la_tabla() -> void:
	if not Red.configurado():
		return
	if not Red.conectado():
		pantallas.estado_red = "REGÍSTRATE EN RÉCORDS PARA ENTRAR AL TOP 10 GLOBAL"
		return
	pantallas.estado_red = "ENVIANDO A LA TABLA GLOBAL…"
	var r: Dictionary = await Red.enviar_partida(puntaje, tiempo, nivel, jefes_derrotados, N.id)
	if r.ok:
		var p := int(r.datos.get("puesto", 0))
		pantallas.estado_red = ("¡ENTRASTE AL TOP 10! PUESTO #%d GLOBAL" if p <= 10 else "PUESTO #%d GLOBAL") % p
	elif r.get("codigo", 0) == 0:
		pantallas.estado_red = "SIN CONEXIÓN: SE ENVIARÁ MÁS TARDE"
	else:
		pantallas.estado_red = String(r.error).to_upper()

func ir_al_menu() -> void:
	_terminar_tutorial()
	Audio.pausa_musical(false)
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("pausa"):
		if estado == "jugando":
			pausar()
		elif estado == "pausa":
			continuar()
	elif estado == "jugando":
		if ev.is_action_pressed("dash"):
			N.intentar_dash()
		elif ev.is_action_pressed("reparar"):
			reparar()
		elif ev.is_action_pressed("bomba"):
			if ev is InputEventMouseButton:
				arrojar_bomba(Vector2.ZERO, get_global_mouse_position())
			elif not arrojar_bomba():
				Audio.sfx("ui_error", -6.0)

func _notification(what: int) -> void:
	# En el teléfono, salir de la app pausa la partida.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if estado == "jugando":
			pausar()

# =====================================================================
# Dibujo (lo llaman las capas de Mundo)
# =====================================================================
func dibujar(capa: String, ci: CanvasItem) -> void:
	Dibujo.capa(self, capa, ci)
