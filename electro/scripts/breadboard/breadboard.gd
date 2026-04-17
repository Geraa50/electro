class_name Breadboard
extends Node2D

## Classic solderless breadboard.
## Pin layout:
##  Row 0    — top "+" power rail   (all columns connected horizontally)
##  Row 1    — top "−" power rail   (all columns connected horizontally)
##  Rows 2-6 — terminal strip A     (each column = 5 pins connected vertically)
##  Row 7    — central ravine       (no electrical connection)
##  Rows 8-12— terminal strip B     (each column = 5 pins connected vertically)

const PIN_SPACING: float = 40.0
const COLS: int = 16
const ROWS: int = 13

const BOARD_BG := Color(0.92, 0.89, 0.78)
const PIN_HOLE_COLOR := Color(0.12, 0.12, 0.12)
const PLUS_COLOR := Color(0.80, 0.15, 0.15)
const MINUS_COLOR := Color(0.15, 0.15, 0.75)
const RAIL_TINT := Color(1.0, 0.94, 0.94, 0.5)
const RAIL_TINT_MINUS := Color(0.94, 0.94, 1.0, 0.5)
const RAVINE_COLOR := Color(0.75, 0.72, 0.62)
const GRID_BORDER_COLOR := Color(0.4, 0.35, 0.25, 0.35)

const ROW_TOP_PLUS: int = 0
const ROW_TOP_MINUS: int = 1
const ROW_STRIP_A_START: int = 2
const ROW_STRIP_A_END: int = 6
const ROW_RAVINE: int = 7
const ROW_STRIP_B_START: int = 8
const ROW_STRIP_B_END: int = 12

## Bus id for each (col,row). -1 = no bus (ravine).
var _bus_by_pin: Dictionary = {}  ## key = Vector2i(col,row) → int bus_id
var _pins_by_bus: Dictionary = {} ## bus_id → Array[Vector2i]
var _next_bus_id: int = 0

func _ready() -> void:
	_build_buses()
	queue_redraw()

func _build_buses() -> void:
	_bus_by_pin.clear()
	_pins_by_bus.clear()
	_next_bus_id = 0

	var top_plus := _new_bus()
	for c in range(COLS):
		_assign(Vector2i(c, ROW_TOP_PLUS), top_plus)

	var top_minus := _new_bus()
	for c in range(COLS):
		_assign(Vector2i(c, ROW_TOP_MINUS), top_minus)

	for c in range(COLS):
		var bus := _new_bus()
		for r in range(ROW_STRIP_A_START, ROW_STRIP_A_END + 1):
			_assign(Vector2i(c, r), bus)

	for c in range(COLS):
		var bus := _new_bus()
		for r in range(ROW_STRIP_B_START, ROW_STRIP_B_END + 1):
			_assign(Vector2i(c, r), bus)

func _new_bus() -> int:
	var id := _next_bus_id
	_next_bus_id += 1
	_pins_by_bus[id] = []
	return id

func _assign(cell: Vector2i, bus_id: int) -> void:
	_bus_by_pin[cell] = bus_id
	_pins_by_bus[bus_id].append(cell)

func get_board_size() -> Vector2:
	return Vector2(COLS * PIN_SPACING, ROWS * PIN_SPACING)

func cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * PIN_SPACING, (cell.y + 0.5) * PIN_SPACING)

func local_to_cell(local_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(local_pos.x / PIN_SPACING)),
		int(floor(local_pos.y / PIN_SPACING))
	)

func nearest_cell_from_global(global_pos: Vector2) -> Vector2i:
	var local_pos := to_local(global_pos)
	var c := int(round(local_pos.x / PIN_SPACING - 0.5))
	var r := int(round(local_pos.y / PIN_SPACING - 0.5))
	c = clampi(c, 0, COLS - 1)
	r = clampi(r, 0, ROWS - 1)
	return Vector2i(c, r)

func snap_global_to_cell(global_pos: Vector2) -> Vector2:
	var cell := nearest_cell_from_global(global_pos)
	return to_global(cell_to_local(cell))

func get_bus_for_cell(cell: Vector2i) -> int:
	return _bus_by_pin.get(cell, -1)

func get_bus_for_global(global_pos: Vector2) -> int:
	var cell := nearest_cell_from_global(global_pos)
	var local_centre := cell_to_local(cell)
	if to_local(global_pos).distance_to(local_centre) > PIN_SPACING * 0.55:
		return -1
	return get_bus_for_cell(cell)

func is_on_board_global(global_pos: Vector2) -> bool:
	var local_pos := to_local(global_pos)
	var sz := get_board_size()
	return local_pos.x >= 0 and local_pos.y >= 0 and local_pos.x <= sz.x and local_pos.y <= sz.y

func get_bus_ids() -> Array:
	return _pins_by_bus.keys()

func _draw() -> void:
	var sz := get_board_size()
	draw_rect(Rect2(Vector2.ZERO, sz), BOARD_BG, true)

	var plus_rect := Rect2(0, 0, sz.x, PIN_SPACING)
	var minus_rect := Rect2(0, PIN_SPACING, sz.x, PIN_SPACING)
	draw_rect(plus_rect, RAIL_TINT, true)
	draw_rect(minus_rect, RAIL_TINT_MINUS, true)

	var plus_rect_b := Rect2(0, (ROW_STRIP_B_END) * PIN_SPACING, sz.x, PIN_SPACING)
	draw_rect(plus_rect_b, Color(0.95, 0.95, 0.82, 0.25), true)

	var ravine_rect := Rect2(0, ROW_RAVINE * PIN_SPACING, sz.x, PIN_SPACING)
	draw_rect(ravine_rect, RAVINE_COLOR, true)
	draw_line(Vector2(0, (ROW_RAVINE + 0.5) * PIN_SPACING), Vector2(sz.x, (ROW_RAVINE + 0.5) * PIN_SPACING), Color(0.35, 0.3, 0.2), 2.0)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(4, 14), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, PLUS_COLOR)
	draw_string(font, Vector2(4, 14 + PIN_SPACING), "−", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MINUS_COLOR)

	for cell in _bus_by_pin.keys():
		var p := cell_to_local(cell)
		draw_circle(p, 3.5, PIN_HOLE_COLOR)
		draw_arc(p, 4.5, 0, TAU, 16, Color(0, 0, 0, 0.35), 1.0)

	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.25, 0.2, 0.1, 0.6), false, 2.0)
