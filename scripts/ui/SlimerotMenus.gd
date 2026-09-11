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

func build(owner_hud: SlimerotHUD, title: String) -> void:
	hud = owner_hud
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
	var sorting := HBoxContainer.new()
	hud.menu_body.add_child(sorting)
	for order in ["DPS", "Rarity", "Name"]:
		var option := Button.new()
		option.text = "Sort: " + order
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.disabled = order == sort_order
		option.pressed.connect(func(): sort_order = order; hud.open_menu("Inventory"))
		sorting.add_child(option)
	hud.menu_button("Sell Duplicates", func(): hud.open_menu("Sell Duplicates"), not GameState.structure_unlocked_flags.get("sell_terminal", false))
	for pair in InventoryManager.sorted_pairs(sort_order):
		var key: String = pair.slime_id + ":" + pair.variant
		var data := SlimeDatabase.get_slime(pair.slime_id)
		card(data.display_name + " · " + pair.variant.capitalize(), SlimeDatabase.threshold_label(data.id) + "\nOwned %d · DPS %.1f · Sell %d Coins" % [pair.quantity, InventoryManager.damage_for_pair(pair) / SkillTreeManager.derived_stats().attack_interval, InventoryManager.sell_value(key)], pair.slime_id, pair.variant)
		hud.menu_button("★ Favorite group" if pair.favorite else "☆ Favorite group", func(): InventoryManager.toggle_favorite(key); hud.open_menu("Inventory"))
		hud.menu_button("Equip one / manage copies →", func(): copy_page = 0; hud.open_menu("Copies:" + key))
	if InventoryManager.sorted_pairs(sort_order).is_empty():
		hud.menu_label("No owned slimes. Tap ROLL to begin.")

func copies(key: String) -> void:
	if not InventoryManager.inventory.has(key): return
	var pair: Dictionary = InventoryManager.inventory[key]
	hud.menu_label(SlimeDatabase.get_slime(pair.slime_id).display_name + " · " + pair.variant.capitalize())
	var pages := maxi(1, ceili(pair.copy_ids.size() / 12.0))
	copy_page = clampi(copy_page, 0, pages - 1)
	hud.menu_label("Page %d / %d · %d owned" % [copy_page + 1, pages, pair.quantity], 18)
	for copy_id in pair.copy_ids.slice(copy_page * 12, (copy_page + 1) * 12):
		var equipped: bool = copy_id in InventoryManager.equipped_copy_ids
		var favorite: bool = pair.favorite or copy_id in pair.favorite_copy_ids
		hud.menu_label(copy_id.trim_prefix("slimerot_") + (" · Equipped" if equipped else "") + (" · Favorite" if favorite else ""), 18)
		hud.menu_button("Unequip" if equipped else "Equip", func():
			if equipped: InventoryManager.unequip(copy_id)
			else: InventoryManager.equip(copy_id)
			hud.open_menu("Copies:" + key), not equipped and InventoryManager.equipped_copy_ids.size() >= SkillTreeManager.derived_stats().equipped_slots)
		hud.menu_button("Unfavorite copy" if favorite else "Favorite copy", func(): InventoryManager.toggle_copy_favorite(copy_id); hud.open_menu("Copies:" + key))
		hud.menu_button("Sell copy · %d Coins" % InventoryManager.sell_value(key), func(): InventoryManager.sell_copy(copy_id); hud.open_menu("Copies:" + key), InventoryManager.is_protected(copy_id) or not GameState.structure_unlocked_flags.get("sell_terminal", false))
	hud.menu_button("Previous copies", func(): copy_page -= 1; hud.open_menu("Copies:" + key), copy_page == 0)
	hud.menu_button("Next copies", func(): copy_page += 1; hud.open_menu("Copies:" + key), copy_page == pages - 1)

func collection() -> void:
	hud.menu_label("%d / 24 discovered · %.1f%%" % [InventoryManager.discoveries.size(), InventoryManager.discoveries.size() * 100.0 / 24.0])
	for entry in InventoryManager.collection():
		var data: SlimerotData.SlimeData = entry.slime
		var subtitle := SlimeDatabase.threshold_label(data.id) + "\nZone %d · Base damage %.0f" % [data.zone_unlock, data.base_damage]
		subtitle += "\nBest owned: " + (entry.best_variant.capitalize() if not entry.best_variant.is_empty() else "None")
		var panel := card(data.display_name if entry.discovered else "Undiscovered", subtitle, data.id, entry.best_variant if not entry.best_variant.is_empty() else "normal", not entry.discovered)
		panel.add_to_group("slimerot_collection_entry")

