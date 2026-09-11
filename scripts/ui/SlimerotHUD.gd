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

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.theme = create_theme()
	death_fade = ColorRect.new()
	death_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_fade.color = Color(0,0,0,0)
	death_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_fade.z_index = 100
	root.add_child(death_fade)
	panel(Rect2(20, 20, 680, 214))
	text("Slimerot", Rect2(42, 31, 380, 51), 40, Color("b6ed78"))
	text("OFFLINE  /  FIRST STEPS", Rect2(42, 83, 440, 24), 16, Color("95b4b3"))
	button("Settings", Rect2(530, 38, 146, 56), func(): open_menu("Settings"))
	wallet = text("", Rect2(42, 116, 632, 38), 26)
	hp_bar = ProgressBar.new()
	hp_bar.position = Vector2(42, 170)
	hp_bar.size = Vector2(276, 16)
	hp_bar.show_percentage = false
	hp_bar.add_theme_stylebox_override("background", style(Color("29464e")))
	hp_bar.add_theme_stylebox_override("fill", style(Color("b6ed78")))
	root.add_child(hp_bar)
	hp_label = text("", Rect2(42, 192, 278, 27), 17, Color("bbd3c5"))
	team_label = text("", Rect2(269, 1178, 164, 55), 17, Color("bbd3c5"))
	team_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portraits = HBoxContainer.new()
	portraits.position = Vector2(266, 1117)
	portraits.size = Vector2(164, 52)
	portraits.add_theme_constant_override("separation", 3)
	root.add_child(portraits)
	panel(Rect2(20, 245, 680, 145))
	location_label = text("", Rect2(30, 250, 660, 42), 26)
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial = text("", Rect2(52, 298, 616, 100), 20, Color("e7dbbb"))
	tutorial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reveal = SlimerotReveal.new()
	root.add_child(reveal)
	notice = text("", Rect2(50, 830, 620, 80), 21, Color("fff0bc"))
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interact_button = button("", Rect2(80, 920, 560, 72), func(): interact_requested.emit())
	interact_button.add_theme_font_size_override("font_size",18)
	interact_button.hide()
	joystick = SlimerotJoystick.new()
	joystick.position = Vector2(30, 1004)
	joystick.size = Vector2(224, 224)
	root.add_child(joystick)
	text("MOVE  /  WASD", Rect2(49, 1211, 217, 28), 16, Color("95b4b3"))
	roll_button = button("ROLL", Rect2(434, 1072, 250, 102), func(): RollManager.request_roll())
	roll_button.add_theme_stylebox_override("normal", style(Color("b6ed78")))
	roll_button.add_theme_color_override("font_color", Color("1a352d"))
	roll_button.add_theme_font_size_override("font_size", 32)
	auto_button = button("Auto Roll · Locked", Rect2(434, 1006, 250, 58), toggle_auto)
	auto_button.add_theme_font_size_override("font_size", 20)
	button("Inventory", Rect2(269, 1006, 153, 58), func(): open_menu("Inventory"))
	skills_button = button("Skills", Rect2(269, 1068, 153, 44), func(): open_menu("Skills"))
	skills_button.add_theme_font_size_override("font_size", 19)
	super_label = text("", Rect2(434, 1187, 250, 58), 18, Color("ffdc77"))
	super_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breakthrough_banner = panel(Rect2(20, 390, 680, 156))
	breakthrough_banner.z_index = 40
	breakthrough_banner.add_theme_stylebox_override("panel", style(Color("264b45")))
	breakthrough_text = Label.new()
	breakthrough_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breakthrough_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	breakthrough_text.add_theme_font_size_override("font_size", 25)
	breakthrough_text.add_theme_color_override("font_color", Color("d5ff8f"))
	breakthrough_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breakthrough_banner.add_child(breakthrough_text)
	breakthrough_banner.hide()
	SkillTreeManager.purchased.connect(on_skill_purchased)
	GameState.changed.connect(refresh)
	GameState.changed.connect(func(): menu_dirty = true)
	SaveManager.save_failed.connect(show_notice)
	refresh()
	if not SaveManager.last_error.is_empty():
		show_notice(SaveManager.last_error)

