class_name CircuitGraph
extends RefCounted

## Represents a node in the circuit graph
class CircuitNode:
	var id: int
	var component: BaseComponent
	var pin_index: int
	var connections: Array[int] = []

	func _init(p_id: int, p_component: BaseComponent, p_pin_index: int) -> void:
		id = p_id
		component = p_component
		pin_index = p_pin_index

## Represents an edge (wire) between two circuit nodes
class CircuitEdge:
	var from_node_id: int
	var to_node_id: int
	var wire_ref: Node2D

	func _init(p_from: int, p_to: int, p_wire: Node2D = null) -> void:
		from_node_id = p_from
		to_node_id = p_to
		wire_ref = p_wire

var nodes: Dictionary = {}
var edges: Array[CircuitEdge] = []
var _next_node_id: int = 0
var solver: CircuitSolver

func _init() -> void:
	solver = CircuitSolver.new()

func add_component(comp: BaseComponent) -> Array[int]:
	var pin_ids: Array[int] = []
	for i in range(comp.pin_positions.size()):
		var node := CircuitNode.new(_next_node_id, comp, i)
		nodes[_next_node_id] = node
		pin_ids.append(_next_node_id)
		_next_node_id += 1
	return pin_ids

func remove_component(comp: BaseComponent) -> void:
	var ids_to_remove: Array[int] = []
	for id in nodes:
		if nodes[id].component == comp:
			ids_to_remove.append(id)
	for id in ids_to_remove:
		_remove_edges_for_node(id)
		nodes.erase(id)

func connect_pins(node_a_id: int, node_b_id: int, wire: Node2D = null) -> void:
	if node_a_id not in nodes or node_b_id not in nodes:
		return
	var edge := CircuitEdge.new(node_a_id, node_b_id, wire)
	edges.append(edge)
	nodes[node_a_id].connections.append(node_b_id)
	nodes[node_b_id].connections.append(node_a_id)

func disconnect_wire(wire: Node2D) -> void:
	var to_remove: Array[CircuitEdge] = []
	for edge in edges:
		if edge.wire_ref == wire:
			to_remove.append(edge)
	for edge in to_remove:
		edges.erase(edge)
		if edge.from_node_id in nodes:
			nodes[edge.from_node_id].connections.erase(edge.to_node_id)
		if edge.to_node_id in nodes:
			nodes[edge.to_node_id].connections.erase(edge.from_node_id)

func _remove_edges_for_node(node_id: int) -> void:
	var to_remove: Array[CircuitEdge] = []
	for edge in edges:
		if edge.from_node_id == node_id or edge.to_node_id == node_id:
			to_remove.append(edge)
	for edge in to_remove:
		edges.erase(edge)
		var other_id := edge.to_node_id if edge.from_node_id == node_id else edge.from_node_id
		if other_id in nodes:
			nodes[other_id].connections.erase(node_id)

func find_node_ids_for_component(comp: BaseComponent) -> Array[int]:
	var result: Array[int] = []
	for id in nodes:
		if nodes[id].component == comp:
			result.append(id)
	return result

func find_power_sources() -> Array[BaseComponent]:
	var sources: Array[BaseComponent] = []
	var seen: Array[BaseComponent] = []
	for id in nodes:
		var comp: BaseComponent = nodes[id].component
		if comp.get_component_type() == "power_source" and comp not in seen:
			sources.append(comp)
			seen.append(comp)
	return sources

func find_consumers() -> Array[BaseComponent]:
	var consumers: Array[BaseComponent] = []
	var seen: Array[BaseComponent] = []
	for id in nodes:
		var comp: BaseComponent = nodes[id].component
		if comp.get_component_type() == "consumer" and comp not in seen:
			consumers.append(comp)
			seen.append(comp)
	return consumers

func solve() -> Dictionary:
	return solver.solve(self)

func is_circuit_closed() -> bool:
	return solver.is_circuit_closed(self)

func get_adjacency() -> Dictionary:
	var adj: Dictionary = {}
	for id in nodes:
		adj[id] = []
	for edge in edges:
		if edge.from_node_id in adj:
			adj[edge.from_node_id].append(edge.to_node_id)
		if edge.to_node_id in adj:
			adj[edge.to_node_id].append(edge.from_node_id)
	# Also connect pins of the same component internally
	var comp_pins: Dictionary = {}
	for id in nodes:
		var comp: BaseComponent = nodes[id].component
		if comp not in comp_pins:
			comp_pins[comp] = []
		comp_pins[comp].append(id)
	for comp in comp_pins:
		if comp.is_conducting():
			var pins: Array = comp_pins[comp]
			for i in range(pins.size()):
				for j in range(i + 1, pins.size()):
					if pins[j] not in adj[pins[i]]:
						adj[pins[i]].append(pins[j])
					if pins[i] not in adj[pins[j]]:
						adj[pins[j]].append(pins[i])
	return adj
