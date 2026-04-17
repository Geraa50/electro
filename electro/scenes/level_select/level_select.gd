extends Control

@onready var level_grid: GridContainer = $VBoxContainer/LevelGrid

func _ready() -> void:
	_create_level_buttons()

func _create_level_buttons() -> void:
	for child in level_grid.get_children():
		child.queue_free()

	for i in range(GameManager.level_files.size()):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(220, 80)
		btn.text = _pretty_level_name(GameManager.level_files[i])

		if GameManager.is_level_completed(i):
			btn.text += "\n✓"
			btn.modulate = Color(0.6, 1.0, 0.6)

		if not GameManager.is_level_unlocked(i):
			btn.disabled = true
			btn.modulate = Color(0.55, 0.55, 0.55)

		btn.pressed.connect(_on_level_pressed.bind(i))
		level_grid.add_child(btn)

func _pretty_level_name(filename: String) -> String:
	var stem := filename.get_basename()
	return stem.replace("_", " ").capitalize()

func _on_level_pressed(level_index: int) -> void:
	GameManager.start_level(level_index)

func _on_back_pressed() -> void:
	GameManager.go_to_main_menu()
