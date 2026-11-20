class_name LevelBuilder
extends Node3D
## Строит этаж станции из ASCII-карты: геометрия, свет, интерактив, пропсы,
## декали, звуковые маркеры, нав-сетка. Всё — процедурные плейсхолдеры.

const CELL := 2.0
const TEX_DIR := "res://assets/tex/"

var map: Dictionary
var grid: Array = []
var w := 0
var h := 0
var ceil_h := 3.0

var nav: AStarGrid2D
var player_spawn_cell := Vector2i(1, 1)
var monster_spawn_cell := Vector2i(-1, -1)
var patrol_cells: Array[Vector2i] = []
var speaker_positions: Array[Vector3] = []
var light_sources: Array[Vector3] = []

var _flicker: Array[Light3D] = []
var _powered_fixtures: Array[MeshInstance3D] = []
var _powered_lights: Array[Light3D] = []
var _drips: Array = []
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _tex_cache := {}


# -------------------------------------------------------- PBR-материалы (Poly Haven, CC0)
func _tex(fname: String) -> Texture2D:
	if not _tex_cache.has(fname):
		_tex_cache[fname] = load(TEX_DIR + fname)
	return _tex_cache[fname]


func _mat_pbr(set_name: String, tint: Color, metal := 0.0, tex_scale := 0.5, use_metal_ch := false) -> StandardMaterial3D:
	var k := "pbr_" + set_name + "_" + tint.to_html(false) + str(metal) + str(tex_scale) + str(use_metal_ch)
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(set_name + "_diff.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = _tex(set_name + "_nor_gl.jpg")
	var arm := _tex(set_name + "_arm.jpg")
	m.ao_enabled = true
	m.ao_texture = arm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness_texture = arm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.metallic = metal
	if use_metal_ch:
		m.metallic = 1.0
		m.metallic_texture = arm
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * tex_scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mats[k] = m
	return m


# ------------------------------------------------------------ материалы
func _mat(key: String, col: Color, rough := 0.85, metal := 0.0, tex_freq := 0.09) -> StandardMaterial3D:
	var k := key + "_" + col.to_html(false)
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if tex_freq > 0.0:
		var n := FastNoiseLite.new()
		n.frequency = tex_freq
		n.seed = 11
		var t := NoiseTexture2D.new()
		t.noise = n
		t.width = 128
		t.height = 128
		m.albedo_texture = t
	_mats[k] = m
	return m


# ------------------------------------------------------------ построение
func build(m: Dictionary) -> void:
	map = m
	grid = m["rows"]
	h = grid.size()
	w = grid[0].length()
	ceil_h = m["ceil_h"]
	_rng.seed = 4711 + int(map["id"]) * 977

	_build_slabs()
	_build_walls()
	_build_nav()
	_place_map_entities()
	_place_safety_light()
	_furnish_rooms()


func _cell(x: int, z: int) -> String:
	if x < 0 or z < 0 or x >= w or z >= h:
		return "#"
	return grid[z][x]


func _is_floor(x: int, z: int) -> bool:
	var c := _cell(x, z)
	return c != "#" and c != "W" and c != "x"


func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, 0.0, (c.y + 0.5) * CELL)


func cell_of_world(pos: Vector3) -> Vector2i:
	return Vector2i(clampi(int(floor(pos.x / CELL)), 0, w - 1), clampi(int(floor(pos.z / CELL)), 0, h - 1))


func _build_slabs() -> void:
	var fm := _mat_pbr("concrete_floor_worn_001", Color(0.55, 0.56, 0.58), 0.0, 0.45)
	var cm := _mat_pbr("concrete_wall_004", Color(0.30, 0.31, 0.33), 0.0, 0.35)
	var floor_mi := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(w * CELL, 0.2, h * CELL)
	floor_mi.mesh = fb
	floor_mi.material_override = fm
	floor_mi.position = Vector3(w * CELL * 0.5, -0.1, h * CELL * 0.5)
	add_child(floor_mi)
	_add_slab_body(floor_mi)
	var ceil_mi := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = fb.size
	ceil_mi.mesh = cb
	ceil_mi.material_override = cm
	ceil_mi.position = Vector3(w * CELL * 0.5, ceil_h + 0.1, h * CELL * 0.5)
	add_child(ceil_mi)
	_add_slab_body(ceil_mi)


