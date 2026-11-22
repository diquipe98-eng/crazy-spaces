class_name Nave
extends RefCounted
## Estado y armas de la nave del jugador. El movimiento llega ya resuelto desde Juego
## (teclado, mando, joystick flotante o arrastre relativo).
## Cada arma tiene sus fórmulas por nivel aquí abajo (stat_*): las usan tanto el
## combate como las tarjetas de mejora, así lo que se promete es lo que pasa.

var j   ## Juego (sin tipar para evitar dependencia circular de class_name)

var id := "drift"
var textura := ""
var pos := Vector2.ZERO
var pos_prev := Vector2.ZERO
var apunte := -PI / 2

# vida y defensa
var vida := 5
var vida_max := 5
var escudo := 0
var escudo_max := 0
var escudo_t := 0.0
var escudo_recarga := 8.5
var inv := 0.0
var muerta := false
var revivir := 0

# ofensiva
var dano := 18.0
var cadencia := 2.0
var disparos := 1            ## cañones paralelos
var perforacion := 0
var vel_bala := 510.0
var critico := 0.0
var crit_mult := 2.4
var robo_vida := 0.0
var explosivo := 0
var drones := 0
var misiles := 0
var orbitas := 0
var nova := 0
var bombas := 0

# movilidad y utilidad
var vel_max := 218.0
var iman := 105.0
var xp_mult := 1.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_recarga := 5.0
var dash_dir := Vector2.UP
var ultima_dir := Vector2.UP
var estelas: Array = []   ## imágenes residuales del dash

# potenciadores temporales (segundos restantes)
var sobrecarga_t := 0.0
var impulso_t := 0.0

# temporizadores de armas
var _t_disparo := 0.22
var _t_dron := 0.6
var _t_misil := 1.0
var _t_orbita := 0.0
var _t_nova := 5.0
var _t_bomba := 0.0          ## recarga de la siguiente carga de bomba
var bomba_cargas := 0
var _t_estela := 0.0
var _destello_canon := 0.0
var _retroceso := 0.0

func _init(juego, nave_id: String) -> void:
	j = juego
	id = nave_id
	textura = "res://art/naves/%s.png" % nave_id
	var b: Dictionary = Datos.JUGADOR_BASE
	vida = b.vida
	vida_max = b.vida
	dano = b.dano
	cadencia = b.cadencia
	disparos = b.disparos
	perforacion = b.perforacion
	vel_bala = b.vel_bala
	vel_max = b.vel_max
	iman = b.iman
	escudo_recarga = b.escudo_recarga
	dash_recarga = b.dash_recarga
	# rasgos de la nave elegida
	var m: Dictionary = Datos.nave(nave_id).get("mod", {})
	dano *= float(m.get("dano", 1.0))
	cadencia *= float(m.get("cadencia", 1.0))
	vel_max *= float(m.get("vel", 1.0))
	vel_bala *= float(m.get("vel_bala", 1.0))
	dash_recarga *= float(m.get("dash", 1.0))
	vida_max += int(m.get("vida", 0))
	vida = vida_max
	escudo_max += int(m.get("escudo", 0))
	escudo = escudo_max
	critico += float(m.get("crit", 0.0))
	perforacion += int(m.get("perfora", 0))
	revivir = int(m.get("revivir", 0))

# =====================================================================
# Fórmulas por nivel (n = nivel del arma)
# =====================================================================
static func stat_laser_total(n: int) -> float:       ## daño total relativo de todos los cañones
	return 1.0 + 0.6 * (n - 1)
