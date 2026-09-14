extends RefCounted

# Slimerot decision-event estimate, deliberately independent of gameplay managers.
# A result is an assumption-sensitive model, never evidence of a full playthrough.
const MODEL_VERSION := "Slimerot pacing decision-event model 1"
const DEFAULTS := {"seeds": 12, "first_seed": 9001, "horizon_minutes": 360.0,
	"frame_hz": 60.0, "travel_seconds": 2.0, "combat_utilisation": 0.70,
	"boss_utilisation": 0.70, "sale_interval_seconds": 300.0}
const COIN_PRIORITY := ["C01", "C02", "C03", "C04", "C05", "C06", "C07", "C08", "C09",
	"C10", "C11", "C12", "C13", "C14", "C15", "C16", "C17", "C18", "C19"]
const OPTIONAL_AFTER := {"R04": ["RO1"], "R08": ["RO2", "RO3"], "R13": ["RO4", "RO5", "RO6"]}
const TARGETS := {"Z2": [8, 12], "R08": [55, 65], "Z5": [70, 90], "R13": [115, 130],
	"Z7": [135, 155], "R18": [170, 190], "final_boss": [200, 230]}
var options: Dictionary = {}
var roster: Array[Dictionary] = []
var pair_order: Array[Dictionary] = []
var roll_rows: Dictionary = {}
var coin_rows: Dictionary = {}
var campaign_rows: Array = []

func _init() -> void:
	for row in SlimerotRoster.ROWS:
		roster.append({"id": row[0], "zone": row[2], "threshold": row[3],
			"damage": SlimerotRoster.damage(row[3]), "sell": SlimerotRoster.sell_value(row[3])})
	roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.threshold < b.threshold)
	for slime in roster:
		for variant in SlimerotBalance.VARIANTS:
			pair_order.append({"key": str(slime.id) + ":" + str(variant), "slime": slime, "variant": variant,
				"raw_damage": float(slime.damage) * float(SlimerotBalance.VARIANT_DATA[variant].damage)})
	pair_order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.key < b.key if a.raw_damage == b.raw_damage else a.raw_damage > b.raw_damage)
	for row in SlimerotRollTree.MAINLINE + SlimerotRollTree.OPTIONAL: roll_rows[row[0]] = row
	for row in SlimerotCoinTree.ROWS: coin_rows[row[0]] = row

func run(overrides: Dictionary = {}) -> Dictionary:
	options = DEFAULTS.duplicate(true)
	options.merge(overrides, true)
	# Tool-only scenario data is copied; runtime tables and saves are never mutated.
	campaign_rows = options.get("campaign_rows", SlimerotCampaign.ROWS).duplicate(true)
	options.seeds = clampi(int(options.seeds), 1, 100)
	options.horizon_minutes = clampf(float(options.horizon_minutes), 1.0, 720.0)
	options.frame_hz = maxf(1.0, float(options.frame_hz))
	options.travel_seconds = maxf(0.0, float(options.travel_seconds))
	options.combat_utilisation = clampf(float(options.combat_utilisation), 0.05, 1.0)
	options.boss_utilisation = clampf(float(options.boss_utilisation), 0.05, 1.0)
	options.sale_interval_seconds = maxf(30.0, float(options.sale_interval_seconds))
	var policies: Array[Dictionary] = []
	for policy in options.get("policies", [{"id": "mainline_continuous", "optional": false, "roll_uptime": 1.0},
		{"id": "mainline_90_percent", "optional": false, "roll_uptime": 0.9},
		{"id": "convenience_continuous", "optional": true, "roll_uptime": 1.0}]):
		var runs: Array[Dictionary] = []
		for index in int(options.seeds):
			runs.append(_campaign(int(options.first_seed) + index, policy))
		policies.append({"policy": policy, "clock": _roll_clock(policy), "summary": _summary(runs), "runs": runs})
	var constants := {"roll": SlimerotRollTree.MAINLINE, "optional_roll": SlimerotRollTree.OPTIONAL,
		"coin": SlimerotCoinTree.ROWS, "campaign": campaign_rows, "boss": SlimerotEncounters.BOSSES,
		"roster": roster, "attack_interval": SlimerotBalance.ATTACK_INTERVAL,
		"roll_cooldown": SlimerotBalance.ROLL_COOLDOWN, "variant_sense": SlimerotBalance.VARIANT_SENSE_MULTIPLIER,
		"variant": _variant_constants(), "structures": SlimerotEncounters.STRUCTURES,
		"respawn_seconds": SlimerotCampaign.RESPAWN_SECONDS, "move_speed": SlimerotBalance.MOVE_SPEED,
		"zone_travel_distance": SlimerotCampaign.ENTRANCE.distance_to(SlimerotCampaign.EXIT_GATE),
		"super_roll_interval": SlimerotRollTree.SUPER_ROLL_INTERVAL, "super_roll_multiplier": SlimerotRollTree.SUPER_ROLL_MULTIPLIER,
		"default_auto_sell_threshold": SlimerotRollTree.DEFAULT_SELL_THRESHOLD, "maximum_slots": SlimerotBalance.MAX_SLOTS}
	return {"model_version": MODEL_VERSION, "constants_sha256": JSON.stringify(constants).sha256_text(),
		"constants": constants, "assumptions": _assumptions(), "options": options.duplicate(),
		"targets_minutes": TARGETS, "policies": policies, "fixtures": _fixtures(),
		"breakthrough_probability": _breakthrough_probability()}

