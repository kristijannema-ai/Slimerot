class_name SlimerotMenus
extends RefCounted

var hud: SlimerotHUD
var sort_order := "DPS"
var skill_tab := "Roll"
var optional_branch := false
var copy_page := 0
var holding := false
var hold_seconds := 0.0
var reset_button: Button
var potion_status: Label
var reset_progress: ProgressBar
var save_status: Label
var auto_status: Button
var luck_status: Label
var stat_labels: Dictionary = {}
var hold_pointer := -2
var slider_dragging := false
var live_seconds := 0.0
var sliders: Array[HSlider] = []
var slider_touch := -1
var active_slider: HSlider

const INK := Color("214953")
const MUTED := Color("527780")
const PAPER := Color("effaf3")
const MINT := Color("d9f1dc")
const GOLD := Color("ffe9a2")
const ROSE := Color("ffe0dc")

func build(owner_hud: SlimerotHUD, title: String) -> void:
	hud = owner_hud
	stat_labels.clear()
	sliders.clear()
	reset_button = null
	reset_progress = null
	save_status = null
	potion_status = null
	auto_status = null
	luck_status = null
	slider_dragging = false
	if title.begins_with("Copies:"):
		copies(title.trim_prefix("Copies:"))
		return
	match title:
		"Inventory": inventory()
		"Collection": collection()
		"Team": team()
		"Sell Duplicates": selling()
		"Skills": skills()
		"Roll Settings": roll_settings()
		"Stats": stats()
		"Settings": settings()
		"Potions": potions()
		"Map": map_menu()
		"Mutation": mutation()
		"Completion":
			hud.menu_label("Slimerot completed!\nThe Singularity Admin is defeated.")
			hud.menu_label("Your collection, team and upgrades are saved. Keep exploring and rolling.")
			hud.menu_button("Continue exploring",hud.close_menu)

func potions() -> void:
	hud.menu_label("Sodas do not stack: stronger luck wins. Boss Brew stacks with Boss Hunter at ×1.25. Same-potion use refreshes 5 minutes.",19)
	for id in SlimerotEncounters.POTIONS:
		var recipe: Dictionary = SlimerotEncounters.POTIONS[id]
		hud.menu_label("%s · Owned %d" % [recipe.name,int(GameState.potion_inventory.get(id,0))])
		hud.menu_button("Drink " + recipe.name,func(): WorldManager.drink_potion(id); hud.open_menu("Potions"), int(GameState.potion_inventory.get(id,0)) == 0 or (id != "boss_brew" and GameState.potion_remaining_seconds > 0 and GameState.active_potion_multiplier > recipe.luck))
		hud.menu_button("Craft · %s Coins" % SlimeDatabase.format_number(recipe.cost),func(): WorldManager.craft_potion(id); hud.open_menu("Potions"),not WorldManager.potion_recipe_unlocked(id) or GameState.current_zone != 2 or WorldManager.boss_active or GameState.coins < recipe.cost)
	hud.menu_label("Craft at the repaired Potion Bench in Italian Village. Hyper Soda needs the Z4 boss; Boss Brew needs the Z6 boss.",18)
	potion_status = Label.new()
	potion_status.add_theme_font_size_override("font_size",19)
	hud.menu_body.add_child(potion_status)

func map_menu() -> void:
	if not GameState.structure_unlocked_flags.get("fast_travel_pillar", false):
		hud.menu_label("Repair the Fast Travel Pillar in Sahara for 15,000 Coins to travel between unlocked entrances.", 20)
	if WorldManager.boss_active: hud.menu_label("Fast Travel is unavailable during a boss encounter.", 20)
	for zone in range(0,9):
		hud.menu_button(SlimerotCampaign.zone(zone).name + (" · Locked" if zone > GameState.highest_zone_unlocked else ""),func():
			if WorldManager.fast_travel(zone): hud.close_menu(), not GameState.structure_unlocked_flags.get("fast_travel_pillar",false) or zone > GameState.highest_zone_unlocked or WorldManager.boss_active)