static func stat_dron_dano(n: int) -> float: return 0.5 + 0.1 * n
static func stat_dron_cd(n: int) -> float: return maxf(0.25, 0.62 - 0.07 * n)
static func stat_misil_dano(n: int) -> float: return 1.5 + 0.25 * n
static func stat_misil_area(n: int) -> float: return 38.0 + 10.0 * n
static func stat_misil_cd(n: int) -> float: return maxf(0.9, 1.6 - 0.15 * n)
static func stat_orbita_dano(n: int) -> float: return 0.55 + 0.15 * n
static func stat_orbita_radio(n: int) -> float: return 46.0 + 10.0 * n
static func stat_orbita_tam(n: int) -> float: return 4.5 + 1.5 * n
static func stat_nova_radio(n: int) -> float: return 120.0 + 32.0 * n
static func stat_nova_dano(n: int) -> float: return 1.4 + 0.6 * n
static func stat_nova_cd(n: int) -> float: return maxf(3.2, 7.5 - 0.9 * n)
static func stat_bomba_radio(n: int) -> float: return 80.0 + 16.0 * n
static func stat_bomba_dano(n: int) -> float: return 1.1 + 0.55 * n
static func stat_bomba_cd(n: int) -> float: return maxf(4.0, 8.4 - 1.3 * n)
static func stat_explosivo_radio(n: int) -> float: return 50.0 + 16.0 * n

## Texto "antes → después" que muestra la tarjeta de cada mejora.
func texto_mejora(m: String) -> String:
	var d := roundi(dano)
	match m:
		"dmg": return "DAÑO %d → %d" % [d, roundi(dano * 1.18)]
		"overclock": return "DAÑO %d → %d" % [d, roundi(dano * 1.08)]
		"rate": return "DISPAROS/S %.1f → %.1f" % [cadencia, cadencia * 1.16]
		"speed": return "VELOCIDAD %d → %d" % [roundi(vel_max), roundi(vel_max * 1.12)]
		"hp": return "VIDA MÁX %d → %d" % [vida_max, vida_max + 1]
		"heal": return "VIDA %d → %d" % [vida, mini(vida_max, vida + 2)]
		"magnet": return "ALCANCE %d → %d" % [roundi(iman), roundi(iman + 55)]
		"xp": return "XP x%.2f → x%.2f" % [xp_mult, xp_mult * 1.15]
		"crit": return "CRÍTICO %d%% → %d%% · x%.1f → x%.1f" % [roundi(critico * 100), roundi((critico + 0.1) * 100), crit_mult, crit_mult + 0.25]
		"multi": return "CAÑONES %d → %d · DAÑO x%.1f → x%.1f" % [disparos, disparos + 1, stat_laser_total(disparos), stat_laser_total(disparos + 1)]
		"pierce": return "ATRAVIESA %d → %d" % [perforacion, perforacion + 1]
		"shield": return "CARGAS %d → %d" % [escudo_max, escudo_max + 1]
		"drone": return "DRONES %d → %d · %d DAÑO C/U" % [drones, drones + 1, roundi(dano * stat_dron_dano(drones + 1))]
		"orbit": return "ORBES %d → %d · ALCANCE %d → %d" % [orbitas, orbitas + 1, roundi(stat_orbita_radio(orbitas)) if orbitas else 0, roundi(stat_orbita_radio(orbitas + 1))]
		"nova": return "RADIO %d → %d · DAÑO %d → %d" % [roundi(stat_nova_radio(nova)) if nova else 0, roundi(stat_nova_radio(nova + 1)), roundi(dano * stat_nova_dano(nova)) if nova else 0, roundi(dano * stat_nova_dano(nova + 1))]
		"missile": return "MISILES %d → %d · %d DAÑO" % [misiles, misiles + 1, roundi(dano * stat_misil_dano(misiles + 1))]
		"bomb": return "CARGAS %d → %d · RADIO %d → %d · DAÑO %d → %d" % [bombas, bombas + 1, roundi(stat_bomba_radio(bombas)) if bombas else 0, roundi(stat_bomba_radio(bombas + 1)), roundi(dano * stat_bomba_dano(bombas)) if bombas else 0, roundi(dano * stat_bomba_dano(bombas + 1))]
		"explode": return "RADIO %d → %d" % [roundi(stat_explosivo_radio(explosivo)) if explosivo else 0, roundi(stat_explosivo_radio(explosivo + 1))]
		"leech": return "PROBABILIDAD %d%% → %d%%" % [roundi(robo_vida * 100), roundi((robo_vida + 0.03) * 100)]
		"glass": return "DAÑO %d → %d · VIDA MÁX %d → %d" % [d, roundi(dano * 1.7), vida_max, vida_max - 1]
	return ""

