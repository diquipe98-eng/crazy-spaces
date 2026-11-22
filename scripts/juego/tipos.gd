class_name Tipos
## Entidades del juego como objetos ligeros (sin nodos) para mover cientos por cuadro.

class Enemigo:
	var tipo := "grunt"
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var vida := 1.0
	var vida_max := 1.0
	var rapidez := 100.0
	var radio := 12.0
	var xp := 1
	var pts := 10
	var elite := false
	var nivel := 1
	var textura := ""
	var escala := 0.44
	var color := Color.WHITE
	var t := 0.0
	var disparo := 1.0
	var destello := 0.0
	var contacto := 0.5
	var golpe := 0.0
	var fase := 0.0
	var sentido := 1.0
	var muerto := false
	var absorbido := false
	var orbita_golpe := -10.0
	# picador / tejedora
	var dash_t := 0.0
	var dash_cd := 3.0
	var aviso := 0.0
	var objetivo := Vector2.ZERO
	var es_jefe := false
	var empuje := Vector2.ZERO   ## retroceso por impactos (decae solo)
	var masa := 1.0

class Jefe extends Enemigo:
	var def: Dictionary = {}
	var indice := 1
	var fase_jefe := 1
	var asentado := false
	var estado := "entrada"     ## entrada | patrulla | carga | embestida | regreso
	var patron := ""
	var patron_i := -1
	var cuenta := 2.0            ## tiempo hasta el próximo ataque
	var carga_t := 0.0           ## cuenta del aviso (sin líneas: brillo y partículas)
	var carga_total := 1.0
	var angulo_fijo := 0.0
	var giro := 0.0
	var inclinacion := 0.0
	var ancla := Vector2.ZERO
	var desde := Vector2.ZERO
	var hasta := Vector2.ZERO
	var mov_t := 0.0
	var mov_dur := 0.5
	var rafagas := 0             ## disparos restantes de un patrón en varias tandas
	var rafaga_t := 0.0
	var estelas: Array = []      ## imágenes residuales durante la embestida
	var nombre := ""
	var visibilidad := 1.0       ## salto: se desvanece y reaparece
	var salto_destino := Vector2.ZERO
	var saltando := 0.0
	var sentido_orbita := 1.0
	var humo_t := 0.0
	var vuelta := 0              ## ciclo de jefes (más agresivo cada vuelta)

class Bala:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var dano := 10.0
	var color := Color("8ff6ff")
	var radio := 4.0
	var vida := 2.6
	var perfora := 0
	var golpeados: Array = []
	var guiada := false
	var objetivo: Enemigo = null
	var tipo := "laser"          ## laser | dron | misil | bomba
	var area := 0.0              ## radio de explosión (misil, bomba)
	var empuje := 40.0
	var destino := Vector2.ZERO  ## bomba: punto de caída
	var vuelo := 0.0
	var vuelo_total := 0.5
	var origen := Vector2.ZERO
	var critico := false
	var muerta := false

class BalaEnemiga:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var color := Color("ff4d6d")
	var radio := 4.0
	var guiada := 0.0            ## giro máximo rad/s para misiles del jefe
	var vida := 9.0
	var muerta := false

class Recogible:
	var tipo := "xp"             ## xp | chatarra
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var valor := 1
	var t := 0.0
	var muerto := false

class Potenciador:
	var tipo := "reparacion"
	var pos := Vector2.ZERO
	var vida := 15.0
	var t := 0.0
	var fase := 0.0
	var muerto := false

class Asteroide:
	var pos := Vector2.ZERO
	var radio := 20.0
	var rot := 0.0
	var giro := 0.2
	var solido := false
	var textura: Texture2D
