class_name CircuitGraph
extends RefCounted

## Builds a circuit from components placed on a Breadboard and solves it via MNA.
## Each breadboard bus is a node. Wires / closed switches / active toggle paths
## are short-circuits that merge buses into supernodes via union-find.

var breadboard: Breadboard
var components: Array[BaseComponent] = []
var solver: MNASolver
var last_result: Dictionary = {}

func _init(p_board: Breadboard = null) -> void:
	breadboard = p_board
	solver = MNASolver.new()

func set_breadboard(bb: Breadboard) -> void:
	breadboard = bb

func add_component(comp: BaseComponent) -> void:
	if comp not in components:
		components.append(comp)

func remove_component(comp: BaseComponent) -> void:
	components.erase(comp)

func clear() -> void:
	components.clear()
	last_result.clear()

## Compute, for each component, the bus id each pin currently lives on.
## Returns dict: component -> Array[int] (size = pin count).
func _component_pin_buses() -> Dictionary:
	var out: Dictionary = {}
	if breadboard == null:
		return out
	for comp in components:
		if not is_instance_valid(comp):
			continue
		var pins: Array = []
		for i in range(comp.pin_positions.size()):
			var gpos := comp.get_pin_global_position(i)
			var bus := breadboard.get_bus_for_global(gpos)
			pins.append(bus)
		out[comp] = pins
	return out

