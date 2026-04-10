class_name BaseComponent
extends Node2D

signal placed_on_board(component: BaseComponent)
signal removed_from_board(component: BaseComponent)
signal parameter_changed(component: BaseComponent)
signal pin_clicked(component: BaseComponent, pin_index: int)

@export var is_fixed: bool = false
@export var is_editable: bool = false
@export var component_label: String = ""

var pin_positions: Array[Vector2] = []
var connected_wires: Array = []
var is_placed: bool = false
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO
var connected_pins: Dictionary = {}
var _press_global_pos: Vector2 = Vector2.ZERO

const PIN_RADIUS := 8.0
const PIN_COLOR := Color(0.2, 0.8, 0.2)
const PIN_HOVER_COLOR := Color(0.9, 0.9, 0.2)
const PIN_CONNECTED_COLOR := Color(0.2, 0.9, 0.9)
const SNAP_SIZE := 64.0
const PIN_HIT_RADIUS := 18.0
const CLICK_THRESHOLD := 5.0

func _ready() -> void:
	_setup_pins()

func _setup_pins() -> void:
	pass

func get_resistance() -> float:
	return 0.0

func get_voltage() -> float:
	return 0.0

func get_current_draw() -> float:
	return 0.0

func get_required_voltage() -> float:
	return 0.0

func get_required_power() -> float:
	return 0.0

func get_component_type() -> String:
	return "base"

func is_conducting() -> bool:
	return true

func update_visual_state(current: float, voltage: float) -> void:
	pass

func get_pin_global_position(pin_index: int) -> Vector2:
	if pin_index < 0 or pin_index >= pin_positions.size():
		return global_position
	return to_global(pin_positions[pin_index])

func snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(
		snapped(pos.x, SNAP_SIZE),
		snapped(pos.y, SNAP_SIZE)
	)

func place_on_board(pos: Vector2) -> void:
	position = snap_to_grid(pos)
	is_placed = true
	placed_on_board.emit(self)

func remove_from_board() -> void:
	is_placed = false
	removed_from_board.emit(self)

func mark_pin_connected(pin_index: int, is_connected: bool) -> void:
	if is_connected:
		connected_pins[pin_index] = true
	else:
		connected_pins.erase(pin_index)
	queue_redraw()

func _draw_connection_indicators() -> void:
	for pin_idx in connected_pins:
		if pin_idx >= 0 and pin_idx < pin_positions.size():
			draw_arc(pin_positions[pin_idx], PIN_RADIUS + 4.0, 0, TAU, 24, PIN_CONNECTED_COLOR, 2.5)

func _draw() -> void:
	for i in range(pin_positions.size()):
		draw_circle(pin_positions[i], PIN_RADIUS, PIN_COLOR)
	_draw_connection_indicators()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_handle_press()
			elif not is_fixed:
				_handle_release()

	if event is InputEventMouseMotion and is_dragging and not is_fixed:
		global_position = get_global_mouse_position() - drag_offset

	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_press()
		elif not is_fixed:
			_handle_release()

	if event is InputEventScreenDrag and is_dragging and not is_fixed:
		global_position = get_global_mouse_position() - drag_offset

func _handle_press() -> void:
	var mouse_global := get_global_mouse_position()
	_press_global_pos = mouse_global
	var local_pos := to_local(mouse_global)
	for i in range(pin_positions.size()):
		if local_pos.distance_to(pin_positions[i]) <= PIN_HIT_RADIUS:
			pin_clicked.emit(self, i)
			get_viewport().set_input_as_handled()
			return
	if is_fixed:
		return
	if _is_point_inside(local_pos):
		is_dragging = true
		drag_offset = mouse_global - global_position
		original_position = position
		z_index = 100
		get_viewport().set_input_as_handled()

func _handle_release() -> void:
	if is_dragging:
		is_dragging = false
		z_index = 0
		var moved := get_global_mouse_position().distance_to(_press_global_pos)
		if moved < CLICK_THRESHOLD:
			position = original_position
			_on_body_clicked()
		else:
			position = snap_to_grid(position)
			if not is_placed:
				place_on_board(position)
		get_viewport().set_input_as_handled()

## Override in subclasses to handle left-click on body (e.g. switch toggle)
func _on_body_clicked() -> void:
	pass

func _is_point_inside(local_pos: Vector2) -> bool:
	var rect := Rect2(-32, -32, 64, 64)
	return rect.has_point(local_pos)
