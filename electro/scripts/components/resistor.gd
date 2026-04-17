class_name Resistor
extends BaseComponent

@export var resistance: float = 100.0

const BODY_SIZE := Vector2(56, 22)
const BORDER_COLOR := Color(0.05, 0.05, 0.05)
const FILL_COLOR := Color(0.05, 0.05, 0.05, 0.0)
const LABEL_COLOR := Color(0.05, 0.05, 0.05)

func _setup_pins() -> void:
	pin_positions = [
		Vector2(-40, 0),
		Vector2(40, 0)
	]

func get_component_type() -> String:
	return "resistor"

func get_resistance() -> float:
	return resistance

func _get_bounding_rect() -> Rect2:
	return Rect2(Vector2(-BODY_SIZE.x * 0.5, -BODY_SIZE.y * 0.5), BODY_SIZE)

func _draw() -> void:
	draw_line(pin_positions[0], Vector2(-BODY_SIZE.x * 0.5, 0), BORDER_COLOR, 2.0)
	draw_line(Vector2(BODY_SIZE.x * 0.5, 0), pin_positions[1], BORDER_COLOR, 2.0)

	var body_rect := Rect2(-BODY_SIZE * 0.5, BODY_SIZE)
	draw_rect(body_rect, FILL_COLOR, true)
	draw_rect(body_rect, BORDER_COLOR, false, 2.0)

	for i in range(pin_positions.size()):
		var col := PIN_CONNECTED_COLOR if i in connected_pins else Color(0.1, 0.1, 0.1)
		draw_circle(pin_positions[i], PIN_RADIUS, col)

	var r_text := _format_resistance(resistance)
	draw_world_text(Vector2(0, BODY_SIZE.y * 0.5 + 12), r_text, 12, LABEL_COLOR)

	_draw_selection_indicator()

func _format_resistance(r: float) -> String:
	if r >= 1000.0:
		return "%.1f кΩ" % (r / 1000.0)
	return "%.0f Ω" % r

func update_visual_state(_current: float, _voltage: float) -> void:
	queue_redraw()