func style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(14)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

func create_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 23
	theme.set_stylebox("normal", "Button", style(Color("29464e")))
	theme.set_stylebox("hover", "Button", style(Color("3c6267")))
	theme.set_stylebox("pressed", "Button", style(Color("527d78")))
	theme.set_stylebox("disabled", "Button", style(Color("23333b")))
	theme.set_stylebox("panel", "PanelContainer", style(Color(0.05, 0.10, 0.14, 0.97)))
	theme.set_color("font_color", "Label", Color("e5eddf"))
	theme.set_color("font_color", "Button", Color("e5eddf"))
	return theme

func panel(rect: Rect2) -> PanelContainer:
	var result := PanelContainer.new()
	result.position = rect.position
	result.size = rect.size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(result)
	return result

func text(value: String, rect: Rect2, font_size: int = 23, color: Color = Color("e5eddf")) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	return label

func button(value: String, rect: Rect2, action: Callable) -> Button:
	var result := Button.new()
	result.text = value
	result.position = rect.position
	result.size = rect.size
	result.focus_mode = Control.FOCUS_NONE
	result.pressed.connect(action)
	root.add_child(result)
	return result

func refresh() -> void:
	var stats := SkillTreeManager.derived_stats()
	wallet.text = "Coins %s   Rolls %s   Luck ×%s" % [SlimeDatabase.format_number(GameState.coins), SlimeDatabase.format_number(GameState.rolls_balance), "%.2f" % RollManager.effective_luck()]
	wallet.add_theme_font_size_override("font_size", 22 if wallet.text.length() > 44 else 26)
	hp_bar.max_value = stats.max_hp
	hp_bar.value = GameState.player_hp
	hp_label.text = "HP  %d / %d" % [GameState.player_hp, stats.max_hp]
	team_label.text = "Team DPS %.1f\n%d / %d equipped" % [InventoryManager.team_dps(), InventoryManager.equipped_copy_ids.size(), stats.equipped_slots]
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
	location_label.add_theme_font_size_override("font_size",22)
	location_label.text = zone.name if zone.id == 0 else "%s · Lv. %d–%d · %d kills" % [zone.name,zone.enemy_level_range.x,zone.enemy_level_range.y,int(GameState.zone_kill_counts.get(str(zone.id),0))]
	if GameState.lifetime_rolls == 0:
		tutorial.text = "Drag the joystick to move, then tap ROLL.\nYour first slime is waiting for you."
	elif GameState.current_zone == 0:
		tutorial.text = "Your slime is equipped. Walk to the green exit\nand tap Enter Backyard.  [E on desktop]"
	else:
		tutorial.text = SlimerotCampaign.wall_hint(zone.id)
		if zone.id == 1 and not GameState.structure_unlocked_flags.get("skill_tree_shrine",false): tutorial.text = "Keep moving and rolling.\nRepair the Skill Tree Shrine for 25 Coins."
		if zone.id == 1 and GameState.structure_unlocked_flags.get("skill_tree_shrine", false) and not GameState.structure_unlocked_flags.get("sell_terminal",false):
			tutorial.text = "Keep moving and rolling. Buy permanent upgrades in Skills.\nRepair the Sell Terminal for 75 Coins."
	skills_button.disabled = false
	skills_button.text = "Skills"
	super_label.visible = stats.super_roll
	super_label.text = "SUPER ROLL ×5\n" + ("Next roll!" if RollManager.rolls_until_super() == 1 else "In %d rolls" % RollManager.rolls_until_super())
	auto_button.disabled = not stats.auto_roll
	auto_button.text = "Auto Roll · Locked" if not stats.auto_roll else ("Auto Roll · ON" if GameState.settings.auto_roll_state else "Auto Roll · OFF")