func mutation() -> void:
	hud.menu_label("5 unprotected Normal copies → 1 Shiny. Favorites and equipped copies cannot be consumed.",20)
	for pair in InventoryManager.sorted_pairs("Name"):
		if pair.variant != "normal": continue
		var slime := SlimeDatabase.get_slime(pair.slime_id)
		var count := InventoryManager.mutation_candidates(slime.id).size()
		var fee := slime.base_sell * SlimerotEncounters.MUTATION_FEE_MULTIPLIER
		hud.menu_label("%s · %d eligible" % [slime.display_name,count],20)
		hud.menu_button("Mutate · %s Coins" % SlimeDatabase.format_number(fee),func(): InventoryManager.mutate(slime.id); hud.open_menu("Mutation"),count < 5 or GameState.coins < fee or GameState.current_zone != 6 or not GameState.structure_unlocked_flags.get("mutation_lab",false) or WorldManager.boss_active)

func inventory() -> void:
	var pairs := InventoryManager.sorted_pairs(sort_order)
	var total := 0
	for pair in pairs: total += int(pair.quantity)
	hud.menu_label("%d slime copies · %d slime + variant groups" % [total, pairs.size()], 19)
	var sorting := HBoxContainer.new()
	sorting.add_theme_constant_override("separation", 8)
	hud.menu_body.add_child(sorting)
	for order in ["DPS", "Rarity", "Name"]:
		var option := Button.new()
		option.text = order
		option.custom_minimum_size.y = 62
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.disabled = order == sort_order
		option.pressed.connect(func(): sort_order = order; hud.open_menu("Inventory"))
		sorting.add_child(option)
	var can_sell: bool = GameState.structure_unlocked_flags.get("sell_terminal", false)
	hud.menu_button("Sell Duplicates" if can_sell else "Sell Duplicates · Terminal locked", func(): hud.open_menu("Sell Duplicates"), not can_sell)
	if not can_sell: hud.menu_label("Repair the Bedroom Sell Terminal to sell spare copies.", 18)
	for pair in pairs:
		var key: String = pair.slime_id + ":" + pair.variant
		var data := SlimeDatabase.get_slime(pair.slime_id)
		var box := card(data.display_name + " · " + pair.variant.capitalize(), SlimeDatabase.threshold_label(data.id) + "\nOwned %d · DPS %.1f · Sell %s Coins" % [pair.quantity, InventoryManager.damage_for_pair(pair) / SkillTreeManager.derived_stats().attack_interval, SlimeDatabase.format_number(InventoryManager.sell_value(key))], pair.slime_id, pair.variant)
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 8)
		box.get_child(0).add_child(actions)
		action_in(actions, "Favorited" if pair.favorite else "Favorite", func(): InventoryManager.toggle_favorite(key); hud.open_menu("Inventory"))
		action_in(actions, "Equip / copies", func(): copy_page = 0; hud.open_menu("Copies:" + key))
	if pairs.is_empty():
		card("Meet your first blob!", "Close this menu and tap ROLL.\nEvery roll is free.", SlimerotBalance.FIRST_SLIME, "normal", true)

func copies(key: String) -> void:
	hud.menu_button("‹ Back to Inventory", func(): hud.open_menu("Inventory"))
	if not InventoryManager.inventory.has(key):
		hud.menu_label("This group has no owned copies.")
		return
	var pair: Dictionary = InventoryManager.inventory[key]
	card(SlimeDatabase.get_slime(pair.slime_id).display_name + " · " + pair.variant.capitalize(), "Equipped and favorite copies are protected from selling.", pair.slime_id, pair.variant)
	var pages := maxi(1, ceili(pair.copy_ids.size() / 12.0))
	copy_page = clampi(copy_page, 0, pages - 1)
	hud.menu_label("Page %d / %d · %d owned" % [copy_page + 1, pages, pair.quantity], 18)
	for copy_id in pair.copy_ids.slice(copy_page * 12, (copy_page + 1) * 12):
		var equipped: bool = copy_id in InventoryManager.equipped_copy_ids
		var favorite: bool = pair.favorite or copy_id in pair.favorite_copy_ids
		var section := section_box(MINT if equipped else PAPER)
		label_in(section, copy_id.trim_prefix("slimerot_").replace("_", " ").capitalize() + (" · Equipped" if equipped else "") + (" · Favorite" if favorite else ""), 19)
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 8)
		section.add_child(actions)
		action_in(actions, "Unequip" if equipped else "Equip", func():
			if equipped: InventoryManager.unequip(copy_id)
			else: InventoryManager.equip(copy_id)
			hud.open_menu("Copies:" + key), not equipped and InventoryManager.equipped_copy_ids.size() >= SkillTreeManager.derived_stats().equipped_slots)
		action_in(actions, "Unfavorite" if favorite else "Favorite", func(): InventoryManager.toggle_copy_favorite(copy_id); hud.open_menu("Copies:" + key))
		action_in(section, "Sell copy · %s Coins" % SlimeDatabase.format_number(InventoryManager.sell_value(key)), func(): InventoryManager.sell_copy(copy_id); hud.open_menu("Copies:" + key), InventoryManager.is_protected(copy_id) or not GameState.structure_unlocked_flags.get("sell_terminal", false))
	hud.menu_button("Previous copies", func(): copy_page -= 1; hud.open_menu("Copies:" + key), copy_page == 0)
	hud.menu_button("Next copies", func(): copy_page += 1; hud.open_menu("Copies:" + key), copy_page == pages - 1)

