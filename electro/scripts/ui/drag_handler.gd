class_name DragHandler
extends Node

var dragging_component: BaseComponent = null
var drag_offset: Vector2 = Vector2.ZERO

func start_drag(component: BaseComponent, mouse_pos: Vector2) -> void:
	if component.is_fixed:
		return
	dragging_component = component
	drag_offset = component.global_position - mouse_pos
	component.z_index = 100

func update_drag(mouse_pos: Vector2) -> void:
	if dragging_component:
		dragging_component.global_position = mouse_pos + drag_offset

func end_drag() -> BaseComponent:
	var comp := dragging_component
	if comp:
		comp.z_index = 0
		comp.position = comp.snap_to_grid(comp.position)
	dragging_component = null
	return comp

func is_dragging() -> bool:
	return dragging_component != null
