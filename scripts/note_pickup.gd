extends Interactable
class_name NotePickup
## Записка на столе/полке — фиксированная на месте (можно перечитать).

var note_key := "n1"


func _ready() -> void:
	setup_box(Vector3(0.8, 0.5, 0.8), Vector3(0, 0.1, 0))
	var paper := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.30, 0.42)
	paper.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.82, 0.80, 0.72)
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	paper.material_override = m
	paper.position = Vector3(0, 0.02, 0)
	paper.rotation_degrees = Vector3(-90, 8, 0)
	add_child(paper)


func get_prompt() -> String:
	return "[E] Прочитать"


func interact(_player: Node3D) -> void:
	Game.note_read()
	Sound.play_at(self, "pickup", global_position, -16.0, 10.0, 0.7)
	if Game.ui != null:
		Game.ui.show_note(note_key)
