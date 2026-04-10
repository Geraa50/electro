class_name ComponentBuffer
extends Node2D

signal component_selected(type_name: String, params: Dictionary)

var available_items: Array[Dictionary] = []

func set_items(items: Array[Dictionary]) -> void:
	available_items = items

func get_items() -> Array[Dictionary]:
	return available_items
