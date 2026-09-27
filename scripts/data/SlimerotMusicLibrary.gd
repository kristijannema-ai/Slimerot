class_name SlimerotMusicLibrary
extends RefCounted

# Slimerot's original soundtrack stays local and independent of progression/save data.
const MUSIC_ROOT := "res://assets/audio/music/"
const CROSSFADE_SECONDS := 0.9
const FALLBACK_TRACK := "bedroom"
const TRACK_IDS := [
	"bedroom", "backyard", "italian_village", "cursed_forest", "sahara",
	"brainrot_city", "backrooms", "moon", "brainrot_dimension", "battle", "final_battle",
]
const WORLD_TRACKS := {
	0: "bedroom", 1: "backyard", 2: "italian_village", 3: "cursed_forest",
	4: "sahara", 5: "brainrot_city", 6: "backrooms", 7: "moon", 8: "brainrot_dimension",
}
const BOSS_TRACKS := {2: "battle", 4: "battle", 6: "battle", 8: "final_battle"}

static func has_track(id: String) -> bool:
	return id in TRACK_IDS

static func world_track(zone_id: int) -> String:
	return str(WORLD_TRACKS.get(zone_id, FALLBACK_TRACK))

static func desired_track(zone_id: int, boss_active: bool) -> String:
	return str(BOSS_TRACKS.get(zone_id, world_track(zone_id))) if boss_active else world_track(zone_id)

static func track_path(id: String) -> String:
	return MUSIC_ROOT + "Slimerot_" + id + ".ogg" if has_track(id) else ""
