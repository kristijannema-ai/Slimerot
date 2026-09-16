class_name SlimerotHUD
extends CanvasLayer

signal interact_requested
var root: Control
var joystick: SlimerotJoystick
var wallet: Label
var location_label: Label
var hp_label: Label
var hp_bar: ProgressBar
var team_label: Label
var tutorial: Label
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
var portraits: HBoxContainer
var menu_dirty := false
var menu_refresh_seconds := 0.0
var menu_scroll: ScrollContainer
var death_fade: ColorRect
var map_button: Button
var boss_label: Label
var safe_rect := Rect2()
var layout_items: Dictionary = {}
var equipped_signature := ""
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

func _ready() -> void:
	layer = 10
	get_tree().quit_on_go_back = false
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.theme = create_theme()
	layout_items.control_dock = panel(Rect2())
	layout_items.control_dock.add_theme_stylebox_override("panel", style(Color("101c2df5")))
	layout_items.health_panel = panel(Rect2())
	layout_items.wallet_panel = panel(Rect2())
	layout_items.brand = text("SLIMEROT", Rect2(), 13, SlimerotPresentation.MINT)
	layout_items.wallet_heading = text("YOUR WALLET", Rect2(), 13, SlimerotPresentation.MUTED)
	wallet = text("", Rect2(), 21, SlimerotPresentation.CREAM)
	for key in ["coins", "rolls", "luck"]:
		var icon := TextureRect.new()
		icon.texture = SlimerotAssets.icon(key)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(icon)
		layout_items[key + "_icon"] = icon
	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.add_theme_stylebox_override("background", meter_style(SlimerotPresentation.INK))
	hp_bar.add_theme_stylebox_override("fill", meter_style(SlimerotPresentation.MINT))
	root.add_child(hp_bar)
	hp_label = text("", Rect2(), 18)
	location_label = text("", Rect2(), 19)
	location_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout_items.settings = button("Pause", Rect2(), func(): open_menu("Settings"))
	map_button = button("Fast Travel", Rect2(), func(): open_menu("Map"))
	map_button.add_theme_font_size_override("font_size", 18)
	layout_items.potions = button("Potions", Rect2(), func(): open_menu("Potions"))
	tutorial = text("", Rect2(), 19, SlimerotPresentation.CREAM)
	tutorial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial.add_theme_color_override("font_shadow_color", SlimerotPresentation.INK)
	tutorial.add_theme_constant_override("shadow_outline_size", 5)
	boss_label = text("", Rect2(), 23)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice = text("", Rect2(), 21, Color("fff0bc"))
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interaction_label = text("", Rect2(), 18)
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interact_button = button("INTERACT", Rect2(), func(): interact_requested.emit())
	interact_button.add_theme_stylebox_override("normal", style(Color("304c44")))
	interact_button.hide()
	joystick = SlimerotJoystick.new()
	joystick.size = Vector2(224, 224)
	root.add_child(joystick)
	roll_button = button("ROLL", Rect2(), func(): RollManager.request_roll())
	roll_button.add_theme_stylebox_override("normal", style(SlimerotPresentation.MINT))
	roll_button.add_theme_stylebox_override("hover", style(Color("dcffac")))
	roll_button.add_theme_stylebox_override("pressed", style(Color("a9dc62")))
	roll_button.add_theme_stylebox_override("disabled", style(Color("344a3e")))
	roll_button.add_theme_color_override("font_color", SlimerotPresentation.INK)
	roll_button.add_theme_color_override("font_hover_color", SlimerotPresentation.INK)
	roll_button.add_theme_color_override("font_pressed_color", SlimerotPresentation.INK)
	roll_button.add_theme_color_override("font_disabled_color", Color("d1e4bd"))
	roll_button.add_theme_font_size_override("font_size", 32)
	auto_button = button("Auto · Locked", Rect2(), toggle_auto)
	auto_button.add_theme_font_size_override("font_size", 20)
	layout_items.inventory = button("Inventory", Rect2(), func(): open_menu("Inventory"))
	layout_items.inventory.add_theme_font_size_override("font_size", 19)
	skills_button = button("Skills", Rect2(), func(): open_menu("Skills"))
	skills_button.add_theme_font_size_override("font_size", 19)
	layout_items.team_panel = panel(Rect2())
	layout_items.team_panel.add_theme_stylebox_override("panel", style(SlimerotPresentation.SURFACE))
	portraits = HBoxContainer.new()
	portraits.alignment = BoxContainer.ALIGNMENT_CENTER
	portraits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portraits.add_theme_constant_override("separation", 2)
	root.add_child(portraits)
	team_label = text("", Rect2(), 16)
	team_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	super_label = text("", Rect2(), 18, Color("ffdc77"))
	super_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reveal = SlimerotReveal.new()
	root.add_child(reveal)
	breakthrough_banner = panel(Rect2())
	breakthrough_banner.z_index = 40
	breakthrough_banner.add_theme_stylebox_override("panel", style(Color("d2ff86")))
	breakthrough_text = Label.new()
	breakthrough_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breakthrough_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	breakthrough_text.add_theme_font_size_override("font_size", 26)
	breakthrough_text.add_theme_color_override("font_color", SlimerotPresentation.INK)
	breakthrough_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breakthrough_banner.add_child(breakthrough_text)
	breakthrough_banner.hide()
	death_fade = ColorRect.new()
	death_fade.color = Color(0, 0, 0, 0)
	death_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_fade.z_index = 100
	root.add_child(death_fade)
	SkillTreeManager.purchased.connect(on_skill_purchased)
	GameState.changed.connect(refresh)
	GameState.changed.connect(func(): menu_dirty = true)
	SaveManager.save_failed.connect(show_notice)
	SaveManager.offline_summary_ready.connect(show_offline_summary)
	get_viewport().size_changed.connect(apply_layout)
	for entry in [[layout_items.settings, "settings"], [layout_items.inventory, "inventory"], [skills_button, "skills"], [auto_button, "auto"], [roll_button, "rolls"]]:
		entry[0].icon = SlimerotAssets.icon(entry[1])
		entry[0].expand_icon = true
	apply_layout()
	refresh()
	if not SaveManager.last_error.is_empty(): show_notice(SaveManager.last_error)
	if not SaveManager.last_offline_summary.is_empty(): show_offline_summary(SaveManager.last_offline_summary)

