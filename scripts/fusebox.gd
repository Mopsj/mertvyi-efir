extends Interactable
class_name FuseBox
## Предохранительный щиток генераторной. Нужны 3 предохранителя.

var _lamp_mat: StandardMaterial3D


func _ready() -> void:
	setup_box(Vector3(1.2, 1.6, 0.8), Vector3(0, 1.0, 0))
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 1.4, 0.28)
	body.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.36, 0.38, 0.33)
	m.metallic = 0.5
	m.roughness = 0.5
	body.material_override = m
	body.position = Vector3(0, 1.2, -0.3)
	add_child(body)

	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color(0.1, 0.1, 0.1)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(0.05, 0.0, 0.0)
	_lamp_mat.emission_energy_multiplier = 0.5
	var lamp := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.07
	lm.height = 0.14
	lamp.mesh = lm
	lamp.material_override = _lamp_mat
	lamp.position = Vector3(0, 1.75, -0.3)
	add_child(lamp)

	Game.power_on.connect(func() -> void:
		_lamp_mat.emission = Color(0.75, 0.12, 0.08)
		_lamp_mat.emission_energy_multiplier = 1.4)


func get_prompt() -> String:
	if Game.power:
		return "Щиток под напряжением"
	return "[E] Установить предохранители (%d/3)" % Game.fuses


func interact(_player: Node3D) -> void:
	if Game.power:
		return
	if Game.fuses < Game.MAX_FUSES:
		Sound.play_at(self, "static_burst", global_position, -20.0, 12.0, 0.6)
		return
	if Game.install_fuse():
		Sound.play_at(self, "fuse_install", global_position, -2.0, 40.0)
		Game.emit_noise(global_position, Game.current_floor, 22.0)
