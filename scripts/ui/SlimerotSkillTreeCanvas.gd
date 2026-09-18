class_name SlimerotSkillTreeCanvas
extends Control

## Presentation only: coordinates and gestures never decide purchases or effects.
signal node_selected(id: String)

const MIN_ZOOM := 0.55
const MAX_ZOOM := 1.80
const NODE_SIZE := Vector2(172, 104)
const DRAG_THRESHOLD := 9.0
const GRAPH_THEME := preload("res://assets/ui/SlimerotTheme.tres")

var zoom_level := 0.65
var pan_offset := Vector2.ZERO
var anchors: Dictionary = {}
var edges: Array[Dictionary] = []
var tree_type := "Roll"
var graph_bounds := Rect2(Vector2.ZERO, Vector2(952, 1200))
var _content: Control
var _centers: Dictionary = {}
var _captions: Dictionary = {}
var _touches: Dictionary = {}
var _press_position := Vector2.ZERO
var _tap_id := ""
var _moved := false
var _pinched := false
var _mouse_held := false
var _last_mouse := Vector2.ZERO
var _view_initialized := false
var _user_adjusted := false

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = GRAPH_THEME
	add_to_group("slimerot_skill_graph")
	resized.connect(_on_resized)
	visibility_changed.connect(_on_visibility_changed)
	if _content == null: configure(tree_type)
	fit_tree()

func configure(kind: String) -> void:
	tree_type = kind
	cancel_gesture()
	anchors.clear()
	edges.clear()
	_centers.clear()
	_captions.clear()
	if is_instance_valid(_content):
		remove_child(_content)
		_content.queue_free()
	_content = Control.new()
	_content.name = "SkillGraphContent"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	if tree_type == "Coin": _layout_coins()
	else: _layout_rolls()
	# Keep the complete tree inside the minimum zoom on a 720×1280 phone.
	# Node sizes stay finger-sized; this removes excess space between rows.
	for id in _centers: _centers[id].y *= 0.86
	# The backend supplies every displayed definition and every real prerequisite.
	# If a future node has no authored position, it still appears in an overflow row.
	var overflow := 0
	for id in SkillTreeManager.nodes:
		var data: SlimerotData.SkillNodeData = SkillTreeManager.nodes[id]
		if data.tree_type != tree_type: continue
		if not _centers.has(id):
			_centers[id] = Vector2(120 + (overflow % 4) * 220, 1420 + (overflow / 4) * 140)
			overflow += 1
		_add_node(id, false)
	for id in anchors.keys():
		var data: SlimerotData.SkillNodeData = SkillTreeManager.nodes[id]
		if data.tree_type != tree_type: continue
		for prerequisite in data.prerequisite_ids:
			if not anchors.has(prerequisite):
				if not _centers.has(prerequisite): _centers[prerequisite] = Vector2(845, 1260)
				_add_node(prerequisite, true)
			edges.append({"source": prerequisite, "target": id})
	graph_bounds = Rect2(Vector2.ZERO, Vector2(952, 1200))
	for id in anchors:
		graph_bounds = graph_bounds.expand(_centers[id] + NODE_SIZE * 0.5 + Vector2(24, 28))
	refresh_states()
	_view_initialized = false
	_user_adjusted = false
	if is_inside_tree(): fit_tree()

func _layout_rolls() -> void:
	# The trunk winds through two central lanes; convenience and Super branches
	# remain visible alongside it rather than hiding behind extra tabs.
	for index in SlimerotRollTree.MAINLINE.size():
		var row: int = index / 2
		var column := index % 2 if row % 2 == 0 else 1 - index % 2
		_centers[SlimerotRollTree.MAINLINE[index][0]] = Vector2(345 + column * 220, 100 + row * 132)
	_centers.merge({
		"RO1": Vector2(125, 232), "RO2": Vector2(125, 496),
		"RO3": Vector2(125, 628), "RO4": Vector2(125, 892),
		"RO6": Vector2(125, 1024), "RO7": Vector2(565, 1288),
		"RO5": Vector2(805, 562), "RO8": Vector2(805, 958),
		"RO9": Vector2(805, 1222),
	})

