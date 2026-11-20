extends Interactable
class_name EndTerminal
## Терминал антенной клетки: финальный выбор.

var _screen_mat: StandardMaterial3D


func _ready() -> void:
	setup_box(Vector3(1.0, 1.8, 1.0), Vector3(0, 0.9, 0))
	var pedestal := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 1.1, 0.6)
	pedestal.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.20, 0.22, 0.21)
	m.metallic = 0.5
	m.roughness = 0.5
	pedestal.material_override = m
	pedestal.position = Vector3(0, 0.55, 0)
	add_child(pedestal)

	_screen_mat = StandardMaterial3D.new()
	_screen_mat.albedo_color = Color(0.01, 0.02, 0.01)
	_screen_mat.emission_enabled = true
	_screen_mat.emission = Color(0.02, 0.05, 0.04)
	_screen_mat.emission_energy_multiplier = 0.25
	var screen := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.55, 0.4, 0.03)
	screen.mesh = sm
	screen.material_override = _screen_mat
	screen.position = Vector3(0, 1.28, 0.0)
	screen.rotation_degrees = Vector3(-12, 0, 0)
	add_child(screen)

	Game.power_on.connect(func() -> void:
		_screen_mat.emission_energy_multiplier = 0.7)


func get_prompt() -> String:
	if Game.nodes_done < Game.NODES_TOTAL:
		return "Терминал заблокирован: узлы без эфира"
	return "[E] Главный селектор станции"


func interact(_player: Node3D) -> void:
	if Game.nodes_done < Game.NODES_TOTAL:
		Sound.play_at(self, "static_burst", global_position, -16.0, 14.0)
		return
	if Game.ui != null:
		Game.ui.show_choice()
