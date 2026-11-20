extends CharacterBody3D
class_name Monster
## «Тишина»: слепая. Только слух. Патруль → проверка шума → охота.

enum State { PATROL, INVESTIGATE, HUNT, LISTEN }

const SPD_PATROL := 1.6
const SPD_INVESTIGATE := 2.4
const SPD_HUNT := 4.4

var floor_id := 2
var astar: AStarGrid2D = null
var patrol_cells: Array[Vector2i] = []

var state: int = State.PATROL
var _path: Array[Vector2i] = []
var _path_i := 0
var _hear_level := 0.0
var _repath_t := 0.0
var _stand_t := 0.0
var _step_t := 0.0
var _rng := RandomNumberGenerator.new()
var _presence: AudioStreamPlayer3D
var _blocked_t := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	_rng.seed = 90210
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 2.1
	cs.shape = cap
	cs.position = Vector3(0, 1.05, 0)
	add_child(cs)

	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.035, 0.035, 0.04)
	m.roughness = 0.85
	var torso := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.26
	cm.height = 1.5
	torso.mesh = cm
	torso.material_override = m
	torso.position = Vector3(0, 1.02, 0)
	torso.scale = Vector3(1.0, 1.0, 0.8)
	add_child(torso)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.16
	hm.height = 0.34
	head.mesh = hm
	head.material_override = m
	head.position = Vector3(0, 1.95, 0.02)
	add_child(head)
	for sx in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var am := CapsuleMesh.new()
		am.radius = 0.07
		am.height = 1.1
		arm.mesh = am
		arm.material_override = m
		arm.position = Vector3(sx * 0.34, 0.95, 0.04)
		arm.rotation_degrees = Vector3(6, 0, sx * 4)
		add_child(arm)

	_presence = AudioStreamPlayer3D.new()
	_presence.stream = Sound.get("presence")
	_presence.max_distance = 22.0
	_presence.unit_size = 2.5
	_presence.volume_db = -8.0
	if _presence.stream is AudioStreamWAV:
		_presence.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_presence.stream.loop_begin = 0
		_presence.stream.loop_end = _presence.stream.data.size() / 2
	add_child(_presence)
	_presence.play()

	Game.noise_event.connect(_on_noise)
	Game.floor_changed.connect(func(fid: int) -> void:
		if fid != floor_id:
			visible = false)


## Перенастроить на конкретный этаж.
func setup(a: AStarGrid2D, patrol: Array[Vector2i], fid: int, spawn_cell: Vector2i) -> void:
	astar = a
	floor_id = fid
	patrol_cells = patrol
	state = State.PATROL
	_hear_level = 0.0
	global_position = Game.main.cell_to_world(fid, spawn_cell)
	visible = true
	if _presence != null and not _presence.playing:
		_presence.play()


func _on_noise(pos: Vector3, fid: int, loudness: float) -> void:
	if Game.ended or not visible:
		return
	var eff := loudness
	if fid != floor_id:
		if loudness < 15.0:
			return
		eff = loudness * 0.4
	var d := global_position.distance_to(pos)
	if d > eff:
		return
	_hear_level = clampf(_hear_level + (eff - d) / maxf(eff, 0.1), 0.0, 2.0)
	if eff - d > eff * 0.5 and d < 9.0:
		state = State.HUNT
		_hear_level = 2.0
		_path = _make_path_to_world(pos)
		_path_i = 0
	elif state != State.HUNT:
		state = State.INVESTIGATE
		_path = _make_path_to_world(pos)
		_path_i = 0

func _physics_process(delta: float) -> void:
	if Game.ended or not visible:
		return
	_hear_level = maxf(0.0, _hear_level - delta * 0.12)

	if state == State.HUNT:
		var p := Game.player
		if p != null and Game.current_floor == floor_id:
			var d := global_position.distance_to(p.global_position)
			if d < 1.5:
				Sound.play_at(get_parent(), "static_burst", global_position, -2.0, 30.0)
				Game.caught()
				return
			if _hear_level < 0.35 and d > 7.0:
				state = State.INVESTIGATE
				_hear_level = 0.8
			elif d < 14.0 and _hear_level > 0.5 and _repath_t <= 0.0:
				_repath_t = 0.7
				_path = _make_path_to_world(p.global_position)
				_path_i = 0
	var speed := SPD_PATROL
	match state:
		State.HUNT:
			speed = SPD_HUNT
		State.INVESTIGATE:
			speed = SPD_INVESTIGATE
		State.LISTEN:
			speed = 0.0

	if state == State.LISTEN:
		_stand_t -= delta
		if _stand_t <= 0.0:
			state = State.PATROL
			_goto_random_patrol()
		move_and_slide()
		return

	if _path_i >= _path.size():
		state = State.LISTEN
		_stand_t = _rng.randf_range(2.2, 4.0)
		Sound.play_at(get_parent(), "whisper", global_position, -10.0, 24.0, _rng.randf_range(0.85, 1.15))
		move_and_slide()
		return

	var wp := _path[_path_i]
	var wp_w := Game.main.cell_to_world(floor_id, wp)
	var to := wp_w - global_position
	to.y = 0.0
	if to.length() < 0.7:
		_path_i += 1
		move_and_slide()
	else:
		var dir := to.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		var yaw := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, yaw, 6.0 * delta)
		move_and_slide()
		var delta_pos := global_position - _prev_pos
		if delta_pos.length() < 0.02 * speed:
			_blocked_t += delta
			if _blocked_t > 0.7:
				_force_nearest_door()
				_blocked_t = 0.0
		else:
			_blocked_t = 0.0
	_prev_pos = global_position

	if state == State.HUNT:
		_repath_t -= delta
	_step_t -= delta * speed
	if _step_t <= 0.0:
		_step_t = 1.15
		Sound.play_at(get_parent(), "step_beast", global_position, -10.0, 30.0, _rng.randf_range(0.8, 1.0))


var _prev_pos := Vector3.ZERO

func _goto_random_patrol() -> void:
	if patrol_cells.is_empty() or astar == null or Game.main == null:
		return
	var from := Game.main.cell_of_world(floor_id, global_position)
	var c := patrol_cells[_rng.randi_range(0, patrol_cells.size() - 1)]
	_path = astar.get_id_path(from, c)
	_path_i = 0


func _make_path_to_world(world_pos: Vector3) -> Array[Vector2i]:
	if astar == null or Game.main == null:
		return []
	var from := Game.main.cell_of_world(floor_id, global_position)
	var to := Game.main.cell_of_world(floor_id, world_pos)
	if from == to:
		return []
	return astar.get_id_path(from, to)


func _force_nearest_door() -> void:
	for d in get_tree().get_nodes_in_group("doors"):
		if d is DoorGate and d.global_position.distance_to(global_position) < 2.4:
			d.force_open()
			return
