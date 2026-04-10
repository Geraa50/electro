class_name SwitchComponent
extends BaseComponent

var is_closed: bool = false

const BODY_SIZE := Vector2(50, 30)
const OFF_COLOR := Color(0.6, 0.2, 0.2)
const ON_COLOR := Color(0.2, 0.6, 0.2)

func _setup_pins() -> void:
	pin_positions = [
		Vector2(-35, 0),
		Vector2(35, 0)
	]

func get_component_type() -> String:
	return "switch"

func get_resistance() -> float:
	if is_closed:
		return 0.001
	return 999999.0

func is_conducting() -> bool:
	return is_closed

func toggle() -> void:
	is_closed = not is_closed
	queue_redraw()

func _on_body_clicked() -> void:
	toggle()

func _draw() -> void:
	draw_line(pin_positions[0], Vector2(-BODY_SIZE.x / 2, 0), Color(0.5, 0.5, 0.5), 2.0)
	draw_line(pin_positions[1], Vector2(BODY_SIZE.x / 2, 0), Color(0.5, 0.5, 0.5), 2.0)

	var body_color := ON_COLOR if is_closed else OFF_COLOR
	draw_rect(Rect2(-BODY_SIZE / 2, BODY_SIZE), body_color, false, 2.0)

	draw_circle(Vector2(-BODY_SIZE.x / 2 + 8, 0), 4, Color.WHITE)
	draw_circle(Vector2(BODY_SIZE.x / 2 - 8, 0), 4, Color.WHITE)

	var lever_end: Vector2
	if is_closed:
		lever_end = Vector2(BODY_SIZE.x / 2 - 8, 0)
	else:
		lever_end = Vector2(BODY_SIZE.x / 4, -BODY_SIZE.y / 2 + 2)
	draw_line(Vector2(-BODY_SIZE.x / 2 + 8, 0), lever_end, Color.WHITE, 3.0)

	var status := "ВКЛ" if is_closed else "ВЫКЛ"
	draw_string(ThemeDB.fallback_font, Vector2(-12, BODY_SIZE.y / 2 + 14), status, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, body_color)

	for pin in pin_positions:
		draw_circle(pin, PIN_RADIUS, PIN_COLOR)

	_draw_connection_indicators()
