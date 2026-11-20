extends Interactable
class_name DoorGate
## Сдвижная стальная дверь. kind="door" — обычная; kind="hatch" — люк тоннеля.

var axis := "x"            # вдоль какой оси лежит проём
var is_open := false
var locked := false
var mat: StandardMaterial3D = null
var red := false

var _slab: StaticBody3D
var _colshape: CollisionShape3D
var _closed_y := 0.0
var _busy := false


func _ready() -> void:
	add_to_group("doors")
	var body_mat: StandardMaterial3D = mat if mat != null else StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.30, 0.30, 0.32) if not red else Color(0.42, 0.16, 0.13)
	body_mat.metallic = 0.7
	body_mat.roughness = 0.55

	_slab = StaticBody3D.new()
	_slab.collision_layer = 1
	_slab.collision_mask = 0
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.0, 2.2, 0.12) if axis == "x" else Vector3(0.12, 2.2, 2.0)
	mi.mesh = bm
	mi.material_override = body_mat
	_slab.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = bm.size
	cs.shape = sh
	_slab.add_child(cs)
	_colshape = cs
	add_child(_slab)
	_closed_y = _slab.position.y
	_slab.position.y = 1.1

	var frame_m := StandardMaterial3D.new()
	frame_m.albedo_color = Color(0.13, 0.13, 0.14)
	for sx in [-1.0, 1.0]:
		var f := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.12, 2.3, 0.22) if axis == "x" else Vector3(0.22, 2.3, 0.12)
		f.mesh = fm
		f.material_override = frame_m
		f.position = Vector3(sx, 1.15, 0.0) if axis == "x" else Vector3(0.0, 1.15, sx)
		add_child(f)

	if red:
		var sign := Label3D.new()
		sign.text = "ОПАСНО\nНЕ ВХОДИТЬ"
		sign.font_size = 42
		sign.pixel_size = 0.004
		sign.modulate = Color(0.9, 0.3, 0.24)
		sign.position = Vector3(0.0, 1.5, 0.08) if axis == "x" else Vector3(0.08, 1.5, 0.0)
		add_child(sign)

	setup_box(Vector3(2.2, 2.3, 1.2) if axis == "x" else Vector3(1.2, 2.3, 2.2), Vector3(0, 1.15, 0))


func get_prompt() -> String:
	if locked:
		return "Заперто. Нужно: все 4 узла связи"
	if is_open:
		return "[E] Закрыть дверь"
	return "[E] Открыть дверь"


func interact(_player: Node3D) -> void:
	_toggle(false)


func force_open() -> void:
	if not is_open:
		_toggle(true)


func _toggle(by_monster: bool) -> void:
	if _busy or locked:
		return
	_busy = true
	is_open = !is_open
	var target_y := _closed_y - 2.05 if is_open else _closed_y
	var tw := create_tween()
	tw.tween_property(_slab, "position:y", target_y, 1.2 if not by_monster else 1.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	Sound.play_at(self, "door_metal", global_position, -6.0)
	Game.emit_noise(global_position, Game.current_floor, 12.0)
	tw.finished.connect(func() -> void:
		if is_instance_valid(_colshape):
			_colshape.set_deferred("disabled", is_open)
		_busy = false)
