extends Node

var suite: Node
var world: Node
var hud: SlimerotHUD

func check(condition: bool, description: String) -> void:
	suite.check(condition, "Mobile UI · " + description)

func settled() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func fresh() -> void:
	SaveManager.enabled = false
	hud.close_menu()
	GameState.reset()
	InventoryManager.reset()
	RollManager.reset()
	GameState.suspended = false
	GameState.menu_paused = false
	WorldManager.travel(0)
	hud.joystick.reset()
	hud.active_touches.clear()
	hud.refresh()

func touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	get_viewport().push_input(event, true)

func drag(index: int, from: Vector2, to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = to
	event.relative = to - from
	get_viewport().push_input(event, true)

func descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(descendants(child))
	return result

func find_button(value: String) -> Button:
	for node in descendants(hud.menu if is_instance_valid(hud.menu) else hud.root):
		if node is Button and node.text.to_lower().begins_with(value.to_lower()): return node
	return null

func all_text() -> String:
	var result := ""
	for node in descendants(hud.menu):
		if node is Label or node is Button: result += node.text + "\n"
	return result

func tap(control: Control, index: int = 70) -> void:
	if control == null:
		check(false, "expected tappable control exists")
		return
	var at := control.get_global_rect().get_center()
	touch(index, at, true)
	touch(index, at, false)
	await settled()

func run(owner_world: Node, owner_suite: Node) -> void:
	world = owner_world
	hud = world.hud
	suite = owner_suite
	fresh()
	await test_navigation()
	await test_tree_gestures()
	await test_purchase_details()
	await test_layouts()
	await test_refresh_and_input()
	fresh()

func test_navigation() -> void:
	await settled()
	check(hud.layout_items.utility.get_child_count() == 3 and hud.layout_items.team.text == "TEAM", "HUD has only Team / gated Skill Tree / gated Map utility entries")
	check(find_button("Inventory") == null and find_button("Potions") == null and not hud.auto_button.visible, "no duplicate Inventory, standalone Potions or locked Auto clutter")
	check(hud.currency_labels.size() == 3 and hud.hp_label.visible and hud.location_label.visible, "top bar contains HP, zone, three currencies and Settings")
	check(not hud.skills_button.visible and not hud.map_button.visible, "Shrine and Fast Travel gates hide their entries")
	hud.open_menu("Skills")
	check(not is_instance_valid(hud.menu), "direct Skill Tree access still delegates the Shrine gate")
	GameState.boss_defeated_flags.zone_4 = true
	hud.refresh()
	check(not hud.map_button.visible, "Z4 boss alone does not expose unrepaired Fast Travel")
	GameState.structure_unlocked_flags.fast_travel_pillar = true
	GameState.structure_unlocked_flags.skill_tree_shrine = true
	hud.refresh()
	check(hud.skills_button.visible and hud.map_button.visible, "repaired structures expose both utilities")
	InventoryManager.add_copies(SlimerotBalance.FIRST_SLIME, "normal", 100003)
	InventoryManager.add_copy("brr_brr_patapim", 3)
	InventoryManager.auto_equip_strongest()
	await tap(hud.layout_items.team)
	check(hud.menu_title == "Team" and all_text().contains("Team DPS"), "Team is the main slime hub with DPS")
	var stacks := get_tree().get_nodes_in_group("slimerot_inventory_stack")
	check(stacks.size() == 2 and all_text().contains("x" + SlimeDatabase.format_number(100003)), "100,003 copies use one quantity card per unique stack")
	var slots := descendants(hud.menu).filter(func(node): return node is SlimerotTeamSlot)
	check(slots.size() == 5 and slots.filter(func(node): return node.locked).size() == 4, "five equipped slot positions preserve backend slot locks")
	check(find_button("Equip Best") != null and find_button("☆ Favorite") != null, "Team exposes Equip Best and stack protection controls")
	await tap(find_button("COLLECTION"))
	check(hud.menu_title == "Collection" and InventoryManager.collection().size() == 24, "Team Collection tab opens the canonical collection")
	await tap(find_button("ITEMS"))
	check(hud.menu_title == "Potions" and all_text().contains("Lucky Soda"), "Team Items tab contains potions")
	await tap(find_button("TEAM"))
	check(hud.menu_title == "Team" and hud.modal_stack.size() == 1, "hub tabs replace the screen without growing modal stack")
	hud.open_menu("Settings")
	await settled()
	var text := all_text().to_upper()
	check(text.contains("GENERAL") and text.contains("ROLLING") and text.contains("SAVE") and text.contains("SYSTEM"), "Settings consolidates General, Rolling and Save/System")
	check(find_button("Roll Settings") == null and find_button("Inventory") == null, "Settings has no legacy global navigation tabs")
	hud.close_menu()
	WorldManager.travel(0)
	await settled()
	for structure in ["skill_tree_shrine", "sell_terminal"]:
		var captions := descendants(world.zone_root).filter(func(node): return node is Label and node.get_meta("structure_id", "") == structure)
		check(captions.size() == 1 and captions[0].horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and captions[0].anchor_right == 1.0 and captions[0].mouse_filter == Control.MOUSE_FILTER_IGNORE, structure + " uses a centered anchored passive world label")

func test_tree_gestures() -> void:
	hud.menus.skill_tab = "Roll"
	hud.open_menu("Skills")
	await settled()
	var canvas: SlimerotSkillTreeCanvas = hud.menus.skill_canvas
	check(is_instance_valid(canvas) and hud.menu_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and canvas.size.y > 400, "Skill Tree is an independent 2D viewport, not a giant scroll list")
	check(canvas.anchors.has("R03") and canvas.anchors.has("RO5") and canvas.anchors.has("RO8") and canvas.anchors.has("RO9") and canvas.edges.size() >= 26, "main trunk, optional and Super branches expose connected nodes")
	var start := canvas.get_global_rect().get_center()
	var pan_before := canvas.pan_offset
	touch(71, start, true)
	drag(71, start, start + Vector2(84, 44))
	touch(71, start + Vector2(84, 44), false)
	await settled()
	check(canvas.pan_offset.distance_to(pan_before) > 30 and hud.menu_title == "Skills", "one-finger viewport drag pans without purchasing or opening a node")
	touch(77, start, true)
	hud.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not canvas.has_active_gesture() and hud.active_touches.is_empty(), "app focus loss cancels canvas and HUD touch captures")
	var resumed_zoom := canvas.zoom_level
	touch(78, start, true)
	drag(78, start, start + Vector2(36, 0))
	touch(78, start + Vector2(36, 0), false)
	check(is_equal_approx(canvas.zoom_level, resumed_zoom), "one-finger drag after resume cannot become a ghost pinch")
	var zoom_before := canvas.zoom_level
	var left := start - Vector2(60, 0)
	var right := start + Vector2(60, 0)
	touch(72, left, true)
	touch(73, right, true)
	drag(72, left, left - Vector2(30, 0))
	drag(73, right, right + Vector2(30, 0))
	touch(72, left - Vector2(30, 0), false)
	touch(73, right + Vector2(30, 0), false)
	await settled()
	check(canvas.zoom_level > zoom_before and hud.menu_title == "Skills", "Android-style two-finger touch/drag events pinch zoom without accidental tap")
	canvas.zoom_by(100.0)
	check(is_equal_approx(canvas.zoom_level, 1.8), "pinch/button zoom clamps at 1.8")
	canvas.zoom_by(0.001)
	check(is_equal_approx(canvas.zoom_level, 0.55), "pinch/button zoom clamps at 0.55")
	await tap(find_button("+"))
	var increased := canvas.zoom_level
	await tap(find_button("−") if find_button("−") != null else find_button("-"))
	check(increased > canvas.zoom_level, "plus and minus fallback buttons change zoom")
	canvas.zoom_by(2.0)
	var unfit_pan := canvas.pan_offset
	await tap(find_button("FIT"))
	check(canvas.zoom_level >= 0.55 and canvas.zoom_level <= 1.8 and canvas.pan_offset != unfit_pan, "Fit restores a centered overview inside zoom limits")
	check(Rect2(Vector2.ZERO, canvas.size).encloses(Rect2(canvas.pan_offset, canvas.graph_bounds.size * canvas.zoom_level)), "Fit shows the entire authored tree on the phone viewport")
	canvas.restore_view({"tree_type":"Roll", "zoom_level":0.55, "pan_offset":Vector2(150, 80)})
	var saved_view := canvas.capture_view()
	canvas.node_selected.emit("R01")
	await settled()
	hud.close_top_modal()
	await settled()
	canvas = hud.menus.skill_canvas
	check(canvas.pan_offset.is_equal_approx(saved_view.pan_offset) and is_equal_approx(canvas.zoom_level, saved_view.zoom_level), "details return preserves positive pan and zoom after container layout")
	canvas.focus_node("R03")
	await settled()
	var target: Control = canvas.anchors.R03
	await tap(target)
	check(hud.menu_title == "Skill:R03" and hud.modal_stack.size() == 2, "tapping Auto Roll opens one details modal")
	check(all_text().contains("40") and all_text().contains("R01") and hud.menu.find_child("SkillPreview", true, false) != null, "details show authoritative cost, prerequisites and current-to-new preview")
	hud.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await settled()
	check(hud.menu_title == "Skills" and hud.modal_stack.size() == 1, "Android Back closes only node details and returns to canvas")
	canvas = hud.menus.skill_canvas
	check(canvas.anchors.R03.position.y < canvas.anchors.R02.position.y, "Auto Roll appears before Luck I along the trunk")
	var view_pan := canvas.pan_offset
	var builds := hud.menu_build_count
	GameState.rolls_balance += 1
	GameState.changed.emit()
	hud._process(0.5)
	check(hud.menu_build_count == builds and canvas.pan_offset == view_pan, "wallet refresh updates node states without rebuilding or moving canvas")
	hud.menus.skill_tab = "Coin"
	hud.open_menu("Skills")
	await settled()
	canvas = hud.menus.skill_canvas
	check(canvas.anchors.has("C20") and canvas.anchors.has("C25") and canvas.edges.size() > 20, "Coin canvas includes new Fortune, speed and cross-tree prerequisite paths")
	hud.close_menu()