func _variant_constants() -> Dictionary:
	var result: Dictionary = {}
	for id in SlimerotBalance.VARIANTS:
		var row: Dictionary = SlimerotBalance.VARIANT_DATA[id]
		result[id] = {"chance": row.chance, "damage": row.damage, "sell": row.sell}
	return result

func _assumptions() -> Array[String]:
	return ["Decision events and continuous expected damage; no physics, deaths, dodging, projectile misses, or player skill are simulated.",
		"Start in Z1 with the first guaranteed starter roll at active second zero. Manual rolls before Auto Roll follow the stated uptime.",
		"Auto Roll is independent of combat and movement. Settings pauses active time; other menus can remain live. No menu interaction time is simulated or added to fill target windows.",
		"Every ordinary roll uses the live score=luck/U sampler, separate variant RNG, and immediately equips the strongest owned copies.",
		"No potions, mutations, offline rewards, specific-slime gate requirements, or free currency are assumed.",
		"Safe Chasers are farmed with the stated travel and damage utilisation. Six spawn positions rotate with the live respawn time.",
		"Coin nodes are bought in the stated priority when eligible and affordable; gates are attempted first. Shrine and terminal are repaired as soon as affordable.",
		"Duplicate sales occur at the stated interval. Trips are approximated from zone entrance/exit distance and movement speed; rolls continue during trips.",
		"After repairing the Z4 fast-travel pillar, sale travel and map/menu interaction are assumed instantaneous. Repair-trip time before sales is omitted (optimistic).",
		"Convenience policy buys all canonical optional nodes immediately after their unlock block, except the post-campaign speed node. Their currency delay is explicit.",
		"Zone residence and coin-blocked time after the kill requirement are estimates, not measured grind-wall experience.",
		"Quantiles use nearest rank. Missing milestones remain null and completion counts are reported; unfinished runs are never silently treated as successes."]

func _roll_sequence(convenience: bool) -> Array:
	var result: Array = []
	for row in SlimerotRollTree.MAINLINE:
		result.append(row)
		if convenience:
			for id in OPTIONAL_AFTER.get(row[0], []): result.append(roll_rows[id])
	return result

func _quantised_cooldown(value: float) -> float:
	return ceil(value * float(options.frame_hz) - 0.000001) / float(options.frame_hz)

