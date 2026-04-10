extends Node2D

const GRID_SIZE := 64.0
const BOARD_COLS := 12
const BOARD_ROWS := 8
const CONNECTION_COLOR := Color(0.3, 0.75, 0.6, 0.6)
const CONNECTION_WIDTH := 2.0
const CONNECTION_HIT_DISTANCE := 10.0
const PIN_SNAP_DISTANCE := 30.0

var circuit_graph: CircuitGraph
var level_data: LevelData
var placed_components: Array[BaseComponent] = []
var time_remaining: float = 0.0
var timer_active: bool = false

# Pin-to-pin connection state (for non-wire click-to-click connections)
var is_connecting: bool = false
var connect_start_component: BaseComponent = null
var connect_start_pin: int = -1
var wire_drawer: WireDrawer = null

# Connection tracking
var connections: Array[Dictionary] = []

# Buffer drag state
var _dragging_from_buffer: bool = false
var _buffer_drag_comp: BaseComponent = null

@onready var breadboard: Node2D = $Breadboard
@onready var components_layer: Node2D = $Breadboard/ComponentsLayer
@onready var wires_layer: Node2D = $Breadboard/WiresLayer
@onready var grid_overlay: Node2D = $Breadboard/GridOverlay
@onready var buffer_items: VBoxContainer = $ComponentBuffer/BufferItems
@onready var level_label: Label = $UILayer/TopPanel/LevelLabel
@onready var hint_panel: PanelContainer = $UILayer/HintPanel
@onready var hint_label: Label = $UILayer/HintPanel/HintLabel
@onready var timer_label: Label = $UILayer/TimerLabel

func _ready() -> void:
	circuit_graph = CircuitGraph.new()
	wire_drawer = WireDrawer.new()
	wires_layer.add_child(wire_drawer)
	_draw_grid()
	_load_current_level()

func _process(delta: float) -> void:
	if is_connecting and wire_drawer:
		wire_drawer.update_wire(wires_layer.to_local(wires_layer.get_global_mouse_position()))

	_update_connection_positions()
	_update_wire_pin_snapping()

	if timer_active and time_remaining > 0:
		time_remaining -= delta
		_update_timer_display()
		if time_remaining <= 0:
			time_remaining = 0
			timer_active = false
			GameManager.fail_level()

func _input(event: InputEvent) -> void:
	if not _dragging_from_buffer or _buffer_drag_comp == null:
		return
	if event is InputEventMouseMotion:
		_buffer_drag_comp.global_position = get_global_mouse_position()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_finish_buffer_drag()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_cancel_buffer_drag()
			get_viewport().set_input_as_handled()

func _finish_buffer_drag() -> void:
	if _buffer_drag_comp == null:
		return
	var mouse_pos := get_global_mouse_position()
	var board_local := mouse_pos - breadboard.global_position
	if board_local.x < 0 or board_local.x > 780 or board_local.y < 0 or board_local.y > 520:
		_cancel_buffer_drag()
		return
	_buffer_drag_comp.position = _buffer_drag_comp.snap_to_grid(_buffer_drag_comp.position)
	if not _buffer_drag_comp.is_placed:
		_buffer_drag_comp.place_on_board(_buffer_drag_comp.position)
	_buffer_drag_comp.z_index = 0
	_buffer_drag_comp = null
	_dragging_from_buffer = false

func _cancel_buffer_drag() -> void:
	if _buffer_drag_comp == null:
		return
	placed_components.erase(_buffer_drag_comp)
	circuit_graph.remove_component(_buffer_drag_comp)
	_buffer_drag_comp.queue_free()
	_buffer_drag_comp = null
	_dragging_from_buffer = false

# ── Level loading ──

func _load_current_level() -> void:
	var level_index := GameManager.current_level_index
	if level_index < 0:
		level_index = 0
	var path := GameManager.get_level_resource_path(level_index)
	if ResourceLoader.exists(path):
		level_data = ResourceLoader.load(path) as LevelData
	if level_data == null:
		level_data = LevelData.new()
		level_data.level_name = "Уровень %d" % level_index
		level_data.hint_text = "Соедините компоненты проводами, чтобы замкнуть цепь"

	level_label.text = level_data.level_name
	if not level_data.win_condition.is_empty():
		var target_val := float(level_data.win_condition.get("target_value", 0))
		var tol := float(level_data.win_condition.get("tolerance", 0))
		level_label.text += "   |   Цель: " + str(target_val) + " В на нагрузке (±" + str(tol) + " В)"
	hint_label.text = level_data.hint_text

	if level_data.time_limit > 0:
		time_remaining = level_data.time_limit
		timer_active = true
		timer_label.visible = true
		_update_timer_display()

	_spawn_fixed_components()
	_populate_buffer()