func test_purchase_details() -> void:
	GameState.lifetime_rolls = 1000
	GameState.rolls_balance = 1000
	hud.menus.skill_tab = "Roll"
	hud.open_menu("Skills")
	await settled()
	var canvas: SlimerotSkillTreeCanvas = hud.menus.skill_canvas
	canvas.fit_tree()
	await settled()
	await suite.capture("Slimerot-p14-roll-tree")
	canvas.focus_node("R01")
	await settled()
	await tap(canvas.anchors.R01)
	var buy := hud.menu.find_child("SkillBuy", true, false) as Button
	check(buy != null and not buy.disabled and all_text().contains("2.40 → 2.20"), "details preview Quick Hands from backend derived stats")
	await suite.capture("Slimerot-p14-skill-details")
	await tap(buy)
	check(hud.menu_title == "Skills" and GameState.rolls_balance == 975 and GameState.lifetime_rolls == 1000 and SkillTreeManager.derived_stats().roll_cooldown == 2.2, "Buy performs exactly one authoritative purchase and returns to tree")
	canvas = hud.menus.skill_canvas
	check(canvas.anchors.R01.theme_type_variation == "PurchasedSkillNode" and canvas.anchors.R03.theme_type_variation == "SkillNode" and canvas.anchors.R02.theme_type_variation == "LockedSkillNode" and canvas.anchors.R08.theme_type_variation == "BreakthroughSkillNode", "purchased, available, locked and Breakthrough styles are distinct")
	canvas.focus_node("R03")
	await settled()
	await tap(canvas.anchors.R03)
	await tap(hud.menu.find_child("SkillBuy", true, false) as Button)
	check(GameState.rolls_balance == 935 and SkillTreeManager.derived_stats().auto_roll and hud.auto_button.visible, "Auto Roll purchase uses the 40-Roll backend and exposes quick toggle")
	hud.close_menu()
	hud.notice.text = ""
	hud.notice_seconds = 0

