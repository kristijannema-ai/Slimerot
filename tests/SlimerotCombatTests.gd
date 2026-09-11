extends Node

var suite: Node
const COSTS := [100,350,600,750,1200,3500,2500,5000,6000,25000,20000,20000,30000,50000,250000,200000,250000,300000,1000000,2000,40000]
const REQUIRES := [[],["C01"],["C01"],["C01"],["C01"],["C05"],[],["C05"],[],["C08"],["C03"],["C04"],["C08"],["C07"],["C13"],["C13"],["C09"],["C11"],["C16","R18"],[],["CO1"]]
const ZONES := [1,1,1,1,1,1,1,1,1,1,4,4,4,5,1,6,1,6,7,2,5]
const BOSSES := [0,0,0,0,0,2,0,0,2,4,0,0,0,0,6,0,6,0,0,0,0]

func check(value: bool, label: String) -> void:
	suite.check(value, label)

func fresh() -> void:
	SaveManager.enabled = false
	InventoryManager.reset()
	RollManager.reset()
	GameState.reset()
	GameState.menu_paused = false
	GameState.suspended = false
	GameState.coins = 3000000
	GameState.coins_earned = 3000000
	GameState.lifetime_rolls = 100000
	GameState.rolls_balance = 100000
	GameState.structure_unlocked_flags.skill_tree_shrine = true
	WorldManager.travel(0)

