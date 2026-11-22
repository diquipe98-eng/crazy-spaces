extends Node
## Música adaptativa y efectos de sonido.
## Música (todas CC0, ver CREDITOS.md):
##  - menú: Juhani Junkala "Title Screen"
##  - sectores: rota Level 1 → Level 2 → Level 3 → HydroGene, cambia tras cada jefe
##  - jefe: MintoDog "8bit Action Boss Battle"; la fase 2 pasa a la versión "Climax"
##  - derrota: Juhani Junkala "Ending"
## En pausa la música se apaga con un filtro paso bajo en lugar de cortarse.

const MUSICA := {
	"menu": "res://audio/musica/menu_title_screen.ogg",
	"sector": ["res://audio/musica/sector1_level1.ogg", "res://audio/musica/sector2_level2.ogg",
		"res://audio/musica/sector3_level3.ogg", "res://audio/musica/sector4_space_shooter.ogg"],
	"jefe1": "res://audio/musica/jefe_fase1.ogg",
	"jefe2": "res://audio/musica/jefe_fase2.ogg",
	"derrota": "res://audio/musica/derrota_ending.ogg",
}

## nombre -> [volumen dB, voces simultáneas, separación mínima en s, variación de tono]
const SFX := {
	"disparo": [-15.0, 4, 0.06, 0.08], "misil": [-11.0, 3, 0.1, 0.06], "dron": [-17.0, 3, 0.08, 0.1],
	"jefe_disparo": [-12.0, 3, 0.08, 0.05], "explosion": [-8.0, 6, 0.035, 0.1], "explosion_grande": [-3.0, 2, 0.2, 0.04],
	"bomba": [-4.0, 2, 0.1, 0.05], "nova": [-6.0, 2, 0.1, 0.03], "escudo_golpe": [-6.0, 2, 0.1, 0.03],
	"escudo_listo": [-10.0, 1, 0.2, 0.0], "iman": [-7.0, 1, 0.2, 0.0], "dano": [-3.0, 2, 0.1, 0.03],
	"impacto": [-20.0, 4, 0.04, 0.15], "dash": [-7.0, 2, 0.1, 0.05], "impulso": [-7.0, 1, 0.2, 0.0],
	"sobrecarga": [-8.0, 1, 0.2, 0.0], "xp": [-19.0, 4, 0.035, 0.12], "chatarra": [-12.0, 3, 0.05, 0.08],
	"nivel": [-5.0, 1, 0.2, 0.0], "mejora": [-6.0, 1, 0.1, 0.0], "ui_click": [-8.0, 2, 0.04, 0.0],
	"ui_atras": [-8.0, 2, 0.04, 0.0], "ui_error": [-8.0, 1, 0.1, 0.0], "potenciador_aparece": [-12.0, 1, 0.3, 0.0],
	"reparar": [-6.0, 1, 0.2, 0.0], "alarma_jefe": [-4.0, 1, 0.5, 0.0], "jefe_fase": [-4.0, 1, 0.5, 0.0],
	"derrota": [-4.0, 1, 0.5, 0.0], "elite": [-10.0, 1, 0.4, 0.0], "sector": [-6.0, 1, 0.5, 0.0],
}

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _ultimo := {}
var _voces := {}
var _musica_a: AudioStreamPlayer
var _musica_b: AudioStreamPlayer
var _actual := ""
var _bus_musica := 0
var _bus_efectos := 0
var _filtro: AudioEffectLowPassFilter
var _filtro_hz := 20000.0
var _filtro_obj := 20000.0
var sector := 0
## En la web el navegador no deja sonar nada hasta el primer toque/clic/tecla, y lo que
## se pide antes se pierde: la música pedida antes se guarda y arranca en ese momento.
var _desbloqueado := not OS.has_feature("web")
var _clave_pendiente := ""
var _fundido_pendiente := 0.8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus_musica = _crear_bus("Musica")
	_bus_efectos = _crear_bus("Efectos")
	_filtro = AudioEffectLowPassFilter.new()
	_filtro.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(_bus_musica, _filtro)
	for i in 18:
		var p := AudioStreamPlayer.new()
		p.bus = "Efectos"
		add_child(p)
		_pool.append(p)
	_musica_a = _nuevo_reproductor_musica()
	_musica_b = _nuevo_reproductor_musica()
	for n in SFX:
		if n == "explosion":
			var lista := []
			for i in 5:
				lista.append(load("res://audio/sfx/explosion_%d.ogg" % i))
			_streams[n] = lista
		else:
			_streams[n] = [load("res://audio/sfx/%s.ogg" % n)]
	aplicar_volumenes()
	Ajustes.cambiados.connect(aplicar_volumenes)

