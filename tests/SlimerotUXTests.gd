extends Node

# Slimerot Prompt 7 interaction regression tests. Pointer checks use real viewport input.
var suite: Node
var world: Node
var hud: SlimerotHUD

func check(condition: bool, description: String) -> void:
	suite.check(condition, "UX · " + description)

func fresh() -> void:
	SaveManager.enabled = false
	hud.close_menu()
	InventoryManager.reset()
	RollManager.reset()
	GameState.reset()
	GameState.suspended = false
	GameState.menu_paused = false
	WorldManager.travel(0)
	hud.joystick.reset()
	hud.active_touches.clear()
	hud.apply_layout()
	hud.refresh()

func settled() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	get_viewport().push_input(event, true)

func drag(index: int, previous: Vector2, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = position - previous
	get_viewport().push_input(event, true)

func tap(control: Control, index: int = 6) -> void:
	var at := control.get_global_rect().get_center()
	touch(index, at, true)
	await get_tree().process_frame
	touch(index, at, false)
	await settled()

func descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(descendants(child))
	return result

func find_button(prefix: String) -> Button:
	if not is_instance_valid(hud.menu): return null
	for child in descendants(hud.menu):
		if child is Button and child.text.begins_with(prefix): return child
	return null

func menu_text() -> String:
	var result := ""
	for child in descendants(hud.menu):
		if child is Label or child is Button: result += child.text + "\n"
	return result

func run(owner_world: Node, owner_suite: Node) -> void:
	world = owner_world
	hud = world.hud
	suite = owner_suite
	fresh()
	await test_layouts()
	await test_pointer_controls()
	await test_menus_and_back()
	await test_touch_scroll()
	await test_settings_touch()
	await test_reveals()
	await test_breakthroughs()
	test_optional_audio()
	fresh()

func test_layouts() -> void:
	GameState.purchased_skill_node_ids.assign(["C15"])
	for index in 5: InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	InventoryManager.auto_equip_strongest()
	hud.refresh()
	var window := get_window()
	var original_size := window.size
	for dimensions in [Vector2i(720, 1280), Vector2i(720, 1440), Vector2i(800, 1280)]:
		window.size = dimensions
		await settled()
		hud.apply_layout()
		await settled()
		var viewport_size := get_viewport().get_visible_rect().size
		check(viewport_size.x >= 720 and viewport_size.y >= 1280, "%s expands portrait canvas without cropping" % str(dimensions))
		for inset in [false, true]:
			var safe := Rect2(Vector2.ZERO, viewport_size)
			if inset: safe = Rect2(12, 48, viewport_size.x - 24, viewport_size.y - 72)
			hud.apply_layout(safe)
			await settled()
			var bounds_ok := true
			for control in [hud.hp_bar, hud.hp_label, hud.location_label, hud.wallet, hud.layout_items.settings,
				hud.joystick, hud.auto_button, hud.roll_button, hud.layout_items.inventory, hud.team_label, hud.portraits]:
				bounds_ok = bounds_ok and safe.grow(0.1).encloses(control.get_global_rect())
			check(bounds_ok, "%s %s HUD remains inside safe bounds" % [str(dimensions), "inset" if inset else "edge"])
			check(not hud.joystick.get_global_rect().intersects(hud.roll_button.get_global_rect()) and not hud.auto_button.get_global_rect().intersects(hud.roll_button.get_global_rect()), "%s %s movement and roll touch targets are separate" % [str(dimensions), "inset" if inset else "edge"])
			hud.open_menu("Collection")
			await settled()
			check(safe.grow(0.1).encloses(hud.menu.get_global_rect()) and hud.menu_scroll.size.y >= 160, "%s %s menu keeps usable scrolling height" % [str(dimensions), "inset" if inset else "edge"])
			if inset:
				var at := hud.menu_scroll.get_global_rect().get_center()
				touch(7, at, true)
				drag(7, at, at - Vector2(0, 60))
				touch(7, at - Vector2(0, 60), false)
				check(absf(hud.menu_scroll.scroll_vertical - 60.0 / hud.root.scale.y) < 2, "%s safe-area scrolling follows the finger in local coordinates" % str(dimensions))
			hud.close_menu()
			RollManager.start_reveal(reveal_result("brainrot_singularity", true))
			await settled()
			check(safe.grow(0.1).encloses(hud.reveal.card.get_global_rect()), "%s %s jackpot card stays in safe bounds" % [str(dimensions), "inset" if inset else "edge"])
			RollManager.reset()
		await suite.capture("Slimerot-stage-7-layout-%dx%d" % [dimensions.x, dimensions.y])
	window.size = original_size
	await settled()
	hud.apply_layout()
	await settled()

func test_pointer_controls() -> void:
	fresh()
	await settled()
	var center := hud.joystick.global_position + hud.joystick.center
	touch(4, center + Vector2(90.1, 0), true)
	check(hud.joystick.touch_id == -1, "joystick rejects contact outside exactly 90 px")
	touch(4, center + Vector2(90.1, 0), false)
	touch(4, center + Vector2(90, 0), true)
	check(hud.joystick.touch_id == 4 and is_equal_approx(hud.joystick.direction.x, 1), "joystick captures the 90 px boundary")
	var start: Vector2 = world.player.position
	var before := GameState.lifetime_rolls
	await tap(hud.roll_button, 5)
	for frame in 8: await get_tree().physics_frame
	check(hud.joystick.touch_id == 4 and GameState.lifetime_rolls == before + 1 and world.player.position.x > start.x + 10, "held movement and real second-finger ROLL both work through reveal")
	touch(4, center + Vector2(90, 0), false)
	check(hud.joystick.direction == Vector2.ZERO, "movement finger release resets direction")
	WorldManager.travel(0)
	world.player.position = Vector2(500, 850)
	world._process(0)
	check(not hud.interact_button.visible, "INTERACT is hidden away from structures and entrances")
	world.player.position = Vector2(500, 1190)
	world._process(0)
	check(hud.interact_button.visible, "INTERACT appears at the actual nearby exit")
	await tap(hud.interact_button)
	check(GameState.current_zone == 1, "touching INTERACT performs the nearby gate action")
	fresh()

func test_menus_and_back() -> void:
	await settled()
	check(not hud.skills_button.visible and not hud.map_button.visible and not hud.super_label.visible and hud.auto_button.disabled, "fresh HUD hides gated Skills, Fast Travel, Super Roll and disables Auto")
	hud.open_menu("Skills")
	check(not is_instance_valid(hud.menu), "direct Skills entry is gated until Shrine repair")
	hud.open_menu("Inventory")
	await settled()
	check(find_button("Sell Duplicates").disabled, "Inventory sale is gated by the Sell Terminal")
	await tap(find_button("Team"))
	check(hud.menu_title == "Team", "touch navigation opens the Team menu")
	var slots: Array[Node] = descendants(hud.menu).filter(func(node): return node is SlimerotTeamSlot)
	check(slots.size() == 5 and slots.filter(func(node): return node.locked).size() == 4, "Team shows five portrait slots with four chained at new game")
	hud.open_menu("Roll Settings")
	await settled()
	check(find_button("Auto Roll").disabled and find_button("MAX") == null and find_button("Auto-sell Normal") == null, "Roll Settings gates Auto, Luck Cap and auto-sell separately")
	GameState.structure_unlocked_flags.skill_tree_shrine = true
	GameState.structure_unlocked_flags.sell_terminal = true
	GameState.boss_defeated_flags.zone_4 = true
	GameState.rolls_balance = 20000
	GameState.lifetime_rolls = 20000
	for row in SlimerotRollTree.MAINLINE:
		if row[0] == "R09": break
		SkillTreeManager.purchase(row[0])
	check(SkillTreeManager.purchase("RO2"), "auto-sell prerequisite purchase succeeds after B1")
	hud.refresh()
	check(hud.skills_button.visible and hud.map_button.visible and not hud.auto_button.disabled, "Shrine, Z4 and Auto unlocks update actual HUD controls")
	hud.open_menu("Roll Settings")
	await settled()
	check(not find_button("Auto Roll").disabled and find_button("MAX") != null and find_button("Auto-sell Normal") != null, "unlocked Roll Settings exposes Auto, Luck Cap and auto-sell")
	var cap := find_button("x1")
	hud.menu_scroll.ensure_control_visible(cap)
	await settled()
	await tap(cap)
	check(GameState.settings.luck_cap == 1.0 and RollManager.rolling_luck() == 1.0, "touch Luck Cap selection updates rolling luck")
	hud.menus.skill_tab = "Roll"
	hud.menus.optional_branch = false
	hud.open_menu("Skills")
	await settled()
	var graphs := get_tree().get_nodes_in_group("slimerot_skill_graph")
	check(graphs.size() == 1 and graphs[0].edges.size() >= 17, "Roll Tree renders connected prerequisite paths")
	hud.menus.skill_tab = "Coin"
	hud.open_menu("Skills")
	await settled()
	check(menu_text().contains("Coin Tree") and menu_text().contains("Coins") and get_tree().get_nodes_in_group("slimerot_skill_graph")[0].edges.size() > 0, "Coin Tree exposes its wallet and prerequisite paths")
	hud.open_menu("Stats")
	await settled()
	var text := menu_text()
	var complete := true
	for label in ["Lifetime Rolls", "Coins Earned", "Coins Spent", "Rarest Threshold", "Collection", "Bosses Defeated", "Playtime", "Highest Luck", "Best Team DPS"]:
		complete = complete and text.to_lower().contains(label.to_lower())
	check(complete and not text.contains("Braincells Lost"), "Stats includes every required metric and no Braincells Lost stat")
	InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	hud.open_menu("Copies:" + SlimerotBalance.FIRST_SLIME + ":normal")
	hud.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check(hud.menu_title == "Inventory", "Android back from copies returns to Inventory")
	hud.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not is_instance_valid(hud.menu), "Android back closes a normal menu")
	hud.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check(hud.menu_title == "Settings" and GameState.is_paused() and not RollManager.request_roll(), "Android back from gameplay opens Pause and prevents rolls")
	hud.menus.reset_button.button_down.emit()
	hud.menus.tick(0.5)
	hud.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not hud.menus.holding and not GameState.is_paused(), "Android back cancels an incomplete reset hold and resumes")
	fresh()

