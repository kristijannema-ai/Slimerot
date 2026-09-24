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
var super_status: Label
var luck_breakdown_status: Label
var stat_labels: Dictionary = {}
var hold_pointer := -2
var slider_dragging := false
var live_seconds := 0.0
var sliders: Array[HSlider] = []
var slider_touch := -1
var active_slider: HSlider
var skill_canvas: SlimerotSkillTreeCanvas
var skill_views: Dictionary = {}
var skill_balance_labels: Dictionary = {}
var skill_zoom_label: Label

const INK := SlimerotUITheme.CREAM
const MUTED := SlimerotUITheme.MUTED
const PAPER := SlimerotUITheme.SURFACE
const MINT := Color("344437")
const GOLD := Color("504027")
const ROSE := Color("4a293f")

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
	super_status = null
	luck_breakdown_status = null
	skill_balance_labels.clear()
	skill_zoom_label = null
	skill_canvas = null
	slider_dragging = false
	if title.begins_with("Skill:"):
		skill_details(title.trim_prefix("Skill:"))
		return
	if title.begins_with("Copies:"):
		copies(title.trim_prefix("Copies:"))
		return
	match title:
		"Inventory": team()
		"Collection": collection()
		"Team": team()
		"Sell Duplicates": selling()
		"Skills": skills()
		"Roll Settings": settings()
		"Stats": stats()
		"Settings": settings()
		"Potions": potions()
		"Map": map_menu()
		"Variant Shrine", "Mutation": mutation()
		"Completion":
			hud.menu_label("Slimerot completed!\nThe Singularity Admin is defeated.")
			hud.menu_label("Your collection, team and upgrades are saved. Keep exploring and rolling.")
			hud.menu_button("Continue exploring",hud.close_menu)

func potions() -> void:
	hud.menu_label("Sodas do not stack: stronger luck wins. Boss Brew stacks with Boss Hunter at ×1.25. Same-potion use refreshes 5 minutes.",19)
	for id in SlimerotEncounters.POTIONS:
		var recipe: Dictionary = SlimerotEncounters.POTIONS[id]
		var section := section_box(PAPER)
		label_in(section, "%s · Owned %d" % [recipe.name,int(GameState.potion_inventory.get(id,0))], 23)
		action_in(section, "Drink " + recipe.name,func(): WorldManager.drink_potion(id); hud.open_menu("Potions"), int(GameState.potion_inventory.get(id,0)) == 0 or (id != "boss_brew" and GameState.potion_remaining_seconds > 0 and GameState.active_potion_multiplier > recipe.luck))
		action_in(section, "Craft · %s Coins" % SlimeDatabase.format_number(recipe.cost),func(): WorldManager.craft_potion(id); hud.open_menu("Potions"),not WorldManager.potion_recipe_unlocked(id) or GameState.current_zone != 2 or WorldManager.boss_active or GameState.coins < recipe.cost)
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
	hud.menu_label("VARIANT SHRINE", 28)
	hud.menu_label("Sacrifice one unprotected variant copy toward ONE of its active categories. Each unique base gives that category ×1.05 odds permanently. A base counts once per category. No Coins are charged.", 19)
	for flag in SlimerotVariants.FLAGS:
		var category := SlimerotVariants.key(flag)
		var chance := SlimerotVariants.probability(flag, InventoryManager.shrine_count(flag), SlimerotBalance.VARIANT_SENSE_MULTIPLIER if SkillTreeManager.derived_stats().variant_sense else 1.0)
		hud.menu_label("%s · %d/24 bases · ×%.3f · %.4f%% chance" % [SlimerotVariants.label(flag), InventoryManager.shrine_count(flag), InventoryManager.shrine_multiplier(flag), chance * 100.0], 19)
	var available := false
	for pair in InventoryManager.sorted_pairs("Name"):
		var flags := SlimerotVariants.mask(pair.variant)
		if flags == 0: continue
		var spans := InventoryManager.available_intervals(pair)
		if spans.is_empty(): continue
		var copy_id := InventoryManager.copy_name(int(spans[0][0]))
		var section := section_box(PAPER)
		label_in(section, SlimeDatabase.get_slime(pair.slime_id).display_name + " · " + SlimerotVariants.label(flags), 22)
		label_in(section, "Consumes one copy: " + copy_id, 16)
		for flag in SlimerotVariants.FLAGS:
			if not (flags & flag): continue
			var category := SlimerotVariants.key(flag)
			var counted: bool = pair.slime_id in GameState.shrine_sacrifices[category]
			action_in(section, "Already offered to " + category.capitalize() if counted else "Sacrifice one → " + category.capitalize(), func(): InventoryManager.sacrifice(copy_id, flag); hud.open_menu("Variant Shrine"), counted or GameState.current_zone != 6 or not GameState.structure_unlocked_flags.get("mutation_lab", false) or WorldManager.boss_active)
		available = true
	if not available: hud.menu_label("No eligible variant copies. Equipped and favorite copies are protected.", 19)
	hud.menu_label("Offer copies at the repaired Variant Shrine in Backrooms. Normal copies cannot be sacrificed.", 18)