func place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

func apply_layout(override_safe: Rect2 = Rect2()) -> void:
	var visible_rect := get_viewport().get_visible_rect()
	safe_rect = visible_rect
	if override_safe.has_area():
		safe_rect = visible_rect.intersection(override_safe)
	elif OS.has_feature("mobile"):
		# Display safe area is in screen pixels; convert through the viewport stretch.
		var native_safe := Rect2(DisplayServer.get_display_safe_area())
		native_safe.position -= Vector2(DisplayServer.window_get_position())
		if native_safe.has_area():
			safe_rect = visible_rect.intersection(get_viewport().get_screen_transform().affine_inverse() * native_safe)
	root.position = safe_rect.position
	root.scale = Vector2.ONE * minf(1.0, safe_rect.size.x / 720.0)
	root.size = safe_rect.size / root.scale
	var w := root.size.x
	var h := root.size.y
	place(layout_items.control_dock, Rect2(16, h - 302, w - 32, 286))
	place(layout_items.health_panel, Rect2(16, 16, 230, 166))
	place(layout_items.wallet_panel, Rect2(256, 16, w - 432, 166))
	place(layout_items.brand, Rect2(32, 28, 198, 22))
	place(layout_items.wallet_heading, Rect2(274, 28, w - 468, 22))
	place(hp_bar, Rect2(32, 57, 198, 10))
	place(hp_label, Rect2(32, 72, 200, 26))
	place(location_label, Rect2(32, 104, 198, 70))
	place(wallet, Rect2(306, 55, w - 498, 110))
	for index in 3:
		place(layout_items[["coins_icon", "rolls_icon", "luck_icon"][index]], Rect2(274, 60 + index * 30, 22, 22))
	place(layout_items.settings, Rect2(w - 166, 16, 150, 62))
	place(map_button, Rect2(w - 166, 86, 150, 62))
	place(layout_items.potions, Rect2(w - 166, 156, 150, 62))
	place(tutorial, Rect2(24, 200, w - 204, 58))
	place(boss_label, Rect2(32, 266, w - 64, 104))
	place(notice, Rect2(42, h - 460, w - 84, 82))
	place(interaction_label, Rect2(42, h - 424, w - 84, 64))
	place(interact_button, Rect2(w * 0.5 - 105, h - 354, 210, 62))
	place(joystick, Rect2(30, h - 276, 224, 224))
	place(roll_button, Rect2(w - 286, h - 208, 250, 102))
	place(auto_button, Rect2(w - 286, h - 278, 250, 62))
	place(layout_items.inventory, Rect2(266, h - 278, w - 564, 62))
	place(skills_button, Rect2(266, h - 208, w - 564, 62))
	place(layout_items.team_panel, Rect2(254, h - 138, w - 546, 116))
	place(portraits, Rect2(260, h - 132, w - 558, 46))
	place(team_label, Rect2(260, h - 77, w - 558, 55))
	place(super_label, Rect2(w - 286, h - 94, 250, 65))
	place(breakthrough_banner, Rect2(20, 370, w - 40, 156))
	place(death_fade, Rect2(Vector2.ZERO, root.size))
	place(reveal, Rect2(Vector2.ZERO, root.size))
	if is_instance_valid(menu): place(menu, Rect2(20, 232, w - 40, h - 526))

