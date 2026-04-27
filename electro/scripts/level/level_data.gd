class_name LevelData
extends Resource

## Runtime data for a level.
##
## Уровни хранятся как нативные Godot-ресурсы (.tres) и подключаются к игре
## через preload() в `GameManager`. Это гарантирует, что они попадают в .pck
## во время компиляции и читаются ResourceLoader-ом без обращений к ФС —
## важно для портов на закрытые ОС (например, Аврора ОС), где доступ к
## произвольным файлам внутри пакета может быть ограничен sandbox-ом.

@export var level_name: String = ""
@export_multiline var hint: String = ""
@export_range(1, 2, 1) var power_count: int = 1
@export var power_voltages: Array[float] = [9.0]
@export_range(1, 2, 1) var goal_count: int = 1
@export var goal_voltages: Array[float] = [9.0]
@export var allow_wire: bool = true
@export var allow_voltammeter: bool = false
@export var allow_toggle: bool = false
@export var allow_switch: bool = false
@export_range(0, 16, 1) var resistor_count: int = 0
@export var resistor_values: Array[float] = []
@export_range(0.0, 5.0, 0.05) var voltage_tolerance: float = 0.5
