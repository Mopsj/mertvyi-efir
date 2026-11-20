extends Node3D
## Корневая сцена: окружение, этажи, игрок/монстр, переходы, смерти, финал.

var builder: LevelBuilder = null
var env_node: WorldEnvironment = null
var _env: Environment = null
var _changing := false
var _mimic_timer: Timer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	Game.main = self
	_rng.seed = 20250

	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.012, 0.014, 0.018)
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.0
	_env.tonemap_white = 6.0
	env_node = WorldEnvironment.new()
	env_node.environment = _env
	add_child(env_node)

	Game.ui = HUD.new()
	add_child(Game.ui)

	_build_floor(1)
	_apply_floor_env()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	Game.power_on.connect(_on_power_on)
	Game.player_caught.connect(_on_caught)
	Game.ending.connect(_on_ending)

	_mimic_timer = Timer.new()
	_mimic_timer.one_shot = true
	_mimic_timer.wait_time = _rng.randf_range(45.0, 80.0)
	_mimic_timer.timeout.connect(_mimic_tick)
	add_child(_mimic_timer)
	_mimic_timer.start()


func cell_to_world(_fid: int, c: Vector2i) -> Vector3:
	return builder.cell_to_world(c)


func cell_of_world(_fid: int, pos: Vector3) -> Vector2i:
	return builder.cell_of_world(pos)


func _floor_map(fid: int) -> Dictionary:
	for m in StationData.MAPS:
		if int(m["id"]) == fid:
			return m
	return StationData.MAPS[1]


func _apply_floor_env() -> void:
	var m := _floor_map(Game.current_floor)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = m["ambient"]
	_env.ambient_light_energy = float(m["ambient_energy"])
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.05, 0.065, 0.085)
	_env.fog_density = float(m["fog_density"])
	_env.fog_sky_affect = 0.0


func _build_floor(fid: int) -> void:
	var m := _floor_map(fid)
	if builder != null:
		remove_child(builder)
		builder.queue_free()
	builder = LevelBuilder.new()
	add_child(builder)
	builder.build(m)

	if Game.player == null:
		Game.player = Player.new()
		add_child(Game.player)
	Game.player.global_position = builder.player_spawn() + Vector3(0, 0.05, 0)
	_face_room_center(builder.player_spawn_cell)

	if Game.monster == null:
		Game.monster = Monster.new()
		add_child(Game.monster)
	_relocate_monster(fid)


func _face_room_center(cell: Vector2i) -> void:
	var dir := Vector3(0, 0, 1)
	for rd in builder.map["rooms"]:
		var r: Array = rd["rect"]
		if cell.x >= r[0] and cell.x <= r[2] and cell.y >= r[1] and cell.y <= r[3]:
			var ctr := builder.cell_to_world(Vector2i(int((r[0] + r[2]) / 2.0), int((r[1] + r[3]) / 2.0)))
			dir = ctr - builder.cell_to_world(cell)
			break
	dir.y = 0
	if dir.length() > 0.1:
		var d := dir.normalized()
		Game.player.rotation.y = atan2(-d.x, -d.z)


func _relocate_monster(fid: int) -> void:
	var spawn := builder.monster_spawn_cell
	if spawn.x < 0:
		if builder.patrol_cells.is_empty():
			spawn = Vector2i(int(builder.w / 2.0), int(builder.h / 2.0))
		else:
			spawn = builder.patrol_cells[0]
	var best := spawn
	var best_d := -1.0
	if Game.player != null:
		for c in builder.patrol_cells:
			var p := builder.cell_to_world(c)
			var d := p.distance_to(Game.player.global_position)
			if d > best_d:
				best_d = d
				best = c
	Game.monster.setup(builder.nav, builder.patrol_cells, fid, best)


func change_floor(target: int) -> void:
	if _changing or Game.ended:
		return
	_changing = true
	Sound.play_at(self, "door_slam", Game.player.global_position, -8.0, 10.0, 0.8)
	Game.ui.fade_to_black(0.7)
	await get_tree().create_timer(0.85).timeout
	Game.current_floor = target
	_build_floor(target)
	_apply_floor_env()
	Game.floor_changed.emit(target)
	Game.ui.fade_in(1.1)
	_changing = false


func _on_power_on() -> void:
	builder.set_power(true)
	Sound.make_2d("fuse_install", -8.0)
	await get_tree().create_timer(1.2).timeout
	Sound.play_at(builder, "door_metal", Game.player.global_position + Vector3(0, -6, 0), 2.0, 60.0, 0.6)


func _on_caught() -> void:
	if _changing or Game.ended:
		return
	_changing = true
	Sound.make_2d("sting", -6.0)
	Game.ui.fade_to_black(0.55)
	await get_tree().create_timer(0.75).timeout
	_build_floor(Game.current_floor)
	Game.ui.fade_in(1.4)
	_changing = false


func _on_ending(which: String) -> void:
	if which == "silence":
		Sound.make_2d("silence_end", -4.0)
	else:
		Sound.make_2d("alarm", -10.0)
		Sound.play_at(self, "mimic", Game.player.global_position, 2.0, 40.0, 0.75)
	Game.ui.fade_to_black(2.4)
	await get_tree().create_timer(2.7).timeout
	Game.ui.show_ending(which)


func _mimic_tick() -> void:
	_mimic_timer.wait_time = _rng.randf_range(45.0, 85.0)
	_mimic_timer.start()
	if Game.ended or _changing:
		return
	if Game.monster == null or not Game.monster.visible:
		return
	if Game.current_floor != Game.monster.floor_id:
		return
	var sps: Array[Vector3] = builder.speaker_positions
	if sps.is_empty():
		return
	var best := sps[0]
	var best_d := -1.0
	var pp := Game.player.global_position
	for sp in sps:
		var d := sp.distance_to(pp)
		if d > best_d and d > 10.0:
			best_d = d
			best = sp
	if best_d > 10.0:
		Sound.play_at(builder, "mimic", best, -6.0, 40.0, _rng.randf_range(0.8, 1.05))
