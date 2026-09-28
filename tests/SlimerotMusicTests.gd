extends Node

# Slimerot soundtrack tests exercise real world/arena signals without user saves.
const WORLD_TRACKS := ["bedroom", "backyard", "italian_village", "cursed_forest", "sahara", "brainrot_city", "backrooms", "moon", "brainrot_dimension"]
var suite: Node
var world: Node
var sound: SlimerotAudio

func check(condition: bool, description: String) -> void:
	suite.check(condition, "Music · " + description)

func settled() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func run(owner_world: Node, owner_suite: Node) -> void:
	world = owner_world
	suite = owner_suite
	sound = get_node("/root/SlimerotSound") as SlimerotAudio
	SaveManager.enabled = false
	world.hud.close_menu()
	var processing := [GameState.is_processing(), RollManager.is_processing(), CombatManager.is_physics_processing(), sound.is_processing()]
	GameState.set_process(false)
	RollManager.set_process(false)
	CombatManager.set_physics_process(false)
	sound.set_process(false)
	GameState.reset()
	InventoryManager.reset()
	RollManager.reset()
	GameState.suspended = false
	GameState.highest_zone_unlocked = 8
	WorldManager.travel(0)
	await settled()
	test_catalogue()
	await test_world_selection()
	await test_encounter_selection()
	await test_crossfades()
	await test_settings_and_lifecycle()
	test_missing_music()
	test_bounded_switching()
	GameState.suspended = false
	WorldManager.travel(0)
	GameState.reset()
	InventoryManager.reset()
	RollManager.reset()
	sound.refresh_track()
	sound.advance_crossfade(SlimerotMusicLibrary.CROSSFADE_SECONDS)
	await settled()
	GameState.set_process(processing[0])
	RollManager.set_process(processing[1])
	CombatManager.set_physics_process(processing[2])
	sound.set_process(processing[3])

func test_catalogue() -> void:
	check(SlimerotMusicLibrary.TRACK_IDS.size() == 11 and SlimerotMusicLibrary.WORLD_TRACKS.size() == 9, "nine world tracks plus two battle tracks are registered")
	check(SlimerotAssets.AUDIO_IDS.size() == 8, "sound effect catalogue remains exactly eight cues")
	var unique_files := {}
	for id in SlimerotMusicLibrary.TRACK_IDS:
		var stream := SlimerotAssets.music(id)
		check(stream is AudioStreamOggVorbis and stream.loop and stream.get_length() >= 30.0, "%s is a complete local Ogg loop of at least 30 seconds" % id)
		if stream != null:
			check(SlimerotAssets.music(id) == stream, "%s shares its cached compressed stream" % id)
		var path := SlimerotMusicLibrary.track_path(id)
		unique_files[FileAccess.get_sha256(path)] = true
	check(unique_files.size() == 11 and not unique_files.has(""), "all eleven compositions have distinct nonempty local files")
	check(not ResourceLoader.exists("res://assets/audio/Slimerot_exploration.wav") and not ResourceLoader.exists("res://assets/audio/Slimerot_boss.wav"), "replaced short exploration/boss loops are absent")
	check(SlimerotMusicLibrary.world_track(-1) == "bedroom" and SlimerotMusicLibrary.world_track(99) == "bedroom", "invalid world metadata has a safe Bedroom fallback")
	check(SlimerotMusicLibrary.desired_track(1, true) == "backyard", "normal zones retain their world theme even with unexpected boss metadata")

func test_world_selection() -> void:
	var played := {}
	for zone in range(9):
		check(WorldManager.travel(zone), "Z%d world transition accepted" % zone)
		await settled()
		check(sound.current_track == WORLD_TRACKS[zone] and sound.music.stream == SlimerotAssets.music(WORLD_TRACKS[zone]), "Z%d transition selects its own music through the live zone signal" % zone)
		played[sound.current_track] = true
		sound.advance_crossfade(SlimerotMusicLibrary.CROSSFADE_SECONDS)
	check(played.size() == 9, "the Hub and every campaign world have distinct themes")
	GameState.structure_unlocked_flags.fast_travel_pillar = true
	check(WorldManager.fast_travel(7) and sound.current_track == "moon", "Fast Travel uses the same world soundtrack selection")
	await settled()
	var player := sound.music
	var stream := sound.music.stream
	sound.advance_crossfade(SlimerotMusicLibrary.CROSSFADE_SECONDS)
	var fade_time := sound.fade_elapsed
	WorldManager.respawn()
	sound.refresh_track()
	check(sound.music == player and sound.music.stream == stream and sound.fade_elapsed == fade_time and not sound.fading, "respawn/current-world refresh preserves the current loop")

