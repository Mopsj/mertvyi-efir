extends CharacterBody3D
class_name Monster
## «Тишина»: слепая. Только слух. Патруль → проверка шума → охота.
## Визуал: CC0-модель «Skeleton Monster» (Quaternius) с анимациями
## Idle/Running/Attack/Spawn/Death + бледный материал с лёгким самосвечением,
## чтобы силуэт читался в темноте. Скорость анимации растёт со скоростью тела.

enum State { PATROL, INVESTIGATE, HUNT, LISTEN }

const SPD_PATROL := 1.6
const SPD_INVESTIGATE := 2.4
const SPD_HUNT := 4.4

const MODEL_PATH := "res://assets/monster/skeleton.fbx"
const MODEL_SCALE := 38.0
const MODEL_PITCH := -90.0
const MODEL_YAW := 180.0

const ANIM_IDLE := "SkeletonArmature|Skeleton_Idle"
const ANIM_RUN := "SkeletonArmature|Skeleton_Running"
const ANIM_ATTACK := "SkeletonArmature|Skeleton_Attack"
const ANIM_SPAWN := "SkeletonArmature|Skeleton_Spawn"

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
var _attack_t := 0.0
var _rng := RandomNumberGenerator.new()
var _presence: AudioStreamPlayer3D
var _blocked_t := 0.0
var _prev_pos := Vector3.ZERO

var _rig: Node3D
var _ap: AnimationPlayer
var _cur_anim := ""


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
	_build_visual()

	_presence = AudioStreamPlayer3D.new()
	_presence.stream = Sound.stream("presence")
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


func _build_visual() -> void:
	var ps: PackedScene = load(MODEL_PATH)
	if ps == null:
		push_warning("Monster model missing: " + MODEL_PATH)
		return
	_rig = Node3D.new()
	_rig.name = "Rig"
	_rig.rotation_degrees = Vector3(MODEL_PITCH, MODEL_YAW, 0.0)
	_rig.scale = Vector3.ONE * MODEL_SCALE
	add_child(_rig)
	var inst: Node3D = ps.instantiate()
	_rig.add_child(inst)

	var mi := _find_mesh(inst) as MeshInstance3D
	if mi != null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.66, 0.64, 0.58)
		m.roughness = 0.72
		m.metallic = 0.0
		m.emission_enabled = true
		m.emission = Color(0.10, 0.095, 0.08)
		m.emission_energy_multiplier = 0.55
		mi.material_override = m

	_ap = null
	var stack: Array[Node] = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is AnimationPlayer:
			_ap = n
		for c in n.get_children():
			stack.append(c)
	if _ap != null:
		for key in [ANIM_IDLE, ANIM_RUN]:
			var a := _ap.get_animation(key)
			a.loop_mode = Animation.LOOP_LINEAR
		_ap.play(ANIM_IDLE)
		_cur_anim = "idle"


func _find_mesh(n: Node) -> Node:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _find_mesh(c)
		if r != null:
			return r
	return null


## Перенастроить на конкретный этаж.
func setup(a: AStarGrid2D, patrol: Array[Vector2i], fid: int, spawn_cell: Vector2i) -> void:
	astar = a
	floor_id = fid
	patrol_cells = patrol
	state = State.PATROL
	_hear_level = 0.0
	_attack_t = 0.0
	global_position = Game.main.cell_to_world(fid, spawn_cell)
	visible = true
	if _ap != null:
		_ap.play(ANIM_SPAWN)
		_cur_anim = "spawn"
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


func _physics_process(delta: float) -> void:
	if Game.ended or not visible:
		return
	_hear_level = maxf(0.0, _hear_level - delta * 0.12)

	if state == State.HUNT:
		var p = Game.player
		if p != null and Game.current_floor == floor_id:
			var d := global_position.distance_to(p.global_position)
			if d < 1.5:
				_do_attack()
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
		_update_anim(0.0)
		if _stand_t <= 0.0:
			state = State.PATROL
			_goto_random_patrol()
		move_and_slide()
		_step_sound(speed)
		return

	if _path_i >= _path.size():
		state = State.LISTEN
		_stand_t = _rng.randf_range(2.2, 4.0)
		_update_anim(0.0)
		move_and_slide()
		Sound.play_at(get_parent(), "whisper", global_position, -10.0, 24.0, _rng.randf_range(0.85, 1.15))
		return

	var wp := _path[_path_i]
	var wp_w: Vector3 = Game.main.cell_to_world(floor_id, wp)
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
	_update_anim(speed)
	_step_sound(speed)

	if state == State.HUNT:
		_repath_t -= delta
	if _attack_t > 0.0:
		_attack_t -= delta


func _do_attack() -> void:
	_attack_t = 1.0
	velocity.x = 0.0
	velocity.z = 0.0
	Sound.play_at(get_parent(), "static_burst", global_position, -2.0, 30.0)
	if _ap != null:
		_ap.play(ANIM_ATTACK)
		_cur_anim = "attack"
	Game.caught()


func _update_anim(speed: float) -> void:
	if _ap == null or _attack_t > 0.0:
		return
	var want := "idle"
	if speed > 0.1:
		want = "run"
	if _cur_anim != want:
		_ap.play(ANIM_RUN if want == "run" else ANIM_IDLE, 0.25)
		_cur_anim = want
	if _cur_anim == "run":
		_ap.speed_scale = clampf(speed / 2.9, 0.45, 1.5)
	elif _cur_anim == "idle":
		_ap.speed_scale = 1.0


func _step_sound(speed: float) -> void:
	_step_t -= get_physics_process_delta_time() * maxf(speed, 0.9)
	if _step_t <= 0.0:
		_step_t = 1.15
		Sound.play_at(get_parent(), "step_beast", global_position, -10.0, 30.0, _rng.randf_range(0.8, 1.0))


func _goto_random_patrol() -> void:
	if patrol_cells.is_empty() or astar == null or Game.main == null:
		return
	var from: Vector2i = Game.main.cell_of_world(floor_id, global_position)
	var c := patrol_cells[_rng.randi_range(0, patrol_cells.size() - 1)]
	_path = astar.get_id_path(from, c)
	_path_i = 0


func _make_path_to_world(world_pos: Vector3) -> Array[Vector2i]:
	if astar == null or Game.main == null:
		return []
	var from: Vector2i = Game.main.cell_of_world(floor_id, global_position)
	var to: Vector2i = Game.main.cell_of_world(floor_id, world_pos)
	if from == to:
		return []
	return astar.get_id_path(from, to)


func _force_nearest_door() -> void:
	for d in get_tree().get_nodes_in_group("doors"):
		if d is DoorGate and d.global_position.distance_to(global_position) < 2.4:
			d.force_open()
			return
