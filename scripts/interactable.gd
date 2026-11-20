class_name Interactable
extends Area3D
## База интерактива: форма коллизии + контракт подсказки/действия.

func _init() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	add_to_group("interact")


func setup_box(size: Vector3, offset: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = offset
	add_child(cs)


func get_prompt() -> String:
	return ""


func interact(_player: Node3D) -> void:
	pass