func inventory() -> void:
	var pairs := InventoryManager.sorted_pairs(sort_order)
	var total := 0
	for pair in pairs: total += int(pair.quantity)
	hud.menu_label("YOUR SLIMES", 24)
	hud.menu_label("%s copies · %d unique stacks" % [SlimeDatabase.format_number(total), pairs.size()], 18)
	var sorting := HBoxContainer.new()
	sorting.add_theme_constant_override("separation", 8)
	hud.menu_body.add_child(sorting)
	for order in ["DPS", "Rarity", "Name"]:
		var option := action_in(sorting, order, func(): sort_order = order; hud.open_menu("Team"), order == sort_order)
		option.theme_type_variation = "TabButton"
		style_selection(option, order == sort_order)
	var stats := SkillTreeManager.derived_stats()
	for pair in pairs:
		var key: String = pair.slime_id + ":" + pair.variant
		var equipped: Array[String] = []
		for copy_id in InventoryManager.equipped_copy_ids:
			if InventoryManager.pair_contains_copy(pair, copy_id): equipped.append(copy_id)
		var candidate := ""
		for copy_id in InventoryManager.first_candidates(pair, SlimerotBalance.MAX_SLOTS):
			if copy_id not in InventoryManager.equipped_copy_ids:
				candidate = copy_id
				break
		var data := SlimeDatabase.get_slime(pair.slime_id)
		var damage := InventoryManager.damage_for_pair(pair)
		var box := card(data.display_name + "  x" + SlimeDatabase.format_number(pair.quantity), "%s · %d equipped\n%s damage · %.1f DPS\n1 in %s" % [SlimerotVariants.label(pair.variant), equipped.size(), SlimeDatabase.format_number(int(damage)), damage / stats.attack_interval, SlimeDatabase.format_number(SlimeDatabase.get_effective_rarity(pair.slime_id, pair.variant))], pair.slime_id, pair.variant)
		box.add_to_group("slimerot_inventory_stack")
		box.set_meta("stack_key", key)
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 8)
		box.get_child(0).add_child(actions)
		var favorite := action_in(actions, "★ Favorite" if pair.favorite else "☆ Favorite", func(): InventoryManager.toggle_favorite(key); hud.open_menu("Team"))
		style_selection(favorite, pair.favorite)
		action_in(actions, "Equip", func(): InventoryManager.equip(candidate); hud.open_menu("Team"), candidate.is_empty() or InventoryManager.equipped_copy_ids.size() >= stats.equipped_slots)
		if not equipped.is_empty():
			action_in(actions, "Unequip", func(): InventoryManager.unequip(equipped.back()); hud.open_menu("Team"))
		action_in(box.get_child(0), "Manage copies", func(): copy_page = 0; hud.open_modal("Copies:" + key))
	if pairs.is_empty():
		card("Meet your first blob!", "Tap ROLL to start your team.\nEvery roll is free.", SlimerotBalance.FIRST_SLIME, "normal", true)
	if GameState.structure_unlocked_flags.get("sell_terminal", false):
		hud.menu_button("Sell spare copies", func(): hud.open_modal("Sell Duplicates"))

