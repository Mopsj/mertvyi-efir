extends Node
## Глобальное состояние вертикального среза: цели, шум, переходы, смерти.

signal noise_event(pos: Vector3, floor_id: int, loudness: float)
signal floor_changed(floor_id: int)
signal objective_changed(text: String)
signal power_on
signal node_activated(total: int)
signal note_opened(note_key: String)
signal show_choice_requested
signal ending(chosen: String)
signal player_caught
signal battery_changed(v: float)

const NODES_TOTAL := 4
const MAX_FUSES := 3
const STAIR_LINK := {"1": [1, 2], "2": [1, 0]}

var current_floor: int = 1
var fuses: int = 0
var fuses_installed: int = 0
var power: bool = false
var nodes_done: int = 0
var bottles: int = 1
var deaths: int = 0
var scares: int = 0
var ended: bool = false
var ending_chosen: String = ""
var notes_read: int = 0
var player = null
var monster = null
var ui = null
var main = null

var _objective := ""


func _ready() -> void:
	reset()


func reset() -> void:
	current_floor = 1
	fuses = 0
	fuses_installed = 0
	power = false
	nodes_done = 0
	bottles = 1
	deaths = 0
	scares = 0
	ended = false
	ending_chosen = ""
	notes_read = 0
	_objective = ""
	set_objective("Восстановить питание: найти предохранители (%d/%d)" % [fuses, MAX_FUSES])


func emit_noise(pos: Vector3, floor_id: int, loudness: float) -> void:
	noise_event.emit(pos, floor_id, loudness)


func set_objective(t: String) -> void:
	_objective = t
	objective_changed.emit(t)


func objective() -> String:
	return _objective


func pickups_changed() -> void:
	if not power:
		set_objective("Восстановить питание: найти предохранители (%d/%d)" % [fuses, MAX_FUSES])
	else:
		refresh_node_objective()


func refresh_node_objective() -> void:
	if nodes_done < NODES_TOTAL:
		set_objective("Запустить узлы связи (%d/%d)" % [nodes_done, NODES_TOTAL])
	elif not ended:
		set_objective("Уйти через технический тоннель")


func install_fuse() -> bool:
	if fuses <= 0 or fuses_installed >= MAX_FUSES:
		return false
	fuses -= 1
	fuses_installed += 1
	if fuses_installed >= MAX_FUSES:
		power = true
		power_on.emit()
		set_objective("Питание восстановлено. Запустить узлы связи (0/%d)" % NODES_TOTAL)
	else:
		set_objective("Предохранители установлены (%d/%d). Искать ещё" % [fuses_installed, MAX_FUSES])
	return true


func activate_begin() -> void:
	set_objective("Выход в эфир. Слышно далеко...")


func activate_node() -> void:
	nodes_done += 1
	node_activated.emit(nodes_done)
	if nodes_done >= NODES_TOTAL:
		set_objective("Все узлы работают. Найти технический тоннель (Б1)")
	else:
		refresh_node_objective()


func open_hatch() -> void:
	set_objective("Люк открыт. Спуститься в клетку антенны")


func choose_ending(which: String) -> void:
	if ended:
		return
	ended = true
	ending_chosen = which
	ending.emit(which)


func note_read() -> void:
	notes_read += 1


func caught() -> void:
	if ended:
		return
	deaths += 1
	player_caught.emit()
