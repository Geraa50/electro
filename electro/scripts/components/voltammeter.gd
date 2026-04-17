class_name Voltammeter
extends BaseComponent

var measured_voltage: float = 0.0
var measured_current: float = 0.0

const BODY_SIZE := Vector2(80, 52)
const BODY_COLOR := Color(0.08, 0.08, 0.12)
const DISPLAY_COLOR := Color(0.1, 0.85, 0.3)
const DISPLAY_BG := Color(0.02, 0.04, 0.02)

func _setup_pins() -> void:
	pin_positions = [
		Vector2(-60, 0),
		Vector2(60, 0)
	]

func get_component_type() -> String:
	return "voltammeter"

func get_resistance() -> float:
	return 0.001

func _get_bounding_rect() -> Rect2:
	return Rect2(-BODY_SIZE * 0.5, BODY_SIZE)

func _draw() -> void:
	draw_line(pin_positions[0], Vector2(-BODY_SIZE.x * 0.5, 0), Color(0.3, 0.3, 0.3), 2.0)
	draw_line(Vector2(BODY_SIZE.x * 0.5, 0), pin_positions[1], Color(0.3, 0.3, 0.3), 2.0)

	draw_rect(Rect2(-BODY_SIZE * 0.5, BODY_SIZE), BODY_COLOR, true)
	draw_rect(Rect2(-BODY_SIZE * 0.5, BODY_SIZE), Color.WHITE, false, 1.5)

	var display_rect := Rect2(-BODY_SIZE.x * 0.5 + 4, -BODY_SIZE.y * 0.5 + 4, BODY_SIZE.x - 8, BODY_SIZE.y - 8)
	draw_rect(display_rect, DISPLAY_BG, true)

	var font := ThemeDB.fallback_font
	var v_text := "U: %.2f В" % measured_voltage
	draw_string(font, Vector2(-BODY_SIZE.x * 0.5 + 8, -6), v_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DISPLAY_COLOR)

	var i_text := "I: %.2f А" % measured_current
	draw_string(font, Vector2(-BODY_SIZE.x * 0.5 + 8, 14), i_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DISPLAY_COLOR)

	var p := measured_voltage * measured_current
	var p_text := "P: %.2f Вт" % p
	draw_string(font, Vector2(-BODY_SIZE.x * 0.5 + 8, BODY_SIZE.y * 0.5 + 14), p_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.LIGHT_GRAY)

	draw_string(font, Vector2(-12, -BODY_SIZE.y * 0.5 - 4), "V/A", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.WHITE)

	for i in range(pin_positions.size()):
		var col := PIN_CONNECTED_COLOR if i in connected_pins else Color(0.85, 0.85, 0.85)
		draw_circle(pin_positions[i], PIN_RADIUS, col)

	_draw_selection_indicator()

func set_measurement(voltage: float, current: float) -> void:
	measured_voltage = voltage
	measured_current = current
	queue_redraw()

func update_visual_state(current: float, voltage: float) -> void:
	set_measurement(voltage, current)
