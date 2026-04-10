class_name Resistor
extends BaseComponent

@export var resistance: float = 100.0

const BODY_SIZE := Vector2(50, 20)
const BODY_COLOR := Color(0.7, 0.55, 0.35)
const STRIPE_COLORS: Array[Color] = [
	Color(0.6, 0.2, 0.2),
	Color(0.2, 0.5, 0.2),
	Color(0.2, 0.2, 0.6),
	Color(0.6, 0.6, 0.2)
]

func _setup_pins() -> void:
	pin_positions = [
		Vector2(-35, 0),
		Vector2(35, 0)
	]

func get_component_type() -> String:
	return "resistor"

func get_resistance() -> float:
	return resistance

func _draw() -> void:
	# Lead wires
	draw_line(pin_positions[0], Vector2(-BODY_SIZE.x / 2, 0), Color(0.5, 0.5, 0.5), 2.0)
	draw_line(pin_positions[1], Vector2(BODY_SIZE.x / 2, 0), Color(0.5, 0.5, 0.5), 2.0)

	# Resistor body
	draw_rect(Rect2(-BODY_SIZE / 2, BODY_SIZE), BODY_COLOR)

	# Color stripes
	for i in range(STRIPE_COLORS.size()):
		var x := -BODY_SIZE.x / 2 + 6 + i * 10
		draw_rect(Rect2(x, -BODY_SIZE.y / 2 + 2, 4, BODY_SIZE.y - 4), STRIPE_COLORS[i])

	# Resistance label
	var r_text := "%.0f Ω" % resistance
	draw_string(ThemeDB.fallback_font, Vector2(-18, BODY_SIZE.y / 2 + 14), r_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color.WHITE)

	# Pins
	for pin in pin_positions:
		draw_circle(pin, PIN_RADIUS, PIN_COLOR)

	_draw_connection_indicators()

func update_visual_state(current: float, voltage: float) -> void:
	queue_redraw()