func _draw_grid() -> void:
	grid_overlay.queue_redraw()

func _parse_vector2(value) -> Vector2:
	if value is Vector2:
		return value
	if value is String:
		var s: String = value.strip_edges()
		s = s.replace("Vector2(", "").replace(")", "")
		var parts := s.split(",")
		if parts.size() >= 2:
			return Vector2(float(parts[0].strip_edges()), float(parts[1].strip_edges()))
	return Vector2.ZERO

func _spawn_fixed_components() -> void:
	for comp_info in level_data.fixed_components:
		var comp := _create_component(comp_info.get("type", ""), comp_info.get("params", {}))
		if comp == null:
			continue
		comp.is_fixed = true
		var pos: Vector2 = _parse_vector2(comp_info.get("position", Vector2.ZERO))
		comp.position = pos
		comp.is_placed = true
		components_layer.add_child(comp)
		placed_components.append(comp)
		circuit_graph.add_component(comp)
		_connect_component_signals(comp)

func _populate_buffer() -> void:
	for child in buffer_items.get_children():
		child.queue_free()

	var seen: Dictionary = {}
	for comp_info in level_data.available_components:
		var type_name: String = comp_info.get("type", "")
		var params: Dictionary = comp_info.get("params", {})
		var key := type_name + str(params)
		if key in seen:
			continue
		seen[key] = true
		var btn := Button.new()
		var display := _get_component_display_name(type_name)
		if type_name == "resistor" and params.has("resistance"):
			display += " (" + str(params["resistance"]) + "Ω)"
		btn.text = display
		btn.custom_minimum_size = Vector2(280, 50)
		btn.button_down.connect(_on_buffer_item_drag_start.bind(type_name, params))
		buffer_items.add_child(btn)

func _create_component(type_name: String, params: Dictionary) -> BaseComponent:
	var comp: BaseComponent = null
	match type_name:
		"power_source":
			var ps := PowerSource.new()
			ps.voltage = params.get("voltage", 9.0)
			ps.max_current = params.get("max_current", 2.0)
			comp = ps
		"resistor":
			var r := Resistor.new()
			r.resistance = params.get("resistance", 100.0)
			comp = r
		"consumer":
			var c := Consumer.new()
			c.required_voltage = params.get("required_voltage", 9.0)
			c.required_power = params.get("required_power", 5.0)
			c.consumer_name = params.get("name", "Лампа")
			comp = c
		"switch":
			var s := SwitchComponent.new()
			comp = s
		"toggle_switch":
			var ts := ToggleSwitch.new()
			comp = ts
		"voltammeter":
			var vam := Voltammeter.new()
			comp = vam
		"wire":
			var w := WireComponent.new()
			comp = w
		_:
			push_warning("Unknown component type: " + type_name)
			return null

	return comp

func _get_component_display_name(type_name: String) -> String:
	match type_name:
		"power_source": return "⚡ Источник питания"
		"resistor": return "◼ Резистор"
		"consumer": return "💡 Потребитель"
		"switch": return "⏻ Выключатель"
		"toggle_switch": return "⇆ Переключатель"
		"voltammeter": return "📊 Вольт-Ампер Метр"
		"wire": return "─ Провод"
	return type_name

func _on_buffer_item_drag_start(type_name: String, params: Dictionary) -> void:
	var comp := _create_component(type_name, params)
	if comp == null:
		return
	components_layer.add_child(comp)
	comp.global_position = get_global_mouse_position()
	placed_components.append(comp)
	circuit_graph.add_component(comp)
	_connect_component_signals(comp)
	comp.z_index = 100
	_buffer_drag_comp = comp
	_dragging_from_buffer = true

func _connect_component_signals(comp: BaseComponent) -> void:
	comp.pin_clicked.connect(_on_pin_clicked)
	if comp is WireComponent:
		comp.pin_drag_ended.connect(_on_wire_pin_drag_ended)

# ── Wire auto-connect system ──