func style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(20)
	box.border_color = color.lightened(0.10)
	box.set_border_width_all(1)
	box.shadow_color = Color(0.015, 0.035, 0.07, 0.24)
	box.shadow_size = 5
	box.shadow_offset = Vector2(0, 4)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func meter_style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(5)
	return box

func selected_style() -> StyleBoxFlat:
	var box := style(Color("304639"))
	box.border_color = SlimerotPresentation.MINT
	return box

func slider_style(color: Color) -> StyleBoxFlat:
	var box := meter_style(color)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box

func slider_knob(color: Color) -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.width = 26
	texture.height = 26
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = Gradient.new()
	texture.gradient.offsets = PackedFloat32Array([0.0, 0.72, 0.84, 0.96, 1.0])
	texture.gradient.colors = PackedColorArray([color.lightened(0.12), color, color.darkened(0.18), color.darkened(0.18), Color(color, 0.0)])
	return texture

func create_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 22
	theme.set_stylebox("normal", "Button", style(SlimerotPresentation.TEAL))
	theme.set_stylebox("hover", "Button", style(Color("30465e")))
	theme.set_stylebox("pressed", "Button", style(Color("344d42")))
	theme.set_stylebox("disabled", "Button", style(Color("1b293a")))
	theme.set_stylebox("panel", "PanelContainer", style(SlimerotPresentation.SURFACE))
	theme.set_color("font_color", "Label", SlimerotPresentation.CREAM)
	theme.set_color("font_color", "Button", SlimerotPresentation.CREAM)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", SlimerotPresentation.MINT)
	theme.set_color("font_disabled_color", "Button", Color("7e91a3"))
	theme.set_constant("icon_max_width", "Button", 25)
	theme.set_constant("h_separation", "Button", 9)
	theme.set_stylebox("background", "ProgressBar", meter_style(SlimerotPresentation.INK))
	theme.set_stylebox("fill", "ProgressBar", meter_style(SlimerotPresentation.MINT))
	theme.set_stylebox("slider", "HSlider", slider_style(SlimerotPresentation.BORDER))
	theme.set_stylebox("grabber_area", "HSlider", slider_style(Color("668b60")))
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_style(SlimerotPresentation.MINT))
	theme.set_icon("grabber", "HSlider", slider_knob(SlimerotPresentation.CREAM))
	theme.set_icon("grabber_highlight", "HSlider", slider_knob(SlimerotPresentation.MINT))
	theme.set_stylebox("scroll", "VScrollBar", meter_style(SlimerotPresentation.INK))
	var scrollbar := meter_style(SlimerotPresentation.BORDER)
	scrollbar.content_margin_left = 4
	scrollbar.content_margin_right = 4
	theme.set_stylebox("grabber", "VScrollBar", scrollbar)
	return theme

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
	result.focus_mode = Control.FOCUS_NONE
	result.pressed.connect(action)
	root.add_child(result)
	return result

