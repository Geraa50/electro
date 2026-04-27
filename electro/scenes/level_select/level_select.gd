extends Control

@onready var level_grid: GridContainer = $Root/ScrollContainer/LevelGrid
@onready var empty_label: Label = $Root/EmptyLabel

const TILE_SIZE := Vector2(220, 140)

func _ready() -> void:
	_update_columns()
	get_viewport().size_changed.connect(_update_columns)
	_create_level_buttons()

func _update_columns() -> void:
	var w: float = get_viewport_rect().size.x
	var cols: int = int(max(1.0, floor((w - 48.0) / (TILE_SIZE.x + 18.0))))
	level_grid.columns = clampi(cols, 1, 5)

func _create_level_buttons() -> void:
	for child in level_grid.get_children():
		child.queue_free()

	var count: int = GameManager.total_levels
	empty_label.visible = count == 0
	if count == 0:
		return

	for i in range(count):
		var data: LevelData = GameManager.get_level_data(i)
		var tile := _build_level_tile(i, data)
		level_grid.add_child(tile)

func _build_level_tile(level_index: int, data: LevelData) -> Button:
	var completed: bool = GameManager.is_level_completed(level_index)
	var unlocked: bool = GameManager.is_level_unlocked(level_index)

	var btn := Button.new()
	btn.custom_minimum_size = TILE_SIZE
	btn.focus_mode = Control.FOCUS_ALL
	btn.clip_text = false
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.text = ""

	var normal_sb := _make_panel(
		Color(0.18, 0.22, 0.32, 1) if unlocked else Color(0.15, 0.16, 0.2, 1),
		Color(0.45, 0.7, 1.0, 1) if unlocked else Color(0.3, 0.3, 0.35, 1)
	)
	var hover_sb := _make_panel(Color(0.23, 0.3, 0.42, 1), Color(0.6, 0.85, 1.0, 1))
	var pressed_sb := _make_panel(Color(0.15, 0.2, 0.3, 1), Color(0.4, 0.7, 1.0, 1))
	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb if unlocked else normal_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb if unlocked else normal_sb)
	btn.add_theme_stylebox_override("disabled", normal_sb)
	btn.add_theme_stylebox_override("focus", hover_sb)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)

	var num_lbl := Label.new()
	num_lbl.text = "Уровень %d" % (level_index + 1)
	num_lbl.add_theme_font_size_override("font_size", 20)
	num_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1) if unlocked else Color(0.55, 0.55, 0.6, 1))
	num_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(num_lbl)

	var status_lbl := Label.new()
	status_lbl.add_theme_font_size_override("font_size", 22)
	if not unlocked:
		status_lbl.text = "🔒"
		status_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 1))
	elif completed:
		status_lbl.text = "✓"
		status_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 1))
	else:
		status_lbl.text = "▶"
		status_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 1))
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(status_lbl)

	var title_lbl := Label.new()
	title_lbl.text = _level_title(level_index, data)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 1) if unlocked else Color(0.5, 0.5, 0.55, 1))
	title_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)

	if unlocked:
		btn.pressed.connect(_on_level_pressed.bind(level_index))
	else:
		btn.disabled = true

	return btn

func _make_panel(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb

func _level_title(level_index: int, data: LevelData) -> String:
	if data != null and data.level_name != "":
		return data.level_name
	return "Уровень %d" % (level_index + 1)

func _on_level_pressed(level_index: int) -> void:
	GameManager.start_level(level_index)

func _on_back_pressed() -> void:
	GameManager.go_to_main_menu()