func test_touch_scroll() -> void:
	for row in SlimerotRoster.ROWS: InventoryManager.add_copy(row[0])
	hud.open_menu("Collection")
	await settled()
	var start := hud.menu_scroll.get_global_rect().get_center()
	var end := start - Vector2(0, 190)
	touch(7, start, true)
	drag(7, start, end)
	touch(7, end, false)
	await settled()
	check(hud.menu_scroll.scroll_vertical >= 150 and hud.scroll_touch == -1, "real touch drag scrolls the 24-card Collection")
	hud.open_menu("Inventory")
	await settled()
	var favorite := find_button("Favorite")
	hud.menu_scroll.ensure_control_visible(favorite)
	await settled()
	var key: String = InventoryManager.sorted_pairs(hud.menus.sort_order)[0].slime_id + ":normal"
	start = favorite.get_global_rect().get_center()
	end = start - Vector2(0, 160)
	var previous_scroll := hud.menu_scroll.scroll_vertical
	touch(8, start, true)
	drag(8, start, end)
	touch(8, end, false)
	await settled()
	check(hud.menu_scroll.scroll_vertical > previous_scroll and not InventoryManager.inventory[key].favorite, "drag beginning on a Favorite button scrolls without activating it")
	check(not favorite.is_pressed(), "touch scroll releases the original button pressed state")
	hud.menu_scroll.ensure_control_visible(favorite)
	await settled()
	await tap(favorite, 8)
	check(InventoryManager.inventory[key].favorite, "Favorite remains tappable after a canceled scroll press")
	hud.close_menu()

