class_name CircuitSolver
extends RefCounted

## Solves electric circuit using graph traversal and Ohm's law.
## Supports series and parallel resistor combinations.

func solve(graph: CircuitGraph) -> Dictionary:
	var result: Dictionary = {
		"is_closed": false,
		"total_resistance": 0.0,
		"total_current": 0.0,
		"source_voltage": 0.0,
		"components": {}
	}

	var sources := graph.find_power_sources()
	if sources.is_empty():
		return result

	var source: BaseComponent = sources[0]
	var source_voltage: float = source.get_voltage()
	result["source_voltage"] = source_voltage

	var source_pins := graph.find_node_ids_for_component(source)
	if source_pins.size() < 2:
		return result

	var positive_pin := source_pins[0]
	var negative_pin := source_pins[1]

	if not _is_path_exists(graph, positive_pin, negative_pin):
		return result

	result["is_closed"] = true

	var paths := _find_all_paths(graph, positive_pin, negative_pin, source)
	if paths.is_empty():
		return result

	var total_resistance := _calculate_total_resistance(graph, paths)
	if total_resistance <= 0.0:
		total_resistance = 0.001

	var total_current := source_voltage / total_resistance
	result["total_resistance"] = total_resistance
	result["total_current"] = total_current

	_calculate_component_values(graph, result, paths, source_voltage, total_current)

	return result

func is_circuit_closed(graph: CircuitGraph) -> bool:
	var sources := graph.find_power_sources()
	if sources.is_empty():
		return false

	var source: BaseComponent = sources[0]
	var source_pins := graph.find_node_ids_for_component(source)
	if source_pins.size() < 2:
		return false

	return _is_path_exists(graph, source_pins[0], source_pins[1])

func _is_path_exists(graph: CircuitGraph, start_id: int, end_id: int) -> bool:
	var adj := graph.get_adjacency()
	var visited: Dictionary = {}
	var queue: Array[int] = [start_id]
	visited[start_id] = true

	while not queue.is_empty():
		var current: int = queue.pop_front()
		if current == end_id:
			return true
		if current not in adj:
			continue
		for neighbor in adj[current]:
			if neighbor not in visited:
				visited[neighbor] = true
				queue.append(neighbor)
	return false

func _find_all_paths(graph: CircuitGraph, start_id: int, end_id: int, source: BaseComponent) -> Array:
	var adj := graph.get_adjacency()
	var all_paths: Array = []
	var current_path: Array[int] = [start_id]
	_dfs_paths(adj, start_id, end_id, current_path, all_paths, {start_id: true}, graph, source)
	return all_paths

func _dfs_paths(adj: Dictionary, current: int, target: int, path: Array[int], all_paths: Array, visited: Dictionary, graph: CircuitGraph, source: BaseComponent) -> void:
	if current == target:
		all_paths.append(path.duplicate())
		return

	if current not in adj:
		return

	for neighbor in adj[current]:
		if neighbor in visited:
			continue
		visited[neighbor] = true
		path.append(neighbor)
		_dfs_paths(adj, neighbor, target, path, all_paths, visited, graph, source)
		path.pop_back()
		visited.erase(neighbor)

func _calculate_total_resistance(graph: CircuitGraph, paths: Array) -> float:
	if paths.size() == 0:
		return 0.0

	if paths.size() == 1:
		return _path_resistance(graph, paths[0])

	# Parallel paths: 1/R_total = sum(1/R_i)
	var sum_inv := 0.0
	for path in paths:
		var r := _path_resistance(graph, path)
		if r > 0.0:
			sum_inv += 1.0 / r
	if sum_inv <= 0.0:
		return 0.001
	return 1.0 / sum_inv

func _path_resistance(graph: CircuitGraph, path: Array) -> float:
	var total_r := 0.0
	var counted_components: Array[BaseComponent] = []

	for node_id in path:
		if node_id not in graph.nodes:
			continue
		var comp: BaseComponent = graph.nodes[node_id].component
		if comp in counted_components:
			continue
		counted_components.append(comp)
		var r := comp.get_resistance()
		if r > 0.0:
			total_r += r

	if total_r <= 0.0:
		total_r = 0.001
	return total_r

func _calculate_component_values(graph: CircuitGraph, result: Dictionary, paths: Array, source_voltage: float, total_current: float) -> void:
	var comp_data: Dictionary = {}

	for path in paths:
		var path_r := _path_resistance(graph, path)
		var path_current: float
		if paths.size() == 1:
			path_current = total_current
		else:
			path_current = source_voltage / path_r if path_r > 0.0 else 0.0

		var counted: Array[BaseComponent] = []
		for node_id in path:
			if node_id not in graph.nodes:
				continue
			var comp: BaseComponent = graph.nodes[node_id].component
			if comp in counted:
				continue
			counted.append(comp)

			var r := comp.get_resistance()
			var v := path_current * r
			var p := v * path_current

			var key := comp.get_instance_id()
			comp_data[key] = {
				"component": comp,
				"current": path_current,
				"voltage": v,
				"power": p,
				"resistance": r
			}

	result["components"] = comp_data

	for key in comp_data:
		var data: Dictionary = comp_data[key]
		var comp: BaseComponent = data["component"]
		comp.update_visual_state(data["current"], data["voltage"])
