extends Node
## Prueba de partida automática. Ejecutar:
##   godot --headless --path . res://tests/prueba.tscn --fixed-fps 30
## Un bot simple esquiva y elige mejoras. Comprueba potenciadores (acumulación y
## topes), aparición y fases del jefe, recompensas y que no se rompa nada.

var juego
var fallos: Array[String] = []
var marcas := {}
var _seg := 0.0
var _invencible := true

func comprobar(cond: bool, msg: String) -> void:
	if not cond:
		fallos.append(msg)
		print("  ✗ ", msg)
	else:
		print("  ✓ ", msg)

func _ready() -> void:
	Ajustes.mostrar_danos = true
	Progreso.guardado_activo = false
	Progreso.saltar_tutorial()
	Progreso.mejor_puntaje = 0
	juego = load("res://scenes/juego.tscn").instantiate()
	get_tree().root.add_child.call_deferred(juego)
	get_tree().current_scene = self
	await get_tree().process_frame
	await get_tree().process_frame
	_pruebas_potenciadores()
	juego.nueva_partida()

func _pruebas_potenciadores() -> void:
	print("POTENCIADORES")
	var N = juego.N
	juego.activar_potenciador("sobrecarga")
	comprobar(is_equal_approx(N.sobrecarga_t, 8.0), "sobrecarga dura 8 s")
	juego.activar_potenciador("sobrecarga")
	comprobar(is_equal_approx(N.sobrecarga_t, 16.0), "sobrecarga se acumula (16 s)")
	juego.activar_potenciador("sobrecarga")
	comprobar(is_equal_approx(N.sobrecarga_t, 20.0), "sobrecarga topa en 20 s")
	juego.activar_potenciador("iman")
	juego.activar_potenciador("iman")
	juego.activar_potenciador("iman")
	comprobar(is_equal_approx(juego.iman_t, 15.0), "imán topa en 15 s")
	var esc0: int = N.escudo_max
	for i in 5:
		juego.activar_potenciador("escudo")
	comprobar(N.escudo_max == 3 and N.escudo == 3, "escudo: capacidad sube hasta 3 y no más (era %d)" % esc0)
	var ch: int = juego.chatarra
	juego.activar_potenciador("reparacion")
	comprobar(juego.chatarra == ch + 15, "reparación con vida y escudo llenos da +15 chatarra")
	N.vida = 3
	juego.activar_potenciador("reparacion")
	comprobar(N.vida == 4, "reparación cura 1 vida")

func _bot() -> Vector2:
	var N = juego.N
	var huir := Vector2.ZERO
	for e in juego.enemigos:
		var d: Vector2 = N.pos - e.pos
		var l := d.length()
		var r: float = 220.0 if e.es_jefe else 90.0
		if l < r and l > 0.01:
			huir += d / l * (r - l) / r * (2.0 if e.es_jefe else 1.0)
	for b in juego.balas_enemigas:
		var d: Vector2 = N.pos - b.pos
		var l := d.length()
		if l < 60.0 and l > 0.01:
			huir += d / l * (60.0 - l) / 60.0 * 1.6
	for p in juego.potenciadores:
		var d: Vector2 = p.pos - N.pos
		huir += d.normalized() * 0.35
	if juego.arena:
		huir += (juego.arena.centro + Vector2(0, 120) - N.pos) * 0.004
	return huir.limit_length(1.0)