func _crear_bus(nombre: String) -> int:
	var i := AudioServer.get_bus_index(nombre)
	if i == -1:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, nombre)
		AudioServer.set_bus_send(i, "Master")
	return i

func _nuevo_reproductor_musica() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Musica"
	p.volume_db = -80.0
	add_child(p)
	return p

func aplicar_volumenes() -> void:
	AudioServer.set_bus_volume_db(_bus_musica, linear_to_db(max(Ajustes.vol_musica, 0.0001)))
	AudioServer.set_bus_volume_db(_bus_efectos, linear_to_db(max(Ajustes.vol_efectos, 0.0001)))
	AudioServer.set_bus_mute(_bus_musica, Ajustes.vol_musica <= 0.001)
	AudioServer.set_bus_mute(_bus_efectos, Ajustes.vol_efectos <= 0.001)

func silenciado() -> bool:
	return AudioServer.is_bus_mute(_bus_musica) and AudioServer.is_bus_mute(_bus_efectos)

func alternar_silencio() -> void:
	var m := not silenciado()
	AudioServer.set_bus_mute(_bus_musica, m)
	AudioServer.set_bus_mute(_bus_efectos, m)

# ---------------------------------------------------------------- efectos
func sfx(nombre: String, volumen_extra := 0.0) -> void:
	var cfg: Array = SFX.get(nombre, [])
	if cfg.is_empty():
		return
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora - float(_ultimo.get(nombre, -10.0)) < float(cfg[2]):
		return
	var activas: Array = _voces.get(nombre, [])
	activas = activas.filter(func(p): return is_instance_valid(p) and p.playing and p.get_meta("sfx", "") == nombre)
	if activas.size() >= int(cfg[1]):
		return
	var libre: AudioStreamPlayer = null
	for p in _pool:
		if not p.playing:
			libre = p
			break
	if libre == null:
		return
	_ultimo[nombre] = ahora
	var lista: Array = _streams[nombre]
	libre.stream = lista[randi() % lista.size()]
	libre.volume_db = float(cfg[0]) + volumen_extra
	libre.pitch_scale = 1.0 + randf_range(-float(cfg[3]), float(cfg[3]))
	libre.set_meta("sfx", nombre)
	libre.play()
	activas.append(libre)
	_voces[nombre] = activas

# ---------------------------------------------------------------- música
func _input(ev: InputEvent) -> void:
	if _desbloqueado:
		return
	var gesto := (ev is InputEventMouseButton or ev is InputEventScreenTouch or ev is InputEventKey or ev is InputEventJoypadButton) and ev.is_pressed()
	if not gesto:
		return
	_desbloqueado = true
	if _clave_pendiente != "":
		musica(_clave_pendiente, _fundido_pendiente)

func musica(clave: String, fundido := 0.8) -> void:
	if not _desbloqueado:
		_clave_pendiente = clave
		_fundido_pendiente = fundido
		return
	var ruta := _ruta(clave)
	if ruta == _actual:
		return
	_actual = ruta
	var sale := _musica_a if _musica_a.playing and _musica_a.volume_db > -60 else _musica_b
	var entra := _musica_b if sale == _musica_a else _musica_a
	if ruta != "":
		var st: AudioStream = load(ruta)
		if st is AudioStreamOggVorbis:
			st.loop = clave != "derrota"
		entra.stream = st
		entra.volume_db = -40.0
		entra.play()
		create_tween().tween_property(entra, "volume_db", 0.0, fundido)
	if sale.playing:
		var tw := create_tween()
		tw.tween_property(sale, "volume_db", -60.0, fundido)
		tw.tween_callback(sale.stop)

func _ruta(clave: String) -> String:
	if clave == "":
		return ""
	if clave == "sector":
		var l: Array = MUSICA.sector
		return l[sector % l.size()]
	return MUSICA.get(clave, "")

## Tras derrotar a un jefe avanza a la siguiente canción de sector.
func siguiente_sector() -> void:
	sector += 1

func pausa_musical(activa: bool) -> void:
	_filtro_obj = 700.0 if activa else 20000.0

func _process(delta: float) -> void:
	if abs(_filtro_hz - _filtro_obj) > 1.0:
		_filtro_hz = lerp(_filtro_hz, _filtro_obj, min(1.0, delta * 6.0))
		_filtro.cutoff_hz = _filtro_hz