func test_encounter_selection() -> void:
	for zone in [2, 4, 6, 8]:
		WorldManager.travel(zone)
		await settled()
		GameState.zone_kill_counts[str(zone)] = SlimerotCampaign.zone(zone).kill_requirement
		check(WorldManager.start_boss(zone), "Z%d real boss encounter starts" % zone)
		var expected := "final_battle" if zone == 8 else "battle"
		check(sound.current_track == expected, "Z%d boss request selects %s" % [zone, expected])
		world.arena.end_fight(false, false)
		sound._process(0.0)
		check(sound.current_track == WORLD_TRACKS[zone], "Z%d retreat returns to the local world theme" % zone)
		await settled()
	# Final victory must also restore exploration during endless free-roam.
	check(WorldManager.start_boss(8), "final boss can be retried after a reset")
	world.arena.end_fight(true, false)
	sound._process(0.0)
	check(GameState.completion_portal_unlocked and sound.current_track == "brainrot_dimension", "final victory restores the Dimension theme with the completion portal open")
	await settled()

func test_crossfades() -> void:
	sound.set_track("bedroom")
	sound.advance_crossfade(SlimerotMusicLibrary.CROSSFADE_SECONDS)
	var bedroom_channel := sound.music
	sound.set_track("backyard")
	check(sound.music != bedroom_channel and sound.music_players.size() == 2, "entering a different world uses the second reusable music channel")
	sound.advance_crossfade(SlimerotMusicLibrary.CROSSFADE_SECONDS * 0.4)
	check(sound.music_levels.all(func(level: float) -> bool: return level > 0.0 and level < 1.0), "world transitions overlap both music envelopes")
	check(is_equal_approx(sound.music_levels[0] + sound.music_levels[1], 1.0), "a normal crossfade keeps the combined gain bounded")
	var before := sound.music_levels.duplicate()
	var fade_before := sound.fade_elapsed
	var destination := sound.music
	sound.set_track("backyard")
	check(sound.music == destination and sound.music_levels == before and sound.fade_elapsed == fade_before, "repeated same-track requests neither restart playback nor restart the envelope")
	sound.set_track("bedroom")
	check(sound.music == bedroom_channel and sound.music_levels == before, "returning through a gate reverses the existing channels without an envelope jump")
	sound.advance_crossfade(SlimerotMusicLibrary.CROSSFADE_SECONDS)
	var inactive := sound.music_players[1] if sound.music == sound.music_players[0] else sound.music_players[0]
	check(not sound.fading and is_equal_approx(sound.music.volume_linear, float(GameState.settings.master_audio) * float(GameState.settings.music_audio)) and inactive.stream == null and not inactive.playing, "completed fade releases the outgoing playback and restores the chosen theme's full gain")
	if sound.playback_enabled:
		sound.music.seek(3.0)
		await get_tree().create_timer(0.08).timeout
		sound.set_track("bedroom")
		check(sound.music.playing and sound.music.get_playback_position() >= 2.9, "rendered playback position survives an identical music request")

func test_settings_and_lifecycle() -> void:
	var original := GameState.settings.duplicate(true)
	WorldManager.travel(3)
	sound.advance_crossfade(SlimerotMusicLibrary.CROSSFADE_SECONDS)
	GameState.settings.master_audio = 0.5
	GameState.settings.music_audio = 0.4
	GameState.settings.sfx_audio = 0.6
	sound.apply_settings()
	check(is_equal_approx(sound.music.volume_linear, 0.2) and sound.voices.all(func(voice: AudioStreamPlayer) -> bool: return is_equal_approx(voice.volume_linear, 0.3)), "existing music/effect sliders retain their independent master-scaled gains")
	WorldManager.travel(4)
	sound.advance_crossfade(SlimerotMusicLibrary.CROSSFADE_SECONDS * 0.25)
	GameState.settings.master_audio = 0.0
	sound.apply_settings()
	check(sound.music_players.all(func(player: AudioStreamPlayer) -> bool: return is_zero_approx(player.volume_linear)) and sound.voices.all(func(player: AudioStreamPlayer) -> bool: return is_zero_approx(player.volume_linear)), "master mute silences both sides of a transition and every effect")
	var levels_before := sound.music_levels.duplicate()
	var time_before := sound.fade_elapsed
	# Godot's stream_paused getter describes an active playback, not a stored flag
	# on an idle player. Start each real effect voice before inspecting suspension.
	var active_audio: Array[AudioStreamPlayer] = []
	if sound.playback_enabled:
		for voice in sound.voices: voice.stop()
		sound.cue_last_played.clear()
		for cue in SlimerotAudio.CUE_IDS: sound.play_cue(cue)
		for player in sound.music_players + sound.voices:
			if player.playing: active_audio.append(player)
		check(active_audio.size() == 10, "rendered suspension fixture has both music channels and all eight effect voices playing")
	GameState.suspended = true
	sound._process(5.0)
	if sound.playback_enabled:
		check(active_audio.all(func(player: AudioStreamPlayer) -> bool: return player.stream_paused), "backgrounding pauses every active music and effect playback")
		# The audio server completes its already-mixed buffer asynchronously. Observe
		# a settled pause, then require zero playback movement over a later interval.
		await get_tree().create_timer(0.10).timeout
		var positions: Array[float] = []
		for player in active_audio: positions.append(player.get_playback_position())
		await get_tree().create_timer(0.06).timeout
		var stopped := true
		for index in active_audio.size():
			var position := active_audio[index].get_playback_position()
			if not is_equal_approx(position, positions[index]):
				stopped = false
				print("Slimerot MUSIC pause movement: %s %.9f -> %.9f" % [active_audio[index].name, positions[index], position])
		check(stopped, "suspended rendered playback positions remain stationary")
	else:
		check(sound.music_players.all(func(player: AudioStreamPlayer) -> bool: return not player.playing) and sound.voices.all(func(player: AudioStreamPlayer) -> bool: return not player.playing), "headless suspension keeps the audio mixer inactive")
	check(sound.music_levels == levels_before and sound.fade_elapsed == time_before, "background time cannot advance a crossfade")
	check(not sound.play_cue("roll"), "background audio cannot start an effect")
	GameState.suspended = false
	sound._process(0.0)
	check(active_audio.all(func(player: AudioStreamPlayer) -> bool: return not player.stream_paused) and sound.music_levels == levels_before, "resume unpauses active audio from its saved fade position")
	GameState.settings = original
	sound.apply_settings()
	sound.advance_crossfade(SlimerotMusicLibrary.CROSSFADE_SECONDS)

