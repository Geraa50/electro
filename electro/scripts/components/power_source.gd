class_name PowerSource
extends BaseComponent

@export var voltage: float = 9.0
@export var max_current: float = 2.0
var is_on: bool = true

const BODY_SIZE := Vector2(60, 40)
const POSITIVE_COLOR := Color(0.8, 0.1, 0.1)
const NEGATIVE_COLOR := Color(0.1, 0.1, 0.1)
const BODY_COLOR := Color(0.3, 0.5, 0.3)

func _setup_pins() -> void:
	pin_positions = [
		Vector2(-40, 0),   # positive (+)
		Vector2(40, 0)     # negative (-)
	]

func get_component_type() -> String:
	return "power_source"

func get_voltage() -> float:
	if is_on:
		return voltage
	return 0.0

func get_max_current() -> float:
	return max_current

func get_resistance() -> float:
	return 0.001

func is_conducting() -> bool:
	return is_on

func _draw() -> void:
	# Battery body
	draw_rect(Rect2(-BODY_SIZE / 2, BODY_SIZE), BODY_COLOR)
	# Positive terminal
	draw_rect(Rect2(-BODY_SIZE.x / 2 - 8, -8, 8, 16), POSITIVE_COLOR)
	# Negative terminal
	draw_rect(Rect2(BODY_SIZE.x / 2, -8, 8, 16), NEGATIVE_COLOR)

	# Labels
	draw_string(ThemeDB.fallback_font, Vector2(-BODY_SIZE.x / 2 - 6, -12), "+", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, POSITIVE_COLOR)
	draw_string(ThemeDB.fallback_font, Vector2(BODY_SIZE.x / 2 + 2, -12), "−", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, NEGATIVE_COLOR)

	# Voltage label
	var v_text := "%.1f В" % voltage
	draw_string(ThemeDB.fallback_font, Vector2(-18, 6), v_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)

	# Pins
	for i in range(pin_positions.size()):
		var color := POSITIVE_COLOR if i == 0 else NEGATIVE_COLOR
		draw_circle(pin_positions[i], PIN_RADIUS, color)

	_draw_connection_indicators()

func update_visual_state(current: float, _voltage: float) -> void:
	queue_redraw()
