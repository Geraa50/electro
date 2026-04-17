class_name Voltammeter
extends BaseComponent

## Двухрежимный измерительный прибор (мультиметр). Один щуп — два пина.
##
##   Режим V (вольтметр)  — внутреннее сопротивление 1 МОм. Прибор практически
##                          не влияет на цепь. Показывает НАПРЯЖЕНИЕ МЕЖДУ
##                          своими щупами (разность потенциалов), как живой
##                          вольтметр, поставленный параллельно измеряемому
##                          участку.
##   Режим A (амперметр)  — внутреннее сопротивление 0.01 Ом. Прибор ведёт
##                          себя как обычный провод, и показывает ТОК, реально
##                          текущий через него (как амперметр, вставленный в
##                          разрыв провода).
##
## Переключение режима — клик по корпусу прибора (двойной клик по-прежнему
## удаляет прибор, как и у остальных компонентов).
##
## Оба измерения считаются MNA-решателем в `circuit_graph.gd` и передаются
## сюда через `set_measurement()`.

signal mode_changed(comp: Voltammeter)

enum Mode { VOLTMETER, AMMETER }

const R_VOLTMETER := 1_000_000.0
const R_AMMETER := 0.01

## Пины на расстоянии 2 клеток макетки (40px каждая). Корпус аккуратно
## помещается в 4 клетки по ширине.
const PIN_OFFSET := 40.0
const BODY_SIZE := Vector2(72, 40)

const BODY_COLOR := Color(0.07, 0.07, 0.11)
const BODY_OUTLINE := Color(0.9, 0.9, 0.95)
const DISPLAY_BG := Color(0.02, 0.05, 0.02)
const DISPLAY_COLOR := Color(0.35, 1.0, 0.55)
const VOLT_MODE_COLOR := Color(1.0, 0.75, 0.2)
const AMP_MODE_COLOR := Color(0.35, 0.85, 1.0)

var mode: int = Mode.VOLTMETER
var measured_voltage: float = 0.0
var measured_current: float = 0.0

func _setup_pins() -> void:
	pin_positions = [
		Vector2(-PIN_OFFSET, 0),
		Vector2(PIN_OFFSET, 0)
	]

func get_component_type() -> String:
	return "voltammeter"

func get_resistance() -> float:
	return R_AMMETER if mode == Mode.AMMETER else R_VOLTMETER

func _get_bounding_rect() -> Rect2:
	return Rect2(-BODY_SIZE * 0.5 - Vector2(4, 4), BODY_SIZE + Vector2(8, 8))

func _on_body_clicked() -> void:
	mode = Mode.AMMETER if mode == Mode.VOLTMETER else Mode.VOLTMETER
	mode_changed.emit(self)
	queue_redraw()

func set_measurement(voltage: float, current: float) -> void:
	measured_voltage = voltage
	measured_current = current
	queue_redraw()

func update_visual_state(_current: float, _voltage: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_line(pin_positions[0], Vector2(-BODY_SIZE.x * 0.5, 0),
		Color(0.3, 0.3, 0.3), 2.0)
	draw_line(Vector2(BODY_SIZE.x * 0.5, 0), pin_positions[1],
		Color(0.3, 0.3, 0.3), 2.0)

	var mode_col: Color = VOLT_MODE_COLOR if mode == Mode.VOLTMETER else AMP_MODE_COLOR
	var mode_letter: String = "V" if mode == Mode.VOLTMETER else "A"

	draw_rect(Rect2(-BODY_SIZE * 0.5, BODY_SIZE), BODY_COLOR, true)
	draw_rect(Rect2(-BODY_SIZE * 0.5, BODY_SIZE), BODY_OUTLINE, false, 1.5)

	var display_rect := Rect2(-BODY_SIZE.x * 0.5 + 3, -BODY_SIZE.y * 0.5 + 3,
		BODY_SIZE.x - 6, BODY_SIZE.y - 6)
	draw_rect(display_rect, DISPLAY_BG, true)
	draw_rect(display_rect, mode_col, false, 1.0)

	var badge_radius := 7.0
	var badge_center := Vector2(-BODY_SIZE.x * 0.5 + badge_radius + 2,
		-BODY_SIZE.y * 0.5 - badge_radius - 2)
	draw_circle(badge_center, badge_radius, mode_col)
	draw_arc(badge_center, badge_radius, 0, TAU, 18, Color(0, 0, 0, 0.6), 1.0)

	for i in range(pin_positions.size()):
		var pin_col: Color = PIN_CONNECTED_COLOR if i in connected_pins else Color(0.85, 0.85, 0.85)
		draw_circle(pin_positions[i], PIN_RADIUS, pin_col)

	draw_world_text(badge_center - Vector2(0, 1), mode_letter, 11,
		Color(0.05, 0.05, 0.1), 20)

	var main_reading: String
	var sub_reading: String
	if mode == Mode.VOLTMETER:
		main_reading = "%.2f В" % measured_voltage
		sub_reading = "I ≈ %.4f А" % measured_current
	else:
		main_reading = "%.3f А" % measured_current
		sub_reading = "U ≈ %.3f В" % measured_voltage

	draw_world_text(Vector2(0, -2), main_reading, 13, DISPLAY_COLOR, 80)
	draw_world_text(Vector2(0, BODY_SIZE.y * 0.5 + 12), sub_reading, 10,
		Color(0.8, 0.85, 1.0), 100)
	draw_world_text(Vector2(0, BODY_SIZE.y * 0.5 + 26),
		"клик — смена режима", 9, Color(0.6, 0.65, 0.75), 140)

	_draw_selection_indicator()
