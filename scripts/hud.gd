extends CanvasLayer
class_name HUD
## Минимальный UI: задача, заряд фонаря, подсказка, записки, выбор, концовка.

var in_note := false
var in_choice := false

var _objective: Label
var _prompt: Label
var _status: Label
var _fade: ColorRect
var _note_root: Control
var _note_title: Label
var _note_text: Label
var _choice_root: Control
var _end_root: Control
var _end_title: Label
var _end_text: Label
var _bat_fill: ColorRect
var _warn: Label
var _warn_t := 0.0
var _blink_t := 0.0
var _low_bat := false


func _ready() -> void:
	layer = 10

	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0, 0, 0, 0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float strength = 0.38;
void fragment() {
	float d = distance(UV, vec2(0.5));
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(0.42, 0.82, d) * strength);
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	vignette.material = sm
	add_child(vignette)

	_objective = _label(13, Color(0.78, 0.80, 0.74), HORIZONTAL_ALIGNMENT_CENTER)
	_objective.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective.anchor_left = 0.0
	_objective.anchor_right = 1.0
	_objective.offset_top = 14.0
	_objective.offset_bottom = 40.0
	add_child(_objective)

	_prompt = _label(15, Color(0.88, 0.88, 0.84), HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.offset_top = -64.0
	_prompt.offset_bottom = -34.0
	add_child(_prompt)

	_status = _label(12, Color(0.55, 0.58, 0.55), HORIZONTAL_ALIGNMENT_LEFT)
	_status.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_status.offset_left = 18.0
	_status.offset_top = -46.0
	_status.offset_bottom = -18.0
	add_child(_status)

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 2.2)

	_build_battery()
	_warn = _label(14, Color(0.90, 0.72, 0.38), HORIZONTAL_ALIGNMENT_CENTER)
	_warn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_warn.anchor_left = 0.0
	_warn.anchor_right = 1.0
	_warn.offset_top = -104.0
	_warn.offset_bottom = -78.0
	_warn.visible = false
	add_child(_warn)

	_build_note()
	_build_choice()
	_build_end()

	Game.objective_changed.connect(func(t: String) -> void: _objective.text = t)
	Game.battery_changed.connect(func(v: float) -> void: _update_status(v))
	_objective.text = Game.objective()
	_update_status(100.0)


func _label(size: int, col: Color, align: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_battery() -> void:
	var bg := ColorRect.new()
	bg.position = Vector2(18, -96)
	bg.size = Vector2(214, 11)
	bg.color = Color(0.06, 0.06, 0.055, 0.88)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_bat_fill = ColorRect.new()
	_bat_fill.position = Vector2(19, -95)
	_bat_fill.size = Vector2(212, 9)
	_bat_fill.color = Color(0.85, 0.62, 0.2, 0.95)
	_bat_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bat_fill)


func _process(delta: float) -> void:
	if _low_bat:
		_blink_t += delta
		var on := fmod(_blink_t, 0.9) < 0.55
		_bat_fill.color = Color(0.82, 0.30, 0.10, 0.95) if on else Color(0.40, 0.16, 0.06, 0.85)
	if _warn_t > 0.0:
		_warn_t -= delta
		_warn.modulate.a = clampf(_warn_t, 0.0, 1.0)
		if _warn_t <= 0.0:
			_warn.visible = false


func flash_warning(t: String) -> void:
	_warn.text = t
	_warn.visible = true
	_warn_t = 2.6
	_warn.modulate.a = 1.0


func _update_status(v: float) -> void:
	var b := "Фонарь: %d%%" % int(v)
	if v <= 0.0:
		b = "Фонарь разряжен"
	_low_bat = v < 20.0
	if not _low_bat:
		_bat_fill.color = Color(0.85, 0.62, 0.2, 0.95)
	_bat_fill.size.x = maxf(0.0, 212.0 * clampf(v / 100.0, 0.0, 1.0))
	if v < 20.0 and v > 0.0 and _blink_t < 0.5:
		flash_warning("Фонарь садится. Найди батарею или химсветильник")
	_status.text = "%s   |   Бутыли: %d   |   Предохранители: %d   |   SHIFT — бег (шум) · CTRL — тихо · Q — бросить" % \
		[b, Game.bottles, Game.fuses]


func set_prompt(t: String) -> void:
	_prompt.text = t


func fade_to_black(dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, dur)


func fade_in(dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, dur)