func test_settings_touch() -> void:
	fresh()
	GameState.coins = 37
	hud.open_menu("Settings")
	await settled()
	var slider: HSlider = hud.menus.sliders[0]
	hud.menu_scroll.ensure_control_visible(slider)
	await settled()
	var start := slider.get_global_rect().get_center()
	var end := Vector2(slider.get_global_rect().end.x - 2, start.y)
	touch(9, start, true)
	drag(9, start, end)
	touch(9, end, false)
	check(GameState.settings.master_audio >= 0.95 and not hud.menus.is_interacting(), "touch volume slider changes sound gain and releases its gesture")
	hud.menu_scroll.ensure_control_visible(hud.menus.reset_button)
	await settled()
	start = hud.menus.reset_button.get_global_rect().get_center()
	touch(9, start, true)
	hud.menus.tick(1.0)
	check(hud.menus.holding and hud.menus.hold_seconds >= 1.0, "reset requires a continuously held touch")
	end = start + Vector2(0, 90)
	drag(9, start, end)
	touch(9, end, false)
	hud.menus.tick(3.0)
	check(not hud.menus.holding and GameState.coins == 37, "dragging off reset cancels without deleting progress")
	touch(9, start, true)
	hud.menus.tick(0.5)
	hud.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not hud.menus.holding and GameState.coins == 37, "focus loss cancels a reset hold")
	touch(9, start, false)
	await suite.capture("Slimerot-stage-7-settings")
	hud.close_menu()
	fresh()

