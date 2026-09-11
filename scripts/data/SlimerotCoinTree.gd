class_name SlimerotCoinTree
extends RefCounted

# Slimerot canonical Coin rows: ID, name, prerequisites, cost, effect, value, zone, boss, structure.
const ROWS := [
	["C01","Slime Bond I",[],100,"team_damage_add",0.10,1,0,""],
	["C02","Equipped Slot 2",["C01"],350,"slot_set",2,1,0,""],
	["C03","Coin Scavenger I",["C01"],600,"coin_scavenger",0.20,1,0,""],
	["C04","Toughness I",["C01"],750,"hp_add",50,1,0,""],
	["C05","Slime Bond II",["C01"],1200,"team_damage_add",0.15,1,0,""],
	["C06","Equipped Slot 3",["C05"],3500,"slot_set",3,1,2,""],
	["C07","Duplicate Dealer I",[],2500,"duplicate_dealer",0.25,1,0,"sell_terminal"],
	["C08","Slime Bond III",["C05"],5000,"team_damage_add",0.20,1,0,""],
	["C09","Boss Hunter I",[],6000,"boss_damage_add",0.20,1,2,""],
	["C10","Equipped Slot 4",["C08"],25000,"slot_set",4,1,4,""],
	["C11","Coin Scavenger II",["C03"],20000,"coin_scavenger",0.30,4,0,""],
	["C12","Toughness II",["C04"],20000,"hp_add",100,4,0,""],
	["C13","Slime Bond IV",["C08"],30000,"team_damage_add",0.25,4,0,""],
	["C14","Duplicate Dealer II",["C07"],50000,"duplicate_dealer",0.50,5,0,""],
	["C15","Equipped Slot 5",["C13"],250000,"slot_set",5,1,6,""],
	["C16","Slime Bond V",["C13"],200000,"team_damage_add",0.30,6,0,""],
	["C17","Boss Hunter II",["C09"],250000,"boss_damage_add",0.30,1,6,""],
	["C18","Coin Scavenger III",["C11"],300000,"coin_scavenger",0.50,6,0,""],
	["C19","Final Bond",["C16","R18"],1000000,"team_damage_add",0.50,7,0,""],
	["CO1","Fleet Feet I",[],2000,"move_speed_add",0.10,2,0,""],
	["CO2","Fleet Feet II",["CO1"],40000,"move_speed_add",0.10,5,0,""],
]
const LEGACY_SLOTS := {"team_slot_2":"C02","team_slot_3":"C06","team_slot_4":"C10","team_slot_5":"C15"}
const LEGACY_COSTS := {"team_slot_2":350,"team_slot_3":3500,"team_slot_4":25000,"team_slot_5":250000}

static func description(effect: String, value: float) -> String:
	match effect:
		"team_damage_add": return "Team damage +%d%% (additive)" % roundi(value*100)
		"boss_damage_add": return "Boss damage +%d%% (additive Boss Hunter bonus)" % roundi(value*100)
		"coin_scavenger": return "Normal-enemy Coins +%d%% (additive)" % roundi(value*100)
		"duplicate_dealer": return "Duplicate sale Coins +%d%% (additive)" % roundi(value*100)
		"hp_add": return "Max HP +%d" % int(value)
		"move_speed_add": return "Movement speed +%d%% of base" % roundi(value*100)
		"slot_set": return "Unlock %d equipped slots" % int(value)
	return ""