func copies(key: String) -> void:
	if not InventoryManager.inventory.has(key):
		hud.menu_label("This group has no owned copies.")
		return
	var pair: Dictionary = InventoryManager.inventory[key]
	card(SlimeDatabase.get_slime(pair.slime_id).display_name + " · " + SlimerotVariants.label(pair.variant), "Equipped and favorite copies are protected from selling.", pair.slime_id, pair.variant)
	var pages := maxi(1, ceili(pair.quantity / 12.0))
	copy_page = clampi(copy_page, 0, pages - 1)
	hud.menu_label("Page %d / %d · %d owned" % [copy_page + 1, pages, pair.quantity], 18)
	for copy_id in InventoryManager.copies_page(pair, copy_page * 12, 12):
		var equipped: bool = copy_id in InventoryManager.equipped_copy_ids
		var favorite: bool = InventoryManager.copy_is_favorite(pair, copy_id)
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
		subtitle += "\nOrigin Z%d · Normal damage %.0f" % [data.zone_unlock, data.base_damage]
		subtitle += "\nBest owned: " + (SlimerotVariants.label(entry.best_variant) if not entry.best_variant.is_empty() else "None")
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
		slot_panel.add_theme_stylebox_override("panel", compact_style(Color("172639") if locked else MINT))
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
		state.add_theme_color_override("font_color", MUTED if locked or portrait.empty_slot else SlimerotPresentation.MINT)
	var best := hud.menu_button("Equip Best", func():
		if InventoryManager.auto_equip_strongest(): hud.open_menu("Team"))
	best.theme_type_variation = "PrimaryButton"
	inventory()

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
		var tab_button := action_in(tabs, tab.to_upper() + " TREE", func():
			remember_skill_view()
			skill_tab = tab
			hud.open_menu("Skills"), tab == skill_tab)
		tab_button.theme_type_variation = "TabButton"
		style_selection(tab_button, tab == skill_tab)
		set_icon(tab_button, "rolls" if tab == "Roll" else "coins")
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	hud.menu_body.add_child(toolbar)
	skill_balance_labels.balance = label_in(toolbar, "", 20, SlimerotUITheme.GOLD)
	var minus := action_in(toolbar, "−", func(): skill_canvas.zoom_by(1.0 / 1.2); refresh_skill_labels())
	minus.custom_minimum_size.x = 64
	minus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	minus.tooltip_text = "Zoom out"
	skill_zoom_label = label_in(toolbar, "", 17)
	skill_zoom_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skill_zoom_label.custom_minimum_size.x = 54
	skill_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var plus := action_in(toolbar, "+", func(): skill_canvas.zoom_by(1.2); refresh_skill_labels())
	plus.custom_minimum_size.x = 64
	plus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plus.tooltip_text = "Zoom in"
	var fit := action_in(toolbar, "FIT", func(): skill_canvas.fit_tree(); refresh_skill_labels())
	fit.custom_minimum_size.x = 80
	fit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skill_canvas = SlimerotSkillTreeCanvas.new()
	skill_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_canvas.custom_minimum_size.y = 280
	hud.menu_body.add_child(skill_canvas)
	skill_canvas.configure(skill_tab)
	skill_canvas.node_selected.connect(func(id: String):
		remember_skill_view()
		hud.open_modal("Skill:" + id))
	if skill_views.has(skill_tab): skill_canvas.restore_view(skill_views[skill_tab])
	label_in(hud.menu_body, "DRAG TO PAN · PINCH TO ZOOM · TAP A SKILL", 16, MUTED)
	refresh_skill_labels()

func remember_skill_view() -> void:
	if is_instance_valid(skill_canvas): skill_views[skill_canvas.tree_type] = skill_canvas.capture_view()

func refresh_skill_labels() -> void:
	if is_instance_valid(skill_balance_labels.get("balance")):
		skill_balance_labels.balance.text = "%s %s" % [SlimeDatabase.format_number(GameState.rolls_balance if skill_tab == "Roll" else GameState.coins), "Rolls" if skill_tab == "Roll" else "Coins"]
	if is_instance_valid(skill_canvas) and is_instance_valid(skill_zoom_label):
		skill_zoom_label.text = "%d%%" % roundi(skill_canvas.zoom_level * 100.0)

