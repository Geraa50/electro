extends Node

signal level_completed(level_index: int)
signal level_failed(level_index: int)

const LEVELS_DIR := "res://resources/levels"
const POWER_COOLDOWN := 5.0

var current_level_index: int = -1
var completed_levels: Array[int] = []
var level_files: Array[String] = []

var total_levels: int:
	get:
		return level_files.size()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_scan_levels()

func _scan_levels() -> void:
	level_files.clear()
	var dir := DirAccess.open(LEVELS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".txt"):
			level_files.append(file)
		file = dir.get_next()
	dir.list_dir_end()
	level_files.sort()

func get_level_resource_path(level_index: int) -> String:
	if level_index < 0 or level_index >= level_files.size():
		return ""
	return "%s/%s" % [LEVELS_DIR, level_files[level_index]]

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