func _add_slab_body(mi: MeshInstance3D) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = (mi.mesh as BoxMesh).size
	cs.shape = sh
	sb.add_child(cs)
	add_child(sb)
	sb.position = mi.position


func _build_walls() -> void:
	var wm := _mat_pbr("plastered_wall", Color(0.62, 0.63, 0.60), 0.0, 0.4)
	var bm := _mat_pbr("concrete_wall_004", Color(0.52, 0.53, 0.56), 0.0, 0.4)
	var wall_col := wm if int(map["id"]) == 1 else bm
	for z in range(h):
		var run_start := -1
		for x in range(w + 1):
			var solid := false
			if x < w:
				var c := _cell(x, z)
				solid = (c == "#") or (c == "x")
			if solid and run_start < 0:
				run_start = x
			elif not solid and run_start >= 0:
				_add_wall_run(run_start, x, z, wall_col)
				run_start = -1
	for z in range(h):
		for x in range(w):
			if _cell(x, z) == "W":
				_make_window(x, z)


func _add_wall_run(x0: int, x1: int, z: int, mat: StandardMaterial3D) -> void:
	var length := (x1 - x0) * CELL
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(length, ceil_h, CELL)
	mi.mesh = b
	mi.material_override = mat
	mi.position = Vector3(x0 * CELL + length * 0.5, ceil_h * 0.5, z * CELL + CELL * 0.5)
	add_child(mi)
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = b.size
	cs.shape = sh
	sb.add_child(cs)
	add_child(sb)
	sb.position = mi.position


func _make_window(x: int, z: int) -> void:
	var wx := (x + 0.5) * CELL
	var wz := (z + 0.5) * CELL
	var dir := Vector3.ZERO
	if _is_floor(x, z + 1):
		dir = Vector3(0, 0, 1)
	elif _is_floor(x, z - 1):
		dir = Vector3(0, 0, -1)
	elif _is_floor(x + 1, z):
		dir = Vector3(1, 0, 0)
	elif _is_floor(x - 1, z):
		dir = Vector3(-1, 0, 0)
	if dir == Vector3.ZERO:
		return
	var rot_y := atan2(dir.x, dir.z)

	var frame := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(1.7, 1.3, 0.4)
	frame.mesh = fb
	frame.material_override = _mat_pbr("metal_plate", Color(0.42, 0.43, 0.45), 0.0, 0.9, true)
	frame.position = Vector3(wx, 1.6, wz) + dir * 0.55
	frame.rotation.y = rot_y
	add_child(frame)

	var glass := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(1.6, 1.2, 0.06)
	glass.mesh = gb
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.62, 0.70, 0.86)
	gm.emission_enabled = true
	gm.emission = Color(0.62, 0.72, 0.92)
	gm.emission_energy_multiplier = 1.15
	glass.material_override = gm
	glass.position = Vector3(wx, 1.6, wz) + dir * 0.62
	glass.rotation.y = rot_y
	add_child(glass)

	var l := OmniLight3D.new()
	l.light_color = Color(0.63, 0.72, 0.94)
	l.omni_range = 5.5
	l.light_energy = 0.85
	l.shadow_enabled = false
	l.position = Vector3(wx, 1.6, wz) + dir * 1.5
	add_child(l)
	light_sources.append(l.position)

	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.0, 3.0, 1.6)
	cs.shape = sh
	sb.add_child(cs)
	add_child(sb)
	sb.position = Vector3(wx, 1.5, wz)
	Sound.make_loop(self, "wind", l.position, -14.0, 14.0)


func _build_nav() -> void:
	nav = AStarGrid2D.new()
	nav.region = Rect2i(0, 0, w, h)
	nav.cell_size = Vector2(CELL, CELL)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	nav.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	nav.update()
	for z in range(h):
		for x in range(w):
			if not _is_floor(x, z):
				nav.set_point_solid(Vector2i(x, z), true)