## Nivel de cada arma del arsenal (0 = no adquirida).
func nivel_arma(arma: String) -> int:
	match arma:
		"laser": return disparos
		"misil": return misiles
		"bomba": return bombas
		"nova": return nova
		"dron": return drones
		"orbita": return orbitas
	return 0

func aplicar_mejora(m: String) -> void:
	match m:
		"dmg": dano *= 1.18
		"rate": cadencia *= 1.16
		"speed": vel_max *= 1.12
		"hp":
			vida_max += 1
			vida = mini(vida_max, vida + 1)
		"heal": vida = mini(vida_max, vida + 2)
		"magnet": iman += 55.0
		"xp": xp_mult *= 1.15
		"crit":
			critico += 0.1
			crit_mult += 0.25
		"multi": disparos += 1
		"pierce": perforacion += 1
		"shield":
			escudo_max += 1
			escudo += 1
		"drone": drones += 1
		"orbit": orbitas += 1
		"nova":
			nova += 1
			_t_nova = minf(_t_nova, 2.0)
		"missile":
			misiles += 1
			_t_misil = minf(_t_misil, 0.5)
		"bomb":
			bombas += 1
			bomba_cargas += 1
		"explode": explosivo += 1
		"leech": robo_vida += 0.03
		"glass":
			dano *= 1.7
			vida_max -= 1
			vida = mini(vida, vida_max)
		"overclock": dano *= 1.08

func cumple_condicion(cond: String) -> bool:
	match cond:
		"herido2": return vida < vida_max - 1
		"vida_mayor_1": return vida_max > 1
	return true

## Multiplicador de cadencia que crece con la amenaza (mantiene el ritmo del HTML).
func ritmo_oleada() -> float:
	return 1.0 + minf(1.75, maxf(0.0, j.amenaza - 1.0) * 0.34)

func velocidad_actual() -> float:
	var m: float = Datos.POTENCIADORES.impulso.mult if impulso_t > 0.0 else 1.0
	return vel_max * m * Datos.VELOCIDAD_A_MUNDO

## DPS aproximado del arsenal (para calcular la vida de los jefes).
func dps_estimado() -> float:
	var crit := 1.0 + clampf(critico, 0.0, 0.85) * (crit_mult - 1.0)
	var total := dano * stat_laser_total(disparos) * cadencia * ritmo_oleada() * crit * 0.86
	if drones: total += dano * stat_dron_dano(drones) * drones / stat_dron_cd(drones) * 0.82
	if misiles: total += dano * stat_misil_dano(misiles) * misiles / stat_misil_cd(misiles) * 0.9
	if bombas: total += dano * stat_bomba_dano(bombas) / stat_bomba_cd(bombas) * 0.7
	if nova: total += dano * stat_nova_dano(nova) / stat_nova_cd(nova) * 0.45
	if orbitas: total += dano * stat_orbita_dano(orbitas) * orbitas * 0.3
	return total

func intentar_dash() -> bool:
	if muerta or dash_cd > 0.0 or dash_t > 0.0:
		return false
	var d := ultima_dir
	if d.length() < 0.15:
		var e = j.enemigo_mas_cercano(pos)
		d = (pos - e.pos) if e else Vector2.from_angle(apunte)
	dash_dir = d.normalized()
	dash_t = Datos.DASH_DURACION
	dash_cd = dash_recarga
	inv = maxf(inv, 0.42)
	j.ef.anillo(pos, 36, Color("79eaff"), 0.32, 3)
	j.ef.chispas(pos, 18, Color("7cecff"), 165, 0.35)
	j.ef.comic(pos + Vector2(0, -28), "DASH!", Color("8ff6ff"), 11, 0.5)
	Audio.sfx("dash")
	Ajustes.vibrar(18)
	return true