func collection() -> void:
	var total := SlimerotRoster.ROWS.size()
	hud.menu_label("%d / %d discovered · %.1f%%" % [InventoryManager.discoveries.size(), total, InventoryManager.discoveries.size() * 100.0 / total])
	hud.menu_label("A whole world of wonderfully weird blobs. Discoveries stay recorded even after selling.", 18)
	for entry in InventoryManager.collection():
		var data: SlimerotData.SlimeData = entry.slime
		var subtitle := ("DISCOVERED" if entry.discovered else "UNDISCOVERED") + "\nBase Rarity Threshold: 1 in " + SlimeDatabase.format_number(data.rarity_threshold)
		subtitle += "\nZone %d · Base damage %.0f" % [data.zone_unlock, data.base_damage]
		subtitle += "\nBest owned: " + (entry.best_variant.capitalize() if not entry.best_variant.is_empty() else "None")
		var panel := card(data.display_name if entry.discovered else "Undiscovered", subtitle, data.id, entry.best_variant if not entry.best_variant.is_empty() else "normal", not entry.discovered)
		panel.add_to_group("slimerot_collection_entry")

func team() -> void:
	hud.menu_label("Team DPS %.1f" % InventoryManager.team_dps())
	hud.menu_label("%d / %d unlocked slots filled" % [InventoryManager.equipped_copy_ids.size(), SkillTreeManager.derived_stats().equipped_slots], 19)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	hud.menu_body.add_child(row)
	for index in SlimerotBalance.MAX_SLOTS:
		var slot_panel := PanelContainer.new()
		slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var locked: bool = index >= SkillTreeManager.derived_stats().equipped_slots
		slot_panel.add_theme_stylebox_override("panel", compact_style(Color("dbe5e8") if locked else MINT))
		row.add_child(slot_panel)
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_panel.add_child(column)
		var label := label_in(column, "Slot %d" % (index + 1), 17)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var portrait := SlimerotTeamSlot.new()
		portrait.locked = locked
		portrait.silhouette = true
		if index < InventoryManager.equipped_copy_ids.size():
			var pair := InventoryManager.pair_for_copy(InventoryManager.equipped_copy_ids[index])
			portrait.slime_id = pair.slime_id
			portrait.variant = pair.variant
			portrait.silhouette = false
			portrait.empty_slot = false
		column.add_child(portrait)
		var state := label_in(column, "Locked" if locked else ("Empty" if portrait.empty_slot else "Ready"), 15)
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.menu_button("Auto Equip Strongest", func(): InventoryManager.auto_equip_strongest(); hud.open_menu("Team"))
	for copy_id in InventoryManager.equipped_copy_ids:
		var pair := InventoryManager.pair_for_copy(copy_id)
		var box := card(SlimeDatabase.get_slime(pair.slime_id).display_name + " · " + pair.variant.capitalize(), "%s damage / hit · every %.2fs" % [SlimeDatabase.format_number(int(InventoryManager.damage_for_copy(copy_id))), SkillTreeManager.derived_stats().attack_interval], pair.slime_id, pair.variant)
		action_in(box.get_child(0), "Unequip", func(): InventoryManager.unequip(copy_id); hud.open_menu("Team"))
	hud.menu_label("Grow the gang", 23)
	for id in SkillTreeManager.nodes:
		var data: SlimerotData.SkillNodeData = SkillTreeManager.nodes[id]
		if data.effect_type != "slot_set": continue
		var owned: bool = id in GameState.purchased_skill_node_ids
		hud.menu_label("Slot %d · %s · %s Coins\n%s" % [int(data.effect_value), id, SlimeDatabase.format_number(data.cost), "Unlocked" if owned else SkillTreeManager.purchase_blocker(id)], 18)
	hud.menu_button("Open Coin Tree", func(): skill_tab = "Coin"; hud.open_menu("Skills"), not GameState.structure_unlocked_flags.get("skill_tree_shrine", false))

