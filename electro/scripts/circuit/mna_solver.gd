class_name MNASolver
extends RefCounted

## Modified Nodal Analysis (MNA) solver for linear DC circuits.
## Correctly handles arbitrary series + parallel topologies and multiple
## independent voltage sources.
##
## Input model:
##   - supernodes: Array of supernode ids (arbitrary ints). Each supernode =
##     set of bus ids electrically merged via short-circuit (wires, closed
##     switches, active toggle paths).
##   - resistors: Array of { "comp": BaseComponent, "a": supernode_id, "b":
##     supernode_id, "r": float }
##   - sources:   Array of { "comp": PowerSource, "p": supernode_id, "n":
##     supernode_id, "v": float }
##   - ground:    supernode_id that is ground (V=0).
##
## Returns:
##   { "ok": bool,
##     "v_of_supernode": {id: float},
##     "i_of_component": {instance_id: float},
##     "v_of_component": {instance_id: float} }

func solve(supernodes: Array, resistors: Array, sources: Array, ground: int) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"v_of_supernode": {},
		"i_of_component": {},
		"v_of_component": {}
	}

	if supernodes.is_empty() or ground == -1:
		return result

	var index_of: Dictionary = {}
	var node_order: Array = []
	for n in supernodes:
		if n == ground:
			continue
		index_of[n] = node_order.size()
		node_order.append(n)

	var n_count := node_order.size()
	var m_count := sources.size()
	var total := n_count + m_count

	if total == 0:
		result["ok"] = true
		result["v_of_supernode"][ground] = 0.0
		return result

	var a := _zeros(total, total)
	var z := _zeros_vec(total)

	for res in resistors:
		var r: float = float(res.get("r", 0.0))
		if r <= 0.0:
			continue
		var g := 1.0 / r
		var a_node: int = res["a"]
		var b_node: int = res["b"]
		var ai: int = -1 if a_node == ground else index_of.get(a_node, -1)
		var bi: int = -1 if b_node == ground else index_of.get(b_node, -1)
		if ai >= 0:
			a[ai][ai] += g
		if bi >= 0:
			a[bi][bi] += g
		if ai >= 0 and bi >= 0:
			a[ai][bi] -= g
			a[bi][ai] -= g

	for k in range(m_count):
		var src: Dictionary = sources[k]
		var p_node: int = src["p"]
		var n_node: int = src["n"]
		var v: float = float(src["v"])
		var pi: int = -1 if p_node == ground else index_of.get(p_node, -1)
		var ni: int = -1 if n_node == ground else index_of.get(n_node, -1)
		var row := n_count + k
		if pi >= 0:
			a[pi][row] += 1.0
			a[row][pi] += 1.0
		if ni >= 0:
			a[ni][row] -= 1.0
			a[row][ni] -= 1.0
		z[row] = v

	var x := _solve_linear(a, z)
	if x.is_empty():
		return result

	result["v_of_supernode"][ground] = 0.0
	for i in range(n_count):
		result["v_of_supernode"][node_order[i]] = x[i]

	for res in resistors:
		var comp = res.get("comp", null)
		if comp == null:
			continue
		var va: float = result["v_of_supernode"].get(res["a"], 0.0)
		var vb: float = result["v_of_supernode"].get(res["b"], 0.0)
		var r: float = float(res.get("r", 1.0))
		var i_val := (va - vb) / r if r > 0.0 else 0.0
		var key: int = comp.get_instance_id()
		result["i_of_component"][key] = i_val
		result["v_of_component"][key] = va - vb

	for k in range(m_count):
		var src: Dictionary = sources[k]
		var comp = src.get("comp", null)
		if comp == null:
			continue
		var key: int = comp.get_instance_id()
		var i_val: float = x[n_count + k]
		result["i_of_component"][key] = i_val
		var vp: float = result["v_of_supernode"].get(src["p"], 0.0)
		var vn: float = result["v_of_supernode"].get(src["n"], 0.0)
		result["v_of_component"][key] = vp - vn

	result["ok"] = true
	return result

func _zeros(rows: int, cols: int) -> Array:
	var m: Array = []
	for i in range(rows):
		var row: Array = []
		row.resize(cols)
		for j in range(cols):
			row[j] = 0.0
		m.append(row)
	return m

func _zeros_vec(n: int) -> Array:
	var v: Array = []
	v.resize(n)
	for i in range(n):
		v[i] = 0.0
	return v

## Gauss elimination with partial pivoting. Returns [] if singular.
func _solve_linear(a_in: Array, b_in: Array) -> Array:
	var n := a_in.size()
	if n == 0:
		return []
	var a: Array = []
	for i in range(n):
		a.append((a_in[i] as Array).duplicate())
	var b: Array = b_in.duplicate()

	for i in range(n):
		var max_row := i
		var max_val := absf(a[i][i])
		for k in range(i + 1, n):
			var v := absf(a[k][i])
			if v > max_val:
				max_val = v
				max_row = k
		if max_val < 1e-12:
			return []
		if max_row != i:
			var tmp: Array = a[i]
			a[i] = a[max_row]
			a[max_row] = tmp
			var tb: float = b[i]
			b[i] = b[max_row]
			b[max_row] = tb

		var diag: float = a[i][i]
		for k in range(i + 1, n):
			var factor: float = a[k][i] / diag
			if absf(factor) < 1e-16:
				continue
			for j in range(i, n):
				a[k][j] -= factor * a[i][j]
			b[k] -= factor * b[i]

	var x: Array = []
	x.resize(n)
	for i in range(n - 1, -1, -1):
		var s: float = b[i]
		for j in range(i + 1, n):
			s -= a[i][j] * x[j]
		x[i] = s / a[i][i]
	return x