func skill_details(id: String) -> void:
	var data: SlimerotData.SkillNodeData = SkillTreeManager.nodes.get(id)
	if data == null:
		hud.menu_label("This skill is unavailable.")
		return
	var owned: bool = id in GameState.purchased_skill_node_ids
	var section := section_box(GOLD if data.effect_type == "checkpoint_luck" else PAPER)
	label_in(section, data.display_name, 30, SlimerotUITheme.GOLD if data.effect_type == "checkpoint_luck" else INK)
	label_in(section, id + " · " + data.tree_type.to_upper() + " TREE", 17, MUTED)
	label_in(section, data.description, 23)
	label_in(section, "%s %s" % [SlimeDatabase.format_number(data.cost), data.currency_type], 25, SlimerotUITheme.GOLD)
	var requirements := PackedStringArray()
	for prerequisite in data.prerequisite_ids:
		var source: SlimerotData.SkillNodeData = SkillTreeManager.nodes.get(prerequisite)
		requirements.append((source.display_name if source != null else prerequisite) + (" ✓" if prerequisite in GameState.purchased_skill_node_ids else ""))
	if data.required_zone > 1: requirements.append("Zone %d unlocked" % data.required_zone)
	if data.required_boss_zone > 0: requirements.append("Zone %d boss defeated" % data.required_boss_zone)
	if not data.required_structure.is_empty(): requirements.append(data.required_structure.replace("_", " ").capitalize() + " repaired")
	label_in(section, "REQUIRES\n" + ("Start of branch" if requirements.is_empty() else "\n".join(requirements)), 19, MUTED)
	var preview := label_in(section, skill_preview(id), 22, SlimerotUITheme.LIME)
	preview.name = "SkillPreview"
	var blocker := SkillTreeManager.purchase_blocker(id)
	var buy := action_in(section, "PURCHASED" if owned else "BUY · %s %s" % [SlimeDatabase.format_number(data.cost), data.currency_type], func():
		if SkillTreeManager.purchase(id): hud.close_top_modal(), not blocker.is_empty())
	buy.name = "SkillBuy"
	buy.theme_type_variation = "PrimaryButton"
	set_icon(buy, "rolls" if data.currency_type == "Rolls" else "coins")
	if not blocker.is_empty() and not owned: label_in(section, blocker, 19, SlimerotUITheme.GOLD)

func skill_preview(id: String) -> String:
	if id in GameState.purchased_skill_node_ids: return "Already part of your build."
	var next_ids: Array = GameState.purchased_skill_node_ids.duplicate()
	next_ids.append(id)
	var before := SkillTreeManager.derived_stats()
	var after := SkillTreeManager.derived_stats(next_ids)
	var lines := PackedStringArray()
	var current_luck := RollManager.get_effective_luck()
	var new_luck := RollManager.get_effective_luck({"node_ids": next_ids})
	if not is_equal_approx(current_luck, new_luck): lines.append("Luck  ×%.2f → ×%.2f" % [current_luck, new_luck])
	var labels := {"roll_cooldown": "Roll cooldown", "max_hp": "Max HP", "move_speed": "Move speed", "attack_interval": "Attack interval", "attack_range": "Attack range", "damage_multiplier": "Team damage multiplier", "boss_damage_bonus": "Boss damage bonus", "equipped_slots": "Team slots", "auto_roll": "Auto Roll", "variant_sense": "Variant Sense", "skip_common": "Skip Common", "auto_sell": "Auto Sell", "filter_1": "Filter I", "filter_2": "Filter II", "super_roll_interval": "Super Roll interval", "super_roll_multiplier": "Super Roll multiplier", "coin_scavenger": "Normal Coin bonus", "duplicate_dealer": "Duplicate sale bonus"}
	for key in labels:
		if before[key] == after[key]: continue
		lines.append("%s  %s → %s" % [labels[key], preview_value(before[key]), preview_value(after[key])])
	return "CURRENT → NEW\n" + ("No additional stat change" if lines.is_empty() else "\n".join(lines))

