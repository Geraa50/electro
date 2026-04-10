extends Control

@onready var title_label: Label = $VBoxContainer/Title
@onready var description_label: Label = $VBoxContainer/Description
@onready var next_button: Button = $VBoxContainer/HBoxContainer/NextButton

func _ready() -> void:
	var level_index := GameManager.current_level_index
	if level_index >= GameManager.total_levels - 1:
		next_button.text = "ВСЕ ПРОЙДЕНО!"
		next_button.disabled = true
		title_label.text = "ПОЗДРАВЛЯЕМ!"
		description_label.text = "Вы прошли все уровни! Вы настоящий электрик!"

func _on_next_pressed() -> void:
	var next_level := GameManager.current_level_index + 1
	if next_level < GameManager.total_levels:
		GameManager.start_level(next_level)

func _on_menu_pressed() -> void:
	GameManager.go_to_level_select()