# ------------------------------------------------------------ сущности карты
func _place_map_entities() -> void:
	var fid := int(map["id"])
	for z in range(h):
		for x in range(w):
			var c := _cell(x, z)
			var pos := cell_to_world(Vector2i(x, z))
			match c:
				"P":
					player_spawn_cell = Vector2i(x, z)
				"M":
					monster_spawn_cell = Vector2i(x, z)
				"m":
					patrol_cells.append(Vector2i(x, z))
				"+", "H":
					_make_door(x, z, c == "H")
				"L":
					_make_lamp(pos, Color(1.0, 0.80, 0.56), 1.05, 7.5, false)
				"l":
					_make_lamp(pos, Color(0.82, 0.88, 1.0), 0.9, 6.5, true)
				"r":
					_make_beacon(pos)
				"N":
					_make_interact(RadioNode.new(), pos)
				"F":
					_make_interact(FuseBox.new(), pos)
				"f":
					_make_interact(FusePickup.new(), pos)
				"n":
					var note := NotePickup.new()
					if fid == 1 and x < 8:
						note.note_key = "n1"
					elif fid == 1:
						note.note_key = "n2"
					else:
						note.note_key = "n3"
					_make_interact(note, pos)
				"b":
					_make_interact(BottlePickup.new(), pos)
				"T":
					_make_interact(EndTerminal.new(), pos)
				"B":
					_make_interact(BatteryPickup.new(), pos)
				"c":
					_make_interact(Lightstick.new(), pos)
				"1", "2":
					var link: Array = Game.STAIR_LINK[c]
					var target: int = link[0] if link[1] == fid else link[1]
					var s := StairGate.new()
					s.target_floor = target
					s.label = "Наверх" if target > fid else "Вниз"
					_make_interact(s, pos)
					_make_stair_steps(pos)
				"x":
					_make_speaker(x, z)
	if patrol_cells.is_empty():
		for z in range(h):
			for x in range(w):
				if _cell(x, z) == ".":
					patrol_cells.append(Vector2i(x, z))


## Эвакуационная безопасность SYS: фосфорные метки у проёмов и аварийные
## дубли света в комнатах без постоянных источников (P0 anti-dead-dark).
func _place_safety_light() -> void:
	for z in range(h):
		for x in range(w):
			var c := _cell(x, z)
			if c == "+" or c == "H":
				var yaw := 0.0
				if not (_is_floor(x - 1, z) and _is_floor(x + 1, z)):
					yaw = PI * 0.5
				_make_phosphor(cell_to_world(Vector2i(x, z)), yaw)
			elif c == "1" or c == "2":
				_make_phosphor(cell_to_world(Vector2i(x, z)), PI * 0.5)
	for rd in map["rooms"]:
		var r: Array = rd["rect"]
		var has_light := false
		for y in range(int(r[1]), int(r[3]) + 1):
			for x in range(int(r[0]), int(r[2]) + 1):
				var cc := _cell(x, y)
				if cc == "L" or cc == "l" or cc == "r" or cc == "W":
					has_light = true
		if has_light:
			continue
		var cw := _center_cell(r)
		if int(r[2]) - int(r[0]) > 5:
			var cp := cell_to_world(cw)
			_make_emergency(cp + Vector3(-3.0 * CELL, 0, 0))
			_make_emergency(cp + Vector3(3.0 * CELL, 0, 0))
		else:
			_make_emergency(cell_to_world(cw))


func _make_interact(node: Interactable, pos: Vector3) -> void:
	add_child(node)
	node.global_position = pos