func _build_note() -> void:
	_note_root = Control.new()
	_note_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_note_root.visible = false
	add_child(_note_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_root.add_child(dim)
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 460)
	panel.position = Vector2(360, 130)
	var pm := StyleBoxFlat.new()
	pm.bg_color = Color(0.10, 0.10, 0.09, 0.97)
	pm.border_color = Color(0.30, 0.29, 0.26)
	pm.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", pm)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_root.add_child(panel)
	_note_title = _label(18, Color(0.85, 0.82, 0.72), HORIZONTAL_ALIGNMENT_LEFT)
	_note_title.position = Vector2(28, 22)
	_note_title.size = Vector2(500, 30)
	panel.add_child(_note_title)
	_note_text = _label(14, Color(0.72, 0.70, 0.64), HORIZONTAL_ALIGNMENT_LEFT)
	_note_text.position = Vector2(28, 64)
	_note_text.size = Vector2(505, 350)
	_note_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_note_text)
	var hint := _label(12, Color(0.5, 0.5, 0.47), HORIZONTAL_ALIGNMENT_CENTER)
	hint.text = "[E] — закрыть"
	hint.position = Vector2(0, 424)
	hint.size = Vector2(560, 24)
	panel.add_child(hint)


func show_note(key: String) -> void:
	var data: Dictionary = StationData.NOTES.get(key, {})
	_note_title.text = str(data.get("title", ""))
	_note_text.text = str(data.get("text", ""))
	_note_root.visible = true
	in_note = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_choice() -> void:
	_choice_root = Control.new()
	_choice_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice_root.visible = false
	add_child(_choice_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_choice_root.add_child(dim)
	var t1 := _label(20, Color(0.85, 0.83, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	t1.text = "Главный селектор"
	t1.set_anchors_preset(Control.PRESET_CENTER_TOP)
	t1.anchor_left = 0.0
	t1.anchor_right = 1.0
	t1.offset_top = 190.0
	_choice_root.add_child(t1)
	var t2 := _label(14, Color(0.6, 0.62, 0.58), HORIZONTAL_ALIGNMENT_CENTER)
	t2.text = "Несущая под рукой. Два переключателя. Один выбор."
	t2.set_anchors_preset(Control.PRESET_CENTER_TOP)
	t2.anchor_left = 0.0
	t2.anchor_right = 1.0
	t2.offset_top = 226.0
	_choice_root.add_child(t2)
	var rows := [["1", "Заглушить станцию навсегда", "silence"], ["2", "Поднять несущую. Передать сигнал", "transmit"]]
	for i in range(rows.size()):
		var which: String = rows[i][2]
		var b := Button.new()
		b.text = "[%s]  %s" % [rows[i][0], rows[i][1]]
		b.custom_minimum_size = Vector2(460, 54)
		b.position = Vector2(410, 300 + i * 74)
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.13, 0.13, 0.12)
		bs.border_color = Color(0.4, 0.4, 0.36)
		bs.set_border_width_all(1)
		b.add_theme_stylebox_override("normal", bs)
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(func() -> void: _choose(which))
		_choice_root.add_child(b)


func show_choice() -> void:
	_choice_root.visible = true
	in_choice = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _choose(which: String) -> void:
	_choice_root.visible = false
	in_choice = false
	Game.choose_ending(which)


func _build_end() -> void:
	_end_root = Control.new()
	_end_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_root.visible = false
	add_child(_end_root)
	_end_title = _label(26, Color(0.8, 0.8, 0.76), HORIZONTAL_ALIGNMENT_CENTER)
	_end_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_end_title.anchor_left = 0.0
	_end_title.anchor_right = 1.0
	_end_title.offset_top = 200.0
	_end_root.add_child(_end_title)
	_end_text = _label(15, Color(0.65, 0.66, 0.62), HORIZONTAL_ALIGNMENT_CENTER)
	_end_text.anchor_left = 0.1
	_end_text.anchor_right = 0.9
	_end_text.anchor_top = 0.3
	_end_text.anchor_bottom = 0.75
	_end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_root.add_child(_end_text)
	var quit := _label(13, Color(0.5, 0.5, 0.48), HORIZONTAL_ALIGNMENT_CENTER)
	quit.text = "[ESC] — выйти из среза"
	quit.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	quit.anchor_left = 0.0
	quit.anchor_right = 1.0
	quit.offset_top = -80.0
	_end_root.add_child(quit)


func show_ending(which: String) -> void:
	var d: Dictionary = StationData.ENDINGS.get(which, {})
	_end_title.text = str(d.get("title", ""))
	_end_text.text = str(d.get("text", ""))
	_end_root.visible = true
	_choice_root.visible = false
	_note_root.visible = false
	in_note = false
	in_choice = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and in_note:
		_note_root.visible = false
		in_note = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("choice_1") and in_choice:
		_choose("silence")
	elif event.is_action_pressed("choice_2") and in_choice:
		_choose("transmit")
	elif event.is_action_pressed("pause"):
		if Game.ended:
			get_tree().quit()
