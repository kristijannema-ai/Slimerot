class_name SlimerotAssets
extends RefCounted

# Optional presentation resources are cached once, including missing paths.
# Keep the canonical Slimerot_* stem; PNG/WebP overrides take priority over SVG.
const ART_ROOT := "res://assets/art/"
const AUDIO_ROOT := "res://assets/audio/"
const ATTACK_SQUASH_SECONDS := 0.12
const ZONE_IDS := ["backyard", "italian_village", "cursed_forest", "sahara", "brainrot_city", "backrooms", "moon", "brainrot_dimension"]
const ICON_IDS := ["coins", "rolls", "luck", "hp", "auto", "team", "inventory", "collection", "skills", "settings"]
const AUDIO_IDS := ["exploration", "boss", "roll", "rare", "jackpot", "hit", "enemy_death", "purchase", "gate", "breakthrough"]
static var _textures: Dictionary = {}
static var _streams: Dictionary = {}
static var _paths: Dictionary = {}

static func resolve_path(stem: String, extensions: Array) -> String:
	var key := stem + str(extensions)
	if _paths.has(key): return _paths[key]
	for extension in extensions:
		var path := stem + "." + str(extension)
		if ResourceLoader.exists(path):
			_paths[key] = path
			return path
	_paths[key] = ""
	return ""

static func texture_path(group: String, id: String) -> String:
	return resolve_path(ART_ROOT + group + "/Slimerot_" + id, ["png", "webp", "svg"])

static func texture(group: String, id: String) -> Texture2D:
	return optional_texture(texture_path(group, id))

static func optional_texture(path: String) -> Texture2D:
	if _textures.has(path): return _textures[path]
	var result: Texture2D = null
	if not path.is_empty() and ResourceLoader.exists(path):
		result = ResourceLoader.load(path) as Texture2D
	_textures[path] = result
	return result

static func optional_audio(path: String, looping: bool = false) -> AudioStream:
	var key := path + str(looping)
	if _streams.has(key): return _streams[key]
	var result: AudioStream = null
	if not path.is_empty() and ResourceLoader.exists(path):
		var loaded := ResourceLoader.load(path) as AudioStream
		if loaded != null:
			result = loaded.duplicate() as AudioStream
			if result is AudioStreamWAV:
				result.loop_mode = AudioStreamWAV.LOOP_FORWARD if looping else AudioStreamWAV.LOOP_DISABLED
				result.loop_begin = 0
				result.loop_end = roundi(result.get_length() * result.mix_rate)
			elif result is AudioStreamOggVorbis or result is AudioStreamMP3:
				result.loop = looping
	_streams[key] = result
	return result

static func audio(id: String, looping: bool = false) -> AudioStream:
	return optional_audio(resolve_path(AUDIO_ROOT + "Slimerot_" + id, ["ogg", "mp3", "wav"]), looping)

static func slime_path(id: String) -> String:
	return texture_path("slimes", id)

static func slime(id: String) -> Texture2D:
	return texture("slimes", id)

static func icon(id: String) -> Texture2D:
	return texture("ui", id)

static func enemy(zone_id: int, archetype: String) -> Texture2D:
	return texture("enemies", "z%d_%s" % [zone_id, archetype])

static func boss(zone_id: int) -> Texture2D:
	if not SlimerotEncounters.BOSSES.has(zone_id): return null
	return texture("bosses", str(SlimerotEncounters.BOSSES[zone_id].id))

static func structure(id: String) -> Texture2D:
	return texture("structures", id)

static func zone(zone_id: int) -> Texture2D:
	if zone_id < 1 or zone_id > ZONE_IDS.size(): return null
	return texture("zones", ZONE_IDS[zone_id - 1])

static func clear_cache() -> void:
	_textures.clear()
	_streams.clear()
	_paths.clear()
