class_name Consumer
extends BaseComponent

@export var required_voltage: float = 9.0
@export var required_power: float = 5.0
@export var consumer_name: String = "Лампа"
@export var consumer_resistance: float = 16.0

var is_powered: bool = false
var current_voltage: float = 0.0
var current_power: float = 0.0

const BODY_RADIUS := 20.0
const OFF_COLOR := Color(0.4, 0.4, 0.4)
const ON_COLOR := Color(1.0, 0.95, 0.3)
const GLOW_COLOR := Color(1.0, 0.9, 0.2, 0.3)

func _setup_pins() -> void:
	pin_positions = [
		Vector2(-30, 0),
		Vector2(30, 0)
	]

func get_component_type() -> String:
	return "consumer"

func get_resistance() -> float:
	return consumer_resistance

func get_required_voltage() -> float:
	return required_voltage

func get_required_power() -> float:
	return required_power

func _draw() -> void:
	# Lead wires
	draw_line(pin_positions[0], Vector2(-BODY_RADIUS, 0), Color(0.5, 0.5, 0.5), 2.0)
	draw_line(pin_positions[1], Vector2(BODY_RADIUS, 0), Color(0.5, 0.5, 0.5), 2.0)

	# Lamp bulb
	var color := ON_COLOR if is_powered else OFF_COLOR
	if is_powered:
		draw_circle(Vector2.ZERO, BODY_RADIUS + 8, GLOW_COLOR)
	draw_circle(Vector2.ZERO, BODY_RADIUS, color)

	# Filament
	if is_powered:
		draw_line(Vector2(-8, 8), Vector2(0, -8), Color(1, 0.7, 0.1), 2.0)
		draw_line(Vector2(0, -8), Vector2(8, 8), Color(1, 0.7, 0.1), 2.0)
	else:
		draw_line(Vector2(-8, 8), Vector2(0, -8), Color(0.3, 0.3, 0.3), 1.5)
		draw_line(Vector2(0, -8), Vector2(8, 8), Color(0.3, 0.3, 0.3), 1.5)

	# Name and status
	var status_text := consumer_name
	if is_powered:
		status_text += " ✓"
	draw_string(ThemeDB.fallback_font, Vector2(-20, BODY_RADIUS + 16), status_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color.WHITE)

	# Voltage info
	var v_text := "%.1f/%.1f В" % [current_voltage, required_voltage]
	draw_string(ThemeDB.fallback_font, Vector2(-24, BODY_RADIUS + 30), v_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.LIGHT_GRAY)

	# Pins
	for pin in pin_positions:
		draw_circle(pin, PIN_RADIUS, PIN_COLOR)

	_draw_connection_indicators()

func update_visual_state(current: float, voltage: float) -> void:
	current_voltage = voltage
	current_power = voltage * current
	var voltage_ok := absf(voltage - required_voltage) <= required_voltage * 0.15
	is_powered = voltage_ok and current > 0.001
	queue_redraw()
