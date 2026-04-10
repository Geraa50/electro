extends Control

func _ready() -> void:
	pass

func _on_play_pressed() -> void:
	GameManager.go_to_level_select()

func _on_exit_pressed() -> void:
	GameManager.quit_game()
