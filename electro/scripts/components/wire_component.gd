class_name WireComponent
extends BaseComponent

signal pin_drag_ended(wire: WireComponent, pin_index: int)

const WIRE_COLOR := Color(0.25, 0.25, 0.25)
const WIRE_ACTIVE_COLOR := Color(0.15, 0.55, 0.15)
const WIRE_WIDTH := 3.5

var is_active: bool = false
var dragging_pin: int = -1
var pin_drag_offset: Vector2 = Vector2.ZERO

func _setup_pins() -> void:
	pin_positions = [
		Vector2(-50, 0),
		Vector2(50, 0)
	]

func get_component_type() -> String:
	return "wire"

func get_resistance() -> float:
	return 0.001

func is_conducting() -> bool:
	return true

func _draw() -> void:
	var color := WIRE_ACTIVE_COLOR if is_active else WIRE_COLOR
	draw_line(pin_positions[0], pin_positions[1], color, WIRE_WIDTH)

	for i in range(pin_positions.size()):
		var pin_color := PIN_CONNECTED_COLOR if i in connected_pins else PIN_COLOR
		draw_circle(pin_positions[i], PIN_RADIUS, pin_color)

func _is_point_inside(local_pos: Vector2) -> bool:
	var a := pin_positions[0]
	var b := pin_positions[1]
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.001:
		return local_pos.distance_to(a) <= 16.0
	var t := clampf((local_pos - a).dot(ab) / len_sq, 0.0, 1.0)
	var proj := a + ab * t
	return local_pos.distance_to(proj) <= 16.0

func update_visual_state(current: float, _voltage: float) -> void:
	is_active = current > 0.001
	queue_redraw()

## Wire overrides _input completely: pin clicks = drag that end
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_wire_press()
			else:
				_wire_release()

	if event is InputEventMouseMotion:
		if dragging_pin >= 0:
			var local_pos := to_local(get_global_mouse_position())
			pin_positions[dragging_pin] = local_pos + pin_drag_offset
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
			var local_pos := to_local(get_global_mouse_position())
			pin_positions[dragging_pin] = local_pos + pin_drag_offset
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
			pin_drag_offset = pin_positions[i] - local_pos
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
		position = snap_to_grid(position)
		if not is_placed:
			place_on_board(position)
		get_viewport().set_input_as_handled()