func team() -> void:
	hud.menu_label("Team DPS %.1f" % InventoryManager.team_dps())
	var row := HBoxContainer.new()
	hud.menu_body.add_child(row)
	for index in SlimerotBalance.MAX_SLOTS:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(column)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 17)
		var locked: bool = index >= SkillTreeManager.derived_stats().equipped_slots
		label.text = "⛓ Locked" if locked else "Slot %d" % (index + 1)
		column.add_child(label)
		var portrait := SlimerotPortrait.new()
		portrait.silhouette = true
		if index < InventoryManager.equipped_copy_ids.size():
			var pair := InventoryManager.pair_for_copy(InventoryManager.equipped_copy_ids[index])
			portrait.slime_id = pair.slime_id
			portrait.variant = pair.variant
			portrait.silhouette = false
		column.add_child(portrait)
	hud.menu_button("Auto Equip Strongest", func(): InventoryManager.auto_equip_strongest(); hud.open_menu("Team"))
	for copy_id in InventoryManager.equipped_copy_ids:
		var pair := InventoryManager.pair_for_copy(copy_id)
		hud.menu_label(SlimeDatabase.get_slime(pair.slime_id).display_name + " · " + pair.variant.capitalize() + "\n%d damage / hit · every 1.00s" % int(InventoryManager.damage_for_copy(copy_id)), 20)
		hud.menu_button("Unequip", func(): InventoryManager.unequip(copy_id); hud.open_menu("Team"))
	hud.menu_label("Slot 2: C01 + 350 Coins\nSlot 3: C05 + Z2 boss + 3,500 Coins\nSlot 4: C08 + Z4 boss + 25,000 Coins\nSlot 5: C13 + Z6 boss + 250,000 Coins", 19)

func selling() -> void:
	hud.menu_label("Keeps every equipped/favorited copy and at least one copy of each slime + variant. Discovery history is permanent.")
	hud.menu_button("Sell unprotected duplicates", func():
		var earned := InventoryManager.sell_duplicates()
		hud.open_menu("Sell Duplicates")
		hud.menu_label("Sold for %d Coins." % earned), not GameState.structure_unlocked_flags.get("sell_terminal", false))

func skills() -> void:
	for tab in ["Roll", "Coin"]:
		hud.menu_button(tab + " Tree · %d %s" % [GameState.rolls_balance if tab == "Roll" else GameState.coins, "Rolls" if tab == "Roll" else "Coins"], func(): skill_tab = tab; hud.open_menu("Skills"), tab == skill_tab)
	if skill_tab == "Roll":
		hud.menu_label("Luck ×%.2f · Cooldown %.2fs\nBreakthroughs %d / 3 · every one multiplies TOTAL luck ×20" % [RollManager.effective_luck(), SkillTreeManager.derived_stats().roll_cooldown, SkillTreeManager.derived_stats().breakthrough_count], 19)
		hud.menu_button("Show mainline" if optional_branch else "Show optional branches", func(): optional_branch = not optional_branch; hud.open_menu("Skills"))
		hud.menu_label("Optional branches never gate a Breakthrough." if optional_branch else "Mainline · R01 → R08 → R13 → R18", 18)
	for id in SkillTreeManager.nodes:
		var data: SlimerotData.SkillNodeData = SkillTreeManager.nodes[id]
		if data.tree_type != skill_tab: continue
		if skill_tab == "Roll" and data.optional != optional_branch: continue
		var box := PanelContainer.new()
		var is_breakthrough := data.effect_type == "checkpoint_luck"
		box.add_theme_stylebox_override("panel", hud.style(Color("294d45") if is_breakthrough else Color("203841")))
		hud.menu_body.add_child(box)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		box.add_child(column)
		var heading := Label.new()
		heading.text = id + " · " + data.display_name
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		heading.add_theme_font_size_override("font_size", 23)
		heading.add_theme_color_override("font_color", Color("d5ff8f") if is_breakthrough else Color("e5eddf"))
		column.add_child(heading)
		var detail := Label.new()
		detail.text = data.description
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_font_size_override("font_size", 18)
		for prerequisite in data.prerequisite_ids:
			detail.text += "\n└ Requires " + prerequisite + (" ✓" if prerequisite in GameState.purchased_skill_node_ids else " · Locked")
		if data.prerequisite_ids.is_empty(): detail.text += "\nStart"
		if data.required_boss_zone > 0:
			detail.text += "\n└ Requires Z%d boss" % data.required_boss_zone
		if data.required_zone > 1: detail.text += "\n└ Requires Z%d unlocked" % data.required_zone
		if not data.required_structure.is_empty(): detail.text += "\n└ Requires repaired Sell Terminal"
		column.add_child(detail)
		var buy := Button.new()
		var blocker := SkillTreeManager.purchase_blocker(id)
		buy.text = ("Owned" if id in GameState.purchased_skill_node_ids else "Buy · %d %s" % [data.cost, data.currency_type])
		buy.custom_minimum_size.y = 58
		buy.disabled = not blocker.is_empty()
		buy.tooltip_text = blocker
		buy.pressed.connect(func(): SkillTreeManager.purchase(id); hud.open_menu("Skills"))
		column.add_child(buy)
		if not blocker.is_empty() and blocker != "Owned":
			detail.text += "\n" + blocker

