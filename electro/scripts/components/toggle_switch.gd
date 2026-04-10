class_name ToggleSwitch
extends BaseComponent

## 0 = output A, 1 = output B
var active_output: int = 0

const BODY_SIZE := Vector2(60, 40)
const ACTIVE_COLOR := Color(0.2, 0.7, 0.3)
const INACTIVE_COLOR := Color(0.5, 0.5, 0.5)

func _setup_pins() -> void:
	pin_positions = [
		Vector2(-40, 0),    # input
		Vector2(40, -12),   # output A
		Vector2(40, 12)     # output B
	]

func get_component_type() -> String:
	return "toggle_switch"

func get_resistance() -> float:
	return 0.001

func is_conducting() -> bool:
	return true

func toggle() -> void:
	active_output = 1 - active_output
	parameter_changed.emit(self)
	queue_redraw()

func _on_body_clicked() -> void:
	toggle()

func _draw() -> void:
	draw_rect(Rect2(-BODY_SIZE / 2, BODY_SIZE), Color(0.3, 0.3, 0.35), false, 2.0)

	draw_line(pin_positions[0], Vector2(-BODY_SIZE.x / 2, 0), Color(0.5, 0.5, 0.5), 2.0)

	var color_a := ACTIVE_COLOR if active_output == 0 else INACTIVE_COLOR
	var color_b := ACTIVE_COLOR if active_output == 1 else INACTIVE_COLOR
	draw_line(Vector2(BODY_SIZE.x / 2, -12), pin_positions[1], color_a, 2.0)
	draw_line(Vector2(BODY_SIZE.x / 2, 12), pin_positions[2], color_b, 2.0)

	draw_circle(Vector2(-10, 0), 5, Color.WHITE)
	var target_y := -12.0 if active_output == 0 else 12.0
	draw_line(Vector2(-10, 0), Vector2(10, target_y), Color.WHITE, 3.0)
	draw_circle(Vector2(10, -12), 4, color_a)
	draw_circle(Vector2(10, 12), 4, color_b)

	draw_string(ThemeDB.fallback_font, Vector2(16, -16), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color_a)
	draw_string(ThemeDB.fallback_font, Vector2(16, 20), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color_b)

	for i in range(pin_positions.size()):
		var c := PIN_COLOR
		if i == 1:
			c = color_a
		elif i == 2:
			c = color_b
		draw_circle(pin_positions[i], PIN_RADIUS, c)

	_draw_connection_indicators()
