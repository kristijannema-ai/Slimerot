class_name SlimerotAudio
extends Node

# SlimerotSound is the optional, presentation-only autoload. Gameplay never waits
# for audio. Eight reusable voices bound mobile allocation and effect overlap.
const MAX_VOICES := 8
const CUE_IDS := ["roll", "rare", "jackpot", "hit", "enemy_death", "purchase", "gate", "breakthrough"]
const CUE_COOLDOWNS := {"hit": 0.075, "enemy_death": 0.09, "roll": 0.05}
var voices: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var current_track := ""
var cue_last_played: Dictionary = {}
var previous_hp := 0.0
var next_voice := 0
var playback_enabled := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Headless validation has no speaker/mixer; still load and validate every resource.
	playback_enabled = DisplayServer.get_name() != "headless"
	music = AudioStreamPlayer.new()
	music.name = "SlimerotMusic"
	add_child(music)
	for index in MAX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "SlimerotEffect%d" % index
		add_child(voice)
		voices.append(voice)
	previous_hp = GameState.player_hp
	GameState.changed.connect(_state_changed)
	GameState.critical_change.connect(_critical_change)
	RollManager.result_committed.connect(func(_result: Dictionary): play_cue("roll"))
	RollManager.revealed.connect(_revealed)
	SkillTreeManager.purchased.connect(_purchased)
	WorldManager.boss_requested.connect(func(_zone: int): set_track("boss"))
	WorldManager.zone_changed.connect(func(_zone: int): set_track("exploration"))
	apply_settings()
	set_track("exploration")

func _process(_delta: float) -> void:
	var wanted := "boss" if WorldManager.boss_active else "exploration"
	if wanted != current_track: set_track(wanted)
	if music != null: music.stream_paused = GameState.suspended
	for voice in voices: voice.stream_paused = GameState.suspended

func apply_settings() -> void:
	var master := clampf(float(GameState.settings.get("master_audio", 1.0)), 0.0, 1.0)
	var music_gain := master * clampf(float(GameState.settings.get("music_audio", 0.7)), 0.0, 1.0)
	var sfx_gain := master * clampf(float(GameState.settings.get("sfx_audio", 1.0)), 0.0, 1.0)
	if music != null: music.volume_linear = music_gain
	for voice in voices: voice.volume_linear = sfx_gain

func set_track(id: String) -> void:
	if music == null or current_track == id: return
	current_track = id
	music.stop()
	music.stream = SlimerotAssets.audio(id, true)
	if music.stream != null and playback_enabled: music.play()

func play_cue(id: String) -> bool:
	if voices.is_empty() or GameState.suspended: return false
	var now := Time.get_ticks_msec() * 0.001
	if now - float(cue_last_played.get(id, -1000.0)) < float(CUE_COOLDOWNS.get(id, 0.0)): return false
	var stream := SlimerotAssets.audio(id)
	if stream == null: return false
	var chosen := next_voice
	for index in voices.size():
		if not voices[index].playing:
			chosen = index
			break
	var voice := voices[chosen]
	voice.stop()
	voice.stream = stream
	if playback_enabled: voice.play()
	next_voice = (chosen + 1) % MAX_VOICES
	cue_last_played[id] = now
	return true

func _state_changed() -> void:
	if GameState.player_hp < previous_hp and not GameState.player_dead: play_cue("hit")
	if GameState.player_hp < previous_hp and GameState.player_dead: play_cue("enemy_death")
	previous_hp = GameState.player_hp
	apply_settings()

func _critical_change(reason: String) -> void:
	if reason == "settings": apply_settings()
	elif reason in ["gate_purchase", "completion_portal"]: play_cue("gate")
	elif reason in ["structure_purchase", "potion_craft", "mutation"]: play_cue("purchase")
	elif reason == "boss_defeat": play_cue("enemy_death")

func _revealed(_slime_id: String, _variant: String, _first: bool) -> void:
	var threshold := int(RollManager.active_reveal.get("threshold", 0))
	if threshold >= 1000000: play_cue("jackpot")
	elif threshold >= 100: play_cue("rare")

func _purchased(id: String, _before: float, _after: float) -> void:
	var data: SlimerotData.SkillNodeData = SkillTreeManager.nodes.get(id)
	play_cue("breakthrough" if data != null and data.effect_type == "checkpoint_luck" else "purchase")

func _exit_tree() -> void:
	# Release active playbacks before the audio server shuts down.
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	for voice in voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
	SlimerotAssets.clear_cache()
