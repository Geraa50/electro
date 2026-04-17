class_name PowerSource
extends BaseComponent

signal power_toggled(source: PowerSource, is_on: bool)

@export var voltage: float = 9.0
@export var max_current: float = 5.0
var is_on: bool = false
var is_cooldown: bool = false
var cooldown_remaining: float = 0.0

const BODY_SIZE := Vector2(80, 48)
const POSITIVE_COLOR := Color(0.85, 0.15, 0.15)
const NEGATIVE_COLOR := Color(0.12, 0.12, 0.12)
const BODY_ON_COLOR := Color(0.25, 0.7, 0.3)
const BODY_OFF_COLOR := Color(0.35, 0.35, 0.4)
const BODY_COOLDOWN_COLOR := Color(0.55, 0.45, 0.15)

func _setup_pins() -> void:
	pin_positions = [
		Vector2(-60, 0),
		Vector2(60, 0)
	]

func get_component_type() -> String:
	return "power_source"

func get_voltage() -> float:
	return voltage if is_on else 0.0

func get_max_current() -> float:
	return max_current

func get_resistance() -> float:
	return 0.001

func is_conducting() -> bool:
	return is_on

func set_on(v: bool) -> void:
	if is_on == v:
		return
	is_on = v
	queue_redraw()
	power_toggled.emit(self, v)

func start_cooldown(duration: float) -> void:
	is_cooldown = true
	cooldown_remaining = duration
	set_on(false)

func _get_bounding_rect() -> Rect2:
	return Rect2(-BODY_SIZE / 2, BODY_SIZE)

func _on_body_clicked() -> void:
	pass

func _process(delta: float) -> void:
	if is_cooldown:
		cooldown_remaining -= delta
		if cooldown_remaining <= 0.0:
			is_cooldown = false
			cooldown_remaining = 0.0
		queue_redraw()

func _draw() -> void:
	var body_color := BODY_OFF_COLOR
	if is_cooldown:
		body_color = BODY_COOLDOWN_COLOR
	elif is_on:
		body_color = BODY_ON_COLOR

	draw_rect(Rect2(-BODY_SIZE / 2, BODY_SIZE), body_color, true)
	draw_rect(Rect2(-BODY_SIZE / 2, BODY_SIZE), Color(0, 0, 0, 0.75), false, 2.0)

	draw_rect(Rect2(-BODY_SIZE.x / 2 - 10, -10, 10, 20), POSITIVE_COLOR, true)
	draw_rect(Rect2(BODY_SIZE.x / 2, -10, 10, 20), NEGATIVE_COLOR, true)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-BODY_SIZE.x / 2 + 4, -6), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_string(font, Vector2(BODY_SIZE.x / 2 - 14, -6), "−", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

	var v_text := "%.1f В" % voltage
	draw_string(font, Vector2(-20, 10), v_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)

	var status: String
	if is_cooldown:
		status = "⚡ %.1fс" % cooldown_remaining
	elif is_on:
		status = "ON"
	else:
		status = "OFF"
	draw_string(font, Vector2(-20, BODY_SIZE.y / 2 + 14), status, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color.WHITE if is_on else Color(0.85, 0.85, 0.85))

	for i in range(pin_positions.size()):
		var c := POSITIVE_COLOR if i == 0 else NEGATIVE_COLOR
		draw_circle(pin_positions[i], PIN_RADIUS, c)
		if i in connected_pins:
			draw_arc(pin_positions[i], PIN_RADIUS + 3.0, 0, TAU, 20, PIN_CONNECTED_COLOR, 2.0)

	_draw_selection_indicator()

func update_visual_state(_current: float, _voltage: float) -> void:
	queue_redraw()
