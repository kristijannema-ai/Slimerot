extends Node

var suite: Node
const HP := [[45,70,130],[180,280,520],[700,1100,2000],[2600,4000,7500],[9000,14000,26000],[30000,48000,90000],[95000,150000,280000],[300000,480000,900000]]
const COINS := [[5,7,10],[18,25,40],[65,90,150],[250,350,600],[900,1300,2200],[3500,5000,8500],[14000,20000,34000],[55000,80000,140000]]
const HITS := [[8,6,12],[12,10,18],[18,15,26],[26,22,38],[38,32,55],[55,45,80],[75,65,110],[100,85,150]]
const KILLS := [12,20,40,30,60,40,90,100]
const GATES := [150,900,4000,18000,75000,300000,1200000,0]
const LEVELS := [[1,3],[4,7],[8,12],[13,18],[19,26],[27,36],[37,48],[49,65]]

func check(value: bool, label: String) -> void:
	suite.check(value,label)

func fresh(world: Node) -> void:
	SaveManager.enabled = false
	world.hud.close_menu()
	InventoryManager.reset()
	RollManager.reset()
	GameState.reset()
	GameState.menu_paused = false
	GameState.suspended = false
	WorldManager.travel(0)

func run(world: Node, owner_suite: Node) -> void:
	suite = owner_suite
	fresh(world)
	for zone in range(1,9):
		var data := SlimerotCampaign.zone(zone)
		check(data.kill_requirement == KILLS[zone-1] and data.gate_coin_cost == GATES[zone-1] and data.enemy_level_range == Vector2i(LEVELS[zone-1][0],LEVELS[zone-1][1]), "Z%d canonical gate, kills and level range" % zone)
		check(data.boss_id_or_null.is_empty() == (zone not in [2,4,6,8]) and data.slime_unlock_ids.size() == 3, "Z%d exact boss requirement and three pool additions" % zone)
		for index in 3:
			var enemy := SlimerotCampaign.enemy(zone,SlimerotCampaign.ARCHETYPES[index])
			check(enemy.max_hp == HP[zone-1][index] and enemy.coin_reward == COINS[zone-1][index] and enemy.attack_damage == HITS[zone-1][index] and enemy.level >= LEVELS[zone-1][0] and enemy.level <= LEVELS[zone-1][1], "Z%d %s fixed HP/reward/damage/level" % [zone,enemy.archetype])
	# Walk to and use the actual Hub context exit, with an ordinary guaranteed starter.
	RollManager.variant_rng.seed = 1234
	check(RollManager.request_roll() and InventoryManager.equipped_copy_ids.size() == 1, "campaign fresh start preserves guaranteed starter equip")
	world.player.position = Vector2(500,1090)
	world._process(0)
	world.interact()
	check(GameState.current_zone == 1 and GameState.coins == 0, "actual Hub interaction enters Backyard without charging currency")
	CombatManager.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("slimerot_enemies"): enemy.set_physics_process(false)
	var lagling: SlimerotEnemy = world.zone_root.get_children().filter(func(n): return n is SlimerotEnemy and n.data.archetype == "chaser")[0]
	var copy: String = InventoryManager.equipped_copy_ids[0]
	for kill in 50:
		while not lagling.dead: lagling.take_damage(InventoryManager.damage_for_copy(copy))
		var earned := GameState.coins
		lagling.take_damage(999)
		check(GameState.coins == earned, "dead enemy cannot double-credit kill %d" % kill)
		lagling._physics_process(SlimerotCampaign.RESPAWN_SECONDS+0.01)
	check(GameState.coins == 250 and GameState.zone_kill_counts["1"] == 50 and not lagling.dead and lagling.hp == 45, "repeatable starter farm awards exactly fixed Coins/kills and respawns fixed HP")
	check(WorldManager.repair("skill_tree_shrine") and WorldManager.repair("sell_terminal") and GameState.coins == 150, "canonical first structures consume exactly 25 plus 75 Coins")
	world.player.position = SlimerotCampaign.EXIT_GATE + Vector2(0,50)
	world._process(0)
	check(world.current_interaction.prompt.contains("150") and world.current_interaction.prompt.contains("50 / 12"), "physical gate UI exposes currency and current kills")
	RollManager.finish_reveal()
	world.reset_camera()
	await suite.capture("Slimerot-stage-5-backyard-gate")
	world.interact()
	check(GameState.current_zone == 2 and WorldManager.gate_open(1) and GameState.coins == 0 and GameState.highest_zone_unlocked == 2, "Z1 to Z2 end-to-end pays 150 once and permanently unlocks zone")
	check(SlimeDatabase.eligible(2).size() == 6 and RollManager.select_base(800,1,GameState.highest_zone_unlocked) == "tralalero_tralala", "gate unlock immediately expands global roll eligibility")
	WorldManager.return_through_gate()
	check(GameState.current_zone == 1 and world.player.position == SlimerotCampaign.RETURN_ARRIVAL and GameState.highest_zone_unlocked == 2, "backtracking arrives at far gate and never shrinks pool")
	world.player.position = SlimerotCampaign.EXIT_GATE
	world._process(0)
	world.interact()
	check(GameState.current_zone == 2 and GameState.coins == 0, "unlocked gate traverses freely with zero wallet")
	GameState.coins = 900
	check(not WorldManager.unlock_gate(2), "Coins alone cannot bypass kill requirement")
	GameState.zone_kill_counts["2"] = 20
	check(not WorldManager.unlock_gate(2) and not WorldManager.gate_open(2) and GameState.coins == 900, "boss placeholder never bypasses boss requirement or charges Coins")
	check(WorldManager.boss_encounter_prompt(2).contains("unavailable") and not WorldManager.is_boss_zone_defeated(2), "encounter placeholder does not invent boss AI or a defeat")
	world.player.position = SlimerotCampaign.EXIT_GATE
	world.reset_camera()
	GameState.changed.emit()
	world._process(0)
	await suite.capture("Slimerot-stage-5-boss-gate")
	# Test each scene, route and gate using explicit fixture boss flags, not a player shortcut.
	for zone in range(2,9):
		GameState.highest_zone_unlocked = maxi(GameState.highest_zone_unlocked,zone)
		WorldManager.travel(zone)
		await get_tree().physics_frame
		check(world.zone_root.name == SlimerotCampaign.SCENES[zone] and get_tree().get_nodes_in_group("slimerot_enemies").size() == 11, "Z%d separately loads only its own scene and enemies" % zone)
		var map: SlimerotZone = world.zone_root
		var navigable := true
		for index in range(1,map.farm_loop.size()):
			if map.navigation.get_id_path(Vector2i(map.farm_loop[index-1]/50),Vector2i(map.farm_loop[index]/50)).is_empty(): navigable = false
		var main_path := map.navigation.get_id_path(Vector2i(SlimerotCampaign.ENTRANCE/50),Vector2i(SlimerotCampaign.EXIT_GATE/50))
		check(navigable and not main_path.is_empty() and SlimerotCampaign.TILE_COUNT == Vector2i(20,30), "Z%d farming loop and main route are traversable at 20x30 tile scale" % zone)
		for enemy in get_tree().get_nodes_in_group("slimerot_enemies"):
			enemy.set_physics_process(false)
			check(enemy.data.zone == zone and enemy.hp == HP[zone-1][SlimerotCampaign.ARCHETYPES.find(enemy.data.archetype)], "Z%d spawned %s starts at its fixed HP" % [zone,enemy.data.archetype])
		GameState.zone_kill_counts[str(zone)] = KILLS[zone-1]
		if zone in [2,4,6,8]: GameState.boss_defeated_flags["zone_%d" % zone] = true
		GameState.coins = GATES[zone-1]-1 if zone < 8 else 0
		if zone < 8: check(not WorldManager.unlock_gate(zone) and GameState.coins == GATES[zone-1]-1, "Z%d rejects one-Coin-short gate without charging" % zone)
		GameState.coins = GATES[zone-1]
		check(WorldManager.unlock_gate(zone) and GameState.coins == 0 and not WorldManager.unlock_gate(zone), "Z%d exact gate price, permanent flag and repeat-purchase protection" % zone)
		var inventory_before := InventoryManager.inventory.duplicate(true)
		CombatManager.damage_player(9999)
		CombatManager._physics_process(1.51)
		check(GameState.current_zone == zone and world.player.position == SlimerotBalance.ENTRANCES[zone] and InventoryManager.inventory == inventory_before and WorldManager.gate_open(zone), "Z%d death respawns at current entrance with inventory and gate intact" % zone)
		world.player.position = Vector2(500,730)
		world.reset_camera()
		world.hud.breakthrough_banner.hide()
		GameState.changed.emit()
		await suite.capture("Slimerot-stage-5-zone-%d" % zone)
	check(GameState.highest_zone_unlocked == 8 and SlimeDatabase.eligible(8).size() == 24 and WorldManager.gate_prompt(8) == "Campaign complete", "final gate completes at 100 kills plus boss and never creates a ninth zone")
	SaveManager.enabled = true
	check(SaveManager.save_game() and SaveManager.load_game() and GameState.current_zone == 8 and WorldManager.gate_open(7), "schema 5 saves late current zone, kill counts and permanent gates")
	SaveManager.enabled = false
	var legacy := SaveManager.snapshot()
	legacy.schema_version = 4
	legacy.erase("unlocked_gate_flags")
	var migrated: Dictionary = SaveManager.migrate(legacy)
	check(SaveManager.validate(migrated) and migrated.unlocked_gate_flags.get("7",false), "prior saves retain previously unlocked global zones through migration")
	var invalid := SaveManager.snapshot()
	invalid.zone_kill_counts["1"] = 0.5
	check(not SaveManager.validate(invalid), "save rejects fractional kill counts")
	# Shooter movement and attack uses the shared projectile implementation.
	WorldManager.travel(1)
	for enemy in get_tree().get_nodes_in_group("slimerot_enemies"): enemy.set_physics_process(false)
	var shooter: SlimerotEnemy = world.zone_root.get_children().filter(func(n): return n is SlimerotEnemy and n.data.archetype == "shooter")[0]
	shooter.position = Vector2(600,1150)
	shooter.home = shooter.position
	world.player.position = Vector2(500,1150)
	CombatManager.clear_projectiles()
	shooter._physics_process(0.016)
	check(shooter.velocity.x > 0 and CombatManager.get_child_count() == 1, "Shooter backs away and fires a dodgeable projectile")
	var shot: SlimerotProjectile = CombatManager.get_child(0)
	check(shot.hostile and shot.damage == 6 and shot.speed == SlimerotCampaign.ENEMY_SHOT_SPEED, "Z1 Shooter fires fixed six-damage shot")
	shooter.position = Vector2(600,1150)
	world.player.position = Vector2(350,1150)
	shooter._physics_process(0.016)
	check(shooter.velocity.x < 0 and CombatManager.get_child_count() == 1, "Shooter approaches outside preferred range without ignoring own attack timer")
	var before := SlimerotCampaign.enemy(8,"tank")
	GameState.coins = 90000000
	GameState.highest_zone_unlocked = 8
	for index in range(1,19): GameState.purchased_skill_node_ids.append("R%02d" % index)
	var after := SlimerotCampaign.enemy(8,"tank")
	check(before.max_hp == after.max_hp and before.attack_damage == after.attack_damage and before.coin_reward == after.coin_reward, "enemy stats never scale with wealth, luck or world progression")
	fresh(world)
	CombatManager.set_physics_process(true)
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(SaveManager.save_path+suffix)