func selling() -> void:
	hud.menu_label("Keeps every equipped/favorited copy and at least one copy of each slime + variant. Discovery history is permanent.")
	hud.menu_button("Sell unprotected duplicates", func():
		var earned := InventoryManager.sell_duplicates()
		hud.open_menu("Sell Duplicates")
		hud.menu_label("Sold for %d Coins." % earned), not GameState.structure_unlocked_flags.get("sell_terminal", false))

func skills() -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	hud.menu_body.add_child(tabs)
	for tab in ["Roll", "Coin"]:
		var tab_button := action_in(tabs, "%s Tree\n%s %s" % [tab, SlimeDatabase.format_number(GameState.rolls_balance if tab == "Roll" else GameState.coins), "Rolls" if tab == "Roll" else "Coins"], func(): skill_tab = tab; hud.open_menu("Skills"), tab == skill_tab)
		set_icon(tab_button, "rolls" if tab == "Roll" else "coins")
	if skill_tab == "Roll":
		hud.menu_label("Luck ×%.2f · Cooldown %.2fs\nBreakthroughs %d / 3 · every one multiplies TOTAL luck ×20" % [RollManager.effective_luck(), SkillTreeManager.derived_stats().roll_cooldown, SkillTreeManager.derived_stats().breakthrough_count], 19)
		hud.menu_button("Show mainline" if optional_branch else "Show optional branches", func(): optional_branch = not optional_branch; hud.open_menu("Skills"))
		hud.menu_label("Optional branches never gate a Breakthrough." if optional_branch else "Mainline · R01 → R08 → R13 → R18", 18)
	hud.menu_label("Follow the connecting paths. Mint = prerequisite owned · Slate = prerequisite locked.", 18)
	var graph := SlimerotSkillConnections.new()
	graph.add_to_group("slimerot_skill_graph")
	hud.menu_body.add_child(graph)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 24)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.add_child(list)
	var displayed: Array[String] = []
	for id in SkillTreeManager.nodes:
		var data: SlimerotData.SkillNodeData = SkillTreeManager.nodes[id]
		if data.tree_type != skill_tab: continue
		if skill_tab == "Roll" and data.optional != optional_branch: continue
		displayed.append(id)
	# Off-tab prerequisites get a real source card and connecting path, never a missing edge.
	for id in displayed:
		var data: SlimerotData.SkillNodeData = SkillTreeManager.nodes[id]
		for prerequisite in data.prerequisite_ids:
			if prerequisite in displayed or graph.anchors.has(prerequisite): continue
			var source: SlimerotData.SkillNodeData = SkillTreeManager.nodes[prerequisite]
			var source_button := action_in(list, "%s · %s\n%s" % [prerequisite, source.display_name, "Owned prerequisite" if prerequisite in GameState.purchased_skill_node_ids else "View prerequisite in " + source.tree_type + " Tree"], func():
				skill_tab = source.tree_type
				optional_branch = source.optional
				hud.open_menu("Skills"))
			graph.add_anchor(prerequisite, source_button)
	for id in displayed:
		var data: SlimerotData.SkillNodeData = SkillTreeManager.nodes[id]
		var box := PanelContainer.new()
		var is_breakthrough := data.effect_type == "checkpoint_luck"
		var owned: bool = id in GameState.purchased_skill_node_ids
		var appearance := hud.style(GOLD if is_breakthrough else (MINT if owned else PAPER))
		appearance.set_border_width_all(3 if is_breakthrough else 2)
		appearance.border_color = Color("e8ae47") if is_breakthrough else Color("bad5c8")
		box.add_theme_stylebox_override("panel", appearance)
		box.add_to_group("slimerot_skill_node")
		box.set_meta("skill_id", id)
		list.add_child(box)
		graph.add_anchor(id, box)
		for prerequisite in data.prerequisite_ids:
			graph.add_edge(prerequisite, id)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 10)
		box.add_child(column)
		if is_breakthrough: label_in(column, "TOTAL LUCK ×20", 29, Color("986022"))
		label_in(column, id + " · " + data.display_name, 23)
		var detail := label_in(column, data.description, 19, MUTED)
		for prerequisite in data.prerequisite_ids:
			detail.text += "\nRequires " + prerequisite + (" · Owned" if prerequisite in GameState.purchased_skill_node_ids else " · Locked")
		if data.prerequisite_ids.is_empty(): detail.text += "\nStart of branch"
		if data.required_boss_zone > 0:
			detail.text += "\nRequires Z%d boss" % data.required_boss_zone
		if data.required_zone > 1: detail.text += "\nRequires Z%d unlocked" % data.required_zone
		if not data.required_structure.is_empty(): detail.text += "\nRequires repaired Sell Terminal"
		var blocker := SkillTreeManager.purchase_blocker(id)
		var buy := action_in(column, "Owned" if owned else "%s · %s %s" % ["BREAK THROUGH" if is_breakthrough else "Buy", SlimeDatabase.format_number(data.cost), data.currency_type], func(): SkillTreeManager.purchase(id); hud.open_menu("Skills"), not blocker.is_empty())
		set_icon(buy, "rolls" if data.currency_type == "Rolls" else "coins")
		buy.tooltip_text = blocker
		if not blocker.is_empty() and blocker != "Owned":
			label_in(column, blocker, 18, Color("8e5754"))

