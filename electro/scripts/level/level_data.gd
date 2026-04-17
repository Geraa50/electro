class_name LevelData
extends RefCounted

## Runtime data for a level parsed from a .txt spec file.
## Fields match the spec in tz.md:
##   level_name          string
##   hint                string
##   power_count         1 or 2
##   power_voltages      array[float] (size = power_count)
##   goal_count          1 or 2
##   goal_voltages       array[float] (size = goal_count)
##   allow_wire          bool (default true)
##   allow_voltammeter   bool
##   allow_toggle        bool
##   allow_switch        bool
##   resistor_count      int (>=0)
##   resistor_values     array[float] (size = resistor_count)

var level_name: String = ""
var hint: String = ""
var power_count: int = 1
var power_voltages: Array[float] = [9.0]
var goal_count: int = 1
var goal_voltages: Array[float] = [9.0]
var allow_wire: bool = true
var allow_voltammeter: bool = false
var allow_toggle: bool = false
var allow_switch: bool = false
var resistor_count: int = 0
var resistor_values: Array[float] = []
var voltage_tolerance: float = 0.5