func _layout_coins() -> void:
	_centers = {
		"C01": Vector2(465, 100), "C02": Vector2(275, 232),
		"C03": Vector2(85, 232), "C04": Vector2(655, 100),
		"C05": Vector2(465, 364), "C06": Vector2(275, 452),
		"C07": Vector2(275, 1112), "C08": Vector2(465, 628),
		"C09": Vector2(85, 1112), "C10": Vector2(275, 672),
		"C11": Vector2(85, 452), "C12": Vector2(655, 320),
		"C13": Vector2(465, 892), "C14": Vector2(275, 1288),
		"C15": Vector2(275, 892), "C16": Vector2(465, 1112),
		"C17": Vector2(85, 1288), "C18": Vector2(85, 672),
		"C19": Vector2(465, 1288), "C20": Vector2(845, 100),
		"C21": Vector2(845, 320), "C22": Vector2(845, 540),
		"C23": Vector2(655, 1112), "C24": Vector2(85, 892),
		"C25": Vector2(845, 1244), "CO1": Vector2(845, 804),
		"CO2": Vector2(845, 1024), "R18": Vector2(655, 1288),
	}

func _add_node(id: String, cross_tree: bool) -> void:
	var data: SlimerotData.SkillNodeData = SkillTreeManager.nodes.get(id)
	if data == null: return
	var button := Button.new()
	button.name = "Skill_" + id
	button.position = _centers[id] - NODE_SIZE * 0.5
	button.size = NODE_SIZE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.focus_mode = Control.FOCUS_NONE
	button.set_meta("skill_id", id)
	button.set_meta("cross_tree", cross_tree)
	button.add_to_group("slimerot_skill_node")
	_content.add_child(button)
	anchors[id] = button
	var marker := _node_label(button, id + (" · " + data.tree_type.to_upper() if cross_tree else ""), Vector2(10, 8), Vector2(152, 19), 15)
	marker.modulate = Color("d0b7ec")
	var title := data.display_name.split(":")[0]
	_node_label(button, title, Vector2(10, 29), Vector2(152, 48), 19)
	_captions[id] = _node_label(button, "", Vector2(8, 81), Vector2(156, 18), 14)