func _make_door(x: int, z: int, locked: bool) -> void:
	var axis := "x"
	if _is_floor(x, z - 1) and _is_floor(x, z + 1):
		axis = "x"
	elif _is_floor(x - 1, z) and _is_floor(x + 1, z):
		axis = "z"
	var d := DoorGate.new()
	d.axis = axis
	d.locked = locked
	d.red = (not locked) and int(map["id"]) == 0 and z == 8 and x == 13
	d.mat = _mat_pbr("rusty_metal_02", Color(0.55, 0.55, 0.57), 0.4, 0.8, true)
	add_child(d)
	d.global_position = cell_to_world(Vector2i(x, z))
	if locked:
		Game.node_activated.connect(d.unlock_on_nodes)


func _make_lamp(pos: Vector3, col: Color, energy: float, radius: float, flick: bool) -> void:
	var y := ceil_h - 0.22
	var fix := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(0.9, 0.09, 0.28)
	fix.mesh = fb
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(0.8, 0.8, 0.8)
	em.emission_enabled = true
	em.emission = col
	em.emission_energy_multiplier = 1.4
	fix.material_override = em
	fix.position = Vector3(pos.x, y, pos.z)
	add_child(fix)

	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = radius
	l.shadow_enabled = false
	l.light_bake_mode = Light3D.BAKE_DYNAMIC
	l.position = Vector3(pos.x, y - 0.35, pos.z)
	add_child(l)
	light_sources.append(l.position)
	if flick:
		_flicker.append(l)
	else:
		_powered_fixtures.append(fix)
		_powered_lights.append(l)


func _make_beacon(pos: Vector3) -> void:
	var y := ceil_h - 0.4
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	dome.mesh = sm
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(0.4, 0.05, 0.03)
	em.emission_enabled = true
	em.emission = Color(0.9, 0.13, 0.09)
	em.emission_energy_multiplier = 1.6
	dome.material_override = em
	dome.position = Vector3(pos.x, y, pos.z)
	add_child(dome)
	var l := OmniLight3D.new()
	l.light_color = Color(0.95, 0.18, 0.12)
	l.light_energy = 0.7
	l.omni_range = 6.0
	l.shadow_enabled = false
	l.position = Vector3(pos.x, y - 0.4, pos.z)
	add_child(l)
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "light_energy", 0.12, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(l, "light_energy", 0.7, 0.9).set_trans(Tween.TRANS_SINE)
	light_sources.append(l.position)


## Аварийный дублирующий свет: тёплый 2700K, без теней. Физика — аккумуляторные
## LED-светильники эвакуационной системы. Гарантия P0: без фонаря не чёрный экран.
func _make_emergency(pos: Vector3) -> void:
	var y := ceil_h - 1.15
	var fix := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(0.34, 0.14, 0.12)
	fix.mesh = fb
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(0.5, 0.42, 0.3)
	em.emission_enabled = true
	em.emission = Color(1.0, 0.62, 0.38)
	em.emission_energy_multiplier = 1.6
	fix.material_override = em
	fix.position = Vector3(pos.x, y, pos.z)
	add_child(fix)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.62, 0.38)
	l.light_energy = 0.55
	l.omni_range = 5.5
	l.shadow_enabled = false
	l.position = Vector3(pos.x, y - 0.25, pos.z)
	add_child(l)
	light_sources.append(l.position)


## Фосфоресцирующая эвакуационная метка: слабое зелёное свечение, читается
## в темноте, отмечает проёмы (правило 9 — свет ведёт игрока).
func _make_phosphor(pos: Vector3, yaw: float) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.55, 0.10)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.28, 0.14)
	m.emission_enabled = true
	m.emission = Color(0.55, 0.75, 0.35)
	m.emission_energy_multiplier = 0.85
	mi.material_override = m
	mi.position = Vector3(pos.x, 0.06, pos.z)
	mi.rotation.y = yaw
	add_child(mi)
	light_sources.append(mi.position + Vector3(0, 0.3, 0))


