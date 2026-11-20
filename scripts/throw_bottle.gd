extends RigidBody3D
class_name ThrownBottle
## Брошенная бутыль: шум при ударе — используется как приманка.

var noise_loudness := 26.0
var _done := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	contact_monitor = true
	max_contacts_reported = 2
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.12
	cs.shape = sh
	add_child(cs)
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.07
	cm.height = 0.3
	body.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.42, 0.50, 0.44)
	m.roughness = 0.15
	body.material_override = m
	add_child(body)
	body_entered.connect(_on_hit)
	get_tree().create_timer(9.0).timeout.connect(queue_free)


func _on_hit(_b: Node) -> void:
	if _done or not is_inside_tree():
		return
	_done = true
	Sound.play_at(get_parent(), "clatter", global_position, -3.0, 34.0, randf_range(0.9, 1.1))
	Game.emit_noise(global_position, Game.current_floor, noise_loudness)