func roll_settings() -> void:
	hud.menu_label("Rolling is free. Each completed roll grants +1 Rolls.", 20)
	luck_status = label_in(hud.menu_body, "", 20, SlimerotPresentation.CREAM)
	auto_status = hud.menu_button("Auto Roll · " + ("ON" if GameState.settings.auto_roll_state else "OFF"), hud.toggle_auto, not SkillTreeManager.derived_stats().auto_roll)
	set_icon(auto_status, "auto")
	if not SkillTreeManager.derived_stats().auto_roll:
		hud.menu_label("Auto Roll unlocks at R03 in the Roll Tree.", 18)
	if SkillTreeManager.derived_stats().breakthrough_count > 0:
		hud.menu_label("Luck Cap · affects rolling only", 20)
		for cap in SlimerotBalance.LUCK_CAPS:
			hud.menu_button(cap + (" ✓" if GameState.settings.luck_cap == SlimerotBalance.LUCK_CAPS[cap] else ""), func(): RollManager.set_luck_cap(SlimerotBalance.LUCK_CAPS[cap]); hud.open_menu("Roll Settings"))
	else:
		hud.menu_label("Luck Cap unlocks with Breakthrough I. Default: MAX.", 18)
	var stats := SkillTreeManager.derived_stats()
	if stats.super_roll:
		hud.menu_label("Super Roll: next in %d rolls. Every 100th Lifetime Roll uses ×5 after the selected cap." % RollManager.rolls_until_super(), 19)
	if stats.auto_sell:
		hud.menu_button("Auto-sell Normal duplicates · " + ("ON" if GameState.settings.auto_sell_settings.enabled else "OFF"), func(): InventoryManager.set_auto_sell(not GameState.settings.auto_sell_settings.enabled); hud.open_menu("Roll Settings"))
		hud.menu_label("Only new Normal duplicates at or below the selected threshold. Keeps one copy per pair; favorites and equipped copies are always protected.", 18)
		var picker := OptionButton.new()
		picker.custom_minimum_size.y = 64
		picker.get_popup().add_theme_constant_override("v_separation", 20)
		var thresholds := InventoryManager.auto_sell_thresholds()
		for index in thresholds.size():
			var threshold: int = thresholds[index]
			picker.add_item("Auto-sell ≤ 1 in " + SlimeDatabase.format_number(threshold), threshold)
			if threshold == int(GameState.settings.auto_sell_settings.threshold): picker.select(index)
		picker.item_selected.connect(func(index): InventoryManager.set_auto_sell_threshold(picker.get_item_id(index)))
		hud.menu_body.add_child(picker)
		hud.menu_label("Filter II: discovered thresholds available." if stats.filter_2 else ("Filter I: 20 / 100 / 1,000." if stats.filter_1 else "Default: 100. Unlock Filter I or II for more choices."), 18)
	else:
		hud.menu_label("Auto-sell unlocks with RO2 after Breakthrough I.", 18)
	hud.menu_label("Normal Luck never changes variant chances.\nNormal: otherwise · Shiny: 1/%d\nGlitched: 1/%s · Golden: 1/%s" % [80 if stats.variant_sense else 100, "800" if stats.variant_sense else "1,000", "8,000" if stats.variant_sense else "10,000"], 19)
	hud.menu_label("Skip Common shortens common toasts after RO1. First-discovery jackpots always play in full.", 18)
	refresh_live()

