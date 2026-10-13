extends RefCounted

const MetricsScript := preload("res://lab/BossLabMetrics.gd")

func run(session: Node, runner: Node) -> void:
	var prior_stats: RefCounted = session.stats
	var prior_id: String = session.selected.id
	var window: Window = session.get_window()
	var prior_size: Vector2i = window.size
	session.stats = MetricsScript.new()
	session.stats.persistence_enabled = false
	session.return_to_menu()
	session.select_boss("espresso")
	window.size = Vector2i(720, 1280)
	await _frames(session)
	var hud: CanvasLayer = session.hud
	runner.check(hud._boss_buttons.size() == 4, "Selection has exactly four encounter cards")
	runner.check(hud._menu.visible and not hud._hud.visible, "Independent lab starts at boss selection")
	await _tap(session, hud._practice_mode_button)
	runner.check(session.mode == "practice", "Real touch selects Practice Mode")
	await _tap(session, hud._practice_button)
	runner.check(hud._debug.visible and session.ui_paused, "Real touch opens practice tools and pauses simulation")
	runner.check(not hud._god.disabled and not hud._hitboxes.disabled, "Practice enables God Mode and accurate hitbox controls")
	await _tap(session, hud._god)
	runner.check(session.god_mode, "Real touch enables practice invulnerability")
	await _tap(session, hud._phase_buttons[2])
	runner.check(session.configured_phase == 3, "Real touch remembers a practice phase before starting")
	await _tap(session, _find_button(hud._debug, "CLOSE"))
	runner.check(not hud.is_modal_open() and not session.ui_paused, "Real touch closes practice tools and releases pause")
	await _tap(session, hud._start_button)
	runner.check(session.running and session.controller.phase == 3, "Practice starts in the selected phase")
	_key(session, KEY_F1)
	await _frames(session)
	for index in range(hud._attack_choice.item_count):
		if str(hud._attack_choice.get_item_metadata(index)) == "double_shot":
			hud._attack_choice.select(index)
	await _tap(session, hud._force_button)
	runner.check(session.controller.current_attack.contains("Double Shot"), "Real touch forces the selected practice attack through the controller")
	await _tap(session, hud._speed_buttons[0])
	runner.check(is_equal_approx(session.speed_scale, 0.5), "Real touch enables 0.5x practice speed")
	await _tap(session, hud._hitboxes)
	runner.check(session.show_hitboxes, "Real touch enables practice hitboxes")
	_key(session, KEY_ESCAPE)
	await _frames(session)
	await _tap(session, _find_button(hud._hud, "MENU"))
	await _tap(session, hud._normal_button)
	runner.check(session.mode == "normal" and not session.god_mode and is_equal_approx(session.speed_scale, 1.0) and not session.show_hitboxes, "Normal Mode resets every active practice cheat")
	await _tap(session, hud._start_button)
	runner.check(session.running and hud._hud.visible and not hud._menu.visible, "Real touch starts the encounter")
	var initial_nodes := _nodes(hud)
	for cycle in range(21):
		_key(session, KEY_F1)
		await _frames(session)
		runner.check(hud._debug.visible and session.ui_paused, "Tools open and pause on cycle %d" % (cycle + 1))
		var elapsed_before: float = session.elapsed
		session.step(0.3)
		runner.check(is_equal_approx(session.elapsed, elapsed_before), "Tools pause combat time on cycle %d" % (cycle + 1))
		if cycle % 2 == 0:
			await _tap(session, _find_button(hud._debug, "CLOSE"))
		else:
			_key(session, KEY_ESCAPE)
			await _frames(session)
		runner.check(not hud.is_modal_open() and session.running and not session.ui_paused, "Close/Back releases only the top modal on cycle %d" % (cycle + 1))
	runner.check(_nodes(hud) == initial_nodes, "Twenty-one Tools Close/Back cycles never grow UI node count")
	runner.check(not session.get_tree().quit_on_go_back, "Android Back cannot automatically quit the lab")
	var back_attempt: int = session.attempt
	_key(session, KEY_F1)
	await _frames(session)
	session.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(session)
	runner.check(not hud.is_modal_open() and session.running and not session.ui_paused and session.attempt == back_attempt, "Android Back notification closes Tools without leaving or restarting the attempt")
	hud._show_statistics()
	await _frames(session)
	runner.check(hud._statistics.visible and session.ui_paused, "Statistics Back test opens a top overlay and pauses the attempt")
	session.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(session)
	runner.check(not hud.is_modal_open() and session.running and not session.ui_paused and session.attempt == back_attempt, "Android Back notification closes Statistics without closing the fight")
	session.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(session)
	runner.check(not session.running and hud._menu.visible, "Android Back with no overlay returns to boss selection while the lab stays open")
	session.start_attempt()
	await _frames(session)
	_key(session, KEY_F1)
	await _frames(session)
	var disabled := true
	for control in hud._practice_controls:
		disabled = disabled and control.disabled
	runner.check(disabled, "Normal attempt disables every God/phase/attack/slow/hitbox/telegraph cheat")
	for button in hud._debug_dps_buttons:
		disabled = disabled and button.disabled
	runner.check(disabled, "Normal attempt cannot change its test team DPS midfight")
	_key(session, KEY_ESCAPE)
	await _frames(session)
	var center: Vector2 = hud._joystick.get_global_rect().get_center()
	_touch(session, 0, center, true)
	await _frames(session)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = center + Vector2(65, 0)
	drag.relative = Vector2(65, 0)
	session.get_viewport().push_input(drag, true)
	await _frames(session)
	runner.check(session.player.touch_direction.x > 0.5, "Real touch drag moves the player joystick")
	var dash_before: int = session.dash_count
	_touch(session, 1, hud._dash.get_global_rect().get_center(), true)
	await _frames(session)
	runner.check(session.dash_count == dash_before + 1 and session.player.is_dashing(), "Second simultaneous touch Dashes while the first finger holds movement")
	runner.check(session.player.touch_direction.x > 0.5, "Dash touch does not release the movement finger")
	_touch(session, 1, hud._dash.get_global_rect().get_center(), false)
	_touch(session, 0, center + Vector2(65, 0), false)
	await _frames(session)
	runner.check(session.player.touch_direction == Vector2.ZERO, "Joystick releases even when the finger is outside its start point")
	session.player.dash_remaining = 0.0
	session.player.hit_remaining = 0.0
	session.player.take_hit(100.0, "UI Attribution Probe")
	await _frames(session)
	runner.check(not session.running and hud._death.visible, "Death result is visible immediately without a timer or loading")
	runner.check(hud._death_details.text.contains("UI Attribution Probe") and hud._death_details.text.contains("Boss HP remaining"), "Death report includes killing attack and remaining boss HP")
	var start_clock := Time.get_ticks_usec()
	await _tap(session, _find_button(hud._death, "RETRY NOW"))
	var retry_seconds := float(Time.get_ticks_usec() - start_clock) / 1000000.0
	runner.check(session.running and not hud._death.visible and retry_seconds < 1.0, "Real touch Retry restarts in less than one second")
	session.finish_attempt(false, "Keyboard Retry Probe")
	await _frames(session)
	session.shake_remaining = 0.16
	session.shake_amount = 0.8
	session.camera.offset = Vector2(1.2, -0.6)
	session.hit_sound.play()
	session.clear_sound.play()
	runner.check(session.hit_sound.playing and session.clear_sound.playing, "Rapid Retry fixture starts real previous-attempt hit and victory audio")
	_key(session, KEY_R)
	runner.check(is_zero_approx(session.shake_remaining) and is_zero_approx(session.shake_amount) and session.camera.offset == Vector2.ZERO, "Instant Retry immediately clears prior-attempt camera shake")
	runner.check(not session.hit_sound.playing and not session.clear_sound.playing, "Instant Retry immediately stops prior-attempt hit and victory audio")
	await _frames(session)
	runner.check(session.running and not hud._death.visible and not hud.is_modal_open(), "Keyboard R immediately clears death and modal overlays")
	for resolution in [Vector2i(720, 1280), Vector2i(720, 1560), Vector2i(800, 1280)]:
		window.size = resolution
		await _frames(session)
		var canvas := Rect2(Vector2.ZERO, hud._root.size)
		var header: Control = hud._hud.get_child(0)
		runner.check(canvas.encloses(hud._dash.get_global_rect()) and canvas.encloses(hud._joystick.get_global_rect()), "Touch controls fit %sx%s" % [resolution.x, resolution.y])
		runner.check(header.get_global_rect().end.y <= 220.0, "Header stays above the arena at %sx%s" % [resolution.x, resolution.y])
		session.return_to_menu()
		await _frames(session)
		runner.check(canvas.encloses(hud._start_button.get_global_rect()), "Start and selection fit %sx%s" % [resolution.x, resolution.y])
		session.start_attempt()
		await _frames(session)
	session.return_to_menu()
	session.stats = prior_stats
	session.select_boss(prior_id)
	session.set_practice(false)
	window.size = prior_size
	await _frames(session)

func _frames(session: Node) -> void:
	await session.get_tree().process_frame
	await session.get_tree().process_frame

func _touch(session: Node, index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	session.get_viewport().push_input(event, true)
	if index == 0:
		# Android/Godot emulates the primary finger as a mouse for stock Controls.
		# push_input deliberately bypasses Input's platform emulation, so include it here.
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		mouse.position = position
		mouse.global_position = position
		mouse.pressed = pressed
		session.get_viewport().push_input(mouse, true)

func _tap(session: Node, control: Control) -> void:
	if control == null:
		return
	_touch(session, 0, control.get_global_rect().get_center(), true)
	await _frames(session)
	_touch(session, 0, control.get_global_rect().get_center(), false)
	await _frames(session)

func _key(session: Node, code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	session.get_viewport().push_input(event, true)
	var release := InputEventKey.new()
	release.physical_keycode = code
	release.keycode = code
	release.pressed = false
	session.get_viewport().push_input(release, true)

func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null

func _nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _nodes(child)
	return count