func _make_speaker(x: int, z: int) -> void:
	var dir := Vector3.ZERO
	if _is_floor(x, z + 1):
		dir = Vector3(0, 0, 1)
	elif _is_floor(x, z - 1):
		dir = Vector3(0, 0, -1)
	elif _is_floor(x + 1, z):
		dir = Vector3(1, 0, 0)
	elif _is_floor(x - 1, z):
		dir = Vector3(-1, 0, 0)
	var pos := cell_to_world(Vector2i(x, z)) + dir * 0.75 + Vector3(0, ceil_h - 0.6, 0)
	var sp := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.34, 0.2)
	sp.mesh = bm
	sp.material_override = _mat("metal", Color(0.2, 0.2, 0.21), 0.6, 0.7, 0.2)
	sp.position = pos
	sp.rotation.y = atan2(dir.x, dir.z)
	add_child(sp)
	Sound.make_loop(self, "radio_loop", pos, -22.0, 12.0)
	speaker_positions.append(pos)


func _make_stair_steps(pos: Vector3) -> void:
	for i in range(7):
		var st := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(1.6, 0.18, 0.55)
		st.mesh = b
		st.material_override = _mat("metal", Color(0.23, 0.24, 0.25), 0.7, 0.6, 0.1)
		st.position = pos + Vector3(0, 0.14 + i * 0.16, 0.9 - i * 0.26)
		add_child(st)


# ------------------------------------------------------------ наполнение
func _furnish_rooms() -> void:
	for rd in map["rooms"]:
		var r: Array = rd["rect"]
		var style: String = rd["style"]
		var name_: String = rd["name"]
		var room_rng := RandomNumberGenerator.new()
		room_rng.seed = hash(name_) + int(map["id"]) * 7919
		_style_props(r, style, room_rng)
		_decor_room(r, room_rng)


func _edge_cell(r: Array, rng: RandomNumberGenerator) -> Variant:
	var x0: int = r[0]
	var y0: int = r[1]
	var x1: int = r[2]
	var y1: int = r[3]
	for attempt in range(14):
		var x: int = rng.randi_range(x0, x1)
		var z: int = rng.randi_range(y0, y1)
		if not _is_floor(x, z):
			continue
		if x == x0 or x == x1 or z == y0 or z == y1:
			return Vector2i(x, z)
	return null


func _center_cell(r: Array) -> Vector2i:
	return Vector2i(int((r[0] + r[2]) / 2.0), int((r[1] + r[3]) / 2.0))


func _box_prop(pos: Vector3, size: Vector3, col: Color, rot_deg: float, rough := 0.85, metal := 0.0, collide := true) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat("prop", col, rough, metal, 0.09)
	mi.position = Vector3(0, size.y * 0.5, 0)
	mi.rotation.y = deg_to_rad(rot_deg)
	root.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.rotation.y = deg_to_rad(rot_deg)
		cs.position = Vector3(0, size.y * 0.5, 0)
		sb.add_child(cs)
		root.add_child(sb)
	return root


func _cyl_prop(pos: Vector3, radius: float, height: float, col: Color, rot := Vector3.ZERO, collide := true) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	mi.mesh = c
	mi.material_override = _mat("metal_c", col, 0.6, 0.65, 0.05)
	mi.position = Vector3(0, height * 0.5, 0)
	mi.rotation = rot
	root.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = radius
		sh.height = height
		cs.shape = sh
		cs.position = Vector3(0, height * 0.5, 0)
		cs.rotation = rot
		sb.add_child(cs)
		root.add_child(sb)
	return root


