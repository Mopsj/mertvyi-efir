extends CharacterBody3D
class_name Player
## Игрок: ходьба, бег (шумит), присед (тихо), фонарь (заряд),
## бросок бутыли, взаимодействие через RayCast3D.

const WALK := 3.1
const SPRINT := 5.6
const CROUCH := 1.5
const ACCEL := 10.0
const MOUSE_SENS := 0.0022

const NOISE_WALK := 8.0
const NOISE_SPRINT := 19.0
const NOISE_CROUCH := 2.5

var look_sens := MOUSE_SENS
var crouching := false
var battery := 100.0

var _cam: Camera3D
var _lamp: SpotLight3D
var _ray: RayCast3D
var _head: Node3D
var _lamp_on := false
var _low_warn := false
var _step_phase := 0.0
var _bob_t := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	cs.name = "CollisionShape3D"
	add_child(cs)

	_head = Node3D.new()
	_head.position = Vector3(0, 1.55, 0)
	add_child(_head)
	_cam = Camera3D.new()
	_cam.fov = 78.0
	_cam.near = 0.05
	_cam.far = 60.0
	_head.add_child(_cam)

	_lamp = SpotLight3D.new()
	_lamp.spot_range = 13.0
	_lamp.spot_angle = 27.0
	_lamp.light_color = Color(1.0, 0.90, 0.74)
	_lamp.light_energy = 2.4
	_lamp.shadow_enabled = true
	_lamp.shadow_bias = 0.03
	_lamp.shadow_normal_bias = 1.2
	_lamp.spot_angle_attenuation = 1.4
	_lamp.distance_fade_enabled = true
	_lamp.distance_fade_begin = 9.0
	_lamp.distance_fade_length = 3.0
	_lamp.position = Vector3(0.16, -0.12, 0.05)
	_lamp.visible = false
	_cam.add_child(_lamp)

	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, 0, -2.3)
	_ray.collide_with_areas = true
	_ray.collide_with_bodies = false
	_ray.collision_mask = 8
	_cam.add_child(_ray)
	_cam.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * look_sens)
		_head.rotation.x = clampf(_head.rotation.x - event.relative.y * look_sens, -1.45, 1.45)
	elif event.is_action_pressed("flashlight"):
		_toggle_lamp()
	elif event.is_action_pressed("throw"):
		_throw_bottle()
	elif event.is_action_pressed("interact"):
		_try_interact()


func _physics_process(delta: float) -> void:
	if Game.ended or Game.ui.in_note or Game.ui.in_choice:
		velocity.x = move_toward(velocity.x, 0, ACCEL * delta)
		velocity.z = move_toward(velocity.z, 0, ACCEL * delta)
		velocity.y = -2.0
		move_and_slide()
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	crouching = Input.is_action_pressed("crouch")
	var sprinting: bool = Input.is_action_pressed("sprint") and input.length() > 0.1 and not crouching

	var speed := CROUCH if crouching else (SPRINT if sprinting else WALK)
	var dir: Vector3 = (transform.basis * Vector3(input.x, 0, input.y))
	dir.y = 0.0
	dir = dir.normalized() * input.length()
	velocity.x = move_toward(velocity.x, dir.x * speed, ACCEL * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, ACCEL * delta)
	velocity.y = -2.0

	var head_target := 1.05 if crouching else 1.55
	_head.position.y = lerpf(_head.position.y, head_target, 8.0 * delta)

	move_and_slide()

	var hspeed := Vector2(velocity.x, velocity.z).length()
	if hspeed > 0.4 and is_on_floor():
		var interval := 0.9 if crouching else (0.32 if sprinting else 0.52)
		_step_phase += hspeed * delta
		if _step_phase >= interval:
			_step_phase = 0.0
			_play_step(crouching, sprinting)
	_bob_t += delta * hspeed * 1.6
	_cam.position.y = sin(_bob_t) * 0.035
	_cam.position.x = cos(_bob_t * 0.5) * 0.02

	if _lamp_on:
		battery = maxf(0.0, battery - delta * 100.0 / 420.0)
		Game.battery_changed.emit(battery)
		if battery <= 0.0:
			_lamp_on = false
			_lamp.visible = false
			Game.ui.flash_warning("Фонарь погас. Ищи батарею, аварийные лампы или фосфорные метки")
	if battery < 20.0 and not _low_warn and _lamp_on:
		_low_warn = true
		Game.ui.flash_warning("Фонарь садится")
	var base_e := 2.4 * (0.35 + 0.65 * clampf(battery / 30.0, 0.0, 1.0))
	if battery < 20.0:
		base_e *= 1.0 - randf_range(0.0, 0.28 - battery * 0.01)
	_lamp.light_energy = base_e

	var t: Node = _ray.get_collider()
	if t != null and t.has_method("get_prompt"):
		Game.ui.set_prompt(t.get_prompt())
	else:
		Game.ui.set_prompt("")


func _play_step(crouch: bool, sprint: bool) -> void:
	var pos := global_position
	var parent := get_parent()
	if crouch:
		Sound.play_at(parent, "step_crouch", pos, -18.0, 10.0, randf_range(0.9, 1.1))
		Game.emit_noise(pos, Game.current_floor, NOISE_CROUCH)
	elif sprint:
		Sound.play_at(parent, "step", pos, -6.0, 26.0, randf_range(0.95, 1.08))
		Game.emit_noise(pos, Game.current_floor, NOISE_SPRINT)
	else:
		Sound.play_at(parent, "step", pos, -12.0, 18.0, randf_range(0.95, 1.08))
		Game.emit_noise(pos, Game.current_floor, NOISE_WALK)


func recharge_battery(v: float) -> void:
	battery = clampf(battery + v, 0.0, 100.0)
	if battery >= 20.0:
		_low_warn = false
	Game.battery_changed.emit(battery)
	Game.ui.flash_warning("Батарея: %d%%" % int(battery))


func _toggle_lamp() -> void:
	if battery <= 0.0:
		Sound.play_at(get_parent(), "pickup", global_position, -20.0, 6.0, 0.5)
		return
	_lamp_on = !_lamp_on
	_lamp.visible = _lamp_on
	Sound.play_at(get_parent(), "pickup", global_position, -14.0, 8.0, 1.6 if _lamp_on else 1.2)


func _throw_bottle() -> void:
	if Game.bottles <= 0 or Game.ended:
		return
	Game.bottles -= 1
	Game.pickups_changed()
	var b := ThrownBottle.new()
	get_parent().add_child(b)
	b.global_position = global_position + Vector3(0, 1.4, 0) - transform.basis.z * 0.6
	b.linear_velocity = -_cam.global_transform.basis.z * 8.5 + Vector3(0, 2.2, 0)
	b.angular_velocity = Vector3(randf() * 6 - 3, 0, randf() * 6 - 3)


func _try_interact() -> void:
	var t: Node = _ray.get_collider()
	if t != null and t.has_method("interact"):
		t.interact(self)
