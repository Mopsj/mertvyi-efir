extends Interactable
class_name RadioNode
## Узел связи. Без питания — мёртв. С питанием — активация (громкий процесс).

var is_active := false
var _busy := false

var _screen_mat: StandardMaterial3D


func _ready() -> void:
	setup_box(Vector3(1.6, 1.8, 1.6), Vector3(0, 0.9, 0))

	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.1, 1.7, 0.7)
	body.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.24, 0.26, 0.24)
	m.roughness = 0.6
	m.metallic = 0.4
	body.material_override = m
	body.position = Vector3(0, 0.85, 0)
	add_child(body)

	_screen_mat = StandardMaterial3D.new()
	_screen_mat.albedo_color = Color(0.02, 0.03, 0.02)
	_screen_mat.emission_enabled = true
	_screen_mat.emission = Color(0.02, 0.05, 0.04)
	_screen_mat.emission_energy_multiplier = 0.3
	var screen := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.5, 0.36, 0.02)
	screen.mesh = sm
	screen.material_override = _screen_mat
	screen.position = Vector3(0, 1.18, 0.36)
	add_child(screen)


func get_prompt() -> String:
	if is_active:
		return "Узел работает"
	if not Game.power:
		return "Узел мёртв. Нет питания"
	if _busy:
		return "Выход в эфир..."
	return "[E] Запустить узел связи"


func interact(_player: Node3D) -> void:
	if is_active or _busy:
		return
	if not Game.power:
		Sound.play_at(self, "static_burst", global_position, -14.0, 18.0)
		return
	_busy = true
	Game.activate_begin()
	Sound.play_at(self, "node_on", global_position, -4.0, 40.0)
	Game.emit_noise(global_position, Game.current_floor, 26.0)
	for i in range(3):
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree() or Game.ended:
			return
		Game.emit_noise(global_position, Game.current_floor, 30.0)
	_screen_mat.emission = Color(0.36, 0.78, 0.55)
	_screen_mat.emission_energy_multiplier = 1.1
	is_active = true
	_busy = false
	Game.activate_node()
