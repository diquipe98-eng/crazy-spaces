extends Node
## Mide el daño real que hace cada arma en 20 s por nivel, contra un blanco
## solo y contra un grupo de 8, para comprobar que cada nivel se nota.
##   godot --headless --path . res://tests/prueba_mejoras.tscn

const ARMAS := ["multi", "drone", "missile", "orbit", "nova", "bomb", "dmg", "rate", "crit", "pierce", "explode"]
var fallos := 0

func _ready() -> void:
	Progreso.guardado_activo = false
	var juego = load("res://scenes/juego.tscn").instantiate()
	add_child(juego)
	juego.set_process(false)
	await get_tree().process_frame
	print("MEJORA      SOLO(NV1/2/3)              GRUPO(NV1/2/3)")
	for arma in ARMAS:
		var solo := []
		var grupo := []
		for nv in range(1, 4):
			solo.append(_medir(juego, arma, nv, 1))
			grupo.append(_medir(juego, arma, nv, 8))
		var base_solo := _medir(juego, "", 0, 1)
		var base_grupo := _medir(juego, "", 0, 8)
		print("%-10s %6.0f %6.0f %6.0f (x%.2f)   %6.0f %6.0f %6.0f (x%.2f)" % [arma, solo[0], solo[1], solo[2], solo[2] / max(1.0, base_solo), grupo[0], grupo[1], grupo[2], grupo[2] / max(1.0, base_grupo)])
		var mejor := grupo if arma in ["nova", "bomb", "orbit", "explode", "pierce"] else solo
		if arma == "explode":
			continue   # los blancos mueren: se mide aparte en la partida
		for k in 2:
			if mejor[k + 1] < mejor[k] * 1.12:
				print("  ✗ %s: el nivel %d casi no mejora (%.0f → %.0f)" % [arma, k + 2, mejor[k], mejor[k + 1]])
				fallos += 1
	print("RESULTADO: ", "OK" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)

## Daño total en 20 s con el arma a nivel "nv" contra "n" blancos quietos.
func _medir(juego, arma: String, nv: int, n: int) -> float:
	seed(12345)
	juego.nueva_partida()
	juego.estado = "jugando"
	juego.prox_jefe = 99999.0
	for k in nv:
		juego.N.aplicar_mejora(arma)
	var blancos := []
	for i in n:
		juego._generar_enemigo("tank", false)
		var e = juego.enemigos[-1]
		e.vida = 400.0 if arma == "explode" else 1e9
		e.vida_max = e.vida
		e.rapidez = 0.0
		e.disparo = 1e9
		e.contacto = 1e9
		e.pos = Vector2(150, -40) + Vector2(i % 4, int(i / 4.0)) * 40.0
		if arma == "orbit":
			e.pos = Vector2.from_angle(i * TAU / n) * Nave.stat_orbita_radio(nv)
		blancos.append([e, e.pos])
	var total := 0.0
	var t := 0.0
	while t < 30.0:
		juego._t_oleada = 99.0
		juego._t_pot = 99.0
		juego.N.inv = 1.0
		juego.N.pos = Vector2.ZERO
		juego.actualizar(1.0 / 30.0)
		t += 1.0 / 30.0
		for b in blancos:
			b[0].pos = b[1]
			b[0].empuje = Vector2.ZERO
		if juego.estado == "mejora":
			juego.estado = "jugando"
	for b in blancos:
		total += b[0].vida_max - max(0.0, b[0].vida)
	# con Núcleo inestable los blancos mueren: cuenta también los que se repusieron
	if arma == "explode":
		total = juego.bajas * 400.0
	return total
