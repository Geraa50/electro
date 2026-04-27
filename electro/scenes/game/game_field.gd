extends Node2D

const POWER_COOLDOWN_SECONDS := 5.0
const WIN_TRANSITION_DELAY := 2.6
## Столько секунд источник остаётся включённым перед проверкой: даёт
## пользователю время снять показания с вольт-амперметра.
const OBSERVATION_DELAY := 2.0

## 5 кликов в нижнем левом углу экрана за короткое время — авто-прохождение
## уровня (чит-код для отладки / прохождения сложных уровней). Зона задана
## размером в пикселях; реальный прямоугольник считается каждый раз от текущего
## размера вьюпорта, чтобы корректно работало при ресайзе окна и на мобильных.
const CHEAT_ZONE_SIZE := Vector2(60, 60)
const CHEAT_CLICKS_NEEDED := 5
const CHEAT_WINDOW_SECONDS := 4.0

var level_data: LevelData
var circuit_graph: CircuitGraph
var placed_components: Array[BaseComponent] = []
var selected_component: BaseComponent = null
var consumer_targets: Array[float] = []

var _dragging_from_buffer: bool = false
var _buffer_drag_comp: BaseComponent = null
var _buffer_slots: Array[Dictionary] = []
var _evaluating: bool = false

var _cheat_clicks: int = 0
var _cheat_last_time: float = 0.0

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
		elif event is InputEventScreenDrag:
			_buffer_drag_comp.global_position = (event as InputEventScreenDrag).position
		elif event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				_finish_buffer_drag()
		elif event is InputEventScreenTouch:
			var st := event as InputEventScreenTouch
			if not st.pressed:
				_finish_buffer_drag()

func _unhandled_input(event: InputEvent) -> void:
	## Клики по нижнему левому углу экрана — счётчик для чит-кода.
	## Сюда попадают только те нажатия, которые не были перехвачены
	## UI-элементами (например, кнопкой «МЕНЮ»).
	var pos: Vector2
	var is_press := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and not mb.double_click:
			pos = mb.position
			is_press = true
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and not st.double_tap:
			pos = st.position
			is_press = true
	if not is_press:
		return
	if not _cheat_zone_rect().has_point(pos):
		return

	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _cheat_last_time > CHEAT_WINDOW_SECONDS:
		_cheat_clicks = 0
	_cheat_last_time = now
	_cheat_clicks += 1

	var left: int = CHEAT_CLICKS_NEEDED - _cheat_clicks
	if _cheat_clicks >= CHEAT_CLICKS_NEEDED:
		_cheat_clicks = 0
		_auto_complete_level()
	else:
		status_label.text = "🛠 Чит: осталось %d нажатий" % left

func _cheat_zone_rect() -> Rect2:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var origin := Vector2(0.0, vp_size.y - CHEAT_ZONE_SIZE.y)
	return Rect2(origin, CHEAT_ZONE_SIZE)

func _auto_complete_level() -> void:
	if _evaluating:
		return
	_evaluating = true
	status_label.text = "🛠 Чит активирован — уровень пройден!"
	await get_tree().create_timer(0.4).timeout
	GameManager.complete_level()
	get_tree().change_scene_to_file("res://scenes/level_complete/level_complete.tscn")

func _load_current_level() -> void:
	var level_index := GameManager.current_level_index
	if level_index < 0:
		level_index = 0
	level_data = GameManager.get_level_data(level_index)
	if level_data == null:
		level_data = LevelData.new()
		level_data.level_name = "Уровень %d" % level_index
		level_data.hint = "Соберите цепь и нажмите на источник питания."

	level_label.text = level_data.level_name
	hint_label.text = level_data.hint

	consumer_targets.clear()
	for v in level_data.goal_voltages:
		consumer_targets.append(v)

	_populate_buffer()
	_update_status_default()

## ── Buffer ──

func _populate_buffer() -> void:
	for child in buffer_items.get_children():
		child.queue_free()
	_buffer_slots.clear()

	if level_data.allow_wire:
		_add_buffer_slot("wire", {}, "Провод", 0, true)

	for i in range(level_data.power_count):
		var pv: float = level_data.power_voltages[i] if i < level_data.power_voltages.size() else 9.0
		_add_buffer_slot("power_source", {
			"voltage": pv,
			"max_current": 5.0
		}, "Источник %.0f В" % pv, 1, false)

	for i in range(level_data.goal_count):
		var gv: float = level_data.goal_voltages[i] if i < level_data.goal_voltages.size() else 9.0
		var lamp_r: float = max(gv * 2.0, 4.0)
		_add_buffer_slot("consumer", {
			"required_voltage": gv,
			"required_power": gv * gv / lamp_r,
			"name": "Лампа %d" % (i + 1),
			"resistance": lamp_r
		}, "Лампа %.0f В" % gv, 1, false)

	for i in range(level_data.resistor_count):
		var r_val: float = level_data.resistor_values[i] if i < level_data.resistor_values.size() else 10.0
		_add_buffer_slot("resistor", {"resistance": r_val}, "Резистор (%s)" % _format_r(r_val), 1, false)

	if level_data.allow_voltammeter:
		_add_buffer_slot("voltammeter", {}, "Вольт-амперметр", 1, false)

	if level_data.allow_switch:
		_add_buffer_slot("switch", {}, "Выключатель", 1, false)

	if level_data.allow_toggle:
		_add_buffer_slot("toggle_switch", {}, "Переключатель", 1, false)

