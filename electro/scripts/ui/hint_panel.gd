class_name HintPanel
extends PanelContainer

@onready var hint_label: Label = $HintLabel

func show_hint(text: String) -> void:
	hint_label.text = text
	visible = true

func hide_hint() -> void:
	visible = false

func toggle() -> void:
	visible = not visible