func refresh() -> void:
	var stats := SkillTreeManager.derived_stats()
	if stats.breakthrough_count == 0:
		breakthrough_seconds = 0.0
		breakthrough_banner.hide()
	wallet.text = "Coins  %s\nRolls   %s\nLuck    ×%s" % [compact(GameState.coins), compact(GameState.rolls_balance), compact(RollManager.effective_luck())]
	hp_bar.max_value = stats.max_hp
	hp_bar.value = GameState.player_hp
	hp_label.text = "HP  %d / %d" % [GameState.player_hp, stats.max_hp]
	team_label.text = "Team DPS %s\n%d / %d equipped" % [compact(InventoryManager.team_dps()), InventoryManager.equipped_copy_ids.size(), stats.equipped_slots]
	var identities: Array = []
	for copy_id in InventoryManager.equipped_copy_ids:
		var identity := InventoryManager.pair_for_copy(copy_id)
		identities.append([copy_id, identity.get("slime_id", ""), identity.get("variant", "")])
	var signature := str(identities)
	if signature != equipped_signature:
		equipped_signature = signature
		for child in portraits.get_children():
			portraits.remove_child(child)
			child.queue_free()
		for copy_id in InventoryManager.equipped_copy_ids:
			var pair := InventoryManager.pair_for_copy(copy_id)
			var portrait := SlimerotPortrait.new()
			portrait.slime_id = pair.slime_id
			portrait.variant = pair.variant
			portraits.add_child(portrait)
			portrait.custom_minimum_size = Vector2(30, 42)
	var zone := SlimerotCampaign.zone(GameState.current_zone)
	location_label.text = zone.name + ("\nSafe hub" if zone.id == 0 else "\nLv. %d–%d" % [zone.enemy_level_range.x, zone.enemy_level_range.y])
	if GameState.lifetime_rolls == 0:
		tutorial.text = "Welcome to Slimerot!\nMove + ROLL to meet your first slime."
	elif GameState.current_zone == 0:
		tutorial.text = "Explore, roll, grow your blob squad!\nApproach the green Backyard exit."
	else:
		tutorial.text = SlimerotCampaign.wall_hint(zone.id)
		if zone.id == 1: tutorial.text = "Keep moving and rolling.\nBedroom Shrine unlocks Skills · 25 Coins."
	skills_button.visible = GameState.structure_unlocked_flags.get("skill_tree_shrine", false)
	map_button.visible = GameState.boss_defeated_flags.get("zone_4", false) or GameState.structure_unlocked_flags.get("fast_travel_pillar", false)
	super_label.visible = stats.super_roll
	super_label.text = "SUPER ROLL ×5\n" + ("Next roll!" if RollManager.rolls_until_super() == 1 else "In %d rolls" % RollManager.rolls_until_super())
	auto_button.disabled = not stats.auto_roll or GameState.is_paused()
	auto_button.text = "Auto · Locked" if not stats.auto_roll else ("Auto · ON" if GameState.settings.auto_roll_state else "Auto · OFF")

func compact(value: float) -> String:
	for row in [[1000000000.0, "B"], [1000000.0, "M"], [1000.0, "K"]]:
		if value >= row[0]: return "%.2f%s" % [value / row[0], row[1]]
	return str(int(value)) if value == floor(value) else "%.2f" % value

func _process(delta: float) -> void:
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
			if menu_title not in ["Stats", "Settings", "Potions"]:
				refresh_menu_body()
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
		for control in [roll_button, auto_button, interact_button, layout_items.settings, layout_items.potions, layout_items.inventory, skills_button, map_button]:
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
	if not is_instance_valid(menu_scroll): return false
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
	var children := node.get_children()
	children.reverse()
	for child in children:
		if child is Control and child.is_visible_in_tree():
			var nested := touch_target(child, at)
			if nested != null: return nested
			if (child is BaseButton or child is Slider) and child.get_global_rect().has_point(at): return child
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

func remember_modal_scroll() -> void:
	if not modal_stack.is_empty() and is_instance_valid(menu_scroll):
		modal_stack[-1].scroll = menu_scroll.scroll_vertical

func open_modal(id: String) -> void:
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
	control.custom_minimum_size.y = SlimerotPresentation.TOUCH_TARGET
	control.focus_mode = Control.FOCUS_NONE
	control.disabled = disabled
	control.pressed.connect(action)
	menu_body.add_child(control)
	return control

