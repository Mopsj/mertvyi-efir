extends Node
## Банк звуков: загрузка WAV, флаги лупов, хелперы воспроизведения.

const NAMES := [
	"hum_room", "hum_transformer", "wind", "radio_loop", "node_hum",
	"drone_dark", "alarm", "presence",
	"step", "step_crouch", "step_beast", "clatter", "door_metal", "hatch",
	"pickup", "fuse_install", "node_on", "drip", "whisper", "mimic",
	"sting", "static_burst", "door_slam", "silence_end",
]
const LOOPS := ["hum_room", "hum_transformer", "wind", "radio_loop", "node_hum", "drone_dark", "alarm", "presence"]

var _bank := {}


func _ready() -> void:
	for n in NAMES:
		var s: AudioStreamWAV = load("res://sounds/%s.wav" % n)
		if s == null:
			push_warning("Нет звука: %s" % n)
			continue
		if n in LOOPS:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = s.data.size() / 2
		_bank[n] = s


func get(name: String) -> AudioStream:
	return _bank.get(name)


## Одноразовый 3D-звук в мире; сам удаляется после конца.
func play_at(parent: Node, snd: String, pos: Vector3, db: float = 0.0, max_dist: float = 26.0, pitch: float = 1.0) -> AudioStreamPlayer3D:
	var st := get(snd)
	if st == null or parent == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.volume_db = db
	p.max_distance = max_dist
	p.unit_size = 4.0
	p.pitch_scale = pitch
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Постоянный 3D-луп (эмбиент).
func make_loop(parent: Node, snd: String, pos: Vector3, db: float = -6.0, max_dist: float = 30.0) -> AudioStreamPlayer3D:
	var st := get(snd)
	if st == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.volume_db = db
	p.max_distance = max_dist
	p.unit_size = 7.0
	parent.add_child(p)
	p.global_position = pos
	p.play()
	return p


## Постоянный не-позиционный луп (музыкальный слой).
func make_2d(snd: String, db: float = -20.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var st := get(snd)
	if st == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = db
	p.pitch_scale = pitch
	p.bus = "Master"
	add_child(p)
	p.play()
	return p
