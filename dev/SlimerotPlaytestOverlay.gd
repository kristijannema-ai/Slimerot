extends CanvasLayer

# Slimerot diagnostic labels are click-through; only the two named buttons consume taps.
var logger: Node
var hud: Node
var root: Control
var panel: PanelContainer
var metrics: Label
var status: Label
var toggle_button: Button
var export_button: Button
var expanded := true
var _elapsed := 0.0
var _last_safe := Rect2()
var _touch_buttons: Dictionary = {}

func _ready() -> void:
	if not OS.is_debug_build() or not is_instance_valid(logger) or not logger.active:
		queue_free()
		return
	layer = 40
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.09, 0.10, 0.91)
	style.border_color = Color("b9f578")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	metrics = Label.new()
	metrics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	metrics.add_theme_color_override("font_color", Color("e6f6ee"))
	metrics.add_theme_font_size_override("font_size", 17)
	metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(metrics)
	status = Label.new()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_theme_color_override("font_color", Color("c5e999"))
	status.add_theme_font_size_override("font_size", 15)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "F8 details · F9 export · recording active time"
	column.add_child(status)
	toggle_button = _button("Hide log", toggle_details)
	export_button = _button("Export log", export_now)
	logger.exported.connect(_on_exported)
	apply_layout()
	refresh()

func _button(title: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = title
	result.focus_mode = Control.FOCUS_NONE
	result.mouse_filter = Control.MOUSE_FILTER_STOP
	result.add_theme_font_size_override("font_size", 17)
	result.pressed.connect(action)
	root.add_child(result)
	return result

func _process(delta: float) -> void:
	if not is_instance_valid(logger) or not logger.active: return
	_elapsed += delta
	if _elapsed >= 0.5:
		_elapsed = 0.0
		apply_layout()
		refresh()

func apply_layout(override_safe: Rect2 = Rect2()) -> void:
	if not is_instance_valid(root): return
	var safe := get_viewport().get_visible_rect()
	if is_instance_valid(hud) and hud.safe_rect.has_area(): safe = hud.safe_rect
	if override_safe.has_area(): safe = safe.intersection(override_safe)
	_last_safe = safe
	root.position = safe.position
	root.scale = Vector2.ONE * minf(1.0, safe.size.x / 720.0)
	root.size = safe.size / root.scale
	# Below the wallet, away from bottom movement/roll controls; panels pass input through.
	var width := minf(490.0, root.size.x - 24.0)
	panel.position = Vector2(12, minf(220.0, root.size.y * 0.20))
	panel.size = Vector2(width, 0)
	panel.custom_minimum_size.x = width
	toggle_button.position = Vector2(12, panel.position.y - 54)
	export_button.position = Vector2(152, panel.position.y - 54)
	toggle_button.size = Vector2(132, 46)
	export_button.size = Vector2(140, 46)

func refresh() -> void:
	if not is_instance_valid(logger) or not logger.active or not is_instance_valid(metrics): return
	var state: Dictionary = logger.snapshot()
	metrics.text = "SLIMEROT · DEVELOPER PLAYTEST\nActive %.1fm · run %.1fm · segment %d · Z%d / %d\nLifetime Rolls %d · spendable %d\nCoins %s · Team DPS %s · slots %d\nLuck x%s · rolling x%s · cap %s\nOwned: %s\nEquipped: %s\nBoss actual %.1f DPS / %.1fs · gate: %s\nEvents %d · samples %d · drops %d / %d" % [
		state.active_play_seconds / 60.0, state.run_active_seconds / 60.0, state.segment, state.current_zone, state.highest_zone_unlocked,
		state.lifetime_rolls, state.spendable_rolls, SlimeDatabase.format_number(state.coins), SlimeDatabase.format_number(state.team_dps), state.slots,
		SlimeDatabase.format_number(state.effective_luck), SlimeDatabase.format_number(state.rolling_luck), "MAX" if state.luck_cap == 0 else str(state.luck_cap),
		_slime_label(state.strongest_owned), _slime_label(state.strongest_equipped), state.observed_boss_dps, state.observed_boss_active_seconds,
		state.gate.state, logger.events.size(), logger.samples.size(), logger.dropped_events, logger.dropped_samples]
	metrics.text += "\nChaser %s sec · Coins/min %.1f · Rolls/min %.1f\nBest 1/%s · raw damage %s · last unlock %.1fs" % [
		"—" if state.current_zone_chaser_ttk_seconds == null else "%.1f" % state.current_zone_chaser_ttk_seconds,
		state.coins_per_minute, state.rolls_per_minute, SlimeDatabase.format_number(state.best_effective_rarity),
		SlimeDatabase.format_number(state.best_raw_damage), state.seconds_since_meaningful_unlock]
	panel.visible = expanded
	toggle_button.text = "Hide log" if expanded else "Show log"
	panel.size.y = 0

func _slime_label(slime: Dictionary) -> String:
	return "none" if slime.is_empty() else "%s %s (%s dmg)" % [str(slime.variant).capitalize(), slime.name, SlimeDatabase.format_number(slime.damage)]

func toggle_details() -> void:
	expanded = not expanded
	refresh()

func export_now() -> void:
	if is_instance_valid(logger) and logger.active: logger.export_run()

func _on_exported(result: Dictionary) -> void:
	status.text = "Exported JSON + text to " + str(logger.output_directory) if result.ok else str(result.error)
	status.add_theme_color_override("font_color", Color("c5e999") if result.ok else Color("ffb29c"))
	print("Slimerot playtest export: ", JSON.stringify(result))

func _input(event: InputEvent) -> void:
	if not is_instance_valid(logger) or not logger.active: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8 or event.physical_keycode == KEY_F8:
			toggle_details()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F9 or event.physical_keycode == KEY_F9:
			export_now()
			get_viewport().set_input_as_handled()
	# The gameplay HUD has custom multi-touch handling, so explicit diagnostic taps
	# are owned here before they can become a roll/menu action underneath.
	elif event is InputEventScreenTouch:
		if event.pressed:
			for button in [toggle_button, export_button]:
				if button.get_global_rect().has_point(event.position):
					_touch_buttons[event.index] = button
					get_viewport().set_input_as_handled()
					return
		elif _touch_buttons.has(event.index):
			var button: Button = _touch_buttons[event.index]
			_touch_buttons.erase(event.index)
			if is_instance_valid(button) and button.get_global_rect().has_point(event.position): button.pressed.emit()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _touch_buttons.has(event.index):
		# A drag cancels the eventual action but still owns this pointer until release.
		_touch_buttons[event.index] = null
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]: _touch_buttons.clear()
