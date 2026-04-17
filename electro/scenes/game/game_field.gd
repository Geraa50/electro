extends Node2D

const POWER_COOLDOWN_SECONDS := 5.0

var level_data: LevelData
var circuit_graph: CircuitGraph
var placed_components: Array[BaseComponent] = []
var selected_component: BaseComponent = null
var consumer_targets: Array[float] = []

var _dragging_from_buffer: bool = false
var _buffer_drag_comp: BaseComponent = null

@onready var breadboard: Breadboard = $BoardArea/Breadboard
@onready var components_layer: Node2D = $BoardArea/ComponentsLayer
@onready var buffer_items: VBoxContainer = $ComponentBuffer/BufferItems
@onready var level_label: Label = $UILayer/TopPanel/LevelLabel
@onready var status_label: Label = $UILayer/StatusPanel/StatusLabel
@onready var hint_overlay: Control = $UILayer/HintOverlay
@onready var hint_label: Label = $UILayer/HintOverlay/HintPanel/HintLabel
@onready var hint_bg: ColorRect = $UILayer/HintOverlay/HintBG

func _ready() -> void:
	circuit_graph = CircuitGraph.new(breadboard)
	await get_tree().process_frame
	_load_current_level()
	hint_bg.gui_input.connect(_on_hint_bg_input)

func _process(_delta: float) -> void:
	if _dragging_from_buffer and _buffer_drag_comp != null:
		_buffer_drag_comp.global_position = get_global_mouse_position()

	_recompute_circuit_if_dirty()

func _input(event: InputEvent) -> void:
	if _dragging_from_buffer and _buffer_drag_comp != null:
		if event is InputEventMouseMotion:
			_buffer_drag_comp.global_position = get_global_mouse_position()
		elif event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				_finish_buffer_drag()
			elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				_cancel_buffer_drag()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			var comp := _find_component_at(get_global_mouse_position())
			if comp != null and not comp.is_fixed and not comp.is_essential:
				_remove_component(comp)
				get_viewport().set_input_as_handled()

func _load_current_level() -> void:
	var level_index := GameManager.current_level_index
	if level_index < 0:
		level_index = 0
	var path := GameManager.get_level_resource_path(level_index)
	level_data = LevelLoader.load_level(path)
	if level_data == null:
		level_data = LevelData.new()
		level_data.level_name = "Уровень %d" % level_index
		level_data.hint = "Соберите цепь и нажмите на источник питания."

	level_label.text = level_data.level_name
	hint_label.text = level_data.hint

	_spawn_fixed_components()
	_populate_buffer()
	_update_status_default()

func _spawn_fixed_components() -> void:
	var board_size := breadboard.get_board_size()
	var ps_count: int = level_data.power_count
	var goal_count: int = level_data.goal_count
	consumer_targets.clear()

	var spacing_y: float = board_size.y / float(ps_count + 1)
	for i in range(ps_count):
		var ps := _make_component("power_source", {
			"voltage": level_data.power_voltages[i],
			"max_current": 5.0
		}) as PowerSource
		ps.is_fixed = false
		ps.is_essential = true
		_add_component_to_scene(ps, true)
		ps.global_position = breadboard.snap_global_to_cell(breadboard.to_global(Vector2(
			Breadboard.PIN_SPACING * 3.0,
			spacing_y * (i + 1)
		)))
		_snap_component_to_board(ps)

	var goal_spacing: float = board_size.y / float(goal_count + 1)
	for i in range(goal_count):
		var gv: float = level_data.goal_voltages[i]
		var lamp_r: float = max(gv * 2.0, 4.0)
		var cons := _make_component("consumer", {
			"required_voltage": gv,
			"required_power": gv * gv / lamp_r,
			"name": "Лампа %d" % (i + 1),
			"resistance": lamp_r
		}) as Consumer
		cons.is_essential = true
		_add_component_to_scene(cons, true)
		cons.global_position = breadboard.snap_global_to_cell(breadboard.to_global(Vector2(
			Breadboard.PIN_SPACING * (Breadboard.COLS - 4.0),
			goal_spacing * (i + 1)
		)))
		_snap_component_to_board(cons)
		consumer_targets.append(level_data.goal_voltages[i])