func test_layouts() -> void:
	var window := get_window()
	var original := window.size
	for dimensions in [Vector2i(720, 1280), Vector2i(720, 1560), Vector2i(800, 1280)]:
		window.size = dimensions
		await settled()
		hud.apply_layout()
		await settled()
		var safe := hud.safe_rect
		var bounded := true
		for control in [hud.layout_items.top, hud.layout_items.currencies, hud.layout_items.team, hud.skills_button, hud.map_button, hud.joystick, hud.roll_button]:
			bounded = bounded and safe.grow(0.1).encloses(control.get_global_rect())
		check(bounded and not hud.joystick.get_global_rect().intersects(hud.roll_button.get_global_rect()), "%s HUD and separate movement/roll controls fit" % str(dimensions))
		await suite.capture("Slimerot-p14-hud-%dx%d" % [dimensions.x, dimensions.y])
		for title in ["Team", "Collection", "Potions", "Settings", "Skills"]:
			hud.open_menu(title)
			await settled()
			check(safe.grow(0.1).encloses(hud.menu.get_global_rect()) and hud.menu.size.x <= hud.root.size.x - 31, "%s %s modal has no horizontal or screen-edge clipping" % [str(dimensions), title])
			if dimensions.x == 720 and dimensions.y == 1280:
				await suite.capture("Slimerot-p14-" + title.to_lower())
			hud.close_menu()
	window.size = original
	await settled()
	hud.apply_layout()

