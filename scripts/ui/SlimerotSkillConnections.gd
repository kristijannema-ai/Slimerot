class_name SlimerotSkillConnections
extends MarginContainer

# Slimerot prerequisite paths stay visible, including prerequisites in the other tab.
var anchors: Dictionary = {}
var edges: Array[Dictionary] = []

func _ready() -> void:
	add_theme_constant_override("margin_left", 42)
	mouse_filter = Control.MOUSE_FILTER_PASS
	sort_children.connect(queue_redraw)
	resized.connect(queue_redraw)

func add_anchor(id: String, control: Control) -> void:
	anchors[id] = control
	control.resized.connect(queue_redraw)
	control.item_rect_changed.connect(queue_redraw)

func add_edge(source: String, target: String) -> void:
	edges.append({"source": source, "target": target})

func _draw() -> void:
	for index in edges.size():
		var edge: Dictionary = edges[index]
		if not anchors.has(edge.source) or not anchors.has(edge.target):
			continue
		var source: Control = anchors[edge.source]
		var target: Control = anchors[edge.target]
		if not is_instance_valid(source) or not is_instance_valid(target):
			continue
		var inverse := get_global_transform_with_canvas().affine_inverse()
		var start := inverse * (source.get_global_transform_with_canvas() * Vector2(0, source.size.y * 0.5))
		var finish := inverse * (target.get_global_transform_with_canvas() * Vector2(0, target.size.y * 0.5))
		var unlocked: bool = edge.source in GameState.purchased_skill_node_ids
		var tone := Color("329f89") if unlocked else Color("889eaa")
		var lane := 8.0 + float(index % 4) * 7.0
		var points := PackedVector2Array([start, Vector2(lane, start.y), Vector2(lane, finish.y), finish])
		draw_polyline(points, Color("effaf3"), 7.0, true)
		draw_polyline(points, tone, 3.0, true)
		draw_circle(start, 5.0, tone)
		draw_circle(finish, 5.0, tone)
		draw_line(finish + Vector2(-8, -5), finish, tone, 3.0, true)
		draw_line(finish + Vector2(-8, 5), finish, tone, 3.0, true)