func open_menu(title: String) -> void:
	if offline_input_locked(): return
	if title == "Skills" and not GameState.structure_unlocked_flags.get("skill_tree_shrine", false):
		show_notice("Repair the Skill Tree Shrine in the Bedroom Hub.")
		return
	if menu_title == title and is_instance_valid(menu):
		refresh_menu_body()
		return
	if title.begins_with("Copies:") or title == "Sell Duplicates":
		if modal_stack.is_empty() or modal_stack[0].id != "Inventory":
			modal_stack.assign([{"id": "Inventory", "scroll": 0}])
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
	menu = panel(Rect2(20, 232, root.size.x - 40, root.size.y - 526))
	var menu_style := style(SlimerotPresentation.INK)
	menu_style.border_color = SlimerotPresentation.BORDER
	menu_style.content_margin_left = 20
	menu_style.content_margin_right = 20
	menu_style.content_margin_top = 18
	menu_style.content_margin_bottom = 18
	menu.add_theme_stylebox_override("panel", menu_style)
	menu.z_index = 20
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	menu.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var heading := Label.new()
	heading.text = "Owned copies" if title.begins_with("Copies:") else title
	heading.add_theme_font_size_override("font_size", 30)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var brand := Label.new()
	brand.text = "SLIMEROT"
	brand.add_theme_font_size_override("font_size", 13)
	brand.add_theme_color_override("font_color", SlimerotPresentation.MINT)
	header.add_child(brand)
	var navigation := GridContainer.new()
	navigation.columns = 4
	navigation.add_theme_constant_override("h_separation", 8)
	navigation.add_theme_constant_override("v_separation", 8)
	layout.add_child(navigation)
	for entry in ["Inventory", "Team", "Collection", "Skills", "Roll Settings", "Stats", "Settings", "Close"]:
		var tab := Button.new()
		tab.text = entry
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 17)
		tab.custom_minimum_size.y = 62
		var icon_id: String = {"Inventory": "inventory", "Team": "team", "Collection": "collection", "Skills": "skills", "Roll Settings": "rolls", "Settings": "settings"}.get(entry, "")
		if not icon_id.is_empty():
			tab.icon = SlimerotAssets.icon(icon_id)
			tab.expand_icon = true
			tab.add_theme_constant_override("icon_max_width", 22)
		tab.focus_mode = Control.FOCUS_NONE
		tab.disabled = (entry == "Skills" and not GameState.structure_unlocked_flags.get("skill_tree_shrine", false)) or entry == title
		if entry == title:
			tab.add_theme_stylebox_override("disabled", selected_style())
			tab.add_theme_color_override("font_disabled_color", SlimerotPresentation.MINT)
		if offline_input_locked(): tab.disabled = true
		if entry == "Close":
			tab.add_theme_color_override("font_color", SlimerotPresentation.MUTED)
		tab.pressed.connect(close_top_modal if entry == "Close" else func(): open_menu(entry))
		navigation.add_child(tab)
	menu_scroll = ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_scroll.scroll_deadzone = int(SlimerotPresentation.SCROLL_DEADZONE)
	layout.add_child(menu_scroll)
	menu_body = VBoxContainer.new()
	menu_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_body.add_theme_constant_override("separation", 14)
	menu_scroll.add_child(menu_body)
	build_menu_content(title)
	if previous_scroll > 0: menu_scroll.set_deferred("scroll_vertical", previous_scroll)
	menu_dirty = false

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
	menus.build(self, title)
	if title != "AFK Summary": return
	var seconds := maxi(0, int(offline_summary.get("seconds_away", 0)))
	menu_label("Welcome back!", 28)
	menu_label("Time away: %dh %02dm %02ds\nOffline rolls: %s\nRolls earned: +%s" % [seconds / 3600, (seconds / 60) % 60, seconds % 60, compact(offline_summary.get("rolls", 0)), compact(offline_summary.get("rolls_earned", 0))])
	var discoveries: Array = offline_summary.get("new_discoveries", [])
	menu_label("New discoveries: %d" % discoveries.size())
	var best: Dictionary = offline_summary.get("best_drop", {})
	if not best.is_empty():
		var slime := SlimeDatabase.get_slime(best.get("slime_id", ""))
		if slime != null: menu_label("Best drop: %s %s\n%s" % [str(best.get("variant", "normal")).capitalize(), slime.display_name, SlimeDatabase.threshold_label(slime.id)])
	if offline_summary.get("pending", false): menu_label("Catching up remaining rolls…", 19)
	menu_button("Continue exploring", close_top_modal, offline_input_locked())
