class_name LevelData
extends Resource

@export var level_name: String = ""
@export var level_description: String = ""
@export var hint_text: String = ""

## Components already placed on the board (fixed)
## Each entry: { "type": "power_source"|"resistor"|"consumer"|"switch", "position": Vector2, "params": {} }
@export var fixed_components: Array[Dictionary] = []

## Components available in the buffer for the player
## Each entry: { "type": String, "params": {} }
@export var available_components: Array[Dictionary] = []

## Win conditions
## { "type": "voltage"|"power"|"current", "target_value": float, "tolerance": float }
@export var win_condition: Dictionary = {}

## Whether to show schematic hint
@export var show_schematic: bool = true

## Whether the player can edit component parameters
@export var allow_parameter_editing: bool = false

## Time limit in seconds (0 = no limit)
@export var time_limit: float = 0.0

## Maximum attempts (0 = unlimited)
@export var max_attempts: int = 0