func _node_label(parent: Control, text: String, at: Vector2, bounds: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = bounds
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func refresh_states() -> void:
	for id in anchors:
		var data: SlimerotData.SkillNodeData = SkillTreeManager.nodes[id]
		var owned: bool = id in GameState.purchased_skill_node_ids
		var blocker := SkillTreeManager.purchase_blocker(id)
		var button: Button = anchors[id]
		var caption: Label = _captions[id]
		var breakthrough := data.effect_type == "checkpoint_luck"
		button.theme_type_variation = "PurchasedSkillNode" if owned else ("BreakthroughSkillNode" if breakthrough else ("SkillNode" if blocker.is_empty() else "LockedSkillNode"))
		button.modulate = Color.WHITE if owned or blocker.is_empty() else Color(0.80, 0.77, 0.86)
		caption.text = "OWNED" if owned else "%s %s" % [SlimeDatabase.format_number(data.cost), data.currency_type.to_upper()]
		caption.modulate = Color("c9f568") if owned else (Color("ffd36b") if breakthrough else Color("e0c6fb"))
		button.tooltip_text = data.display_name + "\n" + data.description + ("\n" + blocker if not blocker.is_empty() else "\nAvailable")
	queue_redraw()

func capture_view() -> Dictionary:
	return {"tree_type": tree_type, "zoom_level": zoom_level, "pan_offset": pan_offset}

func restore_view(view: Dictionary) -> void:
	if view.get("tree_type", tree_type) != tree_type: return
	zoom_level = clampf(float(view.get("zoom_level", zoom_level)), MIN_ZOOM, MAX_ZOOM)
	pan_offset = view.get("pan_offset", pan_offset)
	_view_initialized = true
	_user_adjusted = true
	_apply_view()

func fit_tree() -> void:
	if size.x <= 1 or size.y <= 1: return
	zoom_level = clampf(minf((size.x - 28) / graph_bounds.size.x, (size.y - 28) / graph_bounds.size.y), MIN_ZOOM, MAX_ZOOM)
	pan_offset = (size - graph_bounds.size * zoom_level) * 0.5 - graph_bounds.position * zoom_level
	_view_initialized = true
	_user_adjusted = false
	cancel_gesture()
	_apply_view()

func zoom_by(factor: float) -> void:
	if factor <= 0: return
	_zoom_at(factor, size * 0.5, size * 0.5)

func focus_node(id: String) -> void:
	if not _centers.has(id): return
	_user_adjusted = true
	zoom_level = clampf(maxf(zoom_level, 0.85), MIN_ZOOM, MAX_ZOOM)
	pan_offset = size * 0.5 - _centers[id] * zoom_level
	_apply_view()

func _zoom_at(factor: float, old_anchor: Vector2, new_anchor: Vector2) -> void:
	_user_adjusted = true
	var graph_anchor := (old_anchor - pan_offset) / zoom_level
	zoom_level = clampf(zoom_level * factor, MIN_ZOOM, MAX_ZOOM)
	pan_offset = new_anchor - graph_anchor * zoom_level
	_apply_view()

func _apply_view() -> void:
	# A new Container child starts at zero width. Keep saved coordinates intact
	# until its first real layout, then clamp against the actual visible viewport.
	if not is_instance_valid(_content) or size.x <= 1 or size.y <= 1: return
	var scaled := graph_bounds.size * zoom_level
	for axis in 2:
		if scaled[axis] < size[axis]:
			var centered: float = (size[axis] - scaled[axis]) * 0.5
			pan_offset[axis] = clampf(pan_offset[axis], centered - 100, centered + 100)
		else:
			pan_offset[axis] = clampf(pan_offset[axis], size[axis] - scaled[axis] - 100, 100)
	_content.position = pan_offset
	_content.scale = Vector2.ONE * zoom_level
	queue_redraw()

func _on_resized() -> void:
	if not _view_initialized or not _user_adjusted: fit_tree()
	else: _apply_view()

func _on_visibility_changed() -> void:
	if not is_visible_in_tree(): cancel_gesture()

func cancel_gesture() -> void:
	_touches.clear()
	_tap_id = ""
	_mouse_held = false
	_moved = false
	_pinched = false

func has_active_gesture() -> bool:
	return not _touches.is_empty() or _mouse_held

func _local(at: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * at

func _node_at(at: Vector2) -> String:
	var graph_point := (at - pan_offset) / zoom_level
	for id in anchors:
		if Rect2(_centers[id] - NODE_SIZE * 0.5, NODE_SIZE).has_point(graph_point): return id
	return ""

func handle_input(event: InputEvent) -> bool:
	if not is_visible_in_tree():
		cancel_gesture()
		return false
	if event.device == InputEvent.DEVICE_ID_EMULATION: return false
	if event is InputEventScreenTouch:
		var at := _local(event.position)
		if event.pressed:
			if not Rect2(Vector2.ZERO, size).has_point(at): return false
			if _touches.is_empty():
				_press_position = at
				_tap_id = _node_at(at)
				_moved = false
				_pinched = false
			_touches[event.index] = at
			if _touches.size() > 1: _pinched = true
			return true
		if not _touches.has(event.index): return false
		_touches.erase(event.index)
		var selected := _tap_id if not event.canceled and not _moved and not _pinched and _node_at(at) == _tap_id and Rect2(Vector2.ZERO, size).has_point(at) else ""
		if _touches.is_empty(): cancel_gesture()
		if not selected.is_empty(): node_selected.emit(selected)
		return true
	if event is InputEventScreenDrag:
		if not _touches.has(event.index): return false
		var at := _local(event.position)
		var previous: Vector2 = _touches[event.index]
		if _touches.size() >= 2:
			var keys := _touches.keys()
			var first: Vector2 = _touches[keys[0]]
			var second: Vector2 = _touches[keys[1]]
			var old_center := (first + second) * 0.5
			var old_distance := first.distance_to(second)
			_touches[event.index] = at
			first = _touches[keys[0]]
			second = _touches[keys[1]]
			if old_distance > 1:
				_zoom_at(first.distance_to(second) / old_distance, old_center, (first + second) * 0.5)
			_pinched = true
		else:
			_touches[event.index] = at
			if at.distance_to(_press_position) > DRAG_THRESHOLD: _moved = true
			if _moved or _pinched:
				_user_adjusted = true
				pan_offset += at - previous
				_apply_view()
		return true
	if event is InputEventMouseButton:
		var at := _local(event.position)
		var inside := Rect2(Vector2.ZERO, size).has_point(at)
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed and inside:
			_zoom_at(1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12, at, at)
			return true
		if event.button_index != MOUSE_BUTTON_LEFT: return false
		if event.pressed and inside:
			_mouse_held = true
			_press_position = at
			_last_mouse = at
			_tap_id = _node_at(at)
			_moved = false
			return true
		if not event.pressed and _mouse_held:
			var selected := _tap_id if inside and not _moved and _node_at(at) == _tap_id else ""
			cancel_gesture()
			if not selected.is_empty(): node_selected.emit(selected)
			return true
	if event is InputEventMouseMotion and _mouse_held:
		var at := _local(event.position)
		if at.distance_to(_press_position) > DRAG_THRESHOLD: _moved = true
		if _moved:
			_user_adjusted = true
			pan_offset += at - _last_mouse
			_apply_view()
		_last_mouse = at
		return true
	return false

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("171024"))
	# A quiet dotted field communicates that this surface can move in both axes.
	var spacing := 40.0 * zoom_level
	var origin := Vector2(fposmod(pan_offset.x, spacing), fposmod(pan_offset.y, spacing))
	for x in range(0, ceili(size.x / spacing) + 1):
		for y in range(0, ceili(size.y / spacing) + 1):
			draw_circle(origin + Vector2(x, y) * spacing, 1.2, Color("332543"))
	for edge in edges:
		if not _centers.has(edge.source) or not _centers.has(edge.target): continue
		var start: Vector2 = _centers[edge.source]
		var finish: Vector2 = _centers[edge.target]
		var points := _edge_path(start, finish)
		for index in points.size(): points[index] = pan_offset + points[index] * zoom_level
		var owned: bool = edge.source in GameState.purchased_skill_node_ids
		var super_branch: bool = edge.target in ["RO5", "RO8", "RO9"]
		var color := Color("c9f568") if owned else (Color("aa7ddd") if super_branch else Color("79618f"))
		draw_polyline(points, Color("100b19"), 9 * zoom_level, true)
		draw_polyline(points, color, 4 * zoom_level, true)
		var end: Vector2 = points[-1]
		var direction: Vector2 = (points[-1] - points[-2]).normalized()
		var normal := Vector2(-direction.y, direction.x)
		draw_colored_polygon(PackedVector2Array([end, end - direction * 10 * zoom_level + normal * 6 * zoom_level, end - direction * 10 * zoom_level - normal * 6 * zoom_level]), color)
	draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2), Color("705184"), false, 2)

