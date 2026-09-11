class_name SlimerotCampaign
extends RefCounted

const TILE_SIZE := 50
const TILE_COUNT := Vector2i(20,30)
const SIZE := Vector2(1000,1500)
const ENTRANCE := Vector2(500,1350)
const RETURN_GATE := Vector2(500,1420)
const EXIT_GATE := Vector2(500,180)
const RETURN_ARRIVAL := Vector2(500,300)
const ARCHETYPES := ["chaser","shooter","tank"]
# Name, level range, HP / Coins / damage by archetype, kills, gate Coins, boss zone.
const ROWS := [
	["Backyard",[1,3],[45,70,130],[5,7,10],[8,6,12],12,150,0],
	["Italian Village",[4,7],[180,280,520],[18,25,40],[12,10,18],20,900,2],
	["Cursed Forest",[8,12],[700,1100,2000],[65,90,150],[18,15,26],40,4000,0],
	["Sahara",[13,18],[2600,4000,7500],[250,350,600],[26,22,38],30,18000,4],
	["Brainrot City",[19,26],[9000,14000,26000],[900,1300,2200],[38,32,55],60,75000,0],
	["Backrooms",[27,36],[30000,48000,90000],[3500,5000,8500],[55,45,80],40,300000,6],
	["Moon",[37,48],[95000,150000,280000],[14000,20000,34000],[75,65,110],90,1200000,0],
	["Brainrot Dimension",[49,65],[300000,480000,900000],[55000,80000,140000],[100,85,150],100,0,8],
]
const SCENES := ["SlimerotBedroom","SlimerotBackyard","SlimerotItalianVillage","SlimerotCursedForest","SlimerotSahara","SlimerotBrainrotCity","SlimerotBackrooms","SlimerotMoon","SlimerotBrainrotDimension"]
const PALETTES := [
	["304e43","637364","46795a","d795a6"],
	["765946","bca583","bb775f","e0b786"],
	["223a3b","455253","52604a","a2a373"],
	["b88a54","dbbd7c","907149","dcb383"],
	["283345","4a5266","4c416b","ce86bb"],
	["696044","968959","797251","b6c877"],
	["343a52","69708a","8a91a5","b4b9dc"],
	["2c2146","584273","805696","d387e4"],
]
# Behavior values are explicit tuning knobs; HP/damage/reward rows above are canonical.
const SPEEDS := [75.0,60.0,32.0]
const INTERVALS := [1.0,1.8,1.6]
const AGGRO_RANGE := 300.0
const LEASH_RANGE := 400.0
const SHOOTER_NEAR := 125.0
const SHOOTER_FAR := 230.0
const ENEMY_SHOT_SPEED := 240.0
const RESPAWN_SECONDS := 5.0

static func zone(id: int) -> SlimerotData.ZoneData:
	var result := SlimerotData.ZoneData.new()
	result.id = id
	if id == 0:
		result.name = "Bedroom Hub"
		return result
	var row: Array = ROWS[id-1]
	result.name = row[0]
	result.enemy_level_range = Vector2i(row[1][0],row[1][1])
	result.kill_requirement = row[5]
	result.gate_coin_cost = row[6]
	result.boss_id_or_null = "zone_%d" % id if row[7] > 0 else ""
	for slime in SlimerotRoster.ROWS:
		if slime[2] == id: result.slime_unlock_ids.append(slime[0])
	return result

static func enemy(zone_id: int, archetype: String) -> SlimerotData.EnemyData:
	var index := ARCHETYPES.find(archetype)
	assert(zone_id >= 1 and zone_id <= 8 and index >= 0)
	var row: Array = ROWS[zone_id-1]
	var result := SlimerotData.EnemyData.new()
	result.id = "lagling" if zone_id == 1 and index == 0 else "slimerot_z%d_%s" % [zone_id,archetype]
	result.zone = zone_id
	result.archetype = archetype
	result.level = row[1][index if index < 2 else 1] if index != 1 else roundi((row[1][0]+row[1][1])*0.5)
	result.max_hp = row[2][index]
	result.coin_reward = row[3][index]
	result.attack_damage = row[4][index]
	result.move_speed = SPEEDS[index]
	result.attack_interval = INTERVALS[index]
	return result

static func wall_hint(zone_id: int) -> String:
	match zone_id:
		3: return "Farm the forest loop, upgrade your team, and work toward RNG Overdrive."
		5: return "Chasers and Shooters offer a safer farm. Viral Cascade is your next luck leap."
		7: return "Use the outer Moon loop, improve your team, and reach Singularity RNG."
	return "Keep rolling, farm nearby enemies, and upgrade your team."
