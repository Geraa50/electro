class_name WireDrawer
extends Node2D

var is_drawing: bool = false
var start_pos: Vector2 = Vector2.ZERO
var current_end: Vector2 = Vector2.ZERO
var wire_color := Color(0.3, 0.7, 0.3, 0.8)
var wire_width := 3.0

func start_wire(pos: Vector2) -> void:
	is_drawing = true
	start_pos = pos
	current_end = pos
	queue_redraw()

func update_wire(pos: Vector2) -> void:
	if is_drawing:
		current_end = pos
		queue_redraw()

func cancel_wire() -> void:
	is_drawing = false
	queue_redraw()

func _draw() -> void:
	if not is_drawing:
		return
	draw_line(start_pos, current_end, wire_color, wire_width)
	draw_circle(start_pos, 6.0, Color(0.2, 0.8, 0.2))
	draw_circle(current_end, 5.0, Color(0.8, 0.8, 0.2))
