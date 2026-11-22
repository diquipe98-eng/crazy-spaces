extends Node
## Progreso persistente: récords y nave equipada (user://progreso.cfg).

const RUTA := "user://progreso.cfg"

var mejor_puntaje := 0
var mejor_tiempo := 0.0
var nave_equipada := "drift"
var registros: Array = []   ## [{puntaje, tiempo, nivel, jefes, nave, subido}] ordenados, máximo 5
                            ## subido = ya está en la tabla global (o se jugó con sesión)
var tutorial: Dictionary = {}   ## ventanas de tutorial ya vistas (id -> true)
var piloto := ""                ## nombre elegido en la bienvenida ("" = primera vez)

func _ready() -> void:
	var c := ConfigFile.new()
	if c.load(RUTA) == OK:
		mejor_puntaje = c.get_value("records", "puntaje", 0)
		mejor_tiempo = c.get_value("records", "tiempo", 0.0)
		registros = c.get_value("records", "lista", [])
		nave_equipada = c.get_value("hangar", "nave", "drift")
		tutorial = c.get_value("tutorial", "visto", {})
		piloto = c.get_value("perfil", "nombre", "")
	if not nave_desbloqueada(nave_equipada):
		nave_equipada = "drift"

## "Repetir tutorial" del menú: la próxima partida vuelve a ser de aprendizaje.
func reiniciar_tutorial() -> void:
	tutorial = {}
	guardar()

## Las pruebas automáticas lo desactivan para no tocar los récords reales.
var guardado_activo := true

func guardar() -> void:
	if not guardado_activo:
		return
	var c := ConfigFile.new()
	c.set_value("records", "puntaje", mejor_puntaje)
	c.set_value("records", "tiempo", mejor_tiempo)
	c.set_value("records", "lista", registros)
	c.set_value("hangar", "nave", nave_equipada)
	c.set_value("tutorial", "visto", tutorial)
	c.set_value("perfil", "nombre", piloto)
	c.save(RUTA)

func tutorial_visto(id: String) -> bool:
	return tutorial.has(id)

func marcar_tutorial(id: String) -> void:
	tutorial[id] = true
	guardar()

## Las pruebas automáticas lo usan para que no salgan las ventanas.
func saltar_tutorial() -> void:
	if piloto == "":
		piloto = "PRUEBA"
	for id in ["controles", "mecanicas", "nivel", "jefe"]:
		tutorial[id] = true

func cambiar_piloto(n: String) -> void:
	piloto = limpiar_nombre(n)
	guardar()

## Nombre que se propone la primera vez: el de la cuenta con la que entró, si no
## el usuario del sistema (escritorio) y si no uno al azar.
func nombre_sugerido() -> String:
	if Red.conectado() and Red.nombre != "":
		return Red.nombre
	for v in ["USER", "USERNAME", "LOGNAME"]:
		var n := limpiar_nombre(OS.get_environment(v))
		if n.length() >= 3 and n not in ["ROOT", "WEB_USER", "USER", "ADMIN", "ADMINISTRATOR"]:
			return n
	return ""

func nombre_al_azar() -> String:
	return "PILOTO_%04d" % (randi() % 10000)

## Mayúsculas, sin tildes, solo A-Z 0-9 _ y máximo 14 (lo mismo que acepta la tabla global).
static func limpiar_nombre(n: String) -> String:
	var s := n.strip_edges().to_upper().replace(" ", "_")
	var desde := "ÁÉÍÓÚÜÑÀÈÌÒÙÂÊÎÔÛÇ"
	var hacia := "AEIOUUNAEIOUAEIOUC"
	var out := ""
	for ch in s:
		var k := desde.find(ch)
		if k >= 0:
			ch = hacia[k]
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_":
			out += ch
	return out.substr(0, 14)

func nave_desbloqueada(id: String) -> bool:
	return mejor_puntaje >= int(Datos.nave(id).puntaje)

## Registra una partida. Devuelve true si es nuevo récord de puntaje.
func registrar(puntaje: int, tiempo: float, nivel: int, jefes: int, nave := "") -> bool:
	var nuevo := puntaje > mejor_puntaje
	mejor_puntaje = max(mejor_puntaje, puntaje)
	mejor_tiempo = max(mejor_tiempo, tiempo)
	registros.append({"puntaje": puntaje, "tiempo": tiempo, "nivel": nivel, "jefes": jefes,
		"nave": nave if nave != "" else nave_equipada, "subido": Red.conectado()})
	registros.sort_custom(func(a, b): return a.puntaje > b.puntaje)
	registros = registros.slice(0, 5)
	guardar()
	return nuevo

## Mejor partida local que aún no está en la tabla global ({} si no hay).
func record_sin_subir() -> Dictionary:
	var mejor := {}
	for r in registros:
		if not r.get("subido", false) and int(r.puntaje) > int(mejor.get("puntaje", -1)):
			mejor = r
	return mejor

func marcar_subidos() -> void:
	for r in registros:
		r["subido"] = true
	guardar()

static func formato_tiempo(t: float) -> String:
	var s := int(t)
	return "%02d:%02d" % [s / 60, s % 60]