func _style_props(r: Array, style: String, rng: RandomNumberGenerator) -> void:
	var ctr := _center_cell(r)
	var cp := cell_to_world(ctr)
	match style:
		"guardpost":
			_box_prop(cp + Vector3(-0.8, 0, 0.4), Vector3(1.8, 0.75, 0.8), Color(0.30, 0.27, 0.24), 90)
			_box_prop(cp + Vector3(0.9, 0, -0.5), Vector3(0.7, 1.8, 0.5), Color(0.20, 0.21, 0.22), 0, 0.6, 0.65)
			Sound.make_loop(self, "radio_loop", cp, -20.0, 10.0)
		"hall":
			_box_prop(cp + Vector3(-1.2, 0, 0.3), Vector3(2.4, 0.45, 0.6), Color(0.28, 0.26, 0.23), 90)
			_box_prop(cp + Vector3(1.4, 0, -0.4), Vector3(1.0, 1.5, 0.9), Color(0.19, 0.20, 0.21), 0, 0.6, 0.65)
		"office":
			_box_prop(cp + Vector3(0, 0, 0.2), Vector3(1.9, 0.75, 0.85), Color(0.27, 0.25, 0.22), 0)
			_box_prop(cp + Vector3(-1.4, 0, -0.6), Vector3(0.9, 2.1, 0.5), Color(0.24, 0.23, 0.21), 90)
		"radio":
			for i in range(3):
				_box_prop(cp + Vector3(-1.5 + i * 1.2, 0, -0.9), Vector3(1.0, 1.9, 0.6), Color(0.16, 0.18, 0.17), 0, 0.6, 0.6)
			_led_rack(cp + Vector3(-1.5, 0, -0.9))
			Sound.make_loop(self, "hum_room", cp, -18.0, 14.0)
		"server":
			for i in range(3):
				_box_prop(cp + Vector3(-1.4 + i * 1.3, 0, -1.0), Vector3(1.1, 2.0, 0.65), Color(0.14, 0.16, 0.15), 0, 0.6, 0.6)
			_led_rack(cp + Vector3(-1.4, 0, -1.0))
			Sound.make_loop(self, "hum_transformer", cp, -14.0, 14.0)
		"oproom":
			_box_prop(cp + Vector3(-0.9, 0, 0), Vector3(1.7, 0.75, 0.8), Color(0.29, 0.26, 0.23), 90)
			_box_prop(cp + Vector3(1.0, 0, 0.4), Vector3(0.6, 0.4, 0.4), Color(0.22, 0.23, 0.24), 0, 0.6, 0.65)
			Sound.make_loop(self, "radio_loop", cp, -18.0, 11.0)
		"shower":
			for i in range(3):
				_box_prop(cp + Vector3(-1.2 + i * 1.2, 0, -1.3), Vector3(1.1, 2.0, 0.08), Color(0.45, 0.47, 0.45), 0, 0.5, 0.1, false)
			var ec: Variant = _edge_cell(r, rng)
			if ec != null:
				_make_drip(cell_to_world(ec))
		"storage", "storage_small":
			for i in range(2):
				_box_prop(cp + Vector3(-1.4 + i * 2.4, 0, -0.8), Vector3(1.6, 1.9, 0.5), Color(0.24, 0.25, 0.24), 0, 0.6, 0.65)
			_box_prop(cp + Vector3(0.4, 0, 1.2), Vector3(0.6, 0.55, 0.6), Color(0.30, 0.27, 0.24), 30)
		"canteen":
			for i in range(2):
				_box_prop(cp + Vector3(-1.6 + i * 2.6, 0, 0), Vector3(1.9, 0.75, 0.9), Color(0.33, 0.29, 0.25), 0)
			_box_prop(cp + Vector3(0, 0, 1.4), Vector3(2.2, 0.9, 0.5), Color(0.24, 0.25, 0.24), 0, 0.6, 0.65, false)
		"lift":
			_box_prop(cp, Vector3(1.6, 2.4, 1.6), Color(0.031, 0.032, 0.038), 0, 0.95, 0.0, true)
			_box_prop(cp + Vector3(0, 0, 1.05), Vector3(0.9, 2.2, 0.08), Color(0.30, 0.26, 0.20), 0, 0.6, 0.7, false)
			Sound.make_loop(self, "wind", cp, -22.0, 8.0)
		"stairs":
			pass
		"generator":
			_box_prop(cp + Vector3(0.4, 0, 0.3), Vector3(2.6, 1.4, 1.5), Color(0.24, 0.27, 0.26), 0, 0.6, 0.65)
			_cyl_prop(cp + Vector3(2.2, 0, -0.6), 0.45, 1.6, Color(0.22, 0.24, 0.25))
			_cyl_prop(cp + Vector3(-2.0, 0, 0.8), 0.4, 1.4, Color(0.20, 0.22, 0.23), Vector3(0, 0, deg_to_rad(90)))
			Sound.make_loop(self, "hum_transformer", cp, -10.0, 16.0)
		"boiler":
			for i in range(3):
				_cyl_prop(cp + Vector3(-1.6 + i * 1.5, 0, -0.4), 0.65, 2.2, Color(0.26, 0.22, 0.20))
			_pipes_wall(r, rng)
			Sound.make_loop(self, "wind", cp, -18.0, 10.0)
		"gallery":
			_pipes_wall(r, rng)
			_make_drip(cp)
		"tunnel":
			_pipes_wall(r, rng)
			_make_drip(cp + Vector3(0, 0, 1.4))
		"cage":
			_antenna(cp)
			_mannequin(cp + Vector3(1.6, 0, 1.2))
			Sound.make_loop(self, "wind", cp, -16.0, 20.0)
			Sound.make_loop(self, "drone_dark", cp, -16.0, 18.0)
		"archive":
			for i in range(2):
				_box_prop(cp + Vector3(-1.2 + i * 2.4, 0, -0.9), Vector3(1.8, 2.0, 0.5), Color(0.25, 0.24, 0.22), 0)
			Sound.make_loop(self, "hum_room", cp, -24.0, 10.0)
		"machine":
			for i in range(4):
				_box_prop(cp + Vector3(-2.6 + i * 1.6, 0, -1.1), Vector3(1.0, 1.7, 0.5), Color(0.17, 0.19, 0.18), 0, 0.6, 0.65)
			_mannequin(cp + Vector3(0.5, 0, 1.0))
			Sound.make_loop(self, "hum_transformer", cp, -16.0, 16.0)
		"corridor", "corridor_south", "corridor_basement":
			_pipes_wall(r, rng)
			_box_prop(cp + Vector3(0, 0, 0), Vector3(0.5, 0.6, 0.5), Color(0.22, 0.20, 0.19), 15, 0.9, 0.0, false)


