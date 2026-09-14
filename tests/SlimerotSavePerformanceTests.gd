extends Node

func run(world: Node, suite: Node) -> void:
	SaveManager.enabled = false
	world.hud.close_menu()
	GameState.reset()
	InventoryManager.reset()
	RollManager.reset()
	WorldManager.travel(0)
	GameState.menu_paused = true
	var original_path := SaveManager.save_path
	SaveManager.save_path = "res://.godot/Slimerot-performance-%d.json" % OS.get_process_id()
	# A long session without selling must remain valid; favoriting a whole pair is common.
	for index in 5000: InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME, "normal", false)
	GameState.lifetime_rolls = 5000
	GameState.rolls_balance = 5000
	var pair: Dictionary = InventoryManager.inventory[SlimerotBalance.FIRST_SLIME + ":normal"]
	pair.favorite = true
	pair.favorite_copy_ids = pair.copy_ids.duplicate()
	var started := Time.get_ticks_usec()
	InventoryManager.auto_equip_strongest()
	var equip_ms := float(Time.get_ticks_usec() - started) / 1000.0
	SaveManager.enabled = true
	var samples: Array[float] = []
	for generation in 3:
		started = Time.get_ticks_usec()
		suite.check(SaveManager.save_game(), "Long-session save generation %d remains valid with 5000 favorite copies" % generation)
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	started = Time.get_ticks_usec()
	suite.check(SaveManager.load_game() and InventoryManager.inventory[SlimerotBalance.FIRST_SLIME + ":normal"].quantity == 5000 and InventoryManager.is_protected("slimerot_copy_5000"), "Long-session save restores all quantities and favorite protection")
	var load_ms := float(Time.get_ticks_usec() - started) / 1000.0
	suite.check(InventoryManager.equipped_copy_ids == ["slimerot_copy_1"], "Strongest equip tie retains the earliest physical copy")
	var alternate := SaveManager.snapshot()
	var alternate_pair: Dictionary = alternate.inventory[SlimerotBalance.FIRST_SLIME + ":normal"]
	alternate_pair.variant = "shiny"
	alternate.inventory.erase(SlimerotBalance.FIRST_SLIME + ":normal")
	alternate.inventory[SlimerotBalance.FIRST_SLIME + ":shiny"] = alternate_pair
	alternate.discoveries[SlimerotBalance.FIRST_SLIME].append("shiny")
	SaveManager.apply_snapshot(alternate)
	suite.check(world.hud.portraits.get_child(0).variant == "shiny", "Loading reused copy IDs refreshes HUD portraits when the saved variant changes")
	SaveManager.enabled = false
	GameState.structure_unlocked_flags.sell_terminal = true
	var sale_pair: Dictionary = InventoryManager.inventory[SlimerotBalance.FIRST_SLIME + ":shiny"]
	sale_pair.favorite = false
	sale_pair.favorite_copy_ids.assign(["slimerot_copy_1", "slimerot_copy_3"])
	var unit_value := InventoryManager.sell_value(SlimerotBalance.FIRST_SLIME + ":shiny")
	started = Time.get_ticks_usec()
	var sold_value := InventoryManager.sell_duplicates()
	var sale_ms := float(Time.get_ticks_usec() - started) / 1000.0
	suite.check(sold_value == 4998 * unit_value and sale_pair.quantity == 2 and InventoryManager.is_protected("slimerot_copy_3"), "Large duplicate sale retains exact equipped/favorite copies and pays every other copy once")
	suite.check(InventoryManager.sell_duplicates() == 0, "Repeating a large duplicate sale cannot repay already sold copies")
	print("Slimerot PERFORMANCE: copies=5000 equip_ms=%.3f save_ms=%s load_ms=%.3f" % [equip_ms, str(samples), load_ms])
	print("Slimerot PERFORMANCE: duplicate_sale_ms=%.3f" % sale_ms)
	SaveManager.enabled = false
	for suffix in SlimerotSaveFormat.SUFFIXES:
		if FileAccess.file_exists(SaveManager.save_path + suffix): DirAccess.remove_absolute(SaveManager.save_path + suffix)
	SaveManager.save_path = original_path
	InventoryManager.reset()
	GameState.reset()
	RollManager.reset()
	GameState.menu_paused = false
	WorldManager.travel(0)
	await get_tree().process_frame