func test_missing_music() -> void:
	sound.set_track("Slimerot_missing_music")
	check(sound.current_track == "bedroom" and sound.music.stream != null, "an unknown music request falls back safely to Bedroom")
	var key := SlimerotMusicLibrary.track_path("moon") + str(true)
	var original: AudioStream = SlimerotAssets.music("moon")
	SlimerotAssets._streams[key] = null
	sound.set_track("backyard")
	sound.set_track("moon")
	check(sound.current_track == "bedroom" and sound.requested_track == "moon", "a missing registered world asset safely falls back without changing the requested world")
	sound.advance_crossfade(0.2)
	var fade_before := sound.fade_elapsed
	sound.set_track("moon")
	check(sound.fade_elapsed == fade_before, "a missing track does not retry and reset its fallback every frame")
	var fallback_key := SlimerotMusicLibrary.track_path("bedroom") + str(true)
	var fallback: AudioStream = SlimerotAssets.music("bedroom")
	SlimerotAssets._streams[fallback_key] = null
	sound.set_track("Slimerot_missing_fallback")
	sound.advance_crossfade(SlimerotMusicLibrary.CROSSFADE_SECONDS)
	check(sound.current_track.is_empty() and sound.music_players.all(func(player: AudioStreamPlayer) -> bool: return player.stream == null), "missing world and fallback music safely settle to silence")
	SlimerotAssets._streams[fallback_key] = fallback
	SlimerotAssets._streams[key] = original
	sound.set_track("backyard")
	sound.set_track("moon")
	check(sound.current_track == "moon", "restored world assets can be selected normally")

func test_bounded_switching() -> void:
	for track in SlimerotMusicLibrary.TRACK_IDS: SlimerotAssets.music(track)
	for cue in SlimerotAssets.AUDIO_IDS: SlimerotAssets.audio(cue)
	var cache_size := SlimerotAssets._streams.size()
	var children := sound.get_child_count()
	var wallets := [GameState.coins, GameState.rolls_balance, GameState.lifetime_rolls]
	var bounded := true
	for iteration in 1000:
		sound.set_track(SlimerotMusicLibrary.TRACK_IDS[iteration % 11])
		sound.advance_crossfade(0.01)
		bounded = bounded and sound.music_levels.all(func(level: float) -> bool: return level >= 0.0 and level <= 1.0) and sound.music_levels[0] + sound.music_levels[1] <= 1.00001
	check(bounded and sound.get_child_count() == children and children == 10 and sound.music_players.size() == 2 and sound.voices.size() == 8, "1000 rapid world requests keep two music players, eight effects and bounded levels")
	check(SlimerotAssets._streams.size() == cache_size, "rapid transitions reuse the same finite compressed stream cache")
	sound.advance_crossfade(SlimerotMusicLibrary.CROSSFADE_SECONDS)
	check(sound.music_players.filter(func(player: AudioStreamPlayer) -> bool: return player.stream != null).size() == 1, "only the chosen world playback survives after rapid transitions settle")
	check(wallets == [GameState.coins, GameState.rolls_balance, GameState.lifetime_rolls], "soundtrack changes never modify progression or roll accounting")