func _process(delta: float) -> void:
	death_fade.color.a = clampf(1.0 - CombatManager.death_remaining / SlimerotBalance.DEATH_FADE_SECONDS, 0, 1) if GameState.player_dead else 0.0
	if breakthrough_seconds > 0.0 and not GameState.is_paused():
		breakthrough_seconds = maxf(0.0, breakthrough_seconds - delta)
		if breakthrough_seconds == 0.0: breakthrough_banner.hide()
	roll_button.text = "ROLL  ·  %.1fs" % RollManager.cooldown_remaining if RollManager.cooldown_remaining > 0.0 else "ROLL"
	roll_button.disabled = RollManager.cooldown_remaining > 0.0
	if notice_seconds > 0.0:
		notice_seconds -= delta
		if notice_seconds <= 0.0:
			notice.text = ""
	if menu_dirty and is_instance_valid(menu) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		menu_refresh_seconds += delta
		if menu_refresh_seconds >= 0.4:
			menu_refresh_seconds = 0.0
			var scroll_value := menu_scroll.scroll_vertical
			open_menu(menu_title)
			menu_scroll.set_deferred("scroll_vertical", scroll_value)
			menu_dirty = false
	menus.tick(delta)

func on_skill_purchased(id: String, previous_luck: float, new_luck: float) -> void:
	if SkillTreeManager.nodes[id].effect_type != "checkpoint_luck": return
	breakthrough_text.text = "%s\nLuck ×%.2f → ×%.2f\nTOTAL LUCK ×20" % [SkillTreeManager.nodes[id].display_name, previous_luck, new_luck]
	breakthrough_seconds = 3.0
	breakthrough_banner.show()


func set_interaction(prompt: String) -> void:
	interact_button.visible = not prompt.is_empty() and not is_instance_valid(menu)
	interact_button.text = prompt

func show_notice(message: String) -> void:
	notice.text = message
	notice_seconds = 5.0

func toggle_auto() -> void:
	if not SkillTreeManager.derived_stats().auto_roll:
		return
	GameState.settings.auto_roll_state = not GameState.settings.auto_roll_state
	GameState.changed.emit()
	GameState.critical_change.emit("settings")

func _input(event: InputEvent) -> void:
	# Native mouse emulation only covers the primary touch. Handle ROLL explicitly
	# so a second finger can roll while the joystick owns the first finger.
	if event is InputEventScreenTouch and event.pressed:
		if roll_button.get_global_rect().has_point(event.position):
			RollManager.request_roll()
			get_viewport().set_input_as_handled()
		elif auto_button.get_global_rect().has_point(event.position):
			toggle_auto()
			get_viewport().set_input_as_handled()

func close_menu() -> void:
	GameState.menu_paused = false
	menus.cancel_hold()
	if is_instance_valid(menu):
		root.remove_child(menu)
		menu.queue_free()
		menu = null
	menu_title = ""

func menu_label(value: String, font_size: int = 22) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	menu_body.add_child(label)

func menu_button(value: String, action: Callable, disabled: bool = false) -> Button:
	var control := Button.new()
	control.text = value
	control.custom_minimum_size.y = 62
	control.disabled = disabled
	control.pressed.connect(action)
	menu_body.add_child(control)
	return control

func open_menu(title: String) -> void:
	close_menu()
	menu_title = title
	GameState.menu_paused = title == "Settings"
	menu = panel(Rect2(20, 245, 680, 735))
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	menu.add_child(layout)
	var navigation := GridContainer.new()
	navigation.columns = 4
	layout.add_child(navigation)
	for entry in ["Inventory", "Team", "Collection", "Skills", "Roll Settings", "Stats", "Settings", "Close"]:
		var tab := Button.new()
		tab.text = entry
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 18)
		tab.custom_minimum_size.y = 48
		tab.pressed.connect(close_menu if entry == "Close" else func(): open_menu(entry))
		navigation.add_child(tab)
	menu_scroll = ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(menu_scroll)
	menu_body = VBoxContainer.new()
	menu_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_body.add_theme_constant_override("separation", 12)
	menu_scroll.add_child(menu_body)
	menu_label("Slimerot / " + (title if not title.begins_with("Copies:") else "Owned copies"), 28)
	menus.build(self, title)
	menu_dirty = false
