class_name SlimerotHUD
extends CanvasLayer

signal interact_requested
var root: Control
var joystick: SlimerotJoystick
var currency_labels: Dictionary = {}
var location_label: Label
var hp_label: Label
var hp_bar: ProgressBar
var roll_button: Button
var auto_button: Button
var interact_button: Button
var interaction_label: Label
var skills_button: Button
var super_label: Label
var breakthrough_banner: PanelContainer
var breakthrough_text: Label
var breakthrough_seconds := 0.0
var notice: Label
var notice_seconds := 0.0
var menu: PanelContainer
var menu_body: VBoxContainer
var menu_title := ""
var reveal: SlimerotReveal
var menus := SlimerotMenus.new()
var menu_dirty := false
var menu_refresh_seconds := 0.0
var menu_scroll: ScrollContainer
var death_fade: ColorRect
var map_button: Button
var boss_label: Label
var safe_rect := Rect2()
var layout_items: Dictionary = {}
var scroll_touch := -1
var scroll_start := Vector2.ZERO
var scroll_last := Vector2.ZERO
var scroll_dragging := false
var scroll_offset := 0.0
var active_touches: Dictionary = {}
var scroll_button: Button
var pointer_buttons: Dictionary = {}
var managed_touches: Dictionary = {}
var modal_stack: Array[Dictionary] = []
var modal_generation := 0
var offline_summary: Dictionary = {}
var visible_menu_signature := ""
var menu_build_count := 0
var hud_refresh_pending := false

func _ready() -> void:
	layer = 10
	get_tree().quit_on_go_back = false
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.theme = create_theme()
	build_top_bar()
	var utility := HBoxContainer.new()
	utility.add_theme_constant_override("separation", 12)
	utility.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(utility)
	layout_items.utility = utility
	layout_items.team = button("TEAM", Rect2(), func(): open_menu("Team"))
	layout_items.team.reparent(utility)
	skills_button = button("SKILL TREE", Rect2(), func(): open_menu("Skills"))
	skills_button.reparent(utility)
	map_button = button("MAP", Rect2(), func(): open_menu("Map"))
	map_button.reparent(utility)
	for control in [layout_items.team, skills_button, map_button]:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.custom_minimum_size.y = 68
		control.add_theme_font_size_override("font_size", 20)
	layout_items.team.icon = SlimerotAssets.icon("team")
	skills_button.icon = SlimerotAssets.icon("skills")
	map_button.icon = SlimerotAssets.icon("map")
	joystick = SlimerotJoystick.new()
	joystick.size = Vector2(224, 224)
	root.add_child(joystick)
	roll_button = button("ROLL", Rect2(), func(): RollManager.request_roll())
	SlimerotUITheme.apply_button(roll_button, "PrimaryButton")
	roll_button.icon = SlimerotAssets.icon("roll")
	roll_button.add_theme_font_size_override("font_size", 32)
	roll_button.add_theme_constant_override("icon_max_width", 34)
	auto_button = button("AUTO OFF", Rect2(), toggle_auto)
	auto_button.add_theme_font_size_override("font_size", 20)
	super_label = text("", Rect2(), 17, SlimerotUITheme.GOLD)
	super_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice = text("", Rect2(), 21, SlimerotUITheme.GOLD)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_label = text("", Rect2(), 23)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interaction_label = text("", Rect2(), 18)
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interact_button = button("INTERACT", Rect2(), func(): interact_requested.emit())
	interact_button.hide()
	reveal = SlimerotReveal.new()
	root.add_child(reveal)
	breakthrough_banner = panel(Rect2())
	breakthrough_banner.z_index = 40
	breakthrough_banner.theme_type_variation = "Card"
	breakthrough_text = Label.new()
	breakthrough_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breakthrough_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	breakthrough_text.add_theme_font_size_override("font_size", 26)
	breakthrough_text.add_theme_color_override("font_color", SlimerotUITheme.GOLD)
	breakthrough_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breakthrough_banner.add_child(breakthrough_text)
	breakthrough_banner.hide()
	death_fade = ColorRect.new()
	death_fade.color = Color(0, 0, 0, 0)
	death_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_fade.z_index = 100
	root.add_child(death_fade)
	SkillTreeManager.purchased.connect(on_skill_purchased)
	GameState.changed.connect(func(): hud_refresh_pending = true; menu_dirty = true)
	SaveManager.save_failed.connect(show_notice)
	SaveManager.offline_summary_ready.connect(show_offline_summary)
	get_viewport().size_changed.connect(apply_layout)
	apply_layout()
	refresh()
	if not SaveManager.last_error.is_empty(): show_notice(SaveManager.last_error)
	if not SaveManager.last_offline_summary.is_empty(): show_offline_summary(SaveManager.last_offline_summary)