func _roll_clock(policy: Dictionary) -> Dictionary:
	var rows: Array[Dictionary] = []
	var elapsed := 0.0
	var cooldown := SlimerotBalance.ROLL_COOLDOWN
	var total := 0
	var optional_spend := 0
	for row in _roll_sequence(policy.optional):
		elapsed += float(row[3]) * _quantised_cooldown(cooldown) / float(policy.roll_uptime)
		if total == 0: elapsed -= _quantised_cooldown(cooldown) / float(policy.roll_uptime)
		total += int(row[3])
		if str(row[0]).begins_with("RO"): optional_spend += int(row[3])
		if row[4] == "cooldown_set": cooldown = minf(cooldown, float(row[5]))
		rows.append({"id": row[0], "minutes": elapsed / 60.0, "total_spent": total,
			"optional_spent": optional_spend, "cooldown_seconds": cooldown})
	return {"nodes": rows, "first_roll_seconds": 0.0, "purchase_delay_seconds": 0.0,
		"frame_quantisation_note": "ceil(cooldown * Hz)/Hz; float scheduling jitter and frame stalls are excluded"}

func _stats(owned: Dictionary) -> Dictionary:
	var stats := {"luck": 1.0, "cooldown": SlimerotBalance.ROLL_COOLDOWN,
		"slots": 1, "damage": 1.0, "boss_damage": 1.0, "coin_gain": 1.0, "sale_gain": 1.0,
		"move_speed": SlimerotBalance.MOVE_SPEED, "super_roll": false, "variant_sense": false}
	for id in owned:
		var row: Array = roll_rows.get(id, [])
		if not row.is_empty():
			match row[4]:
				"luck_multiplier", "checkpoint_luck": stats.luck *= float(row[5])
				"cooldown_set": stats.cooldown = minf(stats.cooldown, float(row[5]))
				"super_roll": stats.super_roll = true
				"variant_sense": stats.variant_sense = true
			continue
		row = coin_rows.get(id, [])
		if row.is_empty(): continue
		match row[4]:
			"slot_set": stats.slots = maxi(stats.slots, int(row[5]))
			"team_damage_add": stats.damage += float(row[5])
			"boss_damage_add": stats.boss_damage += float(row[5])
			"coin_scavenger": stats.coin_gain += float(row[5])
			"duplicate_dealer": stats.sale_gain += float(row[5])
			"move_speed_add": stats.move_speed += SlimerotBalance.MOVE_SPEED * float(row[5])
	stats.slots = mini(stats.slots, SlimerotBalance.MAX_SLOTS)
	return stats

func _sample(luck: float, zone: int, rng: RandomNumberGenerator, variants: RandomNumberGenerator, sense: bool) -> Dictionary:
	var score := luck / ((float(rng.randi()) + 1.0) / 4294967296.0)
	var selected: Dictionary = roster[0]
	for slime in roster:
		if slime.zone <= zone and slime.threshold <= score: selected = slime
	var variant := "normal"
	var uniform := float(variants.randi()) / 4294967296.0
	var cumulative := 0.0
	for id in ["golden", "glitched", "shiny"]:
		cumulative += float(SlimerotBalance.VARIANT_DATA[id].chance) * (SlimerotBalance.VARIANT_SENSE_MULTIPLIER if sense else 1.0)
		if uniform < cumulative:
			variant = id
			break
	return {"slime": selected, "variant": variant}

func _team(inventory: Dictionary, stats: Dictionary) -> Dictionary:
	var result := {"dps": 0.0, "boss_dps": 0.0, "strongest_damage": 0.0, "strongest_id": "", "equipped": {}}
	var remaining: int = stats.slots
	# Base-times-variant ordering is immutable; avoid sorting growing inventories on every roll.
	for candidate in pair_order:
		if remaining <= 0: break
		if not inventory.has(candidate.key): continue
		var pair: Dictionary = inventory[candidate.key]
		if int(pair.count) <= 0: continue
		var count := mini(remaining, int(pair.count))
		var raw_damage: float = candidate.raw_damage
		result.dps += count * roundf(raw_damage * float(stats.damage)) / SlimerotBalance.ATTACK_INTERVAL
		result.boss_dps += count * roundf(raw_damage * float(stats.damage) * float(stats.boss_damage)) / SlimerotBalance.ATTACK_INTERVAL
		result.equipped[str(pair.slime.id) + ":" + str(pair.variant)] = count
		if raw_damage > result.strongest_damage:
			result.strongest_damage = raw_damage
			result.strongest_id = str(pair.slime.id) + ":" + str(pair.variant)
		remaining -= count
	return result