func test_refresh_and_input() -> void:
	fresh()
	GameState.structure_unlocked_flags.skill_tree_shrine = true
	GameState.rolls_balance = 65
	GameState.lifetime_rolls = 65
	SkillTreeManager.purchase("R01")
	SkillTreeManager.purchase("R03")
	InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	hud.open_menu("Team")
	await settled()
	var builds := hud.menu_build_count
	for index in 20:
		GameState.player_hp = 80 + index
		GameState.changed.emit()
		hud._process(0.5)
	check(hud.menu_build_count == builds, "irrelevant HP changes do not rebuild visible Team cards")
	hud.close_menu()
	await settled()
	var before := descendants(hud.root).size()
	builds = hud.menu_build_count
	var lifetime := GameState.lifetime_rolls
	GameState.settings.auto_roll_state = true
	RollManager.set_process(false)
	for index in 100:
		RollManager.cooldown_remaining = 0.0
		RollManager._process(0.0)
		hud._process(0.02)
	GameState.settings.auto_roll_state = false
	RollManager.set_process(true)
	RollManager.presentation.clear()
	await settled()
	check(GameState.lifetime_rolls == lifetime + 100 and hud.menu_build_count == builds and descendants(hud.root).size() == before, "100 Auto Rolls with Team closed create no menu rebuilds or leaked UI nodes")
	hud.open_menu("Collection")
	hud.close_menu()
	await settled()
	var move_at := hud.joystick.get_global_rect().get_center() + Vector2(60, 0)
	touch(74, move_at, true)
	RollManager.cooldown_remaining = 0
	hud._process(0)
	lifetime = GameState.lifetime_rolls
	await tap(hud.roll_button, 75)
	check(hud.joystick.touch_id == 74 and hud.joystick.direction.x > 0.5 and GameState.lifetime_rolls == lifetime + 1, "disposed invisible overlays do not block simultaneous joystick and ROLL")
	touch(74, move_at, false)
	for title in ["Team", "Collection", "Potions", "Settings", "Skills", "Map", "Skill:R03"]:
		var passed := true
		for cycle in 20:
			hud.close_menu()
			if title.begins_with("Skill:"): hud.open_menu("Skills")
			hud.open_menu(title)
			await settled()
			var depth := hud.modal_stack.size()
			var close := find_button("Back") if depth > 1 else find_button("Close")
			if close == null: passed = false
			else:
				await tap(close)
				passed = passed and hud.modal_stack.size() == depth - 1
		check(passed, title + " closes exactly one layer over 20 real touch cycles")
	hud.close_menu()