func build_top_bar() -> void:
	var top := panel(Rect2())
	top.theme_type_variation = "Card"
	layout_items.top = top
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	var health := VBoxContainer.new()
	health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(health)
	hp_label = Label.new()
	hp_label.add_theme_font_size_override("font_size", 20)
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health.add_child(hp_label)
	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size.y = 12
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health.add_child(hp_bar)
	location_label = Label.new()
	location_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	location_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	location_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	location_label.add_theme_font_size_override("font_size", 22)
	location_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(location_label)
	layout_items.settings = button("", Rect2(), func(): open_menu("Settings"))
	layout_items.settings.reparent(row)
	SlimerotUITheme.apply_button(layout_items.settings, "IconButton")
	layout_items.settings.custom_minimum_size = Vector2(68, 68)
	layout_items.settings.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	layout_items.settings.icon = SlimerotAssets.icon("settings")
	layout_items.settings.tooltip_text = "Settings"
	var currencies := HBoxContainer.new()
	currencies.add_theme_constant_override("separation", 10)
	currencies.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(currencies)
	layout_items.currencies = currencies
	for key in ["coins", "rolls", "luck"]:
		var chip := PanelContainer.new()
		chip.theme_type_variation = "CurrencyChip"
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		currencies.add_child(chip)
		var contents := HBoxContainer.new()
		contents.alignment = BoxContainer.ALIGNMENT_CENTER
		contents.add_theme_constant_override("separation", 8)
		contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(contents)
		var icon := TextureRect.new()
		icon.texture = SlimerotAssets.icon(key)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(28, 28)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contents.add_child(icon)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 21)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contents.add_child(label)
		currency_labels[key] = label

func place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

func apply_layout(override_safe: Rect2 = Rect2()) -> void:
	var visible_rect := get_viewport().get_visible_rect()
	safe_rect = visible_rect
	if override_safe.has_area():
		safe_rect = visible_rect.intersection(override_safe)
	elif OS.has_feature("mobile"):
		var native_safe := Rect2(DisplayServer.get_display_safe_area())
		native_safe.position -= Vector2(DisplayServer.window_get_position())
		if native_safe.has_area(): safe_rect = visible_rect.intersection(get_viewport().get_screen_transform().affine_inverse() * native_safe)
	root.position = safe_rect.position
	root.scale = Vector2.ONE * minf(1.0, safe_rect.size.x / 720.0)
	root.size = safe_rect.size / root.scale
	var w := root.size.x
	var h := root.size.y
	place(layout_items.top, Rect2(16, 16, w - 32, 112))
	place(layout_items.currencies, Rect2(16, 138, w - 32, 62))
	place(layout_items.utility, Rect2(20, h - 326, w - 40, 68))
	place(joystick, Rect2(24, h - 242, 224, 224))
	place(roll_button, Rect2(w - 292, h - 164, 268, 102))
	place(auto_button, Rect2(w - 292, h - 240, 268, 64))
	place(super_label, Rect2(w - 302, h - 52, 288, 38))
	place(boss_label, Rect2(24, 220, w - 48, 94))
	place(notice, Rect2(40, h - 532, w - 80, 72))
	place(interaction_label, Rect2(30, h - 448, w - 60, 44))
	place(interact_button, Rect2(w * 0.5 - 118, h - 400, 236, 64))
	place(breakthrough_banner, Rect2(20, 328, w - 40, 154))
	place(death_fade, Rect2(Vector2.ZERO, root.size))
	place(reveal, Rect2(Vector2.ZERO, root.size))
	if is_instance_valid(menu): place(menu, modal_rect())

