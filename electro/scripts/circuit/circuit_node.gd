class_name CircuitNodeData
extends RefCounted

## Represents a single pin node in the circuit graph.
## Used internally by CircuitGraph.

var id: int
var component: BaseComponent
var pin_index: int
var connections: Array[int] = []

func _init(p_id: int = -1, p_component: BaseComponent = null, p_pin_index: int = 0) -> void:
	id = p_id
	component = p_component
	pin_index = p_pin_index

func add_connection(other_id: int) -> void:
	if other_id not in connections:
		connections.append(other_id)

func remove_connection(other_id: int) -> void:
	connections.erase(other_id)

func is_connected_to(other_id: int) -> bool:
	return other_id in connections
