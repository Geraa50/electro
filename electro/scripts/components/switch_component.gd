class_name SwitchComponent
extends BaseComponent

var is_closed: bool = false

const BODY_SIZE := Vector2(60, 30)
const OFF_COLOR := Color(0.6, 0.2, 0.2)
const ON_COLOR := Color(0.2, 0.65, 0.25)

func _setup_pins() -> void:
	pin_positions = [
		Vector2(-40, 0),
		Vector2(40, 0)
	]

func get_component_type() -> String:
	return "switch"

func get_resistance() -> float:
	return 0.001 if is_closed else 1.0e9

func is_conducting() -> bool:
	return is_closed

func get_internal_connections() -> Array:
	if is_closed:
		return [[0, 1]]
	return []

func toggle() -> void:
	is_closed = not is_closed
	queue_redraw()

func _on_body_clicked() -> void:
	toggle()

func _get_bounding_rect() -> Rect2:
	return Rect2(-BODY_SIZE * 0.5, BODY_SIZE)

func _draw() -> void:
	var body_color := ON_COLOR if is_closed else OFF_COLOR
	draw_line(pin_positions[0], Vector2(-BODY_SIZE.x * 0.5, 0), Color(0.3, 0.3, 0.3), 2.0)
	draw_line(Vector2(BODY_SIZE.x * 0.5, 0), pin_positions[1], Color(0.3, 0.3, 0.3), 2.0)

	draw_rect(Rect2(-BODY_SIZE * 0.5, BODY_SIZE), Color(0.95, 0.95, 0.95), true)
	draw_rect(Rect2(-BODY_SIZE * 0.5, BODY_SIZE), body_color, false, 2.0)

	draw_circle(Vector2(-BODY_SIZE.x * 0.5 + 10, 0), 4.0, Color(0.2, 0.2, 0.2))
	draw_circle(Vector2(BODY_SIZE.x * 0.5 - 10, 0), 4.0, Color(0.2, 0.2, 0.2))

	var lever_end: Vector2
	if is_closed:
		lever_end = Vector2(BODY_SIZE.x * 0.5 - 10, 0)
	else:
		lever_end = Vector2(4, -BODY_SIZE.y * 0.5 + 4)
	draw_line(Vector2(-BODY_SIZE.x * 0.5 + 10, 0), lever_end, body_color, 3.0)

	for i in range(pin_positions.size()):
		var col := PIN_CONNECTED_COLOR if i in connected_pins else Color(0.1, 0.1, 0.1)
		draw_circle(pin_positions[i], PIN_RADIUS, col)

	var status := "ВКЛ" if is_closed else "ВЫКЛ"
	draw_world_text(Vector2(0, BODY_SIZE.y * 0.5 + 14), status, 11, body_color)

	_draw_selection_indicator()