func modal_rect() -> Rect2:
	return Rect2(16, 16, root.size.x - 32, root.size.y - 278)

func style(color: Color) -> StyleBoxFlat:
	var box := SlimerotUITheme.resource().get_stylebox("panel", "Card").duplicate() as StyleBoxFlat
	box.bg_color = color
	return box
func create_theme() -> Theme:
	return SlimerotUITheme.resource()

func panel(rect: Rect2) -> PanelContainer:
	var result := PanelContainer.new()
	place(result, rect)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(result)
	return result

func text(value: String, rect: Rect2, font_size: int = 23, color: Color = SlimerotPresentation.CREAM) -> Label:
	var label := Label.new()
	label.text = value
	place(label, rect)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	return label

func button(value: String, rect: Rect2, action: Callable) -> Button:
	var result := Button.new()
	result.text = value
	place(result, rect)
	SlimerotUITheme.apply_button(result)
	result.pressed.connect(action)
	root.add_child(result)
	return result

func refresh() -> void:
	hud_refresh_pending = false
	var stats := SkillTreeManager.derived_stats()
	if stats.breakthrough_count == 0:
		breakthrough_seconds = 0.0
		breakthrough_banner.hide()
	currency_labels.coins.text = compact(GameState.coins)
	currency_labels.rolls.text = compact(GameState.rolls_balance)
	currency_labels.luck.text = "×" + compact(RollManager.get_effective_luck())
	for key in currency_labels: currency_labels[key].tooltip_text = key.capitalize()
	hp_bar.max_value = stats.max_hp
	hp_bar.value = GameState.player_hp
	hp_label.text = "HP %d / %d" % [GameState.player_hp, stats.max_hp]
	location_label.text = SlimerotCampaign.zone(GameState.current_zone).name
	skills_button.visible = GameState.structure_unlocked_flags.get("skill_tree_shrine", false)
	map_button.visible = GameState.structure_unlocked_flags.get("fast_travel_pillar", false)
	super_label.visible = stats.super_roll
	super_label.text = "SUPER ×%d · %s" % [int(stats.super_roll_multiplier), "NEXT ROLL" if RollManager.rolls_until_super() == 1 else "%d left" % RollManager.rolls_until_super()]
	auto_button.visible = stats.auto_roll
	auto_button.disabled = not stats.auto_roll or GameState.is_paused()
	auto_button.text = "AUTO ON" if GameState.settings.auto_roll_state else "AUTO OFF"
	auto_button.theme_type_variation = "PrimaryButton" if GameState.settings.auto_roll_state else "SecondaryButton"

func compact(value: float) -> String:
	for row in [[1000000000.0, "B"], [1000000.0, "M"], [1000.0, "K"]]:
		if value >= row[0]: return "%.2f%s" % [value / row[0], row[1]]
	return str(int(value)) if value == floor(value) else "%.2f" % value

func _process(delta: float) -> void:
	if hud_refresh_pending: refresh()
	var recede := 0.45 if reveal.active and reveal.tier >= 2 else 1.0
	for control in [layout_items.top, layout_items.currencies]: control.modulate.a = recede
	var bosses := get_tree().get_nodes_in_group("slimerot_bosses")
	boss_label.visible = WorldManager.boss_active and not bosses.is_empty() and not is_instance_valid(menu)
	if boss_label.visible:
		var boss: SlimerotBoss = bosses[0]
		boss_label.text = "%s · %s / %s HP\n%s%s" % [boss.data.name, compact(boss.hp), compact(boss.data.hp), "PHASE 2 · " if boss.enraged else "", boss.attack_label]
	death_fade.color.a = clampf(1.0 - CombatManager.death_remaining / SlimerotBalance.DEATH_FADE_SECONDS, 0, 1) if GameState.player_dead else 0.0
	if breakthrough_seconds > 0.0 and not GameState.suspended:
		breakthrough_seconds = maxf(0.0, breakthrough_seconds - delta)
		var age := SlimerotPresentation.BREAKTHROUGH_SECONDS - breakthrough_seconds
		breakthrough_banner.pivot_offset = breakthrough_banner.size * 0.5
		breakthrough_banner.scale = Vector2.ONE * (1.0 + sin(minf(age / 0.25, 1.0) * PI) * 0.055)
		breakthrough_banner.modulate.a = minf(1.0, breakthrough_seconds / 0.2)
		if breakthrough_seconds == 0.0: breakthrough_banner.hide()
	roll_button.text = "ROLL · %.1fs" % RollManager.cooldown_remaining if RollManager.cooldown_remaining > 0.0 else "ROLL"
	roll_button.disabled = RollManager.cooldown_remaining > 0.0 or GameState.is_paused() or GameState.player_dead
	auto_button.disabled = not SkillTreeManager.derived_stats().auto_roll or GameState.is_paused()
	if notice_seconds > 0.0:
		notice_seconds -= delta
		if notice_seconds <= 0.0: notice.text = ""
	if menu_dirty and is_instance_valid(menu) and active_touches.is_empty() and not menus.is_interacting() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		menu_refresh_seconds += delta
		if menu_refresh_seconds >= 0.4:
			menu_refresh_seconds = 0.0
			var signature := menus.visible_signature(menu_title)
			if signature != visible_menu_signature:
				if not menus.refresh_visible(menu_title): refresh_menu_body()
				visible_menu_signature = signature
			menu_dirty = false
	menus.tick(delta)