func _campaign(seed_value: int, policy: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	var variants := RandomNumberGenerator.new()
	rng.seed = seed_value
	variants.seed = seed_value + 1000003
	var owned: Dictionary = {}
	var inventory: Dictionary = {}
	var stats := _stats(owned)
	var team := _team(inventory, stats)
	var sequence := _roll_sequence(policy.optional)
	var node_index := 0
	var rolls := 0
	var balance := 0
	var coins := 0
	var coin_earned := 0
	var zone := 1
	var kills := 0
	var bosses: Dictionary = {}
	var structures: Dictionary = {}
	var t := 0.0
	var next_roll := 0.0
	var next_sale: float = options.sale_interval_seconds
	var travel_until := 0.0
	var enemy_hp := 0.0
	var fighting_boss := false
	var spawn_cursor := 0
	var spawn_available: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var milestones := {"Z1": 0.0}
	var snapshots: Array[Dictionary] = []
	var windows: Array[Dictionary] = []
	var zone_rows: Array[Dictionary] = []
	var zone_entry := 0.0
	var coin_blocked_at := -1.0
	var horizon: float = options.horizon_minutes * 60.0
	while t < horizon:
		if t >= next_roll - 0.000001:
			var multiplier := SlimerotRollTree.SUPER_ROLL_MULTIPLIER if stats.super_roll and (rolls + 1) % SlimerotRollTree.SUPER_ROLL_INTERVAL == 0 else 1.0
			var result := _sample(float(stats.luck) * multiplier, zone, rng, variants, stats.variant_sense)
			if rolls == 0: result.slime = roster[0]
			var key: String = str(result.slime.id) + ":" + str(result.variant)
			if not inventory.has(key): inventory[key] = {"slime": result.slime, "variant": result.variant, "count": 0}
			inventory[key].count += 1
			rolls += 1
			balance += 1
			if owned.has("RO2") and structures.has("sell_terminal") and result.variant == "normal" and inventory[key].count > 1 and result.slime.threshold <= SlimerotRollTree.DEFAULT_SELL_THRESHOLD:
				# Auto-sale sees the old equipped copy set, just as the live transaction does.
				if int(team.equipped.get(key, 0)) < int(inventory[key].count):
					var sale := roundi(result.slime.sell * float(stats.sale_gain))
					coins += sale
					coin_earned += sale
					inventory[key].count -= 1
			team = _team(inventory, stats)
			next_roll = t + _quantised_cooldown(stats.cooldown) / float(policy.roll_uptime)
		while node_index < sequence.size() and balance >= int(sequence[node_index][3]):
			var node: Array = sequence[node_index]
			balance -= int(node[3])
			owned[node[0]] = true
			node_index += 1
			stats = _stats(owned)
			team = _team(inventory, stats)
			next_roll = minf(next_roll, t + _quantised_cooldown(stats.cooldown) / float(policy.roll_uptime))
			if node[4] == "checkpoint_luck":
				milestones[node[0]] = t / 60.0
				windows.append({"id": node[0], "at_seconds": t, "zone_before": zone,
					"strongest_before": team.strongest_damage, "dps_before": team.dps,
					"noticeably_stronger_within_10m": false, "first_stronger_seconds": null,
					"dps_after_10m": null, "zones_cleared_10m": null})
				snapshots.append(_snapshot(t, zone, rolls, balance, coins, stats, team, str(node[0])))
		for window in windows:
			if t <= float(window.at_seconds) + 600.0 and team.strongest_damage >= float(window.strongest_before) * 1.25:
				if not window.noticeably_stronger_within_10m: window.first_stronger_seconds = t - float(window.at_seconds)
				window.noticeably_stronger_within_10m = true
			if t >= float(window.at_seconds) + 600.0 and window.dps_after_10m == null:
				window.dps_after_10m = team.dps
				window.zones_cleared_10m = zone - int(window.zone_before)
		var zone_data: Array = campaign_rows[zone - 1]
		if kills >= int(zone_data[5]):
			if int(zone_data[7]) > 0 and not bosses.has(zone):
				if not fighting_boss:
					fighting_boss = true
					enemy_hp = float(SlimerotEncounters.BOSSES[zone].hp)
					travel_until = t + float(options.travel_seconds)
			elif coins >= int(zone_data[6]) and zone < 8:
				coins -= int(zone_data[6])
				zone_rows.append({"zone": zone, "entry_minutes": zone_entry / 60.0,
					"exit_minutes": t / 60.0, "residence_minutes": (t - zone_entry) / 60.0,
					"coin_blocked_after_kills_minutes": 0.0 if coin_blocked_at < 0.0 else (t - coin_blocked_at) / 60.0,
					"exit_dps": team.dps, "kills": kills, "same_team_farm": _farm_comparison(zone + 1, stats, team)})
				zone += 1
				zone_entry = t
				coin_blocked_at = -1.0
				kills = 0
				enemy_hp = 0.0
				spawn_available.fill(t)
				travel_until = t + SlimerotCampaign.ENTRANCE.distance_to(SlimerotCampaign.EXIT_GATE) / float(stats.move_speed)
				milestones["Z%d" % zone] = t / 60.0
				snapshots.append(_snapshot(t, zone, rolls, balance, coins, stats, team, "zone_enter"))
				zone_data = campaign_rows[zone - 1]
			elif int(zone_data[7]) == 0 and coin_blocked_at < 0.0:
				coin_blocked_at = t
		# Affordability is enforced for every purchase; priorities are a disclosed policy.
		for repair in SlimerotEncounters.STRUCTURES.slice(0, 2):
			if not structures.has(repair[0]) and coins >= int(repair[2]):
				coins -= int(repair[2])
				structures[repair[0]] = true
		if zone >= 4 and not structures.has("fast_travel_pillar") and coins >= int(SlimerotEncounters.STRUCTURES[3][2]):
			coins -= int(SlimerotEncounters.STRUCTURES[3][2])
			structures.fast_travel_pillar = true
		if structures.has("skill_tree_shrine"):
			for id in COIN_PRIORITY:
				if owned.has(id): continue
				var row: Array = coin_rows[id]
				if zone < int(row[6]) or (int(row[7]) > 0 and not bosses.has(int(row[7]))): continue
				if not str(row[8]).is_empty() and not structures.has(row[8]): continue
				var eligible := true
				for prerequisite in row[2]:
					if not owned.has(prerequisite): eligible = false
				if not eligible or coins < int(row[3]): continue
				coins -= int(row[3])
				owned[id] = true
				stats = _stats(owned)
				team = _team(inventory, stats)
		if t >= next_sale and not fighting_boss:
			next_sale = t + float(options.sale_interval_seconds)
			if structures.has("sell_terminal"):
				var sale_total := 0
				for key in inventory:
					var pair: Dictionary = inventory[key]
					var retain := maxi(1, int(team.equipped.get(key, 0)))
					var count := maxi(0, int(pair.count) - retain)
					sale_total += count * roundi(pair.slime.sell * SlimerotBalance.VARIANT_DATA[pair.variant].sell * float(stats.sale_gain))
					pair.count -= count
				coins += sale_total
				coin_earned += sale_total
				if sale_total > 0:
					var trip := 0.0 if structures.has("fast_travel_pillar") else 2.0 * zone * SlimerotCampaign.ENTRANCE.distance_to(SlimerotCampaign.EXIT_GATE) / float(stats.move_speed)
					travel_until = maxf(travel_until, t + trip)
					enemy_hp = 0.0
		if enemy_hp <= 0.0 and not fighting_boss:
			enemy_hp = float(zone_data[2][0])
			travel_until = maxf(travel_until, maxf(t + float(options.travel_seconds), spawn_available[spawn_cursor]))
		var damage_rate: float = team.boss_dps * float(options.boss_utilisation) if fighting_boss else team.dps * float(options.combat_utilisation)
		var damage_start := maxf(t, travel_until)
		var defeat_time := damage_start + enemy_hp / maxf(0.001, damage_rate)
		var next_event := minf(horizon, minf(next_roll, defeat_time))
		if not fighting_boss and next_sale > t: next_event = minf(next_event, next_sale)
		for window in windows:
			var deadline: float = window.at_seconds + 600.0
			if deadline > t: next_event = minf(next_event, deadline)
		enemy_hp = maxf(0.0, enemy_hp - maxf(0.0, next_event - damage_start) * damage_rate)
		t = next_event
		if t >= defeat_time - 0.000001:
			# Roundoff must never count the same virtually-zero HP enemy twice.
			enemy_hp = 0.0
			if fighting_boss:
				var boss: Dictionary = SlimerotEncounters.BOSSES[zone]
				coins += int(boss.coins)
				coin_earned += int(boss.coins)
				bosses[zone] = true
				fighting_boss = false
				milestones["boss_Z%d" % zone] = t / 60.0
				if zone == 8:
					milestones.final_boss = t / 60.0
					snapshots.append(_snapshot(t, zone, rolls, balance, coins, stats, team, "final_boss"))
					break
			else:
				kills += 1
				var reward := roundi(float(zone_data[3][0]) * float(stats.coin_gain))
				coins += reward
				coin_earned += reward
				spawn_available[spawn_cursor] = t + SlimerotCampaign.RESPAWN_SECONDS
				spawn_cursor = (spawn_cursor + 1) % spawn_available.size()
	return {"seed": seed_value, "completed": milestones.has("final_boss"), "last_minutes": t / 60.0,
		"milestones_minutes": milestones, "snapshots": snapshots, "zones": zone_rows,
		"breakthrough_windows": windows, "coins_earned": coin_earned, "lifetime_rolls": rolls,
		"spendable_rolls": balance, "final_zone": zone, "purchased_nodes": owned.keys()}

func _snapshot(t: float, zone: int, rolls: int, balance: int, coins: int, stats: Dictionary, team: Dictionary, reason: String) -> Dictionary:
	return {"reason": reason, "active_seconds": t, "zone": zone, "lifetime_rolls": rolls,
		"spendable_rolls": balance, "coins": coins, "team_dps": team.dps, "slots": stats.slots,
		"effective_luck": stats.luck, "strongest_owned": team.strongest_id, "strongest_equipped": team.strongest_id}

func _farm_comparison(zone: int, stats: Dictionary, team: Dictionary, zones_back: int = 1) -> Dictionary:
	if zone <= zones_back: return {}
	var rates: Array[float] = []
	for current in [zone - zones_back, zone]:
		var row: Array = campaign_rows[current - 1]
		var seconds: float = options.travel_seconds + float(row[2][0]) / maxf(0.001, float(team.dps) * float(options.combat_utilisation))
		seconds = maxf(seconds, (seconds + SlimerotCampaign.RESPAWN_SECONDS) / 6.0)
		rates.append(60.0 * roundi(float(row[3][0]) * float(stats.coin_gain)) / seconds)
	return {"team_dps": team.dps, "previous_zone_cpm": rates[0], "new_zone_cpm": rates[1],
		"ratio": rates[1] / maxf(0.001, rates[0]), "meets_three_times": rates[1] >= rates[0] * 3.0,
		"new_zone": zone, "comparison_zone": zone - zones_back,
		"scope": "same team, Chasers, equal travel/utilisation, excludes one-off bosses and duplicate sales"}

func _summary(runs: Array[Dictionary]) -> Dictionary:
	var milestones: Dictionary = {}
	for id in TARGETS:
		var values: Array[float] = []
		for run_data in runs:
			if run_data.milestones_minutes.has(id): values.append(run_data.milestones_minutes[id])
		values.sort()
		milestones[id] = {"observed": values.size(), "runs": runs.size(), "min": values[0] if not values.is_empty() else null,
			"p10": _quantile(values, 0.10), "median": _quantile(values, 0.50), "p90": _quantile(values, 0.90),
			"max": values[-1] if not values.is_empty() else null, "target": TARGETS[id]}
	var breakthroughs: Dictionary = {}
	for id in ["R08", "R13", "R18"]:
		var total := 0
		var complete := 0
		var improved := 0
		var clear_counts: Array[float] = []
		for run_data in runs:
			for window in run_data.breakthrough_windows:
				if window.id != id: continue
				total += 1
				if window.dps_after_10m == null: continue
				complete += 1
				if window.noticeably_stronger_within_10m: improved += 1
				clear_counts.append(float(window.zones_cleared_10m))
		clear_counts.sort()
		breakthroughs[id] = {"purchased_runs": total, "complete_10m_windows": complete,
			"stronger_runs": improved, "stronger_fraction": float(improved) / complete if complete > 0 else null,
			"median_zones_cleared_10m": _quantile(clear_counts, 0.5),
			"noticeably_stronger_definition": "one owned copy has at least 25% more base-times-variant damage than the strongest owned at purchase"}
	return {"milestones": milestones, "breakthroughs": breakthroughs}

func _quantile(values: Array[float], fraction: float) -> Variant:
	return null if values.is_empty() else values[clampi(ceili(values.size() * fraction) - 1, 0, values.size() - 1)]

func _fixtures() -> Array[Dictionary]:
	# Explicit normal-copy loadouts, not claims that every player owns them on arrival.
	var rows := [[1, [2], [], "starter"], [2, [75, 120], ["C01", "C02"], "two ordinary Z1/Z2 copies"],
		[3, [700, 800, 120], ["C01", "C02", "C05", "C06", "C08"], "pre-B1 three-copy team"],
		[4, [4000, 4000, 4000], ["C01", "C02", "C05", "C06", "C08", "C09"], "post-B1 Bombardiro team"],
		[5, [15000, 15000, 15000, 15000], ["C01", "C02", "C05", "C06", "C08", "C09", "C10", "C13"], "pre-B2 Girafa team"],
		[6, [60000, 60000, 60000, 60000], ["C01", "C02", "C05", "C06", "C08", "C09", "C10", "C13"], "post-B2 La Vaca team"],
		[7, [250000, 250000, 250000, 250000, 250000], ["C01", "C02", "C05", "C06", "C08", "C09", "C10", "C13", "C15", "C16", "C17"], "pre-B3 Talpa team"],
		[8, [4000000, 4000000, 4000000, 4000000, 4000000], ["C01", "C02", "C05", "C06", "C08", "C09", "C10", "C13", "C15", "C16", "C17", "R18", "C19"], "generous five Normal Singularity / full Coin damage team"]]
	var result: Array[Dictionary] = []
	var previous_fixture_cpm := 0.0
	for fixture in rows:
		var owned: Dictionary = {}
		for id in fixture[2]: owned[id] = true
		var stats := _stats(owned)
		var dps := 0.0
		var boss_dps := 0.0
		for threshold in fixture[1]:
			dps += roundf(SlimerotRoster.damage(threshold) * float(stats.damage)) / SlimerotBalance.ATTACK_INTERVAL
			boss_dps += roundf(SlimerotRoster.damage(threshold) * float(stats.damage) * float(stats.boss_damage)) / SlimerotBalance.ATTACK_INTERVAL
		var zone: int = fixture[0]
		var hp: float = campaign_rows[zone - 1][2][0]
		var boss_hp: float = SlimerotEncounters.BOSSES.get(zone, {}).get("hp", 0.0)
		var fixture_cpm := 60.0 * roundi(float(campaign_rows[zone - 1][3][0]) * float(stats.coin_gain)) / (float(options.travel_seconds) + hp / dps / float(options.combat_utilisation))
		result.append({"zone": zone, "description": fixture[3], "thresholds": fixture[1], "nodes": fixture[2],
			"team_dps": dps, "boss_dps": boss_dps, "chaser_hp": hp, "boss_hp": boss_hp,
			"chaser_seconds_at_full_uptime": hp / dps, "chaser_seconds_at_assumed_utilisation": hp / dps / float(options.combat_utilisation),
			"boss_minutes_at_full_uptime": boss_hp / boss_dps / 60.0 if boss_hp > 0 else null,
			"boss_minutes_at_assumed_utilisation": boss_hp / boss_dps / 60.0 / float(options.boss_utilisation) if boss_hp > 0 else null,
			"same_team_farm": _farm_comparison(zone, stats, {"dps": dps}),
			"same_team_two_zones_back": _farm_comparison(zone, stats, {"dps": dps}, 2),
			"fixture_cpm": fixture_cpm,
			"ratio_to_previous_fixture_cpm": fixture_cpm / previous_fixture_cpm if previous_fixture_cpm > 0.0 else null,
			"different_team_comparison_scope": "each zone uses its own listed normal-copy loadout; this is NOT a same-team backtracking comparison"})
		previous_fixture_cpm = fixture_cpm
	return result

func _breakthrough_probability() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var owned: Dictionary = {}
	for row in SlimerotRollTree.MAINLINE:
		owned[row[0]] = true
		if row[4] != "checkpoint_luck": continue
		var stats := _stats(owned)
		var zone := 3 if row[0] == "R08" else (5 if row[0] == "R13" else 7)
		for target_zone in [zone, zone + 1]:
			var target: Dictionary = roster[0]
			for slime in roster:
				if slime.zone == target_zone: target = slime
			var p := minf(1.0, float(stats.luck) / float(target.threshold))
			var before := minf(1.0, p / float(row[5]))
			var cooldown := _quantised_cooldown(stats.cooldown)
			var rolls_10m := floori(600.0 / cooldown)
			var seeded_before := 0
			var seeded_after := 0
			for index in int(options.seeds):
				var rng := RandomNumberGenerator.new()
				rng.seed = int(options.first_seed) + index
				var hit_before := false
				var hit_after := false
				for roll_index in rolls_10m:
					var uniform := (float(rng.randi()) + 1.0) / 4294967296.0
					hit_before = hit_before or uniform <= before
					hit_after = hit_after or uniform <= p
				if hit_before: seeded_before += 1
				if hit_after: seeded_after += 1
			result.append({"breakthrough": row[0], "slime": target.id, "eligible_zone": target_zone,
				"threshold": target.threshold, "luck_after": stats.luck, "cooldown": cooldown,
				"mean_minutes_after": cooldown / p / 60.0,
				"median_minutes_after": ceil(log(0.5) / log(1.0 - p)) * cooldown / 60.0 if p < 1.0 else cooldown / 60.0,
				"p90_minutes_after": ceil(log(0.1) / log(1.0 - p)) * cooldown / 60.0 if p < 1.0 else cooldown / 60.0,
				"analytic_10m_before": 1.0 - pow(1.0 - before, rolls_10m),
				"analytic_10m_after": 1.0 - pow(1.0 - p, rolls_10m),
				"seeded_10m_before": float(seeded_before) / float(options.seeds),
				"seeded_10m_after": float(seeded_after) / float(options.seeds),
				"scope": "threshold-or-better event; fixed current cooldown/luck, unlocked target zone, no potions, no variants, no future speed purchases; not necessarily an inventory improvement"})
	return result

func text_summary(report: Dictionary) -> String:
	var lines := PackedStringArray(["Slimerot pacing estimate", "Model: " + str(report.model_version),
		"Constants SHA256: " + str(report.constants_sha256), "", "Assumptions:"])
	for assumption in report.assumptions: lines.append("- " + str(assumption))
	lines.append("Options: " + JSON.stringify(report.options))
	for policy in report.policies:
		lines.append("\nPolicy: " + str(policy.policy.id))
		lines.append("Milestone | observed/runs | min | p10 | median | p90 | max | target minutes")
		for id in TARGETS:
			var metric: Dictionary = policy.summary.milestones[id]
			lines.append("%s | %d/%d | %s | %s | %s | %s | %s | %s" % [id, metric.observed, metric.runs,
				_number(metric.min), _number(metric.p10), _number(metric.median), _number(metric.p90), _number(metric.max), str(metric.target)])
		lines.append("Breakthrough 10-minute windows: " + JSON.stringify(policy.summary.breakthroughs))
	lines.append("\nNormal-copy fixtures (full damage uptime):")
	for fixture in report.fixtures:
		lines.append("Z%d: %s; DPS %.1f; Chaser %.2fs; boss %s min; same-team new/old CPM %s" % [fixture.zone,
			fixture.description, fixture.team_dps, fixture.chaser_seconds_at_full_uptime,
			_number(fixture.boss_minutes_at_full_uptime), _number(fixture.same_team_farm.get("ratio"))])
	lines.append("\nA real full playthrough is still required. See JSON for raw runs, wall residence, fixtures, probability bounds, and clock costs.")
	return "\n".join(lines) + "\n"

func _number(value: Variant) -> String:
	return "unreached" if value == null else "%.2f" % float(value)
