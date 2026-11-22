extends Node
## Prueba manual contra el Supabase REAL (Datos.SUPABASE_URL). Crea una cuenta de prueba:
## bórrala después en Supabase → Authentication → Users.
##   godot --headless --path . res://tests/prueba_real.tscn -- --correo=x@example.com --nombre=PRUEBA_X

var fallos := 0

func _ok(c: bool, que: String) -> void:
	print(("  ✓ " if c else "  ✗ ") + que)
	if not c:
		fallos += 1

func _arg(k: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % k):
			return a.split("=", true, 1)[1]
	return ""

func _ready() -> void:
	Progreso.guardado_activo = false
	Progreso.saltar_tutorial()
	Red.salir()
	var correo := _arg("correo")
	var nom := _arg("nombre")
	print("SERVIDOR: ", Red.url)
	var r := await Red.registrar(correo, nom, "Prueba-123456")
	_ok(r.ok and Red.conectado() and Red.nombre == nom, "registro con correo: " + str(r))
	r = await Red.registrar("otro." + correo, nom, "Prueba-123456")
	_ok(not r.ok and "en uso" in String(r.get("error", "")), "nombre repetido rechazado: " + str(r.get("error", "")))
	r = await Red.enviar_partida(4200, 300.0, 9, 2, "comet")
	_ok(r.ok, "partida enviada: " + str(r))
	r = await Red.cargar_top()
	_ok(r.ok and Red.top.any(func(f): return f.nombre == nom), "aparece en el TOP 10")
	r = await Red.perfil(Red.uid)
	_ok(r.ok and int(r.datos.partidas) == 1, "perfil con su partida")
	var yo := Red.uid
	Red.salir()
	r = await Red.entrar(correo, "mala-clave")
	_ok(not r.ok, "contraseña mala rechazada: " + String(r.get("error", "")))
	r = await Red.entrar(correo.to_upper(), "Prueba-123456")
	_ok(r.ok and Red.uid == yo and Red.nombre == nom, "entrar con correo y contraseña")
	Red.salir()
	print("RESULTADO: ", "OK" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