func reveal_result(slime_id: String, first_discovery: bool) -> Dictionary:
	return {"slime_id": slime_id, "variant": "normal", "first_roll": false,
		"first_discovery": first_discovery, "threshold": SlimeDatabase.get_slime(slime_id).rarity_threshold}

func test_reveals() -> void:
	fresh()
	RollManager.set_process(false)
	for row in [[99, 0, 0.35], [100, 1, 0.65], [9999, 1, 0.65], [10000, 2, 1.10], [99999, 2, 1.10], [100000, 3, 1.70], [999999, 3, 1.70], [1000000, 4, 2.80]]:
		check(SlimerotPresentation.reveal_tier(row[0]) == row[1] and is_equal_approx(RollManager.reveal_duration(row[0], true), row[2]), "threshold %d uses tier %d for exactly %.2fs" % [row[0], row[1], row[2]])
	var shown_tiers: Dictionary = {}
	for slime in SlimeDatabase.eligible(8):
		var expected_tier := SlimerotPresentation.reveal_tier(slime.rarity_threshold)
		if shown_tiers.has(expected_tier): continue
		shown_tiers[expected_tier] = true
		RollManager.reset()
		RollManager.start_reveal(reveal_result(slime.id, true))
		check(hud.reveal.visible and hud.reveal.tier == expected_tier and hud.reveal.portrait.visible == (expected_tier > 0), "actual tier %d uses toast or visible character card" % expected_tier)
		hud.reveal._process(0.1)
		check(get_viewport().get_visible_rect().encloses(hud.reveal.card.get_global_rect()), "tier %d bounce remains within screen bounds" % expected_tier)
		var duration := RollManager.reveal_remaining
		RollManager._process(duration - 0.01)
		check(not RollManager.active_reveal.is_empty(), "tier %d remains visible before its deadline" % expected_tier)
		RollManager._process(0.02)
		check(RollManager.active_reveal.is_empty() and not hud.reveal.visible, "tier %d ends at its presentation deadline" % expected_tier)
	var rare_id := ""
	for slime in SlimeDatabase.eligible(8):
		if slime.rarity_threshold >= 10000 and slime.rarity_threshold < 1000000:
			rare_id = slime.id
			break
	RollManager.start_reveal(reveal_result(rare_id, false))
	var original_duration := RollManager.reveal_remaining
	RollManager.queue_reveal(reveal_result(SlimerotBalance.FIRST_SLIME, false))
	check(RollManager.active_reveal.slime_id == rare_id and is_equal_approx(RollManager.reveal_remaining, original_duration), "faster new rolls do not replace or shorten an active rare card")
	for index in 100: RollManager.queue_reveal(reveal_result(SlimerotBalance.FIRST_SLIME, false))
	check(RollManager.reveal_queue.size() == 1, "repeated pending feedback coalesces during a longer reveal")
	for slime in SlimeDatabase.eligible(8):
		for variant in ["normal", "shiny", "glitched", "golden"]:
			var pending := reveal_result(slime.id, false)
			pending.variant = variant
			RollManager.queue_reveal(pending)
	check(RollManager.reveal_queue.size() <= SlimerotPresentation.MAX_PENDING_REVEALS and RollManager.active_reveal.slime_id == rare_id, "busy repeated rolls bound feedback memory while preserving the active reveal")
	RollManager.reset()
	GameState.purchased_skill_node_ids.append("RO1")
	check(is_equal_approx(RollManager.reveal_duration(99, false), 0.20) and is_equal_approx(RollManager.reveal_duration(100, false), 0.65), "Skip Common changes only thresholds below 100 to 0.20s")
	var jackpot := reveal_result("brainrot_singularity", true)
	RollManager.start_reveal(jackpot)
	await settled()
	await tap(hud.reveal.card)
	check(not RollManager.active_reveal.is_empty() and not RollManager.skip_reveal(), "first-discovery jackpot rejects touch and direct skips")
	var common := reveal_result(SlimerotBalance.FIRST_SLIME, false)
	RollManager.queue_reveal(common)
	check(RollManager.reveal_queue.size() == 1 and RollManager.active_reveal.slime_id == "brainrot_singularity", "new feedback queues behind an unskippable first jackpot")
	RollManager._process(2.81)
	check(RollManager.active_reveal.slime_id == SlimerotBalance.FIRST_SLIME and RollManager.reveal_queue.is_empty(), "queued result follows the complete first jackpot")
	RollManager.reset()
	jackpot.first_discovery = false
	RollManager.start_reveal(jackpot)
	check(is_equal_approx(RollManager.reveal_remaining, 1.0), "repeat jackpot lasts exactly 1.0s")
	var balances := [GameState.coins, GameState.rolls_balance, GameState.lifetime_rolls]
	await tap(hud.reveal.card)
	check(RollManager.active_reveal.is_empty() and balances == [GameState.coins, GameState.rolls_balance, GameState.lifetime_rolls], "repeat jackpot touch skip closes feedback without changing rewards")
	RollManager.set_process(true)