func stats() -> void:
	for key in ["Lifetime Rolls", "Coins Earned", "Coins Spent", "Rarest Threshold Reached", "Collection", "Bosses Defeated", "Playtime", "Highest Luck", "Best Team DPS"]:
		var box := section_box(PAPER)
		label_in(box, key, 18, MUTED)
		stat_labels[key] = label_in(box, "", 25)
	refresh_live()

func settings() -> void:
	hud.menu_button("Resume", hud.close_menu)
	save_status = Label.new()
	save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_status.add_theme_font_size_override("font_size", 18)
	hud.menu_body.add_child(save_status)
	for key in ["screen_shake", "vibration"]:
		hud.menu_button(key.replace("_", " ").capitalize() + (" · ON" if GameState.settings[key] else " · OFF"), func(): GameState.settings[key] = not GameState.settings[key]; GameState.critical_change.emit("settings"); hud.open_menu("Settings"))
	for key in ["master_audio", "music_audio", "sfx_audio"]:
		hud.menu_label({"master_audio": "Master volume", "music_audio": "Music volume", "sfx_audio": "Sound effects"}[key], 19)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = GameState.settings[key]
		slider.custom_minimum_size.y = 62
		slider.focus_mode = Control.FOCUS_NONE
		slider.value_changed.connect(func(value): GameState.settings[key] = value; SlimerotSound.apply_settings())
		slider.drag_started.connect(func(): slider_dragging = true)
		slider.drag_ended.connect(func(_changed): slider_dragging = false; GameState.critical_change.emit("settings"))
		hud.menu_body.add_child(slider)
		sliders.append(slider)
	hud.menu_label("Reset permanently erases this local save. Hold continuously for 3 seconds. Moving off the button cancels.", 18)
	reset_button = hud.menu_button("Hold 3 seconds to reset Slimerot", func(): pass)
	reset_button.add_theme_stylebox_override("normal", hud.style(Color("805058")))
	reset_button.button_down.connect(func(): begin_hold(-1))
	reset_button.button_up.connect(cancel_hold)
	reset_button.mouse_exited.connect(func(): if hold_pointer == -1: cancel_hold())
	reset_progress = ProgressBar.new()
	reset_progress.show_percentage = false
	reset_progress.max_value = SlimerotBalance.RESET_HOLD_SECONDS
	reset_progress.custom_minimum_size.y = 12
	reset_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.menu_body.add_child(reset_progress)
	refresh_live()

func refresh_live() -> void:
	if is_instance_valid(potion_status): potion_status.text = "Luck effect: %.0fs · Boss Brew: %.0fs" % [GameState.potion_remaining_seconds, GameState.boss_brew_seconds]
	if is_instance_valid(save_status): save_status.text = "Save: " + (SaveManager.last_saved_at if SaveManager.last_error.is_empty() else SaveManager.last_error)
	if is_instance_valid(luck_status): luck_status.text = "Effective Luck ×%.2f · Next roll ×%.2f" % [RollManager.effective_luck(), RollManager.rolling_luck(RollManager.next_roll_multiplier())]
	if is_instance_valid(auto_status): auto_status.text = "Auto Roll · " + ("ON" if GameState.settings.auto_roll_state else "OFF")
	if stat_labels.is_empty(): return
	var bosses := 0
	for defeated in GameState.boss_defeated_flags.values():
		if defeated: bosses += 1
	var values := {
		"Lifetime Rolls": SlimeDatabase.format_number(GameState.lifetime_rolls),
		"Coins Earned": SlimeDatabase.format_number(GameState.coins_earned),
		"Coins Spent": SlimeDatabase.format_number(GameState.coins_spent),
		"Rarest Threshold Reached": "None yet" if GameState.rarest_threshold_reached == 0 else "1 in " + SlimeDatabase.format_number(GameState.rarest_threshold_reached),
		"Collection": "%d / 24 · %.1f%%" % [InventoryManager.discoveries.size(), InventoryManager.discoveries.size() * 100.0 / 24],
		"Bosses Defeated": str(bosses),
		"Playtime": "%dh %02dm %02ds" % [int(GameState.active_play_seconds) / 3600, int(GameState.active_play_seconds / 60) % 60, int(GameState.active_play_seconds) % 60],
		"Highest Luck": "×%.2f" % GameState.highest_luck,
		"Best Team DPS": "%.1f" % GameState.best_team_dps,
	}
	for key in stat_labels:
		if is_instance_valid(stat_labels[key]): stat_labels[key].text = values[key]