func solve() -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"is_closed": false,
		"source_voltage": 0.0,
		"total_current": 0.0,
		"components": {}
	}

	if breadboard == null:
		last_result = result
		return result

	var pin_buses := _component_pin_buses()

	var bus_set: Dictionary = {}
	for comp in pin_buses:
		for b in pin_buses[comp]:
			if b >= 0:
				bus_set[b] = true

	if bus_set.is_empty():
		last_result = result
		return result

	var uf := UnionFind.new()
	for b in bus_set.keys():
		uf.add(b)

	## Short-circuit merges (wires, closed switches, active toggle paths, voltammeter-as-wire? No, voltammeter stays as small-R element so we can read current).
	for comp in pin_buses:
		var pins: Array = pin_buses[comp]
		var type: String = comp.get_component_type()
		if type == "wire":
			if pins.size() >= 2 and pins[0] >= 0 and pins[1] >= 0:
				uf.union(pins[0], pins[1])

	## Resistive / measurement elements and conducting switches (as small-R) and voltage sources.
	var resistors: Array = []
	var sources: Array = []

	for comp in pin_buses:
		if not is_instance_valid(comp):
			continue
		var pins: Array = pin_buses[comp]
		var type: String = comp.get_component_type()

		match type:
			"wire":
				pass  # already merged
			"resistor":
				if pins.size() >= 2 and pins[0] >= 0 and pins[1] >= 0:
					resistors.append({"comp": comp, "a": pins[0], "b": pins[1], "r": maxf(comp.get_resistance(), 0.0001)})
			"consumer":
				if pins.size() >= 2 and pins[0] >= 0 and pins[1] >= 0:
					resistors.append({"comp": comp, "a": pins[0], "b": pins[1], "r": maxf(comp.get_resistance(), 0.0001)})
			"voltammeter":
				## В режиме V (вольтметр) внутреннее сопротивление огромное —
				## прибор практически не влияет на цепь. В режиме A (амперметр)
				## сопротивление почти нулевое — прибор ведёт себя как провод,
				## и через него идёт реальный ток ветки.
				if pins.size() >= 2 and pins[0] >= 0 and pins[1] >= 0:
					resistors.append({"comp": comp, "a": pins[0], "b": pins[1], "r": maxf(comp.get_resistance(), 0.0001)})
			"switch":
				if pins.size() >= 2 and pins[0] >= 0 and pins[1] >= 0 and comp.is_conducting():
					resistors.append({"comp": comp, "a": pins[0], "b": pins[1], "r": 0.001})
			"toggle_switch":
				for pair in comp.get_internal_connections():
					var i: int = pair[0]
					var j: int = pair[1]
					if i < pins.size() and j < pins.size() and pins[i] >= 0 and pins[j] >= 0:
						resistors.append({"comp": comp, "a": pins[i], "b": pins[j], "r": 0.001})
			"power_source":
				if pins.size() >= 2 and pins[0] >= 0 and pins[1] >= 0 and comp.is_conducting():
					## Positive terminal = pin 0. Voltage source with + at pin0, - at pin1.
					sources.append({"comp": comp, "p": pins[0], "n": pins[1], "v": comp.get_voltage()})

	var supernode_set: Dictionary = {}
	for b in bus_set.keys():
		supernode_set[uf.find(b)] = true

	var supernodes: Array = supernode_set.keys()

	for r in resistors:
		r["a"] = uf.find(r["a"])
		r["b"] = uf.find(r["b"])
	for s in sources:
		s["p"] = uf.find(s["p"])
		s["n"] = uf.find(s["n"])

	var ground: int = -1
	if not sources.is_empty():
		ground = sources[0]["n"]
	elif not supernodes.is_empty():
		ground = supernodes[0]

	if ground == -1:
		last_result = result
		return result

	var mna := solver.solve(supernodes, resistors, sources, ground)
	if not mna.get("ok", false):
		_zero_out_components()
		last_result = result
		return result

	result["ok"] = true
	var closed := false
	for s in sources:
		var comp = s["comp"]
		var key: int = comp.get_instance_id()
		var i_val: float = mna["i_of_component"].get(key, 0.0)
		if absf(i_val) > 0.0001:
			closed = true
		result["source_voltage"] = comp.get_voltage()
		result["total_current"] += i_val
	result["is_closed"] = closed

	var comp_data: Dictionary = {}
	for comp in pin_buses:
		if not is_instance_valid(comp):
			continue
		var key: int = comp.get_instance_id()
		var i_val: float = mna["i_of_component"].get(key, 0.0)
		var v_val: float = mna["v_of_component"].get(key, 0.0)
		comp_data[key] = {
			"component": comp,
			"current": absf(i_val),
			"voltage": absf(v_val),
			"power": absf(i_val * v_val),
			"resistance": comp.get_resistance()
		}
		comp.update_visual_state(absf(i_val), absf(v_val))

	for comp in pin_buses:
		if comp.get_instance_id() not in comp_data and is_instance_valid(comp):
			comp.update_visual_state(0.0, 0.0)

	## Показания вольт-амперметров.
	##   I — реальный ток через прибор (MNA уже решён с учётом его R).
	##   U — разность потенциалов между его двумя щупами (как у настоящего
	##       вольтметра, поставленного параллельно измеряемому участку).
	##
	## Если ни один источник в данный момент не запитан, живых показаний
	## нет — НО мы не затираем последние значения на дисплее, чтобы
	## пользователь мог прочитать их после того, как источник отключился
	## (например, после неудачной попытки уровня).
	var has_live_source: bool = not sources.is_empty()
	if has_live_source:
		for vcomp in pin_buses:
			if not is_instance_valid(vcomp):
				continue
			if vcomp.get_component_type() != "voltammeter":
				continue
			var vpins: Array = pin_buses[vcomp]
			if vpins.size() < 2 or vpins[0] < 0 or vpins[1] < 0:
				## Хотя бы один щуп в воздухе — измерения нет.
				vcomp.set_measurement(0.0, 0.0)
				continue

			var v_sa: int = uf.find(vpins[0])
			var v_sb: int = uf.find(vpins[1])
			var v_a: float = mna["v_of_supernode"].get(v_sa, 0.0)
			var v_b: float = mna["v_of_supernode"].get(v_sb, 0.0)
			var self_i: float = absf(mna["i_of_component"].get(vcomp.get_instance_id(), 0.0))
			var u: float = absf(v_a - v_b)
			vcomp.set_measurement(u, self_i)

	## Подсветка проводов. Аналогия «вода в трубе»: как только включён
	## источник, давление передаётся на ВСЕ электрически соединённые с ним
	## провода — даже если цепь не замкнута и ток реально не течёт.
	##
	## Алгоритм: BFS по супернодам, сосчитая сопротивления и источники как
	## рёбра графа. Стартовые узлы — клеммы каждого активного источника.
	var pressurized: Dictionary = {}
	if not sources.is_empty():
		var adj: Dictionary = {}
		for r in resistors:
			var ra: int = r["a"]
			var rb: int = r["b"]
			if not adj.has(ra):
				adj[ra] = []
			if not adj.has(rb):
				adj[rb] = []
			adj[ra].append(rb)
			adj[rb].append(ra)
		for s in sources:
			var sp: int = s["p"]
			var sn: int = s["n"]
			if not adj.has(sp):
				adj[sp] = []
			if not adj.has(sn):
				adj[sn] = []
			adj[sp].append(sn)
			adj[sn].append(sp)

		var queue: Array = []
		for s in sources:
			if not pressurized.has(s["p"]):
				pressurized[s["p"]] = true
				queue.append(s["p"])
			if not pressurized.has(s["n"]):
				pressurized[s["n"]] = true
				queue.append(s["n"])

		while not queue.is_empty():
			var cur: int = queue.pop_front()
			for nxt in adj.get(cur, []):
				if not pressurized.has(nxt):
					pressurized[nxt] = true
					queue.append(nxt)

	for wcomp in pin_buses:
		if not is_instance_valid(wcomp):
			continue
		if wcomp.get_component_type() != "wire":
			continue
		var wpins: Array = pin_buses[wcomp]
		var active := false
		## Достаточно, чтобы ХОТЯ БЫ ОДИН конец провода был воткнут в
		## клемму «под давлением». Второй конец может висеть в воздухе —
		## провод всё равно синеет, как труба, у которой открыт только
		## один кран.
		for wp in wpins:
			if wp < 0:
				continue
			if pressurized.has(uf.find(wp)):
				active = true
				break
		wcomp.update_visual_state(1.0 if active else 0.0, 0.0)

	result["components"] = comp_data
	last_result = result
	return result

func _zero_out_components() -> void:
	for comp in components:
		if is_instance_valid(comp):
			comp.update_visual_state(0.0, 0.0)

func find_power_sources() -> Array[BaseComponent]:
	var out: Array[BaseComponent] = []
	for comp in components:
		if is_instance_valid(comp) and comp.get_component_type() == "power_source":
			out.append(comp)
	return out

func find_consumers() -> Array[BaseComponent]:
	var out: Array[BaseComponent] = []
	for comp in components:
		if is_instance_valid(comp) and comp.get_component_type() == "consumer":
			out.append(comp)
	return out

## --- Union-Find helper ---
class UnionFind:
	var parent: Dictionary = {}

	func add(x) -> void:
		if x not in parent:
			parent[x] = x

	func find(x):
		if x not in parent:
			return x
		while parent[x] != x:
			parent[x] = parent[parent[x]]
			x = parent[x]
		return x

	func union(a, b) -> void:
		add(a)
		add(b)
		var ra = find(a)
		var rb = find(b)
		if ra != rb:
			parent[ra] = rb
