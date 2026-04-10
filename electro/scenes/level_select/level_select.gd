extends Control

const LEVEL_NAMES: Array[String] = [
	"Туториал",
	"1: Последовательное",
	"2: Параллельное",
	"3: Параметры",
	"4: Без подсказок",
	"5: Сложная цепь",
	"6: На время!"
]

@onready var level_grid: GridContainer = $VBoxContainer/LevelGrid

func _ready() -> void:
	_create_level_buttons()

func _create_level_buttons() -> void:
	for child in level_grid.get_children():
		child.queue_free()

	for i in range(LEVEL_NAMES.size()):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(180, 80)
		btn.text = LEVEL_NAMES[i]

		if GameManager.is_level_completed(i):
			btn.text += "\n✓"
			btn.modulate = Color(0.6, 1.0, 0.6)

		if not GameManager.is_level_unlocked(i):
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5)

		btn.pressed.connect(_on_level_pressed.bind(i))
		level_grid.add_child(btn)

func _on_level_pressed(level_index: int) -> void:
	GameManager.start_level(level_index)

func _on_back_pressed() -> void:
	GameManager.go_to_main_menu()