func tick(delta: float) -> void:
	live_seconds += delta
	if live_seconds >= 0.2:
		live_seconds = 0.0
		refresh_live()
	if holding and is_instance_valid(reset_button):
		if GameState.suspended or hud.menu_title != "Settings":
			cancel_hold()
			return
		hold_seconds += delta
		reset_button.text = "Reset in %.1f seconds…" % maxf(0, SlimerotBalance.RESET_HOLD_SECONDS - hold_seconds)
		if is_instance_valid(reset_progress): reset_progress.value = hold_seconds
		if hold_seconds >= SlimerotBalance.RESET_HOLD_SECONDS:
			cancel_hold()
			if SaveManager.reset_save(): hud.close_menu()

func begin_hold(pointer: int) -> void:
	if hud == null or hud.menu_title != "Settings": return
	holding = true
	hold_pointer = pointer
	hold_seconds = 0.0

func cancel_hold() -> void:
	holding = false
	hold_pointer = -2
	hold_seconds = 0.0
	slider_dragging = false
	slider_touch = -1
	active_slider = null
	if is_instance_valid(reset_button): reset_button.text = "Hold 3 seconds to reset Slimerot"
	if is_instance_valid(reset_progress): reset_progress.value = 0

func is_interacting() -> bool:
	return holding or slider_dragging or slider_touch >= 0

func handle_input(event: InputEvent) -> bool:
	if hud == null or hud.menu_title != "Settings" or not is_instance_valid(hud.menu_scroll): return false
	if event is InputEventScreenTouch:
		if event.pressed:
			if not hud.menu_scroll.get_global_rect().has_point(event.position): return false
			if is_instance_valid(reset_button) and reset_button.get_global_rect().has_point(event.position):
				if not holding: begin_hold(event.index)
				return true
			for slider in sliders:
				if is_instance_valid(slider) and slider.get_global_rect().has_point(event.position):
					slider_touch = event.index
					active_slider = slider
					slider_dragging = true
					move_slider(event.position)
					return true
		else:
			if event.index == hold_pointer:
				cancel_hold()
				return true
			if event.index == slider_touch:
				move_slider(event.position)
				slider_dragging = false
				slider_touch = -1
				active_slider = null
				GameState.critical_change.emit("settings")
				return true
	elif event is InputEventScreenDrag:
		if event.index == hold_pointer:
			if not reset_button.get_global_rect().has_point(event.position): cancel_hold()
			return true
		if event.index == slider_touch:
			move_slider(event.position)
			return true
	return false

func move_slider(at: Vector2) -> void:
	if not is_instance_valid(active_slider): return
	var local := active_slider.get_global_transform_with_canvas().affine_inverse() * at
	active_slider.value = clampf(local.x / active_slider.size.x, 0.0, 1.0)

func section_box(color: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", hud.style(color))
	hud.menu_body.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	return column

func label_in(parent: Node, value: String, font_size: int = 22, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func action_in(parent: Node, value: String, action: Callable, disabled: bool = false) -> Button:
	var result := Button.new()
	result.text = value
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size.y = 62
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.focus_mode = Control.FOCUS_NONE
	result.disabled = disabled
	result.pressed.connect(action)
	parent.add_child(result)
	return result

func set_icon(button: Button, id: String) -> void:
	button.icon = SlimerotAssets.icon(id)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 26)

func compact_style(color: Color) -> StyleBoxFlat:
	var result := hud.style(color)
	result.content_margin_left = 5
	result.content_margin_right = 5
	return result

func card(title: String, subtitle: String, slime_id: String, variant: String, silhouette: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", hud.style(PAPER))
	hud.menu_body.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var portrait := SlimerotPortrait.new()
	portrait.slime_id = slime_id
	portrait.variant = variant
	portrait.silhouette = silhouette
	row.add_child(portrait)
	portrait.custom_minimum_size = Vector2(104, 118)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	label_in(detail, title, 22)
	label_in(detail, subtitle, 18, MUTED)
	return panel