func actualizar(dt: float, entrada: Vector2, arrastre: Vector2) -> void:
	pos_prev = pos
	dash_cd = maxf(0.0, dash_cd - dt)
	sobrecarga_t = maxf(0.0, sobrecarga_t - dt)
	impulso_t = maxf(0.0, impulso_t - dt)
	inv = maxf(0.0, inv - dt)
	_destello_canon = maxf(0.0, _destello_canon - dt)
	_retroceso = maxf(0.0, _retroceso - dt * 30.0)
	var vmax := velocidad_actual()
	if entrada.length() > 0.08:
		ultima_dir = entrada.normalized()
	if arrastre != Vector2.ZERO:
		ultima_dir = arrastre.normalized()
	if dash_t > 0.0:
		dash_t = maxf(0.0, dash_t - dt)
		pos += dash_dir * vel_max * Datos.DASH_MULT * Datos.VELOCIDAD_A_MUNDO * dt
		inv = maxf(inv, 0.08)
		estelas.append({"pos": pos, "vida": 0.25, "rot": apunte})
	else:
		pos += entrada.limit_length(1.0) * vmax * dt
		# arrastre relativo: copia el movimiento del dedo, sin superar 2.2x la velocidad
		pos += arrastre.limit_length(vmax * 2.2 * dt)
	for e in estelas:
		e.vida -= dt
	estelas = estelas.filter(func(e): return e.vida > 0.0)
	j.limitar_jugador()
	_armas(dt)
	# estela del motor
	_t_estela -= dt
	if _t_estela <= 0.0:
		_t_estela = 0.025
		var atras := Vector2.from_angle(apunte + PI)
		var col: Color = Datos.nave(id).color
		j.ef.estela(pos + atras * 13, Vector2.from_angle(apunte), Color(1, 0.85, 0.4).lerp(col, 0.35), 1.2 if impulso_t > 0.0 else 0.8)

func retroceso() -> float:
	return _retroceso