func preview_value(value: Variant) -> String:
	if value is bool: return "ON" if value else "OFF"
	if value is int: return str(value)
	return "%.2f" % float(value)

func progression_order(ids: Array[String]) -> Array[String]:
	var ordered: Array[String] = []
	var pending: Array[String] = ids.duplicate()
	while not pending.is_empty():
		var ready := -1
		for index in pending.size():
			var blocked := false
			for prerequisite in SkillTreeManager.nodes[pending[index]].prerequisite_ids:
				if prerequisite in pending: blocked = true
			if not blocked:
				ready = index
				break
		# Debug validation diagnoses malformed graphs; the menu still remains usable.
		if ready < 0:
			ordered.append_array(pending)
			break
		ordered.append(pending[ready])
		pending.remove_at(ready)
	return ordered

func toggle_auto_setting() -> void:
	if not SkillTreeManager.derived_stats().auto_roll: return
	GameState.settings.auto_roll_state = not GameState.settings.auto_roll_state
	GameState.critical_change.emit("settings")
	GameState.changed.emit()
	refresh_live()

func roll_settings() -> void:
	hud.menu_label("Every roll is free and earns +1 Rolls.", 18)
	luck_status = label_in(hud.menu_body, "", 20, SlimerotPresentation.CREAM)
	auto_status = hud.menu_button("Auto Roll · " + ("ON" if GameState.settings.auto_roll_state else "OFF"), toggle_auto_setting, not SkillTreeManager.derived_stats().auto_roll)
	set_icon(auto_status, "auto")
	if not SkillTreeManager.derived_stats().auto_roll:
		hud.menu_label("After Quick Hands I, buy R03 Auto Roll for 40 Rolls.", 18)
	if SkillTreeManager.derived_stats().breakthrough_count > 0:
		hud.menu_label("Luck Cap · affects rolling only", 20)
		for cap in SlimerotBalance.LUCK_CAPS:
			var selected: bool = GameState.settings.luck_cap == SlimerotBalance.LUCK_CAPS[cap]
			var cap_button := hud.menu_button(cap + (" ✓" if selected else ""), func(): RollManager.set_luck_cap(SlimerotBalance.LUCK_CAPS[cap]); hud.open_menu("Settings"))
			style_selection(cap_button, selected)
	else:
		hud.menu_label("Luck Cap unlocks with Breakthrough I. Default: MAX.", 18)
	var stats := SkillTreeManager.derived_stats()
	if stats.super_roll:
		super_status = label_in(hud.menu_body, "", 19)
	if stats.auto_sell:
		hud.menu_button("Auto-sell Normal duplicates · " + ("ON" if GameState.settings.auto_sell_settings.enabled else "OFF"), func(): InventoryManager.set_auto_sell(not GameState.settings.auto_sell_settings.enabled); hud.open_menu("Settings"))
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
	hud.menu_label("Common reveals are quicker with Skip Common. New discoveries always get their full reveal.", 18)
	if OS.is_debug_build() and "--slimerot-playtest" in OS.get_cmdline_user_args():
		luck_breakdown_status = label_in(hud.menu_body, "", 18, MUTED)
	refresh_live()

func stats() -> void:
	hud.menu_label("SLIMEROT · Your adventure", 24)
	hud.menu_label("Build a wonderfully weird team. Roll, explore and grow.", 18)
	for key in ["Lifetime Rolls", "Coins Earned", "Coins Spent", "Rarest Threshold Reached", "Collection", "Bosses Defeated", "Playtime", "Highest Luck", "Best Team DPS"]:
		var box := section_box(PAPER)
		label_in(box, key, 18, MUTED)
		stat_labels[key] = label_in(box, "", 30, SlimerotPresentation.GOLD if key.begins_with("Coins") else SlimerotPresentation.MINT)
	refresh_live()

