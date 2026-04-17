class_name WireComponent
extends BaseComponent

signal pin_drag_ended(wire: WireComponent, pin_index: int)
signal body_drag_ended(wire: WireComponent)

const WIRE_COLOR := Color(0.15, 0.15, 0.15)
const WIRE_ACTIVE_COLOR := Color(0.15, 0.75, 0.25)
const WIRE_WIDTH := 4.0
const WIRE_DEFAULT_LENGTH := 80.0

var is_active: bool = false
var dragging_pin: int = -1

func _setup_pins() -> void:
	pin_positions = [
		Vector2(-WIRE_DEFAULT_LENGTH * 0.5, 0),
		Vector2(WIRE_DEFAULT_LENGTH * 0.5, 0)
	]

func get_component_type() -> String:
	return "wire"

func get_resistance() -> float:
	return 0.001

func is_conducting() -> bool:
	return true

func _get_bounding_rect() -> Rect2:
	if pin_positions.size() < 2:
		return Rect2(-16, -16, 32, 32)
	var a := pin_positions[0]
	var b := pin_positions[1]
	var minp := Vector2(min(a.x, b.x) - 6, min(a.y, b.y) - 10)
	var maxp := Vector2(max(a.x, b.x) + 6, max(a.y, b.y) + 10)
	return Rect2(minp, maxp - minp)

func _is_point_inside(local_pos: Vector2) -> bool:
	if pin_positions.size() < 2:
		return false
	var a := pin_positions[0]
	var b := pin_positions[1]
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.001:
		return local_pos.distance_to(a) <= 12.0
	var t := clampf((local_pos - a).dot(ab) / len_sq, 0.0, 1.0)
	var proj := a + ab * t
	return local_pos.distance_to(proj) <= 12.0

func _draw() -> void:
	var color := WIRE_ACTIVE_COLOR if is_active else WIRE_COLOR
	draw_line(pin_positions[0], pin_positions[1], color, WIRE_WIDTH)

	for i in range(pin_positions.size()):
		var pin_color := PIN_CONNECTED_COLOR if i in connected_pins else Color(0.9, 0.6, 0.1)
		draw_circle(pin_positions[i], PIN_RADIUS, pin_color)

	_draw_selection_indicator()

func update_visual_state(current: float, _voltage: float) -> void:
	is_active = current > 0.001
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_wire_press()
			else:
				_wire_release()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed and is_selected and not is_fixed:
			rotate_90(false)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed and is_selected and not is_fixed:
			rotate_90(true)
			get_viewport().set_input_as_handled()

	if event is InputEventKey and is_selected and not is_fixed:
		var ke := event as InputEventKey
		if ke.pressed and ke.keycode == KEY_R:
			rotate_90(not ke.shift_pressed)
			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		if dragging_pin >= 0:
			pin_positions[dragging_pin] = to_local(get_global_mouse_position())
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif is_dragging and not is_fixed:
			global_position = get_global_mouse_position() - drag_offset

	if event is InputEventScreenTouch:
		if event.pressed:
			_wire_press()
		else:
			_wire_release()

	if event is InputEventScreenDrag:
		if dragging_pin >= 0:
			pin_positions[dragging_pin] = to_local(get_global_mouse_position())
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif is_dragging and not is_fixed:
			global_position = get_global_mouse_position() - drag_offset

func _wire_press() -> void:
	var mouse_global := get_global_mouse_position()
	_press_global_pos = mouse_global
	var local_pos := to_local(mouse_global)

	for i in range(pin_positions.size()):
		if local_pos.distance_to(pin_positions[i]) <= PIN_HIT_RADIUS:
			dragging_pin = i
			get_viewport().set_input_as_handled()
			return

	if not _is_point_inside(local_pos):
		return
	if is_fixed:
		body_clicked.emit(self)
		get_viewport().set_input_as_handled()
		return
	is_dragging = true
	drag_offset = mouse_global - global_position
	original_position = position
	z_index = 100
	get_viewport().set_input_as_handled()

func _wire_release() -> void:
	if dragging_pin >= 0:
		var idx := dragging_pin
		dragging_pin = -1
		queue_redraw()
		pin_drag_ended.emit(self, idx)
		get_viewport().set_input_as_handled()
	elif is_dragging:
		is_dragging = false
		z_index = 0
		var moved := get_global_mouse_position().distance_to(_press_global_pos)
		if moved < CLICK_THRESHOLD:
			position = original_position
			body_clicked.emit(self)
		else:
			body_drag_ended.emit(self)
		get_viewport().set_input_as_handled()