func _add_buffer_slot(type_name: String, params: Dictionary, base_label: String, count: int, infinite: bool) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(480, 44)
	buffer_items.add_child(btn)
	var slot: Dictionary = {
		"type": type_name,
		"params": params,
		"base_label": base_label,
		"count": count,
		"infinite": infinite,
		"button": btn
	}
	_buffer_slots.append(slot)
	btn.button_down.connect(_on_buffer_slot_drag_start.bind(slot))
	_refresh_buffer_slot(slot)

func _refresh_buffer_slot(slot: Dictionary) -> void:
	var btn: Button = slot["button"]
	if slot["infinite"]:
		btn.text = slot["base_label"]
		btn.visible = true
		btn.disabled = false
	else:
		btn.text = "%s × %d" % [slot["base_label"], slot["count"]]
		btn.visible = slot["count"] > 0
		btn.disabled = slot["count"] <= 0

func _format_r(r: float) -> String:
	if r >= 1000.0:
		return "%.1f кΩ" % (r / 1000.0)
	return "%.0f Ω" % r

## ── Component factory ──

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
	comp.body_double_clicked.connect(_on_component_double_clicked)
	comp.placed_on_board.connect(_on_component_placed)
	comp.rotated.connect(_on_component_rotated)
	if comp is WireComponent:
		var wire: WireComponent = comp
		wire.pin_drag_ended.connect(_on_wire_pin_drag_ended)
		wire.body_drag_ended.connect(_on_wire_body_drag_ended)
	if comp is Voltammeter:
		(comp as Voltammeter).mode_changed.connect(_on_voltammeter_mode_changed)

func _on_voltammeter_mode_changed(_comp: Voltammeter) -> void:
	_mark_dirty()

func _on_component_rotated(comp: BaseComponent) -> void:
	_snap_component_to_board(comp)

func _on_component_body_clicked(comp: BaseComponent) -> void:
	_set_selected(comp)
	if comp is PowerSource:
		_handle_power_source_click(comp as PowerSource)
	else:
		## Клик по корпусу может переключить состояние (выключатель, SPDT,
		## переключение V/A у вольтамперметра). Пересчитываем цепь.
		_mark_dirty()

func _on_component_double_clicked(comp: BaseComponent) -> void:
	if comp == null or not is_instance_valid(comp):
		return
	if comp.is_fixed:
		return
	_remove_component(comp)

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

## Snap every pin of the component onto its nearest breadboard pin.
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

## ── Buffer dragging ──

func _on_buffer_slot_drag_start(slot: Dictionary) -> void:
	if not slot["infinite"] and slot["count"] <= 0:
		return
	var comp := _make_component(slot["type"], slot["params"])
	if comp == null:
		return
	comp.set_meta("buffer_slot_ref", slot)
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

	if _buffer_drag_comp.has_meta("buffer_slot_ref"):
		var slot: Dictionary = _buffer_drag_comp.get_meta("buffer_slot_ref")
		if not slot["infinite"]:
			slot["count"] -= 1
			_refresh_buffer_slot(slot)

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

	if comp.has_meta("buffer_slot_ref"):
		var slot: Dictionary = comp.get_meta("buffer_slot_ref")
		if not slot["infinite"]:
			slot["count"] += 1
			_refresh_buffer_slot(slot)

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
	if _evaluating:
		return
	_evaluating = true

	for comp in placed_components:
		if comp is PowerSource:
			(comp as PowerSource).set_on(true)
	_mark_dirty()
	await get_tree().process_frame
	_update_pin_connection_visuals()
	circuit_graph.solve()
	_circuit_dirty = false

	## Даём несколько секунд понаблюдать за показаниями приборов,
	## пока источник под напряжением. В это время цепь пересчитывается
	## каждый кадр, так что вольт-амперметр показывает реальные значения.
	status_label.text = "⚡ Питание подано… снимите показания с приборов."
	var t: float = OBSERVATION_DELAY
	while t > 0.0:
		t -= get_process_delta_time()
		_mark_dirty()
		await get_tree().process_frame

	_update_pin_connection_visuals()
	circuit_graph.solve()
	_circuit_dirty = false

	if _check_win_condition():
		status_label.text = "✔ Цепь собрана правильно!"
		await get_tree().create_timer(WIN_TRANSITION_DELAY).timeout
		GameManager.complete_level()
		get_tree().change_scene_to_file("res://scenes/level_complete/level_complete.tscn")
		_evaluating = false
		return

	_start_recharge_all_sources()
	## Источник выключен, но мы НЕ сбрасываем показания приборов — они
	## должны остаться видимыми, чтобы пользователь понял, почему не
	## получилось. Поэтому не помечаем цепь грязной после fail.
	_circuit_dirty = false
	status_label.text = "✘ Напряжение не соответствует. Источник перезаряжается %.0f с." % POWER_COOLDOWN_SECONDS
	_evaluating = false

func _start_recharge_all_sources() -> void:
	for comp in placed_components:
		if comp is PowerSource:
			(comp as PowerSource).start_cooldown(POWER_COOLDOWN_SECONDS)

## Win condition: EACH required target voltage must be matched by at least one
## consumer that is actually powered (voltage within tolerance AND I > 0).
## Matching is a greedy 1-to-1 assignment by best error.
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
	status_label.text = "Перетащите элементы, соберите схему и щёлкните по источнику питания."

## ── UI handlers ──

func _on_back_pressed() -> void:
	GameManager.go_to_level_select()

func _on_hint_pressed() -> void:
	hint_overlay.visible = not hint_overlay.visible

func _on_hint_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hint_overlay.visible = false
	elif event is InputEventScreenTouch and event.pressed:
		hint_overlay.visible = false
