extends Node

var suite: Node

func check(value: bool, label: String) -> void:
	suite.check(value,label)

func fresh(world: Node) -> void:
	SaveManager.enabled = false
	world.hud.close_menu()
	InventoryManager.reset()
	RollManager.reset()
	GameState.reset()
	GameState.suspended = false
	GameState.menu_paused = false
	GameState.highest_zone_unlocked = 8
	GameState.coins = 1000000
	GameState.coins_earned = 1000000
	GameState.lifetime_rolls = 10000
	GameState.rolls_balance = 10000
	WorldManager.travel(0)
	CombatManager.set_physics_process(false)

func begin(world: Node, zone: int) -> SlimerotBoss:
	WorldManager.travel(zone)
	GameState.zone_kill_counts[str(zone)] = SlimerotCampaign.zone(zone).kill_requirement
	assert(WorldManager.start_boss(zone))
	world.arena.set_physics_process(false)
	world.arena.boss.set_physics_process(false)
	return world.arena.boss

func run(world: Node, owner_suite: Node) -> void:
	suite = owner_suite
	fresh(world)
	check(WorldManager.structures.size() == 5, "exactly five permanent structures")
	var rows := [["skill_tree_shrine",0,25],["sell_terminal",0,75],["potion_bench",2,900],["fast_travel_pillar",4,15000],["mutation_lab",6,250000]]
	for row in rows:
		var data: SlimerotData.StructureData = WorldManager.structures[row[0]]
		check(data.zone == row[1] and data.coin_cost == row[2], row[0]+" exact location and price")
		WorldManager.travel(1)
		check(not WorldManager.repair(row[0]), row[0]+" cannot repair remotely")
		WorldManager.travel(row[1])
		GameState.coins = row[2]-1
		check(not WorldManager.repair(row[0]), row[0]+" rejects insufficient Coins")
		GameState.coins = row[2]
		var spent := GameState.coins_spent
		check(WorldManager.repair(row[0]) and GameState.coins == 0 and GameState.coins_spent == spent+row[2] and not WorldManager.repair(row[0]), row[0]+" permanent unlock spends exactly once")
	GameState.highest_zone_unlocked = 4
	check(not WorldManager.fast_travel(5) and not WorldManager.fast_travel(-1) and not WorldManager.fast_travel(9), "Fast Travel rejects locked and invalid targets")
	check(WorldManager.fast_travel(0) and world.player.position == SlimerotBalance.ENTRANCES[0] and WorldManager.fast_travel(4) and world.player.position == SlimerotBalance.ENTRANCES[4], "Fast Travel goes only to Hub/unlocked entrances")
	world.hud.open_menu("Map")
	await suite.capture("Slimerot-stage-6-map")
	world.hud.close_menu()
	GameState.highest_zone_unlocked = 8
	WorldManager.travel(2)
	GameState.coins = 100000
	check(WorldManager.craft_potion("lucky_soda") and GameState.potion_inventory.lucky_soda == 1 and GameState.coins == 99700, "Lucky Soda crafts for exactly 300 Coins at Bench")
	check(not WorldManager.craft_potion("hyper_soda") and not WorldManager.craft_potion("boss_brew"), "later potion recipes remain boss-gated")
	check(WorldManager.drink_potion("lucky_soda") and RollManager.effective_luck() == 2 and GameState.potion_remaining_seconds == 300, "Lucky Soda grants x2 for exactly five active minutes")
	GameState.menu_paused = true
	GameState._process(30)
	check(GameState.potion_remaining_seconds == 300, "pause does not consume potion duration")
	GameState.menu_paused = false
	GameState._process(10)
	check(GameState.potion_remaining_seconds == 290, "active play consumes potion duration")
	GameState.boss_defeated_flags.zone_4 = true
	check(WorldManager.craft_potion("hyper_soda") and GameState.coins == 91700 and WorldManager.drink_potion("hyper_soda") and RollManager.effective_luck() == 3, "Hyper Soda unlocks after Z4, costs 8000 and replaces x2 with x3")
	WorldManager.craft_potion("lucky_soda")
	check(not WorldManager.drink_potion("lucky_soda") and GameState.potion_inventory.lucky_soda == 1 and RollManager.effective_luck() == 3, "weaker soda cannot replace stronger potion or consume a bottle")
	GameState.boss_defeated_flags.zone_6 = true
	var before := GameState.coins
	check(WorldManager.craft_potion("boss_brew") and GameState.coins == before-30000 and WorldManager.drink_potion("boss_brew"), "Boss Brew costs exactly 30000 after Z6")
	var copy := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME,"golden")
	GameState.purchased_skill_node_ids.assign(["C09","C17"])
	check(InventoryManager.damage_for_copy(copy,true) == roundf(7*4*1.5*1.25) and InventoryManager.damage_for_copy(copy) == 28 and RollManager.effective_luck() == 3, "Brew stacks x1.25 with Boss Hunter and coexists with soda without affecting raw DPS")
	GameState._process(299)
	check(GameState.boss_brew_seconds == 1 and GameState.potion_remaining_seconds == 1, "both potion channels count active time independently")
	GameState._process(1)
	check(GameState.boss_brew_seconds == 0 and GameState.potion_remaining_seconds == 0 and RollManager.effective_luck() == 1, "potion effects expire exactly at 300 active seconds")
	GameState.purchased_skill_node_ids.clear()
	WorldManager.travel(6)
	GameState.coins = 100
	InventoryManager.reset()
	var copies: Array[String] = []
	for index in 7: copies.append(InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME))
	InventoryManager.equip(copies[0])
	InventoryManager.toggle_copy_favorite(copies[1])
	check(InventoryManager.mutation_candidates(SlimerotBalance.FIRST_SLIME).size() == 5, "mutation excludes equipped and favorite physical copies")
	check(InventoryManager.mutate(SlimerotBalance.FIRST_SLIME) and GameState.coins == 0 and InventoryManager.inventory[SlimerotBalance.FIRST_SLIME+":normal"].quantity == 2 and InventoryManager.inventory[SlimerotBalance.FIRST_SLIME+":shiny"].quantity == 1, "five identical Normal copies plus 20x base sell create exactly one Shiny")
	check(not InventoryManager.pair_for_copy(copies[0]).is_empty() and not InventoryManager.pair_for_copy(copies[1]).is_empty() and not InventoryManager.mutate(SlimerotBalance.FIRST_SLIME), "mutation preserves protected copies and rejects insufficient eligible quantity")
	for index in 5: InventoryManager.add_copy("brr_brr_patapim")
	GameState.coins = 239
	check(not InventoryManager.mutate("brr_brr_patapim") and InventoryManager.mutation_candidates("brr_brr_patapim").size() == 5 and GameState.coins == 239, "mutation fee failure is atomic")
	for variant in ["shiny","glitched","golden"]:
		for index in 5: InventoryManager.add_copy("chimpanzini_bananini",variant)
	check(not InventoryManager.mutate("chimpanzini_bananini"), "non-Normal variants cannot substitute in mutation recipe")
	world.hud.open_menu("Mutation")
	await suite.capture("Slimerot-stage-6-mutation")
	world.hud.close_menu()
	# Isolated boss patterns and their actual arena lifecycle.
	fresh(world)
	var hp_values := [3000,50000,650000,7500000]
	var rewards := [1000,20000,350000,6000000]
	var contacts := [16,35,65,110]
	for index in 4:
		var zone: int = [2,4,6,8][index]
		WorldManager.travel(zone)
		check(not WorldManager.start_boss(zone), "Z%d boss requires zone kills" % zone)
		var boss := begin(world,zone)
		check(boss.hp == hp_values[index] and boss.data.contact == contacts[index] and WorldManager.boss_active, "Z%d boss exact HP/contact and active arena" % zone)
		check(world.arena.get_child_count() == 5 and not WorldManager.fast_travel(0) and not WorldManager.use_exit(), "Z%d closes arena and blocks travel/gates during fight" % zone)
		check(world.arena.z_index < world.player.z_index, "Z%d arena floor draws behind the visible player and slimes" % zone)
		var wallet := [GameState.coins,GameState.rolls_balance,GameState.lifetime_rolls]
		GameState.player_hp = 87
		boss.take_damage(100)
		world.player.global_position = SlimerotEncounters.ARENA_ORIGIN + Vector2(30,500)
		world.arena._physics_process(0)
		check(not WorldManager.boss_active and GameState.player_hp == 87 and wallet == [GameState.coins,GameState.rolls_balance,GameState.lifetime_rolls] and not WorldManager.is_boss_zone_defeated(zone), "Z%d retreat resets without HP or progression penalty/reward" % zone)
		boss = begin(world,zone)
		check(boss.hp == hp_values[index], "Z%d restart restores full boss HP" % zone)
		world.player.global_position = boss.global_position+Vector2(0,250)
		boss.contact_remaining = 100
		if zone == 2:
			boss.step(3)
			check(boss.phase == "slam_warning", "Espresso chases for 3s then shows slam warning")
			world.player.global_position = boss.global_position+Vector2(0,100)
			GameState.player_hp = 100
			boss.step(0.79)
			check(GameState.player_hp == 100, "Espresso slam waits through 0.79s warning")
			boss.step(0.02)
			check(GameState.player_hp == 76 and boss.phase == "chase", "Espresso warning resolves at 0.8s for exactly 24 damage")
		elif zone == 4:
			boss.step(3.2)
			check(boss.phase == "fan_warning" and CombatManager.get_child_count() == 0, "Sand Router warns before its four-second fan")
			boss.step(0.8)
			check(CombatManager.get_child_count() == 5 and CombatManager.get_child(0).damage == 50, "Sand Router fires five 50-damage waves every four seconds")
		elif zone == 6:
			boss.step(5.99)
			check(boss.teleport_index == 0, "Janitor waits six seconds before teleport")
			boss.step(0.01)
			check(boss.teleport_index == 1 and boss.position == SlimerotEncounters.TELEPORT_POINTS[0], "Janitor teleports to one of four arena points")
			boss.step(0.5)
			boss.step(0.5)
			check(CombatManager.get_child_count() == 6 and CombatManager.get_child(0).damage == 80, "Janitor fires two aimed three-shot bursts for 80 damage")
		else:
			boss.step(3.2)
			boss.step(0.8)
			check(CombatManager.get_child_count() == 5 and CombatManager.get_child(0).damage == 140 and boss.admin_teleport, "Admin alternates five-shot fan into teleport pattern with 140 damage")
			CombatManager.clear_projectiles()
			boss.step(6)
			boss.step(0.5)
			boss.step(0.5)
			check(CombatManager.get_child_count() == 6 and not boss.admin_teleport, "Admin teleport double burst alternates back to fan")
			boss.take_damage(float(boss.data.hp)*0.60)
			check(boss.enraged and boss.hp == 3000000, "Admin phase two starts at exactly 40 percent HP")
			GameState.player_hp = 1000
			boss.step(4)
			check(boss.warnings.size() == 1 and GameState.player_hp == 1000, "phase-two shrinking circle gives a readable warning before damage")
			boss.step(1.21)
			check(GameState.player_hp == 830, "Admin circle resolves for exactly 170 damage")
		CombatManager.clear_projectiles()
		world.player.global_position = SlimerotEncounters.ARENA_ORIGIN + Vector2(450,800)
		world.reset_camera()
		boss.enter_phase("slam_warning" if zone == 2 else "fan_warning" if zone == 4 else "burst_warning")
		if zone == 8: boss.warnings.append({"at":world.player.global_position+Vector2(80,0),"remaining":1.0})
		boss.queue_redraw()
		await suite.capture("Slimerot-stage-6-boss-%d" % zone)
		var coins_before := GameState.coins
		boss.take_damage(boss.hp)
		check(WorldManager.is_boss_zone_defeated(zone) and GameState.coins == coins_before+rewards[index] and not WorldManager.finish_boss_reward(zone) and not WorldManager.start_boss(zone), "Z%d fixed first reward is granted and saved once, never farmed" % zone)
		if zone in [2,4]: check(GameState.potion_inventory.get("lucky_soda" if zone == 2 else "hyper_soda",0) == 1, "Z%d reward includes its exact soda bottle" % zone)
	check(GameState.completion_portal_unlocked and not GameState.campaign_completed and WorldManager.complete_campaign() and GameState.campaign_completed, "Admin unlocks permanent completion portal and entering it marks completion")
	world.hud.close_menu()
	SaveManager.enabled = true
	check(SaveManager.save_game() and SaveManager.load_game() and GameState.completion_portal_unlocked and GameState.campaign_completed and GameState.potion_inventory.lucky_soda == 1, "boss flags, reward bottles and completion portal persist in schema 6")
	SaveManager.enabled = false
	WorldManager.drink_potion("hyper_soda")
	GameState.boss_brew_seconds = 123
	SaveManager.enabled = true
	check(SaveManager.save_game() and SaveManager.load_game() and GameState.potion_remaining_seconds == 300 and GameState.boss_brew_seconds == 123, "independent potion channels resume exact active timers without offline progress")
	SaveManager.enabled = false
	GameState.structure_unlocked_flags.potion_bench = true
	world.hud.open_menu("Potions")
	await suite.capture("Slimerot-stage-6-potions")
	world.hud.open_menu("Completion")
	await suite.capture("Slimerot-stage-6-completion")
	fresh(world)
	var death_boss := begin(world,2)
	CombatManager.damage_player(999)
	world.arena._physics_process(0)
	CombatManager._physics_process(1.51)
	check(not WorldManager.boss_active and not WorldManager.is_boss_zone_defeated(2) and GameState.player_hp == 100 and world.player.position == SlimerotBalance.ENTRANCES[2], "boss death resets arena and preserves ordinary current-zone respawn")
	check(death_boss.dead, "reset boss cannot receive further in-flight hits")
	fresh(world)
	CombatManager.set_physics_process(true)
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(SaveManager.save_path+suffix)
