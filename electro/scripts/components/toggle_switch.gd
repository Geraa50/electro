class_name ToggleSwitch
extends BaseComponent

## A single-pole double-throw (SPDT) switch.
## Pin 0 = common input. Pin 1 = output A. Pin 2 = output B.
## In position A: pin0 ↔ pin1 (B disconnected).
## In position B: pin0 ↔ pin2 (A disconnected).

var active_output: int = 0  # 0 -> outputs via pin 1 (A), 1 -> pin 2 (B)

const BODY_SIZE := Vector2(64, 48)
const BODY_FILL := Color(0.95, 0.95, 0.95)
const ACTIVE_COLOR := Color(0.2, 0.7, 0.3)
const INACTIVE_COLOR := Color(0.5, 0.5, 0.5)

func _setup_pins() -> void:
	pin_positions = [
		Vector2(-40, 0),    # common input
		Vector2(40, -40),   # output A
		Vector2(40, 40)     # output B
	]

func get_component_type() -> String:
	return "toggle_switch"

func get_resistance() -> float:
	return 0.001

func is_conducting() -> bool:
	return true

## Only one of (0↔1) or (0↔2) is shorted, depending on active_output.
func get_internal_connections() -> Array:
	if active_output == 0:
		return [[0, 1]]
	return [[0, 2]]

func toggle() -> void:
	active_output = 1 - active_output
	queue_redraw()

func _on_body_clicked() -> void:
	toggle()

func _get_bounding_rect() -> Rect2:
	return Rect2(-BODY_SIZE * 0.5, BODY_SIZE)

func _draw() -> void:
	draw_rect(Rect2(-BODY_SIZE * 0.5, BODY_SIZE), BODY_FILL, true)
	draw_rect(Rect2(-BODY_SIZE * 0.5, BODY_SIZE), Color(0.2, 0.2, 0.2), false, 2.0)

	draw_line(pin_positions[0], Vector2(-BODY_SIZE.x * 0.5, 0), Color(0.3, 0.3, 0.3), 2.0)

	var color_a := ACTIVE_COLOR if active_output == 0 else INACTIVE_COLOR
	var color_b := ACTIVE_COLOR if active_output == 1 else INACTIVE_COLOR
	draw_line(Vector2(BODY_SIZE.x * 0.5, -20), pin_positions[1], color_a, 2.0)
	draw_line(Vector2(BODY_SIZE.x * 0.5, 20), pin_positions[2], color_b, 2.0)

	var pivot := Vector2(-14, 0)
	draw_circle(pivot, 4.0, Color(0.2, 0.2, 0.2))
	var target_y := -14.0 if active_output == 0 else 14.0
	draw_line(pivot, Vector2(14, target_y), Color(0.1, 0.1, 0.1), 3.0)
	draw_circle(Vector2(14, -14), 4.0, color_a)
	draw_circle(Vector2(14, 14), 4.0, color_b)

	for i in range(pin_positions.size()):
		var c := Color(0.1, 0.1, 0.1)
		if i in connected_pins:
			c = PIN_CONNECTED_COLOR
		elif i == 1 and active_output == 0:
			c = ACTIVE_COLOR
		elif i == 2 and active_output == 1:
			c = ACTIVE_COLOR
		draw_circle(pin_positions[i], PIN_RADIUS, c)

	var status := "A" if active_output == 0 else "B"
	draw_world_text(Vector2(0, BODY_SIZE.y * 0.5 + 14), "Ветка: " + status, 11,
		ACTIVE_COLOR)

	_draw_selection_indicator()
