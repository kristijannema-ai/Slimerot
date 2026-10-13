extends Node

func run(session: BLSession) -> void:
	session.stats.persistence_enabled = false
	session.set_physics_process(false)
	await capture("selection")
	for id in ["espresso", "sand", "janitor", "admin"]:
		session.select_boss(id)
		session.set_practice(true)
		session.god_mode = true
		session.configured_phase = 3
		session.start_attempt()
		var move: String = {"espresso":"overcaffeinated", "sand":"sand_wall", "janitor":"wrong_door", "admin":"event_horizon"}[id]
		session.force_attack(move)
		for frame in 60: session.step(1.0 / 60.0)
		await capture(id)
		session.return_to_menu()
	session.hud.toggle_debug()
	await capture("tools")
	session.hud.close_top_modal()
	session.start_attempt()
	session.god_mode = false
	session.player.god_mode = false
	session.elapsed = 86.0
	session.controller.hp = session.selected.max_hp * 0.23
	session.player.take_hit(100, "Admin Delete")
	await capture("death")
	session.hit_sound.stop()
	session.clear_sound.stop()
	for frame in 12: await get_tree().process_frame
	print("BOSS LAB CAPTURES COMPLETE")
	get_tree().quit()

func capture(label: String) -> void:
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var directory := "res://.godot/captures"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--boss-lab-artifacts="): directory = arg.trim_prefix("--boss-lab-artifacts=")
	DirAccess.make_dir_recursive_absolute(directory)
	get_viewport().get_texture().get_image().save_png(directory.path_join("BossLab-" + label + ".png"))
