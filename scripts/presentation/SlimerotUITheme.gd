class_name SlimerotUITheme
extends RefCounted

const THEME_PATH := "res://assets/ui/SlimerotTheme.tres"
const TOUCH_SIZE := 64.0
const ICON_SIZE := 28
const INK := Color("171126")
const SURFACE := Color("2b2141")
const CREAM := Color("fff5df")
const MUTED := Color("c4b4cf")
const LIME := Color("c9f568")
const GOLD := Color("ffd36b")
const PURPLE := Color("b592ff")
static var _resource: Theme

static func resource() -> Theme:
	if _resource == null:
		_resource = load(THEME_PATH) as Theme
	return _resource

static func apply_button(button: Button, variation: String = "SecondaryButton") -> void:
	button.theme_type_variation = variation
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, TOUCH_SIZE)
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", ICON_SIZE)

# Bounds are world-space areas belonging to a structure/landmark, never screen
# baselines. Anchors keep multiline captions centered across camera resolutions.
static func world_label(parent: Node, bounds: Rect2, caption: String, font_size: int = 20) -> Label:
	var frame := Control.new()
	frame.name = "WorldCaption"
	frame.position = bounds.position
	frame.size = bounds.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.focus_mode = Control.FOCUS_NONE
	frame.theme = resource()
	parent.add_child(frame)
	var label := Label.new()
	label.name = "CenteredLabel"
	label.theme_type_variation = "WorldLabel"
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	frame.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return label

static func landmark_label(parent: Node, landmark: Rect2, caption: String, font_size: int = 20) -> Label:
	var caption_size := Vector2(landmark.size.x * 2.0, font_size * 3.2)
	var caption_origin := Vector2(landmark.get_center().x - caption_size.x * 0.5, landmark.end.y)
	return world_label(parent, Rect2(caption_origin, caption_size), caption, font_size)