func _on_wire_pin_drag_ended(wire: WireComponent, pin_index: int) -> void:
	_remove_connections_on_pin(wire, pin_index)

	var pin_global: Vector2 = wire.get_pin_global_position(pin_index)
	var target: Variant = _find_nearest_pin(pin_global, wire)

	if target:
		var target_comp: BaseComponent = target["comp"]
		var target_pin: int = target["pin"]
		var target_global := target_comp.get_pin_global_position(target_pin)
		wire.pin_positions[pin_index] = wire.to_local(target_global)
		wire.queue_redraw()
		_create_connection(wire, pin_index, target_comp, target_pin)

func _find_nearest_pin(global_pos: Vector2, exclude_comp: BaseComponent) -> Variant:
	var best_dist := PIN_SNAP_DISTANCE
	var result = null
	for comp in placed_components:
		if comp == exclude_comp:
			continue
		for i in range(comp.pin_positions.size()):
			var pin_global := comp.get_pin_global_position(i)
			var dist := global_pos.distance_to(pin_global)
			if dist < best_dist:
				best_dist = dist
				result = {"comp": comp, "pin": i}
	return result

func _update_wire_pin_snapping() -> void:
	for c in connections:
		var from_comp: BaseComponent = c["from_comp"]
		var to_comp: BaseComponent = c["to_comp"]
		if not is_instance_valid(from_comp) or not is_instance_valid(to_comp):
			continue
		if from_comp is WireComponent:
			var wire: WireComponent = from_comp
			if wire.dragging_pin < 0:
				var target_global := to_comp.get_pin_global_position(c["to_pin"])
				wire.pin_positions[c["from_pin"]] = wire.to_local(target_global)
				wire.queue_redraw()
		if to_comp is WireComponent:
			var wire: WireComponent = to_comp
			if wire.dragging_pin < 0:
				var target_global := from_comp.get_pin_global_position(c["from_pin"])
				wire.pin_positions[c["to_pin"]] = wire.to_local(target_global)
				wire.queue_redraw()

# ── Connection system (pin-to-pin links) ──

func _pin_to_local(comp: BaseComponent, pin_index: int) -> Vector2:
	return wires_layer.to_local(comp.get_pin_global_position(pin_index))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if is_connecting:
				_cancel_connecting()
				get_viewport().set_input_as_handled()
				return
			var mouse_local := wires_layer.to_local(wires_layer.get_global_mouse_position())
			var conn_idx := _find_connection_at(mouse_local)
			if conn_idx >= 0:
				_remove_connection(conn_idx)
				get_viewport().set_input_as_handled()

func _on_pin_clicked(component: BaseComponent, pin_index: int) -> void:
	if not is_connecting:
		connect_start_component = component
		connect_start_pin = pin_index
		is_connecting = true
		if wire_drawer:
			wire_drawer.start_wire(_pin_to_local(component, pin_index))
	else:
		if component != connect_start_component:
			_create_connection(connect_start_component, connect_start_pin, component, pin_index)
		_cancel_connecting()

func _cancel_connecting() -> void:
	is_connecting = false
	connect_start_component = null
	connect_start_pin = -1
	if wire_drawer:
		wire_drawer.cancel_wire()

func _create_connection(from_comp: BaseComponent, from_pin: int, to_comp: BaseComponent, to_pin: int) -> void:
	var line := Line2D.new()
	line.width = CONNECTION_WIDTH
	line.default_color = CONNECTION_COLOR
	line.add_point(_pin_to_local(from_comp, from_pin))
	line.add_point(_pin_to_local(to_comp, to_pin))
	wires_layer.add_child(line)

	var from_ids := circuit_graph.find_node_ids_for_component(from_comp)
	var to_ids := circuit_graph.find_node_ids_for_component(to_comp)
	if from_pin < from_ids.size() and to_pin < to_ids.size():
		circuit_graph.connect_pins(from_ids[from_pin], to_ids[to_pin], line)

	connections.append({
		"line": line,
		"from_comp": from_comp,
		"from_pin": from_pin,
		"to_comp": to_comp,
		"to_pin": to_pin,
	})

	from_comp.mark_pin_connected(from_pin, true)
	to_comp.mark_pin_connected(to_pin, true)

	_recalculate_circuit()

func _update_connection_positions() -> void:
	for c in connections:
		var line: Line2D = c["line"]
		var from_comp: BaseComponent = c["from_comp"]
		var to_comp: BaseComponent = c["to_comp"]
		if not is_instance_valid(from_comp) or not is_instance_valid(to_comp):
			continue
		line.set_point_position(0, _pin_to_local(from_comp, c["from_pin"]))
		line.set_point_position(1, _pin_to_local(to_comp, c["to_pin"]))