func on_skill_purchased(id: String, previous_luck: float, new_luck: float) -> void:
	if SkillTreeManager.nodes[id].effect_type != "checkpoint_luck": return
	breakthrough_text.text = "%s\nLuck ×%.2f → ×%.2f\nTOTAL LUCK ×20" % [SkillTreeManager.nodes[id].display_name, previous_luck, new_luck]
	breakthrough_seconds = SlimerotPresentation.BREAKTHROUGH_SECONDS
	breakthrough_banner.modulate.a = 1.0
	breakthrough_banner.show()

func set_interaction(prompt: String) -> void:
	var available := not prompt.is_empty() and not is_instance_valid(menu) and not WorldManager.boss_active and not GameState.player_dead
	interact_button.visible = available
	interaction_label.visible = available
	interaction_label.text = prompt

func show_notice(message: String) -> void:
	notice.text = message
	notice_seconds = 5.0

func show_offline_summary(summary: Dictionary) -> void:
	offline_summary = summary.duplicate(true)
	open_modal("AFK Summary")

func toggle_auto() -> void:
	if not SkillTreeManager.derived_stats().auto_roll or GameState.is_paused(): return
	GameState.settings.auto_roll_state = not GameState.settings.auto_roll_state
	GameState.changed.emit()
	GameState.critical_change.emit("settings")

func offline_input_locked() -> bool:
	# Catch-up samples a fixed snapshot, then durably commits its rewards. Keep all
	# player edits out of that transaction, including menu actions while suspended.
	return SaveManager.offline_processing or SaveManager.offline_commit_pending

func _input(event: InputEvent) -> void:
	# Godot can synthesize mouse events from touch, and touch from a desktop mouse.
	# Real mouse clicks use native Button.pressed; real touch uses the capture below.
	# Never deliver both representations of the same pointer to a gameplay button.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		if event is InputEventMouse: get_viewport().set_input_as_handled()
		return
	if offline_input_locked():
		active_touches.clear()
		cancel_pointer_buttons()
		pointer_buttons.clear()
		managed_touches.clear()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		handle_back()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed: active_touches[event.index] = true
		else: active_touches.erase(event.index)
	if menus.handle_input(event):
		if event is InputEventScreenTouch:
			if event.pressed: managed_touches[event.index] = true
			else: managed_touches.erase(event.index)
		get_viewport().set_input_as_handled()
		return
	if handle_scroll(event): return
	if event is InputEventScreenDrag and pointer_buttons.has(event.index):
		var capture: Dictionary = pointer_buttons[event.index]
		var target: Button = capture.target.get_ref()
		if not is_instance_valid(target) or not target.get_global_rect().has_point(event.position):
			capture.canceled = true
			if is_instance_valid(target): target.set_pressed_no_signal(false)
		get_viewport().set_input_as_handled()
		return
	if event is not InputEventScreenTouch: return
	if not event.pressed:
		if pointer_buttons.has(event.index):
			var capture: Dictionary = pointer_buttons[event.index]
			pointer_buttons.erase(event.index)
			var target: Button = capture.target.get_ref()
			get_viewport().set_input_as_handled()
			if is_instance_valid(target):
				target.set_pressed_no_signal(false)
				if not capture.canceled and capture.generation == modal_generation and target.get_global_rect().has_point(event.position):
					activate_button(target)
		elif managed_touches.has(event.index):
			managed_touches.erase(event.index)
			get_viewport().set_input_as_handled()
		return
	var target: Control
	if is_instance_valid(menu) and menu.get_global_rect().has_point(event.position):
		target = touch_target(menu, event.position)
		managed_touches[event.index] = true
		get_viewport().set_input_as_handled()
	elif not GameState.is_paused():
		for control in [roll_button, auto_button, interact_button, layout_items.settings, layout_items.team, skills_button, map_button]:
			if control.is_visible_in_tree() and control.get_global_rect().has_point(event.position):
				target = control
				break
	if target is Button:
		managed_touches.erase(event.index)
		pointer_buttons[event.index] = {"target": weakref(target), "generation": modal_generation, "canceled": target.disabled}
		if not target.disabled: target.set_pressed_no_signal(true)
		get_viewport().set_input_as_handled()

