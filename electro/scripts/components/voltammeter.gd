class_name Voltammeter
extends BaseComponent

var measured_voltage: float = 0.0
var measured_current: float = 0.0

const BODY_SIZE := Vector2(60, 50)
const BODY_COLOR := Color(0.15, 0.15, 0.25)
const DISPLAY_COLOR := Color(0.1, 0.8, 0.3)

func _setup_pins() -> void:
	pin_positions = [
		Vector2(-40, 0),
		Vector2(40, 0)
	]

func get_component_type() -> String:
	return "voltammeter"

func get_resistance() -> float:
	return 0.001

func _draw() -> void:
	# Lead wires
	draw_line(pin_positions[0], Vector2(-BODY_SIZE.x / 2, 0), Color(0.5, 0.5, 0.5), 2.0)
	draw_line(pin_positions[1], Vector2(BODY_SIZE.x / 2, 0), Color(0.5, 0.5, 0.5), 2.0)

	# Meter body
	draw_rect(Rect2(-BODY_SIZE / 2, BODY_SIZE), BODY_COLOR)
	draw_rect(Rect2(-BODY_SIZE / 2, BODY_SIZE), Color.WHITE, false, 1.5)

	# Display area
	var display_rect := Rect2(-BODY_SIZE.x / 2 + 4, -BODY_SIZE.y / 2 + 4, BODY_SIZE.x - 8, BODY_SIZE.y - 8)
	draw_rect(display_rect, Color(0.05, 0.05, 0.1))

	# Voltage reading
	var v_text := "U: %.2f В" % measured_voltage
	draw_string(ThemeDB.fallback_font, Vector2(-BODY_SIZE.x / 2 + 8, -4), v_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DISPLAY_COLOR)

	# Current reading
	var i_text := "I: %.2f А" % measured_current
	draw_string(ThemeDB.fallback_font, Vector2(-BODY_SIZE.x / 2 + 8, 14), i_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DISPLAY_COLOR)

	# Power
	var p := measured_voltage * measured_current
	var p_text := "P: %.2f Вт" % p
	draw_string(ThemeDB.fallback_font, Vector2(-BODY_SIZE.x / 2 + 8, BODY_SIZE.y / 2 + 14), p_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.LIGHT_GRAY)

	# Label
	draw_string(ThemeDB.fallback_font, Vector2(-10, -BODY_SIZE.y / 2 - 4), "ВАМ", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.WHITE)

	# Pins
	for pin in pin_positions:
		draw_circle(pin, PIN_RADIUS, PIN_COLOR)

	_draw_connection_indicators()

func update_visual_state(current: float, voltage: float) -> void:
	measured_voltage = voltage
	measured_current = current
	queue_redraw()
