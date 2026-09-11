class_name SlimerotEncounters
extends RefCounted

const BOSSES := {
	2:{"id":"espresso_golem","name":"Espresso Golem","hp":3000,"contact":16,"slam":24,"shot":0,"aoe":0,"coins":1000,"potion":"lucky_soda","speed":65.0},
	4:{"id":"sand_router","name":"Sand Router","hp":50000,"contact":35,"slam":0,"shot":50,"aoe":0,"coins":20000,"potion":"hyper_soda","speed":70.0},
	6:{"id":"backrooms_janitor","name":"Backrooms Janitor","hp":650000,"contact":65,"slam":0,"shot":80,"aoe":0,"coins":350000,"potion":"","speed":0.0},
	8:{"id":"singularity_admin","name":"Singularity Admin","hp":7500000,"contact":110,"slam":0,"shot":140,"aoe":170,"coins":6000000,"potion":"","speed":75.0},
}
# id, location, Coins, function, interaction position.
const STRUCTURES := [
	["skill_tree_shrine",0,25,"skill_tree",Vector2(450,500)],
	["sell_terminal",0,75,"sell_duplicates",Vector2(770,500)],
	["potion_bench",2,900,"potions",Vector2(780,970)],
	["fast_travel_pillar",4,15000,"fast_travel",Vector2(780,970)],
	["mutation_lab",6,250000,"mutation",Vector2(780,970)],
]
const POTIONS := {
	"lucky_soda":{"name":"Lucky Soda","cost":300,"boss":0,"luck":2.0},
	"hyper_soda":{"name":"Hyper Soda","cost":8000,"boss":4,"luck":3.0},
	"boss_brew":{"name":"Boss Brew","cost":30000,"boss":6,"luck":1.0},
}
const POTION_SECONDS := 300.0
const BREW_MULTIPLIER := 1.25
const MUTATION_COPIES := 5
const MUTATION_FEE_MULTIPLIER := 20
const ARENA_ORIGIN := Vector2(1200,0)
const ARENA_SIZE := Vector2(900,1200)
const RESET_BOUNDARY := Rect2(45,55,810,1090)
const PLAYER_START := Vector2(450,930)
const BOSS_START := Vector2(450,550)
const TELEPORT_POINTS := [Vector2(220,360),Vector2(680,360),Vector2(220,770),Vector2(680,770)]
const SHOT_SPEED := 250.0
const SLAM_RADIUS := 150.0
const AOE_RADIUS := 85.0
const AOE_WARNING := 1.2
