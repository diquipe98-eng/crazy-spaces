extends Node
## Capturas del menú: inicio, hangar y ajustes.
func _ready() -> void:
	Progreso.guardado_activo = false
	var m = load("res://scenes/menu.tscn").instantiate()
	add_child(m)
	DirAccess.make_dir_recursive_absolute("user://capturas")
	for v in ["inicio", "hangar", "ajustes"]:
		m._ir(v)
		for i in 20:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://capturas/menu_%s.png" % v)
	get_tree().quit()