func run(world: Node, owner_suite: Node) -> void:
	suite = owner_suite
	fresh()
	world.hud.close_menu()
	CombatManager.set_physics_process(false)
	var coin_nodes: Array = SkillTreeManager.nodes.values().filter(func(n): return n.tree_type == "Coin")
	check(coin_nodes.size() == 21, "exactly 19 Coin nodes and two Fleet Feet nodes")
	for index in 21:
		var id := "C%02d" % (index+1) if index < 19 else "CO%d" % (index-18)
		var node: SlimerotData.SkillNodeData = SkillTreeManager.nodes[id]
		check(node.cost == COSTS[index] and node.prerequisite_ids == REQUIRES[index] and node.currency_type == "Coins" and node.required_zone == ZONES[index] and node.required_boss_zone == BOSSES[index], id+" exact canonical cost and gates")
	check(not SkillTreeManager.purchase("C02") and not SkillTreeManager.purchase("C07") and not SkillTreeManager.purchase("CO1"), "Coin prerequisites, Sell Terminal and world gates cannot be bypassed")
	GameState.coins = 99
	check(not SkillTreeManager.purchase("C01") and GameState.coins_spent == 0, "unaffordable Coin purchase changes no accounting")
	GameState.coins = 3000000
	var copy := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME)
	InventoryManager.equip(copy)
	check(InventoryManager.team_dps() == 7, "raw starter DPS uses actual rounded damage")
	check(SkillTreeManager.purchase("C01") and InventoryManager.team_dps() == 8 and GameState.best_team_dps == 8, "purchase instantly updates actual and best Team DPS")
	check(not SkillTreeManager.purchase("C01") and GameState.coins_spent == 100, "repeat Coin purchase cannot charge twice")
	GameState.highest_zone_unlocked = 8
	GameState.structure_unlocked_flags.sell_terminal = true
	for zone in [2,4,6]: GameState.boss_defeated_flags["zone_%d" % zone] = true
	for index in range(2,19): check(SkillTreeManager.purchase("C%02d" % index), "purchase Coin node C%02d" % index)
	check(not SkillTreeManager.purchase("C19"), "Final Bond still requires Breakthrough III")
	for index in range(1,19): SkillTreeManager.purchase("R%02d" % index)
	check(SkillTreeManager.purchase("C19") and SkillTreeManager.purchase("CO1") and SkillTreeManager.purchase("CO2"), "Final Bond and both movement upgrades purchase")
	var stats := SkillTreeManager.derived_stats()
	check(is_equal_approx(stats.damage_multiplier,2.5) and is_equal_approx(stats.boss_damage_bonus,0.5), "Final Bond adds to 2.5x team and Boss Hunter adds to 1.5x bosses")
	check(stats.max_hp == 250 and is_equal_approx(stats.move_speed,216) and stats.equipped_slots == 5, "Toughness 250 HP, Fleet Feet 216 px/s, five-slot cap")
	check(is_equal_approx(stats.coin_scavenger,1) and is_equal_approx(stats.duplicate_dealer,0.75), "Scavenger totals +100%, Dealer totals +75% independently")
	check(GameState.coins_spent == COSTS.reduce(func(a,b): return a+b,0) and GameState.coins == GameState.coins_earned-GameState.coins_spent and GameState.lifetime_rolls == GameState.rolls_balance+SkillTreeManager.rolls_spent(GameState.purchased_skill_node_ids), "all Coin spending counted once and Rolls ledger unchanged by Coin nodes")
	for variant in SlimerotBalance.VARIANTS:
		var id := InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME,variant)
		var mult: float = SlimerotBalance.VARIANT_DATA[variant].damage
		check(InventoryManager.damage_for_copy(id) == roundf(7*mult*2.5) and InventoryManager.damage_for_copy(id,true) == roundf(7*mult*2.5*1.5), variant+" rounds only after base ×variant ×team ×boss")
	InventoryManager.reset()
	var copies: Array[String] = []
	for index in 6: copies.append(InventoryManager.add_copy(SlimerotBalance.FIRST_SLIME))
	for index in 5: check(InventoryManager.equip(copies[index]), "equip distinct owned copy %d of same slime" % index)
	check(not InventoryManager.equip(copies[0]) and not InventoryManager.equip(copies[5]) and not InventoryManager.equip("missing"), "no duplicate physical ID, sixth slot or unowned equip")
	check(InventoryManager.team_dps() == 90, "five rounded 18-damage copies truthfully display 90 DPS")
	InventoryManager.toggle_copy_favorite(copies[5])
	check(InventoryManager.sell_duplicates() == 0 and InventoryManager.sell_copy(copies[0]) == 0, "equipped and favorite copies survive bulk and individual sales")
	InventoryManager.toggle_copy_favorite(copies[5])
	var earned_before := GameState.coins_earned
	check(InventoryManager.sell_copy(copies[5]) == 9 and GameState.coins_earned == earned_before+9, "sale value rounded after +75% Dealer and credited to Coins Earned")
	earned_before = GameState.coins_earned
	WorldManager.record_kill(1,5)
	check(GameState.coins_earned == earned_before+10, "normal enemy gets only Scavenger bonus")
	earned_before = GameState.coins_earned
	check(WorldManager.award_boss_reward(8,100) and not WorldManager.award_boss_reward(8,100) and GameState.coins_earned == earned_before+100, "boss payout fixed, one time, no Coin multipliers")
	InventoryManager.unequip(copies[4])
	check(InventoryManager.team_dps() == 72, "unequip instantly removes physical copy DPS")
	var rare := InventoryManager.add_copy("brainrot_singularity","golden")
	InventoryManager.auto_equip_strongest()
	check(InventoryManager.equipped_copy_ids[0] == rare and InventoryManager.equipped_copy_ids.size() == 5, "Auto Equip fills only available slots with highest rounded DPS copies")
	var snapshot := SaveManager.snapshot()
	check(SaveManager.validate(snapshot), "full Coin/Roll progression validates schema 4")
	SaveManager.enabled = true
	check(SaveManager.save_game() and SaveManager.load_game() and is_equal_approx(SkillTreeManager.derived_stats().damage_multiplier,2.5), "Coin effects and accounting survive JSON save/load without stacking")
	SaveManager.enabled = false
	var legacy := snapshot.duplicate(true)
	legacy.schema_version = 3
	legacy.purchased_skill_node_ids = ["team_slot_2","team_slot_3","team_slot_4","team_slot_5"]
	legacy.roll_skill_spend = {}
	legacy.rolls_balance = legacy.lifetime_rolls
	var migrated: Dictionary = SaveManager.migrate(legacy)
	check(SaveManager.validate(migrated) and SkillTreeManager.derived_stats(migrated.purchased_skill_node_ids).equipped_slots == 5 and migrated.coins == legacy.coins and migrated.coins_spent == legacy.coins_spent, "legacy slots migrate with ancestors, capacity and historical Coin accounting preserved")
	# Controlled physics boundaries, with no live enemies or automatic manager ticks.
	InventoryManager.equipped_copy_ids.clear()
	GameState.player_hp = 250
	CombatManager.damage_player(100)
	CombatManager._physics_process(3.9)
	check(GameState.player_hp == 150, "no regeneration before four damage-free seconds")
	CombatManager._physics_process(0.2)
	check(is_equal_approx(GameState.player_hp,151.25), "regen delay crossing heals only eligible time at 5% max HP/sec")
	CombatManager.damage_player(1)
	CombatManager._physics_process(4)
	check(is_equal_approx(GameState.player_hp,150.25), "fresh damage resets four-second regen delay")
	GameState.menu_paused = true
	CombatManager._physics_process(10)
	check(is_equal_approx(GameState.player_hp,150.25), "pause freezes regen and damage-free timer")
	GameState.menu_paused = false
	CombatManager._physics_process(100)
	check(GameState.player_hp == 250, "regeneration clamps to upgraded max HP")
	var wallet := [GameState.coins,GameState.rolls_balance,GameState.lifetime_rolls]
	var owned := InventoryManager.inventory.duplicate(true)
	CombatManager.damage_player(999)
	CombatManager._physics_process(1.49)
	check(GameState.player_dead and GameState.player_hp == 0 and not RollManager.request_roll(), "death fade lasts 1.5s and prevents extra actions")
	CombatManager._physics_process(0.02)
	check(not GameState.player_dead and GameState.player_hp == 250 and world.player.position == SlimerotBalance.ENTRANCES[0] and wallet == [GameState.coins,GameState.rolls_balance,GameState.lifetime_rolls] and owned == InventoryManager.inventory, "fade completion respawns full HP with zero progression loss")
	world.player.position = Vector2(500,700)
	var enemy := SlimerotEnemy.new()
	enemy.position = Vector2(650,700)
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.hp = 1000
	var shot: SlimerotProjectile = CombatManager.fire_slime_projectile(Vector2(500,700),enemy,18)
	shot.set_physics_process(false)
	shot._physics_process(0.1)
	check(shot.position == Vector2(550,700) and enemy.hp == 1000, "projectile travels 500 px/s and never deals instant damage")
	enemy.position = Vector2(850,700)
	shot._physics_process(0.2)
	check(enemy.hp == 982 and shot.spent, "straight committed projectile guarantees one hit on a moving living target")
	shot._physics_process(1)
	check(enemy.hp == 982, "spent projectile never hits twice")
	shot = CombatManager.fire_slime_projectile(Vector2(500,700),enemy,18)
	shot.set_physics_process(false)
	enemy.dead = true
	shot._physics_process(0.1)
	check(shot.spent and enemy.hp == 982, "projectile disappears when target dies first")
	enemy.dead = false
	InventoryManager.equipped_copy_ids.assign([copies[0],copies[1]])
	enemy.position = CombatManager.slime_position(0) + Vector2(100,0)
	var other := SlimerotEnemy.new()
	other.position = CombatManager.slime_position(1) - Vector2(100,0)
	world.add_child(other)
	other.set_physics_process(false)
	check(CombatManager.find_target(CombatManager.slime_position(0)) == enemy and CombatManager.find_target(CombatManager.slime_position(1)) == other, "each slot independently selects its nearest hostile from its orbit position")
	CombatManager.clear_projectiles()
	CombatManager.attack_timers.clear()
	CombatManager._physics_process(0)
	var shots := CombatManager.get_child_count()
	CombatManager._physics_process(0.99)
	check(shots == 2 and CombatManager.get_child_count() == 2, "two equipped slimes independently fire once, then wait a full second")
	CombatManager._physics_process(0.02)
	check(CombatManager.get_child_count() == 4, "both independent attack timers fire again after one second")
	CombatManager.clear_projectiles()
	world.remove_child(enemy)
	world.remove_child(other)
	enemy.queue_free()
	other.queue_free()
	InventoryManager.equipped_copy_ids.clear()
	GameState.player_hp = 250
	world.player.force_update_transform()
	for frame in 3: await get_tree().physics_frame
	shot = CombatManager.fire_enemy_projectile(Vector2(400,700),Vector2.RIGHT,20)
	shot.set_physics_process(false)
	shot._physics_process(0.3)
	check(GameState.player_hp == 230 and shot.spent, "enemy projectile swept collision damages player through shared HP hook")
	shot = CombatManager.fire_enemy_projectile(Vector2(400,700),Vector2.RIGHT,20)
	shot.set_physics_process(false)
	world.player.position.y += 100
	world.player.force_update_transform()
	for frame in 3: await get_tree().physics_frame
	shot._physics_process(0.3)
	check(GameState.player_hp == 230 and not shot.spent, "movement dodges straight enemy projectile")
	CombatManager.reset_combat()
	InventoryManager.auto_equip_strongest()
	GameState.changed.emit()
	world.hud.breakthrough_seconds = 0
	world.hud.breakthrough_banner.hide()
	world.hud.menus.skill_tab = "Coin"
	world.hud.open_menu("Skills")
	await suite.capture("Slimerot-stage-4-coin-tree")
	world.hud.open_menu("Team")
	await suite.capture("Slimerot-stage-4-team")
	world.hud.close_menu()
	CombatManager.set_physics_process(true)
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(SaveManager.save_path+suffix)