func _edge_path(start: Vector2, finish: Vector2) -> PackedVector2Array:
	if absf(start.y - finish.y) < 1:
		var direction := signf(finish.x - start.x)
		return PackedVector2Array([start + Vector2(NODE_SIZE.x * 0.5 * direction, 0), finish - Vector2(NODE_SIZE.x * 0.5 * direction, 0)])
	if absf(start.x - finish.x) < 1:
		var direction := signf(finish.y - start.y)
		return PackedVector2Array([start + Vector2(0, NODE_SIZE.y * 0.5 * direction), finish - Vector2(0, NODE_SIZE.y * 0.5 * direction)])
	if absf(start.y - finish.y) < NODE_SIZE.y + 28:
		# Nearby side branches enter horizontally, through the gap between trunk rows.
		var direction := signf(finish.y - start.y)
		var from := start + Vector2(0, NODE_SIZE.y * 0.5 * direction)
		var to := finish - Vector2(NODE_SIZE.x * 0.5 * signf(finish.x - start.x), 0)
		return PackedVector2Array([from, Vector2(from.x, to.y), to])
	var direction := signf(finish.y - start.y)
	var from := start + Vector2(0, NODE_SIZE.y * 0.5 * direction)
	var to := finish - Vector2(0, NODE_SIZE.y * 0.5 * direction)
	var lane := from.y + direction * 14
	return PackedVector2Array([from, Vector2(from.x, lane), Vector2(to.x, lane), to])