func _armas(dt: float) -> void:
	if j.singularidad > 0.0:
		return
	var objetivo = j.objetivo_combate(pos)
	if objetivo:
		apunte = lerp_angle(apunte, (objetivo.pos - pos).angle(), minf(1.0, dt * 18.0))
	# láser principal
	_t_disparo -= dt
	if _t_disparo <= 0.0:
		var m_sob: float = Datos.POTENCIADORES.sobrecarga.mult if sobrecarga_t > 0.0 else 1.0
		_t_disparo += 1.0 / (cadencia * ritmo_oleada() * m_sob)
		_t_disparo = maxf(_t_disparo, 0.0)
		if objetivo:
			_disparar(objetivo)
	# drones: cada uno busca su propio blanco
	if drones > 0:
		_t_dron -= dt
		if _t_dron <= 0.0:
			_t_dron = stat_dron_cd(drones)
			var usados := []
			var disparo := false
			for i in drones:
				var p := posicion_dron(i)
				# primero: quien te está atacando por un flanco que el cañón no cubre
				var e = j.atacante_de_flanco(pos, apunte, usados)
				if e == null:
					e = j.enemigo_cercano_excepto(p, usados, 330.0)
				if e == null:
					e = objetivo
				if e == null:
					continue
				usados.append(e)
				var b = j.agregar_bala(p, (e.pos - p).angle(), vel_bala * 0.95, dano * stat_dron_dano(drones), Color("7dffa8"), "dron")
				b.objetivo = e
				b.empuje = 25.0
				j.ef.destello(p, 5, Color(0.5, 1, 0.7), 0.06)
				disparo = true
			if disparo:
				Audio.sfx("dron")
	# misiles: salva a blancos distintos
	if misiles > 0:
		_t_misil -= dt
		if _t_misil <= 0.0:
			_t_misil = stat_misil_cd(misiles)
			var blancos: Array = j.blancos_prioritarios(pos, misiles)
			for i in misiles:
				var e = blancos[i % blancos.size()] if blancos.size() else null
				var lado := -1.0 if i % 2 == 0 else 1.0
				var a := apunte + PI + lado * (0.9 + 0.25 * int(i / 2.0))
				var b = j.agregar_bala(pos + Vector2.from_angle(a) * 8.0, a, 170.0, dano * stat_misil_dano(misiles), Color("ffa24d"), "misil")
				b.objetivo = e
				b.area = stat_misil_area(misiles)
				b.empuje = 160.0
			Audio.sfx("misil")
	# satélites: golpean, empujan y destruyen balas enemigas
	if orbitas > 0:
		_t_orbita -= dt
		if _t_orbita <= 0.0:
			_t_orbita = 0.05
			for i in orbitas:
				var p := posicion_orbita(i)
				for e in j.enemigos:
					if e.muerto or e.absorbido or p.distance_to(e.pos) > e.radio + stat_orbita_tam(orbitas) + 3.0 or j.tiempo - e.orbita_golpe < 0.45 / orbitas:
						continue
					e.orbita_golpe = j.tiempo
					j.danar_enemigo(e, dano * stat_orbita_dano(orbitas), false, true)
					j.empujar(e, (e.pos - pos).normalized(), 150.0)
					j.ef.chispas(p, 7, Color("e0a0ff"), 110, 0.25)
					j.ef.destello(p, 9, Color(0.9, 0.6, 1.0), 0.08)
				for b in j.balas_enemigas:
					if not b.muerta and b.pos.distance_to(p) < b.radio + stat_orbita_tam(orbitas) + 2.0:
						b.muerta = true
						j.ef.chispas(b.pos, 4, b.color, 80, 0.2)
	# pulso nova
	if nova > 0:
		_t_nova -= dt
		if _t_nova <= 0.0:
			_t_nova = stat_nova_cd(nova)
			j.pulso_nova(stat_nova_radio(nova), dano * stat_nova_dano(nova), Color("66efff"))
	# bomba: habilidad del jugador; aquí solo se recargan las cargas
	if bombas > 0 and bomba_cargas < bombas:
		_t_bomba += dt
		if _t_bomba >= stat_bomba_cd(bombas):
			_t_bomba = 0.0
			bomba_cargas += 1
			j.ef.anillo(pos, 30, Color("ff9b4d"), 0.3, 2)
			Audio.sfx("ui_click", -8.0)
	# escudo
	if escudo < escudo_max:
		escudo_t += dt
		if escudo_t >= escudo_recarga:
			escudo += 1
			escudo_t = 0.0
			j.ef.anillo(pos, 30, Color("7cc8ff"), 0.35, 2)
			Audio.sfx("escudo_listo")

## Cañones paralelos que convergen en el blanco: más nivel = más daño visible.
func _disparar(objetivo) -> void:
	var a: float = (objetivo.pos - pos).angle()
	var dir := Vector2.from_angle(a)
	var perp := Vector2(-dir.y, dir.x)
	var boca := pos + dir * 14.0
	var por_bala := dano * stat_laser_total(disparos) / disparos
	for i in disparos:
		var k := i - (disparos - 1) / 2.0
		var p := boca + perp * k * 7.0 - dir * absf(k) * 3.0
		var ang: float = (objetivo.pos - p).angle()
		var b = j.agregar_bala(p, ang, vel_bala, por_bala, Color("8ff6ff"), "laser")
		b.objetivo = objetivo
		j.ef.destello(p, 7, Color(0.55, 0.95, 1.0), 0.07)
	_destello_canon = 0.06
	_retroceso = 1.0
	Audio.sfx("disparo")

func posicion_dron(i: int) -> Vector2:
	var a: float = j.reloj * 2.7 + i * TAU / maxi(1, drones)
	return pos + Vector2.from_angle(a) * 34.0

func posicion_orbita(i: int) -> Vector2:
	var a: float = j.reloj * (2.4 + 0.3 * orbitas) + i * TAU / maxi(1, orbitas)
	return pos + Vector2.from_angle(a) * stat_orbita_radio(orbitas)

func destello_canon() -> float:
	return _destello_canon
