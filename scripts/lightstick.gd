extends Interactable
class_name Lightstick
## Химический светильник (эвакуационный). Одноразовая альтернатива фонарю:
## после активации даёт постоянный слабый зелёный свет.

var _used := false
var _tube: MeshInstance3D
var _lamp: OmniLight3D


func _ready() -> void:
	setup_box(Vector3(0.4, 0.5, 0.4), Vector3(0, 0.25, 0))
	_tube = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.03
	cm.height = 0.26
	_tube.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.20, 0.12)
	m.roughness = 0.5
	_tube.material_override = m
	_tube.position = Vector3(0, 0.35, 0)
	add_child(_tube)
	var base := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.12, 0.18, 0.12)
	base.mesh = b
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.30, 0.32, 0.30)
	bm.roughness = 0.5
	bm.metallic = 0.4
	base.material_override = bm
	base.position = Vector3(0, 0.09, 0)
	add_child(base)


func get_prompt() -> String:
	if _used:
		return ""
	return "[E] Активировать химсветильник"


func interact(_player: Node3D) -> void:
	if _used:
		return
	_used = true
	var m := _tube.material_override as StandardMaterial3D
	m.emission_enabled = true
	m.emission = Color(0.70, 0.92, 0.42)
	m.emission_energy_multiplier = 1.5
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(0.70, 0.92, 0.42)
	_lamp.light_energy = 0.75
	_lamp.omni_range = 6.0
	_lamp.shadow_enabled = false
	_lamp.position = Vector3(0, 0.4, 0)
	add_child(_lamp)
	monitoring = false
	var lb := get_parent() as LevelBuilder
	if lb != null:
		lb.light_sources.append(global_position + Vector3(0, 0.4, 0))
	Sound.play_at(self, "pickup", global_position, -12.0, 8.0, 1.8)
	Game.emit_noise(global_position, Game.current_floor, 3.0)