func activate_button(target: Button) -> void:
	# All regular touch buttons terminate at the same signal as native mouse input.
	if offline_input_locked() or not is_instance_valid(target) or not target.is_visible_in_tree() or target.disabled: return
	if target is OptionButton: target.show_popup()
	else: target.pressed.emit()

func handle_scroll(event: InputEvent) -> bool:
	if not is_instance_valid(menu_scroll) or menu_title == "Skills": return false
	if event is InputEventScreenTouch:
		if event.pressed and scroll_touch == -1 and menu_scroll.get_global_rect().has_point(event.position):
			if menus.is_interacting(): return false
			var target := touch_target(menu_body, event.position)
			if target is Slider or target is OptionButton: return false
			scroll_button = target as Button
			scroll_touch = event.index
			scroll_start = event.position
			scroll_last = event.position
			scroll_offset = menu_scroll.scroll_vertical
			scroll_dragging = false
			get_viewport().set_input_as_handled()
			return true
		elif not event.pressed and event.index == scroll_touch:
			var tapped: bool = not scroll_dragging and event.position.distance_to(scroll_start) < SlimerotPresentation.SCROLL_DEADZONE
			var target := scroll_button
			scroll_touch = -1
			scroll_dragging = false
			scroll_button = null
			get_viewport().set_input_as_handled()
			if tapped and is_instance_valid(target) and not target.disabled and target.get_global_rect().has_point(event.position):
				activate_button(target)
			return true
	elif event is InputEventScreenDrag and event.index == scroll_touch:
		if event.position.distance_to(scroll_start) >= SlimerotPresentation.SCROLL_DEADZONE: scroll_dragging = true
		if scroll_dragging:
			menu_scroll.scroll_vertical = int(scroll_offset + (scroll_start.y - event.position.y) / root.scale.y)
			get_viewport().set_input_as_handled()
			return true
	return false

func touch_target(node: Node, at: Vector2) -> Control:
	# Clipped graph nodes and offscreen cards are not touch targets. Walking the
	# tree must honor the same clipping and pointer rules as Godot's GUI picker.
	if node is Control and node.clip_contents and not node.get_global_rect().has_point(at): return null
	var children := node.get_children()
	children.reverse()
	for child in children:
		if child is Control and child.is_visible_in_tree():
			var nested := touch_target(child, at)
			if nested != null: return nested
			if (child is BaseButton or child is Slider) and child.mouse_filter != Control.MOUSE_FILTER_IGNORE and child.get_global_rect().has_point(at): return child
	return null

func handle_back() -> void:
	if offline_input_locked(): return
	menus.cancel_hold()
	joystick.reset()
	if not modal_stack.is_empty():
		close_top_modal()
	else:
		open_menu("Settings")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(root): handle_back()
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		menus.cancel_hold()
		if is_instance_valid(menus.skill_canvas): menus.skill_canvas.cancel_gesture()
		active_touches.clear()
		cancel_pointer_buttons()
		pointer_buttons.clear()
		managed_touches.clear()
		scroll_touch = -1
		if is_instance_valid(joystick): joystick.reset()

