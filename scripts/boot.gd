extends Node
## Boot: регистрация действий ввода (клавиатура), базовые настройки.

func _enter_tree() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("sprint", KEY_SHIFT)
	_add_key("crouch", KEY_CTRL)
	_add_key("interact", KEY_E)
	_add_key("flashlight", KEY_F)
	_add_key("throw", KEY_Q)
	_add_key("pause", KEY_ESCAPE)
	_add_key("choice_1", KEY_1)
	_add_key("choice_2", KEY_2)


func _add_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)