func settings() -> void:
	hud.menu_label("GENERAL", 25)
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
	hud.menu_label("ROLLING", 25)
	roll_settings()
	hud.menu_label("SAVE / SYSTEM", 25)
	save_status = label_in(hud.menu_body, "", 18, MUTED)
	hud.menu_button("Stats / About", func(): hud.open_modal("Stats"))
	hud.menu_label("Reset permanently erases this local save. Hold continuously for 3 seconds. Moving off the button cancels.", 18)
	reset_button = hud.menu_button("Hold 3 seconds to reset Slimerot", func(): pass)
	reset_button.add_theme_stylebox_override("normal", hud.style(ROSE))
	reset_button.add_theme_color_override("font_color", Color("ffc5c0"))
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
	if is_instance_valid(save_status):
		save_status.text = "Save: " + (SaveManager.last_saved_at if SaveManager.last_error.is_empty() else SaveManager.last_error)
		if not SaveManager.recovery_status.is_empty(): save_status.text += " · " + SaveManager.recovery_status
	if is_instance_valid(luck_status): luck_status.text = "Effective Luck ×%.2f · Next roll ×%.2f" % [RollManager.effective_luck(), RollManager.rolling_luck(RollManager.next_roll_multiplier())]
	if is_instance_valid(super_status):
		var stats := SkillTreeManager.derived_stats()
		super_status.text = "Super Roll %s · next in %d rolls\n×%d luck after the selected cap · repeats every %d rolls. Upgrades keep an earlier scheduled trigger." % [["", "I", "II", "III"][stats.super_roll_tier], RollManager.rolls_until_super(), int(stats.super_roll_multiplier), stats.super_roll_interval]
	if is_instance_valid(luck_breakdown_status):
		var breakdown := RollManager.get_luck_breakdown({"super_roll_multiplier": RollManager.next_roll_multiplier(), "apply_cap": true})
		luck_breakdown_status.text = "DEV · Next-roll luck components"
		for component in ["minor_roll_tree_product", "breakthrough_product", "zone_luck_multiplier", "coin_tree_luck_product", "active_potion_multiplier", "super_roll_multiplier"]:
			luck_breakdown_status.text += "\n%s: ×%.6f" % [component, breakdown[component]]
		luck_breakdown_status.text += "\nTOTAL: ×%.6f · After cap: ×%.6f" % [breakdown.total, breakdown.capped_total]
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
	if hud != null and hud.menu_title == "Skills" and is_instance_valid(skill_canvas):
		var handled := skill_canvas.handle_input(event)
		if handled: refresh_skill_labels()
		return handled
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
	var appearance := SlimerotUITheme.resource().get_stylebox("panel", "Card").duplicate() as StyleBoxFlat
	appearance.bg_color = color
	appearance.set_border_width_all(1)
	appearance.border_color = SlimerotPresentation.BORDER
	appearance.content_margin_left = 18
	appearance.content_margin_right = 18
	appearance.content_margin_top = 16
	appearance.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", appearance)
	hud.menu_body.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
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
	label.add_theme_constant_override("line_spacing", 3)
	parent.add_child(label)
	return label

func action_in(parent: Node, value: String, action: Callable, disabled: bool = false) -> Button:
	var result := Button.new()
	result.text = value
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SlimerotUITheme.apply_button(result)
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