func close_menu() -> void:
	modal_stack.clear()
	dispose_menu()
	GameState.menu_paused = false

func cancel_pointer_buttons() -> void:
	for capture in pointer_buttons.values():
		var target: Button = capture.target.get_ref()
		if is_instance_valid(target): target.set_pressed_no_signal(false)
		capture.canceled = true

func dispose_menu() -> void:
	menus.remember_skill_view()
	modal_generation += 1
	menus.cancel_hold()
	cancel_pointer_buttons()
	scroll_touch = -1
	scroll_dragging = false
	scroll_button = null
	if is_instance_valid(menu):
		root.remove_child(menu)
		menu.queue_free()
		menu = null
	menu_scroll = null
	menu_body = null
	menu_title = ""
	layout_items.utility.show()

func remember_modal_scroll() -> void:
	if not modal_stack.is_empty() and is_instance_valid(menu_scroll):
		modal_stack[-1].scroll = menu_scroll.scroll_vertical

func open_modal(id: String) -> void:
	id = canonical_menu(id)
	if offline_input_locked() and id != "AFK Summary": return
	if id == "Skills" and not GameState.structure_unlocked_flags.get("skill_tree_shrine", false):
		show_notice("Repair the Skill Tree Shrine in the Bedroom Hub.")
		return
	remember_modal_scroll()
	for index in modal_stack.size():
		if modal_stack[index].id == id:
			modal_stack.resize(index + 1)
			build_modal(id, int(modal_stack[-1].scroll))
			return
	modal_stack.append({"id": id, "scroll": 0})
	build_modal(id)

func close_top_modal() -> void:
	if offline_input_locked() or modal_stack.is_empty(): return
	modal_stack.pop_back()
	dispose_menu()
	if modal_stack.is_empty(): GameState.menu_paused = false
	else: build_modal(modal_stack[-1].id, int(modal_stack[-1].scroll))

func close_modal(id: String) -> void:
	id = canonical_menu(id)
	for index in modal_stack.size():
		if modal_stack[index].id != id: continue
		if index == modal_stack.size() - 1: close_top_modal()
		else:
			modal_stack.remove_at(index)
			update_modal_pause()
		return

func update_modal_pause() -> void:
	GameState.menu_paused = modal_stack.any(func(entry: Dictionary): return entry.id == "Settings")
	if GameState.menu_paused: joystick.reset()

func menu_label(value: String, font_size: int = 22) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_body.add_child(label)

func menu_button(value: String, action: Callable, disabled: bool = false) -> Button:
	var control := Button.new()
	control.text = value
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SlimerotUITheme.apply_button(control)
	control.focus_mode = Control.FOCUS_NONE
	control.disabled = disabled
	control.pressed.connect(action)
	menu_body.add_child(control)
	return control

func open_menu(title: String) -> void:
	title = canonical_menu(title)
	if offline_input_locked(): return
	if title == "Skills" and not GameState.structure_unlocked_flags.get("skill_tree_shrine", false):
		show_notice("Repair the Skill Tree Shrine in the Bedroom Hub.")
		return
	if menu_title == title and is_instance_valid(menu):
		refresh_menu_body()
		return
	if title.begins_with("Skill:"):
		open_modal(title)
		return
	if title.begins_with("Copies:") or title == "Sell Duplicates":
		if modal_stack.is_empty() or modal_stack[0].id != "Team":
			modal_stack.assign([{"id": "Team", "scroll": 0}])
		open_modal(title)
		return
	# Navigation tabs replace the root screen; only explicit subviews/modal calls
	# push a layer. Reopening a screen never adds duplicate close connections.
	modal_stack.clear()
	open_modal(title)

