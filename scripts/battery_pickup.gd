extends Interactable
class_name BatteryPickup
## Элемент питания от налобного фонаря. Восстанавливает заряд до 100%.

var battery := 100.0


func _ready() -> void:
	setup_box(Vector3(0.45, 0.45, 0.45), Vector3(0, 0.12, 0))
	var body := MeshInstance3D.new()
	var b := CylinderMesh.new()
	b.top_radius = 0.055
	b.bottom_radius = 0.055
	b.height = 0.16
	body.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.18, 0.30, 0.22)
	m.roughness = 0.4
	m.metallic = 0.3
	body.material_override = m
	body.position = Vector3(0, 0.08, 0)
	add_child(body)
	var cap := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.05
	c.bottom_radius = 0.05
	c.height = 0.03
	cap.mesh = c
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(0.7, 0.68, 0.62)
	mc.metallic = 0.85
	mc.roughness = 0.3
	cap.material_override = mc
	cap.position = Vector3(0, 0.17, 0)
	add_child(cap)
	var led := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.016
	s.height = 0.032
	led.mesh = s
	var me := StandardMaterial3D.new()
	me.albedo_color = Color(0.2, 0.3, 0.2)
	me.emission_enabled = true
	me.emission = Color(0.35, 0.85, 0.45)
	me.emission_energy_multiplier = 1.4
	led.material_override = me
	led.position = Vector3(0.05, 0.17, 0)
	add_child(led)


func get_prompt() -> String:
	return "[E] Взять батарею"


func interact(player: Node3D) -> void:
	if player != null and player.has_method("recharge_battery"):
		player.recharge_battery(battery)
	Sound.play_at(self, "pickup", global_position, -6.0, 10.0, 0.8)
	Game.ui.flash_warning("Батарея заменена")
	Game.emit_noise(global_position, Game.current_floor, 4.0)
	queue_free()