func _populate_buffer() -> void:
	for child in buffer_items.get_children():
		child.queue_free()

	if level_data.allow_wire:
		for i in range(8):
			_add_buffer_button("wire", {}, "Провод")

	for i in range(level_data.resistor_count):
		var r_val: float = level_data.resistor_values[i] if i < level_data.resistor_values.size() else 10.0
		_add_buffer_button("resistor", {"resistance": r_val}, "Резистор (%s)" % _format_r(r_val))

	if level_data.allow_voltammeter:
		_add_buffer_button("voltammeter", {}, "Вольт-ампер метр")

	if level_data.allow_switch:
		_add_buffer_button("switch", {}, "Выключатель")

	if level_data.allow_toggle:
		_add_buffer_button("toggle_switch", {}, "Переключатель")

func _format_r(r: float) -> String:
	if r >= 1000.0:
		return "%.1f кΩ" % (r / 1000.0)
	return "%.0f Ω" % r

func _add_buffer_button(type_name: String, params: Dictionary, label: String) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(480, 44)
	btn.button_down.connect(_on_buffer_item_drag_start.bind(type_name, params))
	buffer_items.add_child(btn)

func _make_component(type_name: String, params: Dictionary) -> BaseComponent:
	var comp: BaseComponent
	match type_name:
		"power_source":
			var ps := PowerSource.new()
			ps.voltage = float(params.get("voltage", 9.0))
			ps.max_current = float(params.get("max_current", 5.0))
			comp = ps
		"resistor":
			var r := Resistor.new()
			r.resistance = float(params.get("resistance", 10.0))
			comp = r
		"consumer":
			var c := Consumer.new()
			c.required_voltage = float(params.get("required_voltage", 9.0))
			c.required_power = float(params.get("required_power", 5.0))
			c.consumer_name = str(params.get("name", "Лампа"))
			c.consumer_resistance = float(params.get("resistance", 16.0))
			comp = c
		"switch":
			comp = SwitchComponent.new()
		"toggle_switch":
			comp = ToggleSwitch.new()
		"voltammeter":
			comp = Voltammeter.new()
		"wire":
			comp = WireComponent.new()
		_:
			return null
	return comp

func _add_component_to_scene(comp: BaseComponent, placed: bool) -> void:
	components_layer.add_child(comp)
	if placed:
		comp.is_placed = true
	placed_components.append(comp)
	circuit_graph.add_component(comp)
	_connect_component_signals(comp)

func _connect_component_signals(comp: BaseComponent) -> void:
	comp.body_clicked.connect(_on_component_body_clicked)
	comp.placed_on_board.connect(_on_component_placed)
	comp.rotated.connect(_on_component_rotated)
	if comp is WireComponent:
		var wire: WireComponent = comp
		wire.pin_drag_ended.connect(_on_wire_pin_drag_ended)
		wire.body_drag_ended.connect(_on_wire_body_drag_ended)

func _on_component_rotated(comp: BaseComponent) -> void:
	_snap_component_to_board(comp)

func _on_component_body_clicked(comp: BaseComponent) -> void:
	_set_selected(comp)
	if comp is PowerSource:
		_handle_power_source_click(comp as PowerSource)
	elif comp is SwitchComponent:
		pass  # already toggled inside the switch
	elif comp is ToggleSwitch:
		pass

func _on_component_placed(comp: BaseComponent) -> void:
	_snap_component_to_board(comp)
	queue_redraw()

func _on_wire_pin_drag_ended(wire: WireComponent, pin_index: int) -> void:
	var global_pin := wire.get_pin_global_position(pin_index)
	if not breadboard.is_on_board_global(global_pin):
		return
	var snapped_global := breadboard.snap_global_to_cell(global_pin)
	wire.pin_positions[pin_index] = wire.to_local(snapped_global)
	wire.queue_redraw()
	_mark_dirty()

func _on_wire_body_drag_ended(wire: WireComponent) -> void:
	_snap_component_to_board(wire)

## Snap every pin of the component onto its nearest breadboard pin. Use the
## first pin to decide the overall offset, so the relative layout is preserved.
func _snap_component_to_board(comp: BaseComponent) -> void:
	if comp.pin_positions.is_empty():
		return
	var first_pin_global := comp.get_pin_global_position(0)
	var snapped_first := breadboard.snap_global_to_cell(first_pin_global)
	var delta := snapped_first - first_pin_global
	comp.global_position += delta

	if comp is WireComponent:
		for i in range(comp.pin_positions.size()):
			var pg := comp.get_pin_global_position(i)
			var sp := breadboard.snap_global_to_cell(pg)
			comp.pin_positions[i] = comp.to_local(sp)
		comp.queue_redraw()

	_update_pin_connection_visuals()
	_mark_dirty()