func test_breakthroughs() -> void:
	fresh()
	GameState.rolls_balance = 20000
	GameState.lifetime_rolls = 20000
	for row in SlimerotRollTree.MAINLINE:
		var previous := RollManager.effective_luck()
		var bought := SkillTreeManager.purchase(row[0])
		if row[4] != "checkpoint_luck": continue
		check(bought and is_equal_approx(RollManager.effective_luck(), previous * 20) and hud.breakthrough_banner.visible and hud.breakthrough_text.text.contains(row[1]), "%s purchase shows its ×20 transformation banner" % row[0])
		hud._process(SlimerotPresentation.BREAKTHROUGH_SECONDS - 0.01)
		check(hud.breakthrough_banner.visible, "%s short celebration remains before deadline" % row[0])
		hud._process(0.02)
		check(not hud.breakthrough_banner.visible and not GameState.is_paused(), "%s celebration ends promptly without pausing gameplay" % row[0])

func test_optional_audio() -> void:
	var sound := get_node_or_null("/root/SlimerotSound")
	check(sound != null, "central replaceable audio service is available")
	check(sound.voices.size() == 8, "sound effects use a bounded eight-voice pool")
	for row in SlimerotRoster.ROWS:
		var texture := SlimerotAssets.slime(row[0])
		check(texture != null and texture.get_size() == Vector2(256, 256) and texture.get_image().detect_alpha() != Image.ALPHA_NONE, "%s has its own transparent 256px sprite" % row[0])
	for zone in range(1, 9):
		for archetype in ["chaser", "shooter", "tank"]:
			check(SlimerotAssets.enemy(zone, archetype) != null, "Z%d %s themed sprite loads" % [zone, archetype])
		check(SlimerotAssets.zone(zone) != null, "Z%d ground texture loads" % zone)
	for zone in [2, 4, 6, 8]: check(SlimerotAssets.boss(zone) != null, "Z%d boss sprite loads" % zone)
	for row in SlimerotEncounters.STRUCTURES: check(SlimerotAssets.structure(row[0]) != null, "%s has a distinct structure sprite" % row[0])
	for id in SlimerotAssets.ICON_IDS: check(SlimerotAssets.icon(id) != null, "%s HUD/menu icon loads" % id)
	for id in SlimerotAssets.AUDIO_IDS: check(SlimerotAssets.audio(id) != null, "%s audio placeholder loads" % id)
	check(SlimerotAssets.optional_texture("res://assets/Slimerot_missing_optional.png") == null and SlimerotAssets.optional_audio("res://assets/Slimerot_missing_optional.ogg") == null, "missing optional art/audio returns safe null fallbacks")
	check(not sound.play_cue("Slimerot_missing_optional"), "missing optional cue never interrupts gameplay")
	var original := GameState.settings.duplicate(true)
	GameState.settings.master_audio = 0.0
	sound.apply_settings()
	check(is_zero_approx(sound.music.volume_linear) and is_zero_approx(sound.voices[0].volume_linear), "master zero mutes music and effects")
	GameState.settings.master_audio = 0.5
	GameState.settings.music_audio = 0.4
	GameState.settings.sfx_audio = 0.6
	sound.apply_settings()
	check(is_equal_approx(sound.music.volume_linear, 0.2) and is_equal_approx(sound.voices[0].volume_linear, 0.3), "music and effect sliders independently multiply master gain")
	sound.set_track("boss")
	check(sound.current_track == "boss" and sound.music.stream != null and sound.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "boss track supports continuous looping")
	GameState.settings = original
	sound.apply_settings()
	sound.set_track("exploration")
