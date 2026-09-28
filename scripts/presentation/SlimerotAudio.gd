class_name SlimerotAudio
extends Node

# SlimerotSound is the optional, presentation-only autoload. Gameplay never waits
# for audio. Eight effects and two reusable music players bound mobile allocation.
const MAX_VOICES := 8
const CUE_IDS := ["roll", "rare", "jackpot", "hit", "enemy_death", "purchase", "gate", "breakthrough"]
const CUE_COOLDOWNS := {"hit": 0.075, "enemy_death": 0.09, "roll": 0.05}
var voices: Array[AudioStreamPlayer] = []
# Compatibility alias for the destination of the current music transition.
var music: AudioStreamPlayer
var music_players: Array[AudioStreamPlayer] = []
var music_levels: Array[float] = [0.0, 0.0]
var music_track_ids: Array[String] = ["", ""]
var current_track := ""
var requested_track := ""
var fade_elapsed := 0.0
var fading := false
var _fade_from: Array[float] = [0.0, 0.0]
var _target_channel := 0
var cue_last_played: Dictionary = {}
var previous_hp := 0.0
var next_voice := 0
var playback_enabled := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Headless validation has no speaker/mixer; still load and validate every resource.
	playback_enabled = DisplayServer.get_name() != "headless"
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.name = "SlimerotMusic%d" % index
		add_child(player)
		music_players.append(player)
	music = music_players[0]
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
	WorldManager.boss_requested.connect(func(_zone: int): refresh_track())
	WorldManager.zone_changed.connect(func(_zone: int): refresh_track())
	apply_settings()
	refresh_track()

func _process(delta: float) -> void:
	refresh_track()
	for player in music_players: player.stream_paused = GameState.suspended
	for voice in voices: voice.stream_paused = GameState.suspended
	# Freeze both envelopes and playback while Android is backgrounded. Ordinary
	# menus leave the current music playing, as they did before world-specific music.
	if not GameState.suspended: advance_crossfade(delta)

func refresh_track() -> void:
	set_track(SlimerotMusicLibrary.desired_track(GameState.current_zone, WorldManager.boss_active))

func apply_settings() -> void:
	var master := clampf(float(GameState.settings.get("master_audio", 1.0)), 0.0, 1.0)
	var music_gain := master * clampf(float(GameState.settings.get("music_audio", 0.7)), 0.0, 1.0)
	var sfx_gain := master * clampf(float(GameState.settings.get("sfx_audio", 1.0)), 0.0, 1.0)
	for index in music_players.size(): music_players[index].volume_linear = music_gain * music_levels[index]
	for voice in voices: voice.volume_linear = sfx_gain

func set_track(id: String) -> void:
	if music_players.size() != 2 or requested_track == id: return
	requested_track = id
	var resolved_id := id if SlimerotMusicLibrary.has_track(id) else SlimerotMusicLibrary.FALLBACK_TRACK
	var stream := SlimerotAssets.music(resolved_id)
	if stream == null:
		resolved_id = SlimerotMusicLibrary.FALLBACK_TRACK
		stream = SlimerotAssets.music(resolved_id)
	if stream == null: resolved_id = ""
	if current_track == resolved_id: return
	current_track = resolved_id
	# Returning through a gate during a fade reverses the envelope without restarting
	# a still-playing loop. Other rapid transitions reuse the quieter of two players.
	var destination := music_track_ids.find(resolved_id) if not resolved_id.is_empty() else -1
	if destination < 0:
		destination = 0 if music_levels[0] <= music_levels[1] else 1
		var player := music_players[destination]
		player.stop()
		player.stream = stream
		# Set silence before play() so the audio thread cannot render a new song at
		# the reused channel's previous gain, even during very fast gate changes.
		player.volume_linear = 0.0
		music_track_ids[destination] = resolved_id
		music_levels[destination] = 0.0
		if stream != null and playback_enabled: player.play()
		player.stream_paused = GameState.suspended
	_target_channel = destination
	music = music_players[destination]
	_fade_from.assign(music_levels)
	fade_elapsed = 0.0
	fading = true
	apply_settings()

func advance_crossfade(delta: float) -> void:
	if not fading or GameState.suspended: return
	fade_elapsed = minf(fade_elapsed + maxf(delta, 0.0), SlimerotMusicLibrary.CROSSFADE_SECONDS)
	var progress := fade_elapsed / SlimerotMusicLibrary.CROSSFADE_SECONDS
	for index in music_players.size():
		var target := 1.0 if index == _target_channel and not current_track.is_empty() else 0.0
		music_levels[index] = lerpf(_fade_from[index], target, progress)
	if progress >= 1.0:
		fading = false
		for index in music_players.size():
			if index == _target_channel and not current_track.is_empty(): continue
			music_players[index].stop()
			music_players[index].stream = null
			music_track_ids[index] = ""
	apply_settings()

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
	elif reason in ["structure_purchase", "potion_craft", "variant_sacrifice"]: play_cue("purchase")
	elif reason == "boss_defeat": play_cue("enemy_death")

func _revealed(_slime_id: String, _variant: String, _first: bool) -> void:
	var tier := int(RollManager.active_reveal.get("tier", 0))
	if tier >= 4: play_cue("jackpot")
	elif tier >= 2: play_cue("rare")

func _purchased(id: String, _before: float, _after: float) -> void:
	var data: SlimerotData.SkillNodeData = SkillTreeManager.nodes.get(id)
	play_cue("breakthrough" if data != null and data.effect_type == "checkpoint_luck" else "purchase")

func _exit_tree() -> void:
	# Release active playbacks before the audio server shuts down.
	for player in music_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	for voice in voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
	SlimerotAssets.clear_cache()