func _update_pin_connection_visuals() -> void:
	var bus_usage: Dictionary = {}
	for comp in placed_components:
		if not is_instance_valid(comp):
			continue
		for i in range(comp.pin_positions.size()):
			var bus := breadboard.get_bus_for_global(comp.get_pin_global_position(i))
			if bus < 0:
				comp.mark_pin_connected(i, false)
				continue
			bus_usage[bus] = bus_usage.get(bus, 0) + 1

	for comp in placed_components:
		if not is_instance_valid(comp):
			continue
		for i in range(comp.pin_positions.size()):
			var bus := breadboard.get_bus_for_global(comp.get_pin_global_position(i))
			if bus < 0:
				comp.mark_pin_connected(i, false)
				continue
			comp.mark_pin_connected(i, bus_usage.get(bus, 0) > 1)

func _snap_global_to_board(global_pos: Vector2) -> Vector2:
	return to_local(breadboard.snap_global_to_cell(global_pos))

## ── Buffer dragging ──

func _on_buffer_item_drag_start(type_name: String, params: Dictionary) -> void:
	var comp := _make_component(type_name, params)
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

func _finish_buffer_drag() -> void:
	if _buffer_drag_comp == null:
		return
	if not breadboard.is_on_board_global(_buffer_drag_comp.global_position):
		_cancel_buffer_drag()
		return
	_buffer_drag_comp.z_index = 0
	_snap_component_to_board(_buffer_drag_comp)
	_buffer_drag_comp.is_placed = true
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

func _find_component_at(global_pos: Vector2) -> BaseComponent:
	for i in range(placed_components.size() - 1, -1, -1):
		var comp: BaseComponent = placed_components[i]
		if not is_instance_valid(comp):
			continue
		var local := comp.to_local(global_pos)
		if comp._is_point_inside(local):
			return comp
	return null

func _remove_component(comp: BaseComponent) -> void:
	if comp == null:
		return
	placed_components.erase(comp)
	circuit_graph.remove_component(comp)
	if selected_component == comp:
		selected_component = null
	comp.queue_free()
	_mark_dirty()

func _set_selected(comp: BaseComponent) -> void:
	if selected_component == comp:
		return
	if selected_component != null and is_instance_valid(selected_component):
		selected_component.set_selected(false)
	selected_component = comp
	if comp != null:
		comp.set_selected(true)

## ── Circuit / win logic ──

var _circuit_dirty: bool = true

func _mark_dirty() -> void:
	_circuit_dirty = true

func _recompute_circuit_if_dirty() -> void:
	if not _circuit_dirty:
		return
	_circuit_dirty = false
	_update_pin_connection_visuals()
	circuit_graph.solve()

func _handle_power_source_click(ps: PowerSource) -> void:
	if ps.is_cooldown:
		status_label.text = "Источник перезаряжается: %.1f с" % ps.cooldown_remaining
		return

	for comp in placed_components:
		if comp is PowerSource:
			(comp as PowerSource).set_on(true)
	_mark_dirty()
	await get_tree().process_frame
	_update_pin_connection_visuals()
	circuit_graph.solve()

	if _check_win_condition():
		status_label.text = "✔ Цепь собрана правильно!"
		await get_tree().create_timer(0.6).timeout
		GameManager.complete_level()
		get_tree().change_scene_to_file("res://scenes/level_complete/level_complete.tscn")
	else:
		_start_recharge_all_sources()
		status_label.text = "✘ Напряжение не соответствует. Источник перезаряжается 5 с."

func _start_recharge_all_sources() -> void:
	for comp in placed_components:
		if comp is PowerSource:
			(comp as PowerSource).start_cooldown(POWER_COOLDOWN_SECONDS)

func _check_win_condition() -> bool:
	var consumers := circuit_graph.find_consumers()
	if consumers.is_empty():
		return false

	if consumer_targets.is_empty():
		return false

	if consumers.size() < consumer_targets.size():
		return false

	var remaining := consumer_targets.duplicate()
	for cons in consumers:
		var found_index: int = -1
		var best_err := INF
		for k in range(remaining.size()):
			var target: float = remaining[k]
			var err: float = absf(cons.current_voltage - target)
			if err < best_err:
				best_err = err
				found_index = k
		if found_index < 0:
			return false
		if best_err > level_data.voltage_tolerance:
			return false
		if cons.current_current <= 0.001:
			return false
		remaining.remove_at(found_index)
	return true

func _update_status_default() -> void:
	status_label.text = "Соберите схему и щёлкните по источнику питания."

## ── UI handlers ──

func _on_back_pressed() -> void:
	GameManager.go_to_level_select()

func _on_hint_pressed() -> void:
	hint_overlay.visible = not hint_overlay.visible

func _on_hint_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hint_overlay.visible = false