func _remove_connection(index: int) -> void:
	if index < 0 or index >= connections.size():
		return
	var c: Dictionary = connections[index]
	var line: Line2D = c["line"]
	var from_comp: BaseComponent = c["from_comp"]
	var to_comp: BaseComponent = c["to_comp"]
	var from_pin: int = c["from_pin"]
	var to_pin: int = c["to_pin"]

	circuit_graph.disconnect_wire(line)
	line.queue_free()
	connections.remove_at(index)

	if is_instance_valid(from_comp) and not _has_connections_on_pin(from_comp, from_pin):
		from_comp.mark_pin_connected(from_pin, false)
	if is_instance_valid(to_comp) and not _has_connections_on_pin(to_comp, to_pin):
		to_comp.mark_pin_connected(to_pin, false)

	_recalculate_circuit()

func _remove_connections_on_pin(comp: BaseComponent, pin: int) -> void:
	var to_remove: Array[int] = []
	for i in range(connections.size()):
		var c: Dictionary = connections[i]
		if (c["from_comp"] == comp and c["from_pin"] == pin) or \
		   (c["to_comp"] == comp and c["to_pin"] == pin):
			to_remove.append(i)
	to_remove.reverse()
	for idx in to_remove:
		_remove_connection(idx)

func _has_connections_on_pin(comp: BaseComponent, pin: int) -> bool:
	for c in connections:
		if (c["from_comp"] == comp and c["from_pin"] == pin) or \
		   (c["to_comp"] == comp and c["to_pin"] == pin):
			return true
	return false

func _find_connection_at(local_pos: Vector2) -> int:
	for i in range(connections.size()):
		var line: Line2D = connections[i]["line"]
		if line.get_point_count() < 2:
			continue
		var a := line.get_point_position(0)
		var b := line.get_point_position(1)
		if _point_to_segment_distance(local_pos, a, b) <= CONNECTION_HIT_DISTANCE:
			return i
	return -1

func _point_to_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	var proj := a + ab * t
	return p.distance_to(proj)

# ── Circuit ──

func _recalculate_circuit() -> Dictionary:
	return circuit_graph.solve()

func _check_win_condition() -> bool:
	var result := _recalculate_circuit()
	if not result.get("is_closed", false):
		return false

	var win := level_data.win_condition
	if win.is_empty():
		return result.get("is_closed", false)

	var win_type: String = win.get("type", "voltage")
	var target: float = win.get("target_value", 0.0)
	var tolerance: float = win.get("tolerance", 0.5)

	var consumers := circuit_graph.find_consumers()
	for consumer in consumers:
		var comp_data: Dictionary = result.get("components", {})
		var key := consumer.get_instance_id()
		if key not in comp_data:
			continue
		var data: Dictionary = comp_data[key]
		match win_type:
			"voltage":
				if absf(data.get("voltage", 0.0) - target) <= tolerance:
					return true
			"power":
				if absf(data.get("power", 0.0) - target) <= tolerance:
					return true
			"current":
				if absf(data.get("current", 0.0) - target) <= tolerance:
					return true
	return false

# ── UI ──

func _on_back_pressed() -> void:
	GameManager.go_to_level_select()

func _on_hint_pressed() -> void:
	hint_panel.visible = not hint_panel.visible

func _on_check_pressed() -> void:
	var result := _recalculate_circuit()
	if _check_win_condition():
		GameManager.complete_level()
		get_tree().change_scene_to_file("res://scenes/level_complete/level_complete.tscn")
	else:
		_show_feedback(result)

func _show_feedback(result: Dictionary) -> void:
	if not result.get("is_closed", false):
		hint_label.text = "Цепь не замкнута! Проверьте соединения."
	else:
		var current: float = result.get("total_current", 0.0)
		var voltage: float = result.get("source_voltage", 0.0)
		hint_label.text = "Цепь замкнута. Ток: %.2f А, Напряжение: %.2f В\nНо условие победы не выполнено." % [current, voltage]
	hint_panel.visible = true

func _on_debug_auto_complete() -> void:
	GameManager.complete_level()
	get_tree().change_scene_to_file("res://scenes/level_complete/level_complete.tscn")

func _update_timer_display() -> void:
	var minutes := int(time_remaining) / 60
	var seconds := int(time_remaining) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
