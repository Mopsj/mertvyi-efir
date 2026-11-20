extends Interactable
class_name BottlePickup
## Стеклянная бутыль — приманка (Q — бросить).


func _ready() -> void:
	setup_box(Vector3(0.5, 0.5, 0.5), Vector3(0, 0.1, 0))
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.07
	cm.height = 0.3
	body.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.42, 0.50, 0.44)
	m.roughness = 0.15
	m.metallic = 0.1
	body.material_override = m
	body.position = Vector3(0, 0.15, 0)
	add_child(body)


func get_prompt() -> String:
	return "[E] Взять бутыль"


func interact(_player: Node3D) -> void:
	Game.bottles += 1
	Game.pickups_changed()
	Sound.play_at(self, "pickup", global_position, -10.0, 14.0, 1.3)
	queue_free()
