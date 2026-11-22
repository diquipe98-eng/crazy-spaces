extends Node
## Captura del inicio sin servidor configurado (lo que ve hoy el jugador).

func _ready() -> void:
	Progreso.guardado_activo = false
	Progreso.saltar_tutorial()
	Progreso.registros = [{"puntaje": 93322, "tiempo": 1009.0, "nivel": 41, "jefes": 4}, {"puntaje": 51200, "tiempo": 700.0, "nivel": 30, "jefes": 3}]
	var menu = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	for i in 40:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("user://capturas")
	get_viewport().get_texture().get_image().save_png("user://capturas/menu_sin_servidor.png")
	get_tree().quit()
