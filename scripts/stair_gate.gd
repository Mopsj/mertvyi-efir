extends Interactable
class_name StairGate
## Лестничный переход между этажами (fade-переход).

var target_floor := 1
var label := ""


func _ready() -> void:
	setup_box(Vector3(1.8, 2.0, 1.8), Vector3(0, 1.0, 0))
	if label != "":
		var sign := Label3D.new()
		sign.text = label
		sign.font_size = 40
		sign.pixel_size = 0.004
		sign.modulate = Color(0.72, 0.76, 0.70)
		add_child(sign)


func get_prompt() -> String:
	return "[E] Лестница"


func interact(_player: Node3D) -> void:
	if Game.main != null:
		Game.main.change_floor(target_floor)
