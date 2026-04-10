class_name LevelLoader
extends RefCounted

static func load_level(path: String) -> LevelData:
	if not ResourceLoader.exists(path):
		push_error("Level resource not found: " + path)
		return null
	var res := ResourceLoader.load(path)
	if res is LevelData:
		return res as LevelData
	push_error("Invalid level resource: " + path)
	return null

static func get_level_path(index: int) -> String:
	if index == 0:
		return "res://resources/levels/tutorial.tres"
	return "res://resources/levels/level_%d.tres" % index