func build_modal(title: String, previous_scroll: int = 0) -> void:
	dispose_menu()
	menu_title = title
	update_modal_pause()
	layout_items.utility.hide()
	menu = panel(modal_rect())
	menu.theme_type_variation = "ModalPanel"
	menu.z_index = 20
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	menu.add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)
	var heading := Label.new()
	heading.text = "TEAM" if title in ["Team", "Collection", "Potions"] else ("SLIME COPIES" if title.begins_with("Copies:") else ("UPGRADE" if title.begins_with("Skill:") else ("SKILL TREE" if title == "Skills" else title.to_upper())))
	heading.theme_type_variation = "TitleLabel"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(heading)
	var close := Button.new()
	close.text = "Back" if modal_stack.size() > 1 else "Close"
	SlimerotUITheme.apply_button(close, "SecondaryButton")
	close.custom_minimum_size.x = 104
	close.disabled = offline_input_locked()
	close.pressed.connect(close_top_modal)
	header.add_child(close)
	if title in ["Team", "Collection", "Potions"]:
		var tabs := HBoxContainer.new()
		tabs.add_theme_constant_override("separation", 8)
		layout.add_child(tabs)
		for entry in [["Team", "TEAM", "team"], ["Collection", "COLLECTION", "collection"], ["Potions", "ITEMS", "potions"]]:
			var tab := Button.new()
			tab.text = entry[1]
			tab.icon = SlimerotAssets.icon(entry[2])
			SlimerotUITheme.apply_button(tab, "TabButton")
			tab.add_theme_font_size_override("font_size", 18)
			tab.add_theme_constant_override("icon_max_width", 22)
			tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tab.disabled = title == entry[0]
			tab.pressed.connect(func(): open_menu(entry[0]))
			tabs.add_child(tab)
	menu_scroll = ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if title == "Skills" else ScrollContainer.SCROLL_MODE_AUTO
	menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_scroll.scroll_deadzone = int(SlimerotPresentation.SCROLL_DEADZONE)
	layout.add_child(menu_scroll)
	menu_body = VBoxContainer.new()
	menu_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_body.size_flags_vertical = Control.SIZE_EXPAND_FILL if title == "Skills" else Control.SIZE_FILL
	menu_body.add_theme_constant_override("separation", 14)
	menu_scroll.add_child(menu_body)
	build_menu_content(title)
	if previous_scroll > 0: menu_scroll.set_deferred("scroll_vertical", previous_scroll)
	menu_dirty = false

func canonical_menu(title: String) -> String:
	if title == "Inventory": return "Team"
	if title == "Roll Settings": return "Settings"
	return title

func refresh_menu_body() -> void:
	if not is_instance_valid(menu_body): return
	var previous_scroll := menu_scroll.scroll_vertical
	for child in menu_body.get_children():
		menu_body.remove_child(child)
		child.queue_free()
	build_menu_content(menu_title)
	if previous_scroll > 0: menu_scroll.set_deferred("scroll_vertical", previous_scroll)
	menu_dirty = false

func build_menu_content(title: String) -> void:
	menu_build_count += 1
	menus.build(self, title)
	visible_menu_signature = menus.visible_signature(title)
	if title != "AFK Summary": return
	var seconds := maxi(0, int(offline_summary.get("seconds_away", 0)))
	menu_label("Welcome back!", 28)
	menu_label("Time away: %dh %02dm %02ds\nOffline rolls: %s\nRolls earned: +%s" % [seconds / 3600, (seconds / 60) % 60, seconds % 60, compact(offline_summary.get("rolls", 0)), compact(offline_summary.get("rolls_earned", 0))])
	var discoveries: Array = offline_summary.get("new_discoveries", [])
	menu_label("New bases: %d · New variant combinations: %d" % [discoveries.size(), offline_summary.get("new_variant_discoveries", []).size()])
	var best: Dictionary = offline_summary.get("best_drop", {})
	if not best.is_empty():
		var slime := SlimeDatabase.get_slime(best.get("slime_id", ""))
		if slime != null: menu_label("Best drop: %s %s\nEffective rarity: 1 in %s · Damage %s" % [SlimerotVariants.label(best.get("variant_flags", best.get("variant", "normal"))), slime.display_name, SlimeDatabase.format_number(int(best.get("effective_rarity", SlimeDatabase.get_effective_rarity(slime.id, best.get("variant", "normal"))))), SlimeDatabase.format_number(SlimeDatabase.get_base_combat_damage(slime.id, best.get("variant_flags", best.get("variant", "normal"))))])
	if offline_summary.get("pending", false): menu_label("Catching up remaining rolls…", 19)
	menu_button("Continue exploring", close_top_modal, offline_input_locked())