func _process(delta: float) -> void:
	if juego == null or juego.N == null:
		return
	_seg += delta
	var N = juego.N
	if _invencible:
		N.inv = max(N.inv, 0.05)
	# entrada simulada
	var v := _bot()
	for a in ["mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo"]:
		Input.action_release(a)
	if v.x < -0.2: Input.action_press("mover_izquierda", -v.x)
	if v.x > 0.2: Input.action_press("mover_derecha", v.x)
	if v.y < -0.2: Input.action_press("mover_arriba", -v.y)
	if v.y > 0.2: Input.action_press("mover_abajo", v.y)
	if v.length() > 0.9 and N.dash_cd <= 0.0:
		N.intentar_dash()
	if juego.estado == "jugando" and N.bomba_cargas > 0 and juego.enemigos.size() >= 4:
		if juego.arrojar_bomba():
			marcas["bombas_lanzadas"] = marcas.get("bombas_lanzadas", 0) + 1
	match juego.estado:
		"mejora":
			marcas["mejoras"] = marcas.get("mejoras", 0) + 1
			var ops: Array = juego.tirar_opciones(juego.recompensa_jefe)
			if juego.recompensa_jefe:
				marcas["recompensa_jefe"] = true
			juego.elegir_mejora(ops[0].id if ops.size() else "overclock")
		"fin":
			marcas["fin"] = juego.tiempo
			_terminar()
			return
	if juego.potenciadores.size() > 0 and not marcas.has("pot_t"):
		marcas["pot_t"] = juego.tiempo
	if juego.potenciadores.size() > Datos.POT_MAX_EN_CAMPO:
		marcas["pot_exceso"] = true
	if juego.jefe:
		if not marcas.has("jefe_t"):
			marcas["jefe_t"] = juego.tiempo
			print("jefe aparece a los %.1f s (nivel %d, bajas %d), vida %d" % [juego.tiempo, juego.nivel, juego.bajas, juego.jefe.vida])
		marcas["estados_" + juego.jefe.estado] = true
		if juego.jefe.fase_jefe == 2 and not marcas.has("fase2_t"):
			marcas["fase2_t"] = juego.tiempo
		if not juego.arena.rect.grow(1).has_point(N.pos):
			marcas["fuera_arena"] = true
		if juego.jefe.estado == "patrulla" and juego.jefe.asentado and not juego.arena.rect.has_point(juego.jefe.pos):
			marcas["jefe_fuera"] = true
	elif marcas.has("jefe_t") and not marcas.has("jefe_muere_t"):
		marcas["jefe_muere_t"] = juego.tiempo
		print("jefe derrotado a los %.1f s (duelo %.1f s)" % [juego.tiempo, juego.tiempo - marcas.jefe_t])
	marcas["max_part"] = max(marcas.get("max_part", 0), juego.ef.particulas.size())
	marcas["max_ene"] = max(marcas.get("max_ene", 0), juego.enemigos.size())
	if juego.tiempo >= 330.0 and _invencible:
		print("tiempo %.0f s · nivel %d · bajas %d · puntaje %d · jefes %d" % [juego.tiempo, juego.nivel, juego.bajas, juego.puntaje, juego.jefes_derrotados])
		_invencible = false   # ahora el bot puede morir: comprueba el fin de partida
	if juego.tiempo > 900.0:
		_terminar()

func _terminar() -> void:
	set_process(false)
	print("PARTIDA")
	comprobar(marcas.has("pot_t") and marcas.pot_t >= 14.0 and marcas.pot_t < 17.0, "primer potenciador a los ~15 s (%.1f)" % marcas.get("pot_t", -1.0))
	comprobar(not marcas.has("pot_exceso"), "nunca más de %d potenciadores en el campo" % Datos.POT_MAX_EN_CAMPO)
	comprobar(marcas.has("jefe_t") and marcas.jefe_t >= 90.0 and marcas.jefe_t <= 111.0, "primer jefe entre 90 y 110 s (%.1f)" % marcas.get("jefe_t", -1.0))
	comprobar(marcas.has("estados_carga") and marcas.has("estados_embestida") and marcas.has("estados_regreso"), "el jefe avisa, embiste y regresa")
	comprobar(marcas.has("fase2_t"), "el jefe entra en fase 2")
	comprobar(marcas.has("jefe_muere_t"), "el jefe puede ser derrotado")
	if marcas.has("jefe_muere_t"):
		var duelo: float = marcas.jefe_muere_t - marcas.jefe_t
		comprobar(duelo > 20.0 and duelo < 95.0, "duelo de jefe razonable (%.1f s)" % duelo)
	comprobar(marcas.get("recompensa_jefe", false), "derrotar al jefe da recompensa de mejora")
	comprobar(not marcas.has("fuera_arena"), "la nave no sale de la arena del jefe")
	comprobar(not marcas.has("jefe_fuera"), "el jefe patrulla dentro de la arena")
	comprobar(marcas.get("mejoras", 0) >= 6, "se eligieron mejoras (%d)" % marcas.get("mejoras", 0))
	comprobar(marcas.get("max_part", 0) <= Datos.MAX_PARTICULAS, "partículas bajo el tope (%d)" % marcas.get("max_part", 0))
	comprobar(marcas.get("max_ene", 0) <= Datos.MAX_ENEMIGOS + 1, "enemigos bajo el tope (%d)" % marcas.get("max_ene", 0))
	comprobar(marcas.has("fin"), "la partida termina al perder (%.0f s)" % marcas.get("fin", -1.0))
	print("RESULTADO: ", "OK" if fallos.is_empty() else "%d FALLOS" % fallos.size())
	get_tree().quit(0 if fallos.is_empty() else 1)
