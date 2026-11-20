extends Interactable
class_name FusePickup
## Керамический предохранитель на полке/станке.


func _ready() -> void:
	setup_box(Vector3(0.6, 0.6, 0.6), Vector3(0, 0.2, 0))
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.045
	cm.bottom_radius = 0.045
	cm.height = 0.22
	body.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.74, 0.62)
	m.roughness = 0.35
	body.material_override = m
	body.position = Vector3(0, 0.2, 0)
	add_child(body)
	for sx in [-1.0, 1.0]:
		var cap := MeshInstance3D.new()
		var cm2 := CylinderMesh.new()
		cm2.top_radius = 0.055
		cm2.bottom_radius = 0.055
		cm2.height = 0.03
		cap.mesh = cm2
		var cm3 := StandardMaterial3D.new()
		cm3.albedo_color = Color(0.6, 0.58, 0.55)
		cm3.metallic = 0.8
		cap.material_override = cm3
		cap.position = Vector3(0, 0.2 + sx * 0.105, 0)
		add_child(cap)


func get_prompt() -> String:
	return "[E] Взять предохранитель"


func interact(_player: Node3D) -> void:
	Game.fuses += 1
	Sound.play_at(self, "pickup", global_position, -6.0)
	Game.pickups_changed()
	queue_free()
