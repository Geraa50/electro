class_name LevelLoader
extends RefCounted

## Parses a plain-text level spec file. Format (one `key = value` pair per line,
## lines starting with `#` are comments, blank lines ignored):
##
##   name           = Уровень 1: последовательное
##   hint           = ...
##   power_count    = 1
##   power_voltages = 12
##   goal_count     = 1
##   goal_voltages  = 6
##   wire           = true      (default true if omitted)
##   voltammeter    = true
##   toggle         = false
##   switch         = true
##   resistors      = 3
##   resistor_values= 10, 20, 5
##   tolerance      = 0.5       (optional, volts)

static func load_level(path: String) -> LevelData:
	var text := _read_text(path)
	if text.is_empty():
		push_error("Level spec not found or empty: " + path)
		return null
	return parse_text(text)

static func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var txt := f.get_as_text()
	f.close()
	return txt

static func parse_text(text: String) -> LevelData:
	var data := LevelData.new()
	for raw_line in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var eq := line.find("=")
		if eq < 0:
			continue
		var key := line.substr(0, eq).strip_edges().to_lower()
		var value := line.substr(eq + 1).strip_edges()
		_apply_field(data, key, value)
	_normalize(data)
	return data

static func _apply_field(data: LevelData, key: String, value: String) -> void:
	match key:
		"name", "level_name", "title":
			data.level_name = value
		"hint", "подсказка":
			data.hint = value
		"power_count", "source_count":
			data.power_count = clampi(_to_int(value, 1), 1, 2)
		"power_voltages", "power_voltage", "source_voltage", "source_voltages":
			data.power_voltages = _parse_float_list(value)
		"goal_count", "target_count":
			data.goal_count = clampi(_to_int(value, 1), 1, 2)
		"goal_voltages", "goal_voltage", "target_voltage", "target_voltages":
			data.goal_voltages = _parse_float_list(value)
		"wire", "wires":
			data.allow_wire = _to_bool(value, true)
		"voltammeter", "volt_amper_meter", "volt_amp":
			data.allow_voltammeter = _to_bool(value, false)
		"toggle", "toggle_switch", "переключатель":
			data.allow_toggle = _to_bool(value, false)
		"switch", "выключатель":
			data.allow_switch = _to_bool(value, false)
		"resistors", "resistor_count":
			data.resistor_count = maxi(_to_int(value, 0), 0)
		"resistor_values", "resistors_values", "resistance_array":
			data.resistor_values = _parse_float_list(value)
		"tolerance", "voltage_tolerance":
			data.voltage_tolerance = _to_float(value, 0.5)

static func _normalize(data: LevelData) -> void:
	if data.power_voltages.size() < data.power_count:
		while data.power_voltages.size() < data.power_count:
			data.power_voltages.append(9.0)
	if data.goal_voltages.size() < data.goal_count:
		while data.goal_voltages.size() < data.goal_count:
			data.goal_voltages.append(data.power_voltages[0])
	if data.resistor_values.size() < data.resistor_count:
		while data.resistor_values.size() < data.resistor_count:
			data.resistor_values.append(10.0)
	elif data.resistor_values.size() > data.resistor_count:
		data.resistor_values.resize(data.resistor_count)

static func _to_int(v: String, default_val: int) -> int:
	var t := v.strip_edges()
	if t.is_empty():
		return default_val
	if not t.is_valid_int() and not t.is_valid_float():
		return default_val
	return int(t.to_float())

static func _to_float(v: String, default_val: float) -> float:
	var t := v.strip_edges()
	if t.is_empty():
		return default_val
	if not t.is_valid_float() and not t.is_valid_int():
		return default_val
	return t.to_float()

static func _to_bool(v: String, default_val: bool) -> bool:
	var t := v.strip_edges().to_lower()
	if t in ["true", "1", "yes", "y", "да"]:
		return true
	if t in ["false", "0", "no", "n", "нет"]:
		return false
	return default_val

static func _parse_float_list(v: String) -> Array[float]:
	var out: Array[float] = []
	var cleaned := v.replace("[", "").replace("]", "").replace(";", ",")
	for part in cleaned.split(","):
		var t: String = part.strip_edges()
		if t.is_empty():
			continue
		if t.is_valid_float() or t.is_valid_int():
			out.append(t.to_float())
	return out
