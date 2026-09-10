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
var notice: Label
var notice_seconds := 0.0
var menu: PanelContainer
var menu_body: VBoxContainer
var menu_title := ""
var reveal: Label
var reveal_seconds := 0.0

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.theme = create_theme()
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
	team_label = text("", Rect2(345, 166, 330, 54), 19, Color("bbd3c5"))
	panel(Rect2(20, 245, 680, 145))
	location_label = text("", Rect2(30, 250, 660, 42), 26)
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial = text("", Rect2(52, 298, 616, 100), 20, Color("e7dbbb"))
	tutorial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reveal = text("", Rect2(50, 410, 620, 114), 23, Color("d5f794"))
	reveal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reveal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice = text("", Rect2(50, 830, 620, 80), 21, Color("fff0bc"))
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interact_button = button("", Rect2(80, 920, 560, 72), func(): interact_requested.emit())
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
	auto_button = button("Auto Roll · Locked", Rect2(414, 1187, 270, 58), toggle_auto)
	auto_button.add_theme_font_size_override("font_size", 20)
	button("Inventory", Rect2(277, 1006, 189, 55), func(): open_menu("Inventory"))
	skills_button = button("Skills · Locked", Rect2(478, 1006, 206, 55), func(): open_menu("Skills"))
	skills_button.add_theme_font_size_override("font_size", 19)
	GameState.changed.connect(refresh)
	RollManager.revealed.connect(on_reveal)
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
	wallet.text = "Coins  %d      Rolls  %d      Lifetime  %d" % [GameState.coins, GameState.rolls_balance, GameState.lifetime_rolls]
	hp_bar.max_value = stats.max_hp
	hp_bar.value = GameState.player_hp
	hp_label.text = "HP  %d / %d" % [GameState.player_hp, stats.max_hp]
	team_label.text = "Team DPS  %.1f   ·   Luck ×%.2f\nEquipped %d / %d  ·  Max 5" % [InventoryManager.team_dps(), stats.luck, InventoryManager.equipped_copy_ids.size(), stats.equipped_slots]
	location_label.text = "Bedroom Hub" if GameState.current_zone == 0 else "01  /  Backyard · %d kills" % int(GameState.zone_kill_counts.get("1", 0))
	if GameState.lifetime_rolls == 0:
		tutorial.text = "Drag the joystick to move, then tap ROLL.\nYour first slime is waiting for you."
	elif GameState.current_zone == 0:
		tutorial.text = "Your slime is equipped. Walk to the green exit\nand tap Enter Backyard.  [E on desktop]"
	else:
		tutorial.text = "Stay within 180 px of a Lagling to attack automatically.\nKeep moving and rolling. Repair the Shrine for 25 Coins."
		if GameState.structure_unlocked_flags.get("skill_tree_shrine", false):
			tutorial.text = "Keep moving and rolling. Buy permanent upgrades in Skills.\nRepair the Sell Terminal for 75 Coins."
	skills_button.disabled = not GameState.structure_unlocked_flags.get("skill_tree_shrine", false)
	skills_button.text = "Skills" if not skills_button.disabled else "Skills · Locked"
	auto_button.disabled = not stats.auto_roll
	auto_button.text = "Auto Roll · Locked" if not stats.auto_roll else ("Auto Roll · ON" if GameState.settings.auto_roll_state else "Auto Roll · OFF")

func _process(delta: float) -> void:
	roll_button.text = "ROLL  ·  %.1fs" % RollManager.cooldown_remaining if RollManager.cooldown_remaining > 0.0 else "ROLL"
	roll_button.disabled = RollManager.cooldown_remaining > 0.0
	if notice_seconds > 0.0:
		notice_seconds -= delta
		if notice_seconds <= 0.0:
			notice.text = ""
	if reveal_seconds > 0.0:
		reveal_seconds -= delta
		if reveal_seconds <= 0.0:
			reveal.text = ""

func on_reveal(slime_id: String, _variant: String, first: bool) -> void:
	reveal.text = ("FIRST SLIME · AUTO-EQUIPPED\n" if first else "SLIME COLLECTED\n") + SlimeDatabase.get_slime(slime_id).display_name + "\n+1 Rolls  ·  +1 Lifetime Roll"
	reveal_seconds = 2.2

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

func close_menu() -> void:
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

