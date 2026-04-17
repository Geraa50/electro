class_name BaseComponent
extends Node2D

signal placed_on_board(component: BaseComponent)
signal removed_from_board(component: BaseComponent)
signal pin_clicked(component: BaseComponent, pin_index: int)
signal body_clicked(component: BaseComponent)
signal body_double_clicked(component: BaseComponent)
signal rotated(component: BaseComponent)

@export var is_fixed: bool = false
@export var is_essential: bool = false
@export var component_label: String = ""

var pin_positions: Array[Vector2] = []
var connected_wires: Array = []
var is_placed: bool = false
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO
var connected_pins: Dictionary = {}
var _press_global_pos: Vector2 = Vector2.ZERO
var is_selected: bool = false
var _last_double_click_frame: int = -1

const PIN_RADIUS := 6.0
const PIN_COLOR := Color(0.25, 0.25, 0.25)
const PIN_HOVER_COLOR := Color(0.9, 0.9, 0.2)
const PIN_CONNECTED_COLOR := Color(0.15, 0.85, 0.85)
const SNAP_SIZE := 40.0
const PIN_HIT_RADIUS := 18.0
const CLICK_THRESHOLD := 6.0
const ROTATION_STEP_DEG := 90.0

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

func get_max_current() -> float:
	return 0.0

func get_component_type() -> String:
	return "base"

func is_conducting() -> bool:
	return true

## For multi-pin components (e.g. toggle switch) that want to gate specific pin connections.
## Returns a list of pin-pairs that are internally shorted (conducting) right now.
func get_internal_connections() -> Array:
	var result: Array = []
	if pin_positions.size() >= 2 and is_conducting():
		for i in range(pin_positions.size()):
			for j in range(i + 1, pin_positions.size()):
				result.append([i, j])
	return result

func update_visual_state(_current: float, _voltage: float) -> void:
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

func rotate_90(clockwise: bool = true) -> void:
	rotation_degrees += ROTATION_STEP_DEG if clockwise else -ROTATION_STEP_DEG
	rotation_degrees = fposmod(rotation_degrees, 360.0)
	rotated.emit(self)
	queue_redraw()

func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()

func _draw_connection_indicators() -> void:
	for pin_idx in connected_pins:
		if pin_idx >= 0 and pin_idx < pin_positions.size():
			draw_arc(pin_positions[pin_idx], PIN_RADIUS + 3.0, 0, TAU, 20, PIN_CONNECTED_COLOR, 2.0)

func _draw_selection_indicator() -> void:
	if not is_selected:
		return
	var r := _get_bounding_rect()
	r = r.grow(6.0)
	draw_rect(r, Color(0.2, 0.8, 1.0, 0.9), false, 2.0)

func _get_bounding_rect() -> Rect2:
	return Rect2(Vector2(-32, -32), Vector2(64, 64))

## Draw text that stays world-oriented (does NOT rotate with the component).
## world_offset is the desired pixel offset from the component origin in WORLD
## (un-rotated) coordinates: e.g. Vector2(0, 40) always appears "below" the
## component, regardless of its rotation.
func draw_world_text(world_offset: Vector2, text: String, font_size: int = 12,
		color: Color = Color(0.1, 0.1, 0.1), max_width: float = 180.0,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var local_anchor := world_offset.rotated(-rotation)
	draw_set_transform(local_anchor, -rotation, Vector2.ONE)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-max_width * 0.5, 0), text, align, max_width, font_size, color)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _draw() -> void:
	for i in range(pin_positions.size()):
		var col := PIN_CONNECTED_COLOR if i in connected_pins else PIN_COLOR
		draw_circle(pin_positions[i], PIN_RADIUS, col)
	_draw_connection_indicators()
	_draw_selection_indicator()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.double_click:
					_handle_double_tap()
				else:
					_handle_press()
			else:
				_handle_release()
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

	if event is InputEventMouseMotion and is_dragging and not is_fixed:
		global_position = get_global_mouse_position() - drag_offset

	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if st.double_tap:
				_handle_double_tap()
			else:
				_handle_press()
		else:
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
	if not _is_point_inside(local_pos):
		return
	if is_fixed:
		body_clicked.emit(self)
		_on_body_clicked()
		get_viewport().set_input_as_handled()
		return
	is_dragging = true
	drag_offset = mouse_global - global_position
	original_position = position
	z_index = 100
	get_viewport().set_input_as_handled()

func _handle_release() -> void:
	if not is_dragging:
		return
	is_dragging = false
	z_index = 0
	var moved := get_global_mouse_position().distance_to(_press_global_pos)
	if moved < CLICK_THRESHOLD:
		position = original_position
		body_clicked.emit(self)
		_on_body_clicked()
	else:
		placed_on_board.emit(self)
	get_viewport().set_input_as_handled()

func _handle_double_tap() -> void:
	var mouse_global := get_global_mouse_position()
	var local_pos := to_local(mouse_global)
	if not _is_point_inside(local_pos):
		return
	## De-dupe events that arrive both as mouse + emulated touch in the same frame.
	var frame := Engine.get_process_frames()
	if frame == _last_double_click_frame:
		get_viewport().set_input_as_handled()
		return
	_last_double_click_frame = frame
	## Cancel any half-started drag so we don't leave the component floating.
	if is_dragging:
		is_dragging = false
		z_index = 0
		position = original_position
	body_double_clicked.emit(self)
	get_viewport().set_input_as_handled()

func _on_body_clicked() -> void:
	pass

func _is_point_inside(local_pos: Vector2) -> bool:
	return _get_bounding_rect().has_point(local_pos)
