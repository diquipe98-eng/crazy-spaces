extends Node
## Enfrenta a los 5 jefes uno por uno (jugador invencible con daño fijo) y mide:
## duración del duelo, amplitud y velocidad de su movimiento y patrones usados.
##   godot --headless --path . res://tests/prueba_jefes.tscn

var fallos := 0
var capturar := "--capturas" in OS.get_cmdline_user_args()

func _ready() -> void:
	Progreso.guardado_activo = false
	Progreso.saltar_tutorial()
	var juego = load("res://scenes/juego.tscn").instantiate()
	add_child(juego)
	juego.set_process(false)
	await get_tree().process_frame
	var dt := 1.0 / 30.0
	print("JEFE                 DUR   ANCHO  VEL  BALAS  B/S   PATRONES")
	var presion_ant := 0.0
	for bi in range(1, 7):
		juego.nueva_partida()
		juego.estado = "jugando"
		juego.N.dano = 40.0
		juego.N.cadencia = 3.0
		juego.jefes_derrotados = bi - 1
		juego.tiempo = 100.0
		juego._iniciar_jefe()
		var j = juego.jefe
		var xs := []
		var vel_total := 0.0
		var n := 0
		var patrones := {}
		var t := 0.0
		var fuera := false
		var esbirros := 0
		var foto := 0
		var balas0: int = juego.balas_disparadas
		while t < 160.0 and juego.jefe != null:
			juego.N.inv = 1.0
			juego.N.pos = juego.arena.centro + Vector2(cos(t * 0.7) * 150.0, 150.0)
			juego.actualizar(dt)
			juego._camara(dt)
			# con --capturas guarda dos imágenes de cada duelo (requiere ventana)
			if capturar and ((foto == 0 and t > 9.0) or (foto == 1 and j.fase_jefe == 2 and juego.balas_enemigas.size() > 30 + 25 * bi)):
				foto += 1
				for c in [juego.capa_base, juego.capa_brillo, juego.capa_textos, juego.hud]:
					c.queue_redraw()
				await get_tree().process_frame
				await get_tree().process_frame
				DirAccess.make_dir_recursive_absolute("user://capturas")
				get_viewport().get_texture().get_image().save_png("user://capturas/jefe_%d_%d.png" % [bi, foto])
			if juego.estado == "mejora":
				break
			t += dt
			if j.asentado and j.estado != "entrada":
				xs.append(j.pos.x)
				vel_total += j.vel.length()
				n += 1
				patrones[j.patron] = true
				if not juego.arena.rect.grow(2).has_point(j.pos):
					fuera = true
			esbirros = max(esbirros, juego.esbirros_vivos())
		var ancho: float = (xs.max() - xs.min()) if xs.size() else 0.0
		var nombre: String = j.nombre
		var balas: int = juego.balas_disparadas - balas0
		print("%-20s %5.1f %6.0f %5.0f %6d %4.1f   %s%s" % [nombre, t, ancho, vel_total / max(1, n), balas, balas / maxf(1.0, t), ", ".join(patrones.keys().filter(func(p): return p != "")), ("  (esbirros %d)" % esbirros) if esbirros else ""])
		if juego.jefe != null:
			print("  ✗ no fue derrotado"); fallos += 1
		if bi > 1 and bi <= 5 and balas < presion_ant * 1.9:
			print("  ✗ no es el doble de exigente que el anterior (%d balas vs %d)" % [balas, presion_ant]); fallos += 1
		presion_ant = balas
		if fuera:
			print("  ✗ salió de la arena"); fallos += 1
		if j.def.patrones_f2.has("salto") and not patrones.has("salto"):
			print("  ✗ el VACÍO no saltó"); fallos += 1
		if j.def.patrones_f1.has("invocar") and esbirros == 0:
			print("  ✗ la COLMENA no invocó"); fallos += 1
	# ---------------------------------------------------------------- oleadas por etapa
	print("\nETAPA  RAZAS                          NAVES/MIN  VIDA/MIN   PRESIÓN")
	var base := 0.0
	for et in 5:
		juego.nueva_partida()
		juego.estado = "jugando"
		juego.jefes_derrotados = et
		juego.prox_jefe = 1e9
		juego.espera_jefe_hasta = 1e9
		juego.N.dano = 0.0
		juego.enemigos_generados = 0
		juego.vida_generada = 0.0
		var razas := {}
		var t2 := 0.0
		while t2 < 60.0:
			juego.N.inv = 1.0
			juego.actualizar(1.0 / 30.0)
			t2 += 1.0 / 30.0
			for e in juego.enemigos:
				razas[e.tipo] = true
				e.vida = 0.0 if e.pos.distance_to(juego.N.pos) < 80.0 else e.vida   # no saturar el tope
			juego.enemigos = juego.enemigos.filter(func(e): return e.vida > 0.0)
		var presion: float = juego.vida_generada
		if et == 0:
			base = presion
		print("%-6d %-30s %9d %9.0f   x%.1f" % [et + 1, ", ".join(razas.keys()), juego.enemigos_generados, juego.vida_generada, presion / maxf(1.0, base)])
		if et > 0 and presion < base * pow(2.0, et) * 0.9:
			print("  ✗ las oleadas de la etapa %d no duplican a la anterior" % (et + 1)); fallos += 1
	print("RESULTADO: ", "OK" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