func style_selection(button: Button, selected: bool) -> void:
	if not selected: return
	var selected_style := SlimerotUITheme.resource().get_stylebox("normal", "PrimaryButton").duplicate() as StyleBoxFlat
	selected_style.border_color = SlimerotUITheme.LIME.lightened(0.12)
	for state in ["normal", "disabled", "hover"]:
		button.add_theme_stylebox_override(state, selected_style)
	for color in ["font_color", "font_disabled_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(color, SlimerotUITheme.INK)
	button.add_theme_stylebox_override("pressed", SlimerotUITheme.resource().get_stylebox("pressed", "PrimaryButton"))

func compact_style(color: Color) -> StyleBoxFlat:
	var result := SlimerotUITheme.resource().get_stylebox("panel", "Card").duplicate() as StyleBoxFlat
	result.bg_color = color
	result.content_margin_left = 5
	result.content_margin_right = 5
	result.set_border_width_all(1)
	result.border_color = SlimerotPresentation.BORDER
	return result

func card(title: String, subtitle: String, slime_id: String, variant: String, silhouette: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	var accent: Color = SlimerotVariants.color(variant)
	if silhouette: accent = SlimerotPresentation.BORDER
	var appearance := SlimerotUITheme.resource().get_stylebox("panel", "Card").duplicate() as StyleBoxFlat
	appearance.set_border_width_all(1)
	appearance.border_width_top = 3
	appearance.border_color = accent.darkened(0.24) if not silhouette else accent
	appearance.content_margin_left = 18
	appearance.content_margin_right = 18
	appearance.content_margin_top = 18
	appearance.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", appearance)
	hud.menu_body.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	var preview := PanelContainer.new()
	var preview_style := SlimerotUITheme.resource().get_stylebox("panel", "Card").duplicate() as StyleBoxFlat
	preview_style.bg_color = SlimerotUITheme.INK
	preview_style.set_border_width_all(1)
	preview_style.border_color = accent.darkened(0.55) if not silhouette else accent
	preview_style.set_corner_radius_all(14)
	preview_style.set_content_margin_all(6)
	preview.add_theme_stylebox_override("panel", preview_style)
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(preview)
	var portrait := SlimerotPortrait.new()
	portrait.slime_id = slime_id
	portrait.variant = variant
	portrait.silhouette = silhouette
	preview.add_child(portrait)
	portrait.custom_minimum_size = Vector2(120, 124)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(detail)
	label_in(detail, title, 23, MUTED if silhouette else INK)
	label_in(detail, subtitle, 18, MUTED)
	return panel

func visible_signature(title: String) -> String:
	match title:
		"Team", "Inventory":
			return str([inventory_signature(), InventoryManager.equipped_copy_ids, SkillTreeManager.derived_stats(), sort_order, GameState.structure_unlocked_flags.get("sell_terminal", false)])
		"Collection":
			var variants: Array = []
			for row in SlimerotRoster.ROWS: variants.append(InventoryManager.best_variant_owned(str(row[0])))
			return str([InventoryManager.discoveries, variants])
		"Potions":
			return str([GameState.potion_inventory, GameState.coins, GameState.current_zone, WorldManager.boss_active, GameState.structure_unlocked_flags, GameState.boss_defeated_flags, GameState.active_potion_multiplier, GameState.potion_remaining_seconds > 0])
		"Settings", "Roll Settings":
			return str([GameState.settings, GameState.purchased_skill_node_ids, InventoryManager.discoveries])
		"Stats": return "live-stats"
		"Skills":
			return str([GameState.coins, GameState.rolls_balance, GameState.purchased_skill_node_ids, GameState.highest_zone_unlocked, GameState.structure_unlocked_flags, GameState.boss_defeated_flags])
		"Map":
			return str([GameState.current_zone, GameState.highest_zone_unlocked, WorldManager.boss_active, GameState.structure_unlocked_flags.get("fast_travel_pillar", false)])
	if title.begins_with("Skill:"): return str([visible_signature("Skills"), GameState.active_potion_multiplier])
	if title.begins_with("Copies:"):
		var pair: Dictionary = InventoryManager.inventory.get(title.trim_prefix("Copies:"), {})
		var page: Array[String] = []
		if not pair.is_empty(): page = InventoryManager.copies_page(pair, copy_page * 12, 12)
		var favorites: Array = []
		for copy_id in page: favorites.append(InventoryManager.copy_is_favorite(pair, copy_id))
		return str([pair.get("quantity", 0), page, favorites, InventoryManager.equipped_copy_ids, GameState.purchased_skill_node_ids])
	return str([inventory_signature(), GameState.current_zone, GameState.structure_unlocked_flags, GameState.purchased_skill_node_ids, WorldManager.boss_active])

func inventory_signature() -> Array:
	var stacks: Array = []
	for key in InventoryManager.inventory:
		var pair: Dictionary = InventoryManager.inventory[key]
		stacks.append([key, pair.quantity, pair.favorite])
	return stacks

func refresh_visible(title: String) -> bool:
	if title == "Skills" and is_instance_valid(skill_canvas):
		skill_canvas.refresh_states()
		refresh_skill_labels()
		return true
	if title == "Stats":
		refresh_live()
		return true
	return false
