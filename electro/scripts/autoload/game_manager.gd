extends Node

signal level_completed(level_index: int)
signal level_failed(level_index: int)

const POWER_COOLDOWN := 5.0

# Уровни описаны как нативные Godot-ресурсы (.tres) и подгружаются через
# preload(). Это критично для портов на закрытые ОС (например, Аврора ОС):
#   * preload запекает ресурсы в .pck во время компиляции скрипта — не нужен
#     DirAccess/FileAccess для перечисления файлов внутри PCK;
#   * .tres читается ResourceLoader-ом, а значит не требуется отдельных
#     разрешений FS на чтение «сырых» файлов вроде .txt;
#   * порядок уровней задаётся явно этим массивом, никаких сюрпризов с
#     сортировкой имён файлов.
var levels: Array[LevelData] = [
	preload("res://resources/levels/01_tutorial.tres"),
	preload("res://resources/levels/02_parallel.tres"),
	preload("res://resources/levels/03_measure.tres"),
	preload("res://resources/levels/04_toggle.tres"),
	preload("res://resources/levels/05_double.tres"),
]

var current_level_index: int = -1
var completed_levels: Array[int] = []

var total_levels: int:
	get:
		return levels.size()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func get_level_data(level_index: int) -> LevelData:
	if level_index < 0 or level_index >= levels.size():
		return null
	return levels[level_index]

func start_level(level_index: int) -> void:
	current_level_index = level_index
	get_tree().change_scene_to_file("res://scenes/game/game_field.tscn")

func complete_level() -> void:
	if current_level_index >= 0 and current_level_index not in completed_levels:
		completed_levels.append(current_level_index)
	level_completed.emit(current_level_index)

func fail_level() -> void:
	level_failed.emit(current_level_index)

func go_to_main_menu() -> void:
	current_level_index = -1
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func go_to_level_select() -> void:
	get_tree().change_scene_to_file("res://scenes/level_select/level_select.tscn")

func is_level_completed(level_index: int) -> bool:
	return level_index in completed_levels

func is_level_unlocked(level_index: int) -> bool:
	if level_index == 0:
		return true
	return (level_index - 1) in completed_levels

func quit_game() -> void:
	get_tree().quit()