func _led_rack(pos: Vector3) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.03, 0.03)
	m.emission_enabled = true
	m.emission = Color(0.55, 0.24, 0.12)
	m.emission_energy_multiplier = 1.2
	for i in range(4):
		var led := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.05, 0.02)
		led.mesh = bm
		led.material_override = m
		led.position = pos + Vector3(0.3, 1.1 + 0.18 * i, 0.34)
		add_child(led)


func _antenna(pos: Vector3) -> void:
	var col := Color(0.14, 0.15, 0.16)
	for i in range(8):
		var a := i * TAU / 8.0
		var off := Vector3(cos(a), 0, sin(a)) * 1.9
		_box_prop(pos + off, Vector3(0.09, 2.55, 0.09), col, 0, 0.6, 0.7, false)
	for k in range(3):
		_box_prop(pos + Vector3(0, 0.6 + k * 0.8, 0), Vector3(3.9, 0.07, 0.07), col, 0, 0.6, 0.7, false)
		_box_prop(pos + Vector3(0, 0.6 + k * 0.8, 0), Vector3(0.07, 0.07, 3.9), col, 0, 0.6, 0.7, false)
	_cyl_prop(pos + Vector3(0, 2.5, 0), 0.07, 2.6, col)


func _mannequin(pos: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos + Vector3(0, 0.25, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.30, 0.28, 0.26)
	m.roughness = 0.9
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.18
	cm.height = 1.1
	body.mesh = cm
	body.material_override = m
	body.rotation.z = deg_to_rad(90)
	root.add_child(body)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.13
	hm.height = 0.26
	head.mesh = hm
	head.material_override = m
	head.position = Vector3(0.62, 0, 0.05)
	root.add_child(head)


func _pipes_wall(r: Array, rng: RandomNumberGenerator) -> void:
	var x0: int = r[0]
	var y0: int = r[1]
	var x1: int = r[2]
	var y1: int = r[3]
	var wide := (x1 - x0) > (y1 - y0)
	var yy := ceil_h - 0.45
	if wide:
		var zm := (y0 + y1) * 0.5 * CELL + CELL
		var xa := (x0 + 0.3) * CELL
		var xb := (x1 + 0.7) * CELL
		var mid := (xa + xb) * 0.5
		var pipe_len := xb - xa
		_pipe_mesh(Vector3(mid, yy, zm - 0.5), pipe_len, 0.07, Color(0.24, 0.26, 0.27), true)
		_pipe_mesh(Vector3(mid + rng.randf_range(-1, 1), yy - 0.28, zm - 0.05), pipe_len * 0.98, 0.05, Color(0.30, 0.25, 0.20), true)
	else:
		var xm := (x0 + x1) * 0.5 * CELL + CELL
		var za := (y0 + 0.3) * CELL
		var zb := (y1 + 0.7) * CELL
		var mid2 := (za + zb) * 0.5
		var pipe_len2 := zb - za
		_pipe_mesh(Vector3(xm - 0.5, yy, mid2), pipe_len2, 0.07, Color(0.24, 0.26, 0.27), false)


func _pipe_mesh(pos: Vector3, length: float, radius: float, col: Color, along_x: bool) -> void:
	var c := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = length
	c.mesh = cm
	c.material_override = _mat("pipe", col, 0.65, 0.6, 0.05)
	c.rotation = Vector3(deg_to_rad(90), 0, 0) if along_x else Vector3(deg_to_rad(90), 0, deg_to_rad(90))
	c.position = pos
	add_child(c)


func _make_drip(pos: Vector3) -> void:
	_drips.append({"t": randf_range(2.0, 7.0), "pos": pos})


func _decor_room(r: Array, rng: RandomNumberGenerator) -> void:
	var x0: int = r[0]
	var y0: int = r[1]
	var x1: int = r[2]
	var y1: int = r[3]
	var area := (x1 - x0 + 1) * (y1 - y0 + 1)
	var decals := clampi(area / 8, 1, 4)
	for i in range(decals):
		var x: int = rng.randi_range(x0, x1)
		var z: int = rng.randi_range(y0, y1)
		if not _is_floor(x, z):
			continue
		var d := Decal.new()
		var n := FastNoiseLite.new()
		n.frequency = 0.10
		n.seed = 33 + i
		var t := NoiseTexture2D.new()
		t.noise = n
		t.width = 64
		t.height = 64
		d.texture_albedo = t
		d.size = Vector3(rng.randf_range(1.4, 2.6), 1.4, rng.randf_range(1.4, 2.6))
		d.modulate = Color(0.20, 0.18, 0.15, 0.55)
		add_child(d)
		d.position = cell_to_world(Vector2i(x, z)) + Vector3(0, 0.62, 0)
	var debris := clampi(area / 6, 1, 5)
	for i in range(debris):
		var x2: int = rng.randi_range(x0, x1)
		var z2: int = rng.randi_range(y0, y1)
		if not _is_floor(x2, z2):
			continue
		var s := rng.randf_range(0.08, 0.25)
		_box_prop(cell_to_world(Vector2i(x2, z2)) + Vector3(rng.randf_range(-0.7, 0.7), 0, rng.randf_range(-0.7, 0.7)),
			Vector3(s, s, s), Color(0.24, 0.22, 0.20), rng.randf_range(0, 90), 0.95, 0.0, false)


# ------------------------------------------------------------ время
func _process(delta: float) -> void:
	for l in _flicker:
		if randf() < 0.02:
			l.light_energy = randf_range(0.0, 0.9)
		elif randf() < 0.06:
			l.light_energy = randf_range(0.4, 0.95)
	for d in _drips:
		d["t"] -= delta
		if d["t"] <= 0.0:
			d["t"] = randf_range(3.0, 9.0)
			Sound.play_at(self, "drip", d["pos"], -8.0, 14.0, randf_range(0.85, 1.2))


func set_power(on: bool) -> void:
	for f in _powered_fixtures:
		(f.material_override as StandardMaterial3D).emission_energy_multiplier = 2.1
	for l in _powered_lights:
		l.light_energy *= 1.55


func player_spawn() -> Vector3:
	return cell_to_world(player_spawn_cell)
