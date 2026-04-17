class_name Consumer
extends BaseComponent

@export var required_voltage: float = 9.0
@export var required_power: float = 5.0
@export var consumer_name: String = "Лампа"
@export var consumer_resistance: float = 16.0

var is_powered: bool = false
var current_voltage: float = 0.0
var current_current: float = 0.0
var current_power: float = 0.0

const BODY_RADIUS := 22.0
const OFF_COLOR := Color(0.4, 0.4, 0.4)
const ON_COLOR := Color(1.0, 0.95, 0.3)
const GLOW_COLOR := Color(1.0, 0.9, 0.2, 0.3)

func _setup_pins() -> void:
	pin_positions = [
		Vector2(-40, 0),
		Vector2(40, 0)
	]

func get_component_type() -> String:
	return "consumer"

func get_resistance() -> float:
	return consumer_resistance

func get_required_voltage() -> float:
	return required_voltage

func get_required_power() -> float:
	return required_power

func _get_bounding_rect() -> Rect2:
	return Rect2(Vector2(-BODY_RADIUS, -BODY_RADIUS), Vector2(BODY_RADIUS * 2, BODY_RADIUS * 2))

func _draw() -> void:
	draw_line(pin_positions[0], Vector2(-BODY_RADIUS, 0), Color(0.3, 0.3, 0.3), 2.0)
	draw_line(Vector2(BODY_RADIUS, 0), pin_positions[1], Color(0.3, 0.3, 0.3), 2.0)

	var color := ON_COLOR if is_powered else OFF_COLOR
	if is_powered:
		draw_circle(Vector2.ZERO, BODY_RADIUS + 10, GLOW_COLOR)
	draw_circle(Vector2.ZERO, BODY_RADIUS, color)
	draw_arc(Vector2.ZERO, BODY_RADIUS, 0, TAU, 32, Color(0.2, 0.2, 0.2), 2.0)

	var fil_col := Color(1.0, 0.6, 0.1) if is_powered else Color(0.3, 0.3, 0.3)
	draw_line(Vector2(-8, 8), Vector2(0, -8), fil_col, 2.0)
	draw_line(Vector2(0, -8), Vector2(8, 8), fil_col, 2.0)

	for i in range(pin_positions.size()):
		var c := PIN_CONNECTED_COLOR if i in connected_pins else Color(0.1, 0.1, 0.1)
		draw_circle(pin_positions[i], PIN_RADIUS, c)

	var name_text := consumer_name
	if is_powered:
		name_text += " ✓"
	draw_world_text(Vector2(0, BODY_RADIUS + 16), name_text, 12, Color(0.1, 0.1, 0.1))

	var v_text := "%.1f / %.1f В" % [current_voltage, required_voltage]
	draw_world_text(Vector2(0, BODY_RADIUS + 32), v_text, 11, Color(0.25, 0.25, 0.25))

	var i_text := "I: %.2f А" % current_current
	draw_world_text(Vector2(0, BODY_RADIUS + 46), i_text, 11, Color(0.25, 0.25, 0.35))

	_draw_selection_indicator()

func update_visual_state(current: float, voltage: float) -> void:
	current_voltage = voltage
	current_current = current
	current_power = voltage * current
	## Lamp lights up based solely on its OWN voltage — independent from the rest
	## of the circuit or other consumers.
	var voltage_ok: bool = absf(voltage - required_voltage) <= maxf(required_voltage * 0.15, 0.5)
	is_powered = voltage_ok and current > 0.001
	queue_redraw()

func is_target_met() -> bool:
	return absf(current_voltage - required_voltage) <= maxf(required_voltage * 0.15, 0.5) and current_current > 0.001