func roll_settings() -> void:
	hud.menu_label("Rolling is free. Each completed roll grants +1 Rolls.\nEffective Luck ×%.2f · Next roll ×%.2f" % [RollManager.effective_luck(), RollManager.rolling_luck(RollManager.next_roll_multiplier())])
	hud.menu_button("Auto Roll · " + ("ON" if GameState.settings.auto_roll_state else "OFF"), hud.toggle_auto, not SkillTreeManager.derived_stats().auto_roll)
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
		picker.custom_minimum_size.y = 56
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
	hud.menu_button("Skip current reveal", func(): RollManager.skip_reveal(), RollManager.active_reveal.is_empty() or (RollManager.active_reveal.get("threshold", 0) >= 1000000 and RollManager.active_reveal.get("first_discovery", false)))

func stats() -> void:
	var bosses := 0
	for flag in GameState.boss_defeated_flags.values():
		if flag: bosses += 1
	hud.menu_label("Lifetime Rolls: %d\nRolls spent on skill nodes: %d\nCoins Earned: %d\nCoins Spent: %d\nRarest Threshold Reached: %s\nCollection: %d / 24 (%.1f%%)\nBosses Defeated: %d\nActive Playtime: %.1f minutes\nHighest Luck: ×%.2f\nBest Team DPS: %.1f" % [GameState.lifetime_rolls, SkillTreeManager.rolls_spent(GameState.purchased_skill_node_ids), GameState.coins_earned, GameState.coins_spent, ("None yet" if GameState.rarest_threshold_reached == 0 else "1 in " + SlimeDatabase.format_number(GameState.rarest_threshold_reached)), InventoryManager.discoveries.size(), InventoryManager.discoveries.size() * 100.0 / 24, bosses, GameState.active_play_seconds / 60.0, GameState.highest_luck, GameState.best_team_dps])

func settings() -> void:
	hud.menu_button("Resume", hud.close_menu)
	hud.menu_label("Save: " + (SaveManager.last_saved_at if SaveManager.last_error.is_empty() else SaveManager.last_error), 18)
	for key in ["screen_shake", "vibration"]:
		hud.menu_button(key.replace("_", " ").capitalize() + (" · ON" if GameState.settings[key] else " · OFF"), func(): GameState.settings[key] = not GameState.settings[key]; GameState.critical_change.emit("settings"); hud.open_menu("Settings"))
	for key in ["master_audio", "music_audio", "sfx_audio"]:
		hud.menu_label(key.replace("_", " ").capitalize(), 18)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = GameState.settings[key]
		slider.custom_minimum_size.y = 42
		slider.value_changed.connect(func(value): GameState.settings[key] = value; GameState.critical_change.emit("settings"))
		hud.menu_body.add_child(slider)
	hud.menu_label("Reset permanently erases this local save. Hold the button for 3 seconds to confirm.", 18)
	reset_button = hud.menu_button("Hold 3 seconds to reset Slimerot", func(): pass)
	reset_button.button_down.connect(func(): holding = true; hold_seconds = 0)
	reset_button.button_up.connect(cancel_hold)
	reset_button.mouse_exited.connect(cancel_hold)

func tick(delta: float) -> void:
	if is_instance_valid(potion_status): potion_status.text = "Luck effect: %.0fs · Boss Brew: %.0fs" % [GameState.potion_remaining_seconds,GameState.boss_brew_seconds]
	if holding and is_instance_valid(reset_button):
		if GameState.suspended:
			cancel_hold()
			return
		hold_seconds += delta
		reset_button.text = "Reset in %.1f seconds…" % maxf(0, SlimerotBalance.RESET_HOLD_SECONDS - hold_seconds)
		if hold_seconds >= SlimerotBalance.RESET_HOLD_SECONDS:
			cancel_hold()
			if SaveManager.reset_save(): hud.close_menu()

func cancel_hold() -> void:
	holding = false
	hold_seconds = 0.0
	if is_instance_valid(reset_button):
		reset_button.text = "Hold 3 seconds to reset Slimerot"

func card(title: String, subtitle: String, slime_id: String, variant: String, silhouette: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", hud.style(Color("203841")))
	hud.menu_body.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var portrait := SlimerotPortrait.new()
	portrait.slime_id = slime_id
	portrait.variant = variant
	portrait.silhouette = silhouette
	row.add_child(portrait)
	var label := Label.new()
	label.text = title + "\n" + subtitle
	label.add_theme_font_size_override("font_size", 19)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return panel