func menu_button(value: String, action: Callable, disabled: bool = false) -> void:
	var control := Button.new()
	control.text = value
	control.custom_minimum_size.y = 62
	control.disabled = disabled
	control.pressed.connect(action)
	menu_body.add_child(control)

func open_menu(title: String) -> void:
	close_menu()
	menu_title = title
	menu = panel(Rect2(40, 262, 640, 638))
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(scroll)
	menu_body = VBoxContainer.new()
	menu_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_body.add_theme_constant_override("separation", 13)
	scroll.add_child(menu_body)
	menu_label("Slimerot / " + title, 29)
	menu_button("Close  ×", close_menu)
	match title:
		"Inventory":
			menu_label("Team %d / %d · Collection %d" % [InventoryManager.equipped_copy_ids.size(), SkillTreeManager.derived_stats().equipped_slots, InventoryManager.inventory.size()])
			if InventoryManager.inventory.is_empty():
				menu_label("Tap ROLL to meet your first slime.")
			for key in InventoryManager.inventory:
				var pair: Dictionary = InventoryManager.inventory[key]
				menu_label("%s\n%s · owned %d · damage %.0f" % [SlimeDatabase.get_slime(pair.slime_id).display_name, pair.variant.capitalize(), pair.quantity, SlimeDatabase.get_slime(pair.slime_id).base_damage])
				menu_button("★ Favorited" if pair.favorite else "☆ Favorite", func(): InventoryManager.toggle_favorite(key); open_menu("Inventory"))
				for copy_id in pair.copy_ids.slice(0, 8):
					var equipped: bool = copy_id in InventoryManager.equipped_copy_ids
					menu_button(("Unequip " if equipped else "Equip ") + copy_id.trim_prefix("slimerot_"), func():
						if equipped: InventoryManager.unequip(copy_id)
						else: InventoryManager.equip(copy_id)
						open_menu("Inventory"), not equipped and InventoryManager.equipped_copy_ids.size() >= SkillTreeManager.derived_stats().equipped_slots)
			if GameState.structure_unlocked_flags.get("sell_terminal", false):
				menu_button("Sell Duplicates →", func(): open_menu("Sell Duplicates"))
			else:
				menu_label("Repair the Sell Terminal to sell duplicates.", 18)
		"Sell Duplicates":
			menu_label("Keeps every equipped and favorited copy, and at least one copy of each slime + variant.")
			menu_button("Sell unprotected duplicates", func():
				var earned := InventoryManager.sell_duplicates()
				open_menu("Sell Duplicates")
				menu_label("Sold for %d Coins." % earned))
			menu_button("← Inventory", func(): open_menu("Inventory"))
		"Skills":
			menu_label("Roll tree · %d Rolls available" % GameState.rolls_balance)
			for id in SkillTreeManager.nodes:
				var data: SlimerotData.SkillNodeData = SkillTreeManager.nodes[id]
				var owned: bool = id in GameState.purchased_skill_node_ids
				menu_button(id.replace("_", " ").capitalize() + (" · Owned" if owned else " · %d Rolls" % data.cost), func(): SkillTreeManager.purchase(id); open_menu("Skills"), owned or GameState.rolls_balance < data.cost or skills_button.disabled)
			menu_label("Permanent upgrades. Coin-tree and checkpoint nodes arrive with their full balance tables.", 18)
		"Settings":
			menu_label("Fully offline · saved every 10 seconds\nActive play: %.0f seconds" % GameState.active_play_seconds)
			for key in ["screen_shake", "vibration"]:
				menu_button(key.replace("_", " ").capitalize() + (" · ON" if GameState.settings[key] else " · OFF"), func(): GameState.settings[key] = not GameState.settings[key]; GameState.critical_change.emit("settings"); open_menu("Settings"))
			for key in ["master_audio", "music_audio", "sfx_audio"]:
				menu_label(key.replace("_", " ").capitalize(), 18)
				var slider := HSlider.new()
				slider.min_value = 0.0
				slider.max_value = 1.0
				slider.step = 0.05
				slider.value = GameState.settings[key]
				slider.custom_minimum_size.y = 42
				slider.value_changed.connect(func(value): GameState.settings[key] = value; GameState.critical_change.emit("settings"))
				menu_body.add_child(slider)
			menu_label("Placeholder art · silent audio\nDesktop: WASD/arrows, Space to roll, E to interact.", 18)
