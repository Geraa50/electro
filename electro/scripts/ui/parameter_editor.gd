class_name ParameterEditor
extends PanelContainer

signal parameter_applied(component: BaseComponent)

var target_component: BaseComponent = null

@onready var title_label: Label = $VBox/TitleLabel
@onready var param_container: VBoxContainer = $VBox/ParamContainer
@onready var apply_button: Button = $VBox/ApplyButton

func _ready() -> void:
	visible = false
	apply_button.pressed.connect(_on_apply)

func open_for(component: BaseComponent) -> void:
	if not component.is_editable:
		return
	target_component = component
	_build_ui()
	visible = true

func close() -> void:
	visible = false
	target_component = null

func _build_ui() -> void:
	for child in param_container.get_children():
		child.queue_free()

	if target_component == null:
		return

	title_label.text = "Параметры: " + target_component.get_component_type()

	match target_component.get_component_type():
		"power_source":
			var ps := target_component as PowerSource
			_add_slider("Напряжение (В)", ps.voltage, 1.0, 50.0, "voltage")
		"resistor":
			var r := target_component as Resistor
			_add_slider("Сопротивление (Ом)", r.resistance, 1.0, 1000.0, "resistance")
		"consumer":
			pass
		"switch":
			var sw := target_component as SwitchComponent
			var btn := Button.new()
			btn.text = "ВКЛ" if sw.is_closed else "ВЫКЛ"
			btn.pressed.connect(func(): sw.toggle(); btn.text = "ВКЛ" if sw.is_closed else "ВЫКЛ")
			param_container.add_child(btn)

func _add_slider(label_text: String, value: float, min_val: float, max_val: float, param_name: String) -> void:
	var label := Label.new()
	label.text = label_text + ": %.1f" % value
	param_container.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = value
	slider.step = 0.1
	slider.custom_minimum_size = Vector2(200, 30)
	slider.value_changed.connect(func(val: float):
		label.text = label_text + ": %.1f" % val
		_set_param(param_name, val)
	)
	param_container.add_child(slider)

func _set_param(param_name: String, value: float) -> void:
	if target_component == null:
		return
	match param_name:
		"voltage":
			if target_component is PowerSource:
				(target_component as PowerSource).voltage = value
		"resistance":
			if target_component is Resistor:
				(target_component as Resistor).resistance = value

func _on_apply() -> void:
	if target_component:
		target_component.parameter_changed.emit(target_component)
		target_component.queue_redraw()
		parameter_applied.emit(target_component)
	close()
