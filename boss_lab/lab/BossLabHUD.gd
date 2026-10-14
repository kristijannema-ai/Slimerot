class_name BLHUD
extends CanvasLayer

## Presentation only. All encounter rules and practice commands belong to BLSession.
const INK := Color("eaf9f5")
const MUTED := Color("9db2bd")
const GREEN := Color("a3f7c0")
const CYAN := Color("73dbe9")
const PANEL := Color("162832")
const BG := Color("09151d")
const JoystickScript := preload("res://lab/BossLabJoystick.gd")

var session: Node
var _root: Control
var _menu: Control
var _hud: Control
var _death: Control
var _debug: Control
var _statistics: Control
var _joystick: Control
var _title: Label
var _boss_bar: ProgressBar
var _player_bar: ProgressBar
var _fight_line: Label
var _player_line: Label
var _footer_line: Label
var _dash: Button
var _death_title: Label
var _death_details: Label
var _debug_readout: Label
var _stats_readout: Label
var _stats_boss: OptionButton
var _stats_mode: OptionButton
var _profile_hint: Label
var _practice_button: Button
var _normal_button: Button
var _practice_mode_button: Button
var _start_button: Button
var _god: CheckButton
var _hitboxes: CheckButton
var _telegraphs: CheckButton
var _attack_choice: OptionButton
var _force_button: Button
var _phase_buttons: Array[Button] = []
var _speed_buttons: Array[Button] = []
var _dps_buttons: Array[Button] = []
var _debug_dps_buttons: Array[Button] = []
var _boss_buttons: Dictionary = {}
var _practice_controls: Array[BaseButton] = []
var _last_boss := ""
var _practice_phase := 1
var _refresh_pending := true
var _refresh_time := 0.0
var _theme: Theme

func setup(value: Node) -> void:
	session = value
	_theme = _make_theme()
	_build()
	session.updated.connect(refresh)
	session.selection_changed.connect(_selection_changed)
	session.attempt_ended.connect(_attempt_ended)
	_selection_changed()

func refresh() -> void:
	_refresh_pending = true

func attempt_started() -> void:
	_close_all()
	_death.visible = false
	_joystick.reset()
	refresh()

func show_menu() -> void:
	_close_all()
	_death.visible = false
	_joystick.reset()
	refresh()

func _process(delta: float) -> void:
	if session == null:
		return
	_refresh_time += delta
	if _refresh_pending or _refresh_time >= 0.10:
		_refresh_pending = false
		_refresh_time = 0.0
		_refresh_values()

func toggle_debug() -> void:
	if _debug.visible:
		_close_modal(_debug)
	else:
		_open_modal(_debug)
		_refresh_values()

func close_top_modal() -> bool:
	if _statistics.visible:
		_close_modal(_statistics)
		return true
	if _debug.visible:
		_close_modal(_debug)
		return true
	return false

func is_modal_open() -> bool:
	return _debug.visible or _statistics.visible

func _build() -> void:
	_root = Control.new()
	_root.name = "BossLabInterface"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _theme
	add_child(_root)
	_build_hud()
	_build_menu()
	_build_death()
	_build_debug()
	_build_statistics()

func _build_menu() -> void:
	_menu = _scrim("BossSelection", BG)
	var margin := _margin(_menu, 28)
	var column := _column(margin, 10)
	var title := _label("BOSS LAB", 48, GREEN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := _label("SLIMEROT  /  LEARN. DODGE. RETRY.", 18, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	var modes := _row(column, 12)
	_normal_button = _button("NORMAL TEST", _set_normal, 60)
	_practice_mode_button = _button("PRACTICE", _set_practice, 60)
	_expand(modes, _normal_button)
	_expand(modes, _practice_mode_button)
	column.add_child(_label("CHOOSE YOUR ENCOUNTER", 17, MUTED))
	for profile in session.profiles:
		var button := _button(profile.display_name.to_upper() + "\n" + profile.subtitle, _select_boss.bind(profile.id), 80)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 21)
		button.add_theme_stylebox_override("normal", _style(PANEL, profile.accent.darkened(0.45)))
		column.add_child(button)
		_boss_buttons[profile.id] = button
	_profile_hint = _label("", 18, MUTED)
	_profile_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_profile_hint.custom_minimum_size.y = 46
	column.add_child(_profile_hint)
	column.add_child(_label("TEST SLIME TEAM · 3 AUTO-ATTACKING SLIMES", 17, MUTED))
	var dps_row := _row(column, 10)
	for preset in ["LOW", "EXPECTED", "HIGH"]:
		var button := _button(preset + " DPS", _set_dps.bind(preset), 58)
		_expand(dps_row, button)
		_dps_buttons.append(button)
	_practice_button = _button("PRACTICE TOOLS", toggle_debug, 58)
	column.add_child(_practice_button)
	column.add_child(_button("ATTEMPT STATISTICS", _show_statistics, 58))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	_start_button = _button("START ENCOUNTER", _start, 88, true)
	column.add_child(_start_button)
	var controls := _label("WASD / ARROWS: MOVE   •   SPACE / Q: DASH\nR: INSTANT RETRY   •   F1: TOOLS   •   ESC: BACK", 16, MUTED)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(controls)

func _build_hud() -> void:
	_hud = Control.new()
	_hud.name = "FightHUD"
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud)
	var header := _fixed_panel(_hud, Rect2(24, 20, 672, 184))
	var column := _column(_margin(header, 10), 5)
	var row := _row(column, 8)
	_title = _label("", 25, INK)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_title)
	var tools := _button("TOOLS", toggle_debug, 48)
	tools.custom_minimum_size.x = 110
	tools.add_theme_font_size_override("font_size", 16)
	row.add_child(tools)
	_boss_bar = _bar(Color("ed8666"), 23)
	column.add_child(_boss_bar)
	_fight_line = _label("", 17, MUTED)
	column.add_child(_fight_line)
	_player_bar = _bar(GREEN, 14)
	column.add_child(_player_bar)
	_player_line = _label("", 17, INK)
	column.add_child(_player_line)
	_joystick = JoystickScript.new()
	_joystick.name = "MoveJoystick"
	_joystick.position = Vector2(32, 1015)
	_joystick.size = Vector2(214, 214)
	_joystick.direction_changed.connect(_touch_direction)
	_hud.add_child(_joystick)
	var footer := _fixed_panel(_hud, Rect2(258, 1030, 240, 198))
	_footer_line = _label("", 16, MUTED)
	_footer_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_footer_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_margin(footer, 12).add_child(_footer_line)
	_dash = _button("DASH", _request_dash, 120, true)
	_dash.pressed.disconnect(_request_dash)
	_dash.button_mask = 0
	_dash.gui_input.connect(_dash_gui_input)
	_dash.name = "DashButton"
	_dash.position = Vector2(514, 1030)
	_dash.size = Vector2(180, 120)
	_dash.add_theme_font_size_override("font_size", 30)
	_hud.add_child(_dash)
	var back := _button("MENU", _return_to_menu, 64)
	back.position = Vector2(514, 1164)
	back.size = Vector2(180, 64)
	_hud.add_child(back)

func _build_death() -> void:
	_death = _scrim("AttemptResult", Color(0.02, 0.06, 0.09, 0.94))
	var panel := _fixed_panel(_death, Rect2(30, 270, 660, 740))
	var column := _column(_margin(panel, 28), 20)
	_death_title = _label("ATTEMPT COMPLETE", 34, GREEN)
	_death_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_death_title)
	_death_details = _label("", 24, INK)
	_death_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_death_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_death_details)
	column.add_child(_button("RETRY NOW", _retry, 100, true))
	var row := _row(column, 12)
	_expand(row, _button("STATISTICS", _show_statistics, 64))
	_expand(row, _button("BOSS SELECT", _return_to_menu, 64))
	_death.visible = false

func _build_debug() -> void:
	_debug = _scrim("DeveloperPanel", Color(0.015, 0.04, 0.065, 0.96))
	var panel := _fixed_panel(_debug, Rect2(28, 65, 664, 1150))
	var column := _column(_margin(panel, 20), 10)
	var heading := _row(column, 10)
	var title := _label("ENCOUNTER TOOLS", 26, GREEN)
	_expand(heading, title)
	heading.add_child(_button("CLOSE", _close_modal.bind(_debug), 56))
	column.add_child(_label("Fight paused while tools are open.", 17, MUTED))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var content := _column(scroll, 10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_debug_readout = _label("", 18, INK)
	_debug_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_debug_readout)
	content.add_child(_button("RESTART NOW  [R]", _retry, 66, true))
	content.add_child(_label("PRACTICE CONTROLS  /  NORMAL IS READ-ONLY", 16, MUTED))
	_god = _check("GOD MODE", _set_god)
	content.add_child(_god)
	_practice_controls.append(_god)
	var phases := _row(content, 8)
	for phase in range(1, 5):
		var button := _button("PHASE %d" % phase, _set_phase.bind(phase), 58)
		_expand(phases, button)
		_phase_buttons.append(button)
		_practice_controls.append(button)
	_attack_choice = OptionButton.new()
	_attack_choice.custom_minimum_size.y = 60
	_attack_choice.add_theme_font_size_override("font_size", 18)
	content.add_child(_attack_choice)
	_practice_controls.append(_attack_choice)
	_force_button = _button("FORCE SELECTED ATTACK", _force_attack, 60)
	content.add_child(_force_button)
	_practice_controls.append(_force_button)
	var speeds := _row(content, 10)
	for scale in [0.5, 1.0]:
		var button := _button("SLOW 0.5x" if scale < 1.0 else "NORMAL SPEED", _set_speed.bind(scale), 60)
		_expand(speeds, button)
		_speed_buttons.append(button)
		_practice_controls.append(button)
	_hitboxes = _check("SHOW ACCURATE HITBOXES", _set_hitboxes)
	_telegraphs = _check("SHOW TELEGRAPH AREAS", _set_telegraphs)
	content.add_child(_hitboxes)
	content.add_child(_telegraphs)
	_practice_controls.append(_hitboxes)
	_practice_controls.append(_telegraphs)
	content.add_child(_label("TEST TEAM DPS", 17, MUTED))
	var dps := _row(content, 10)
	for preset in ["LOW", "EXPECTED", "HIGH"]:
		var button := _button(preset, _set_dps.bind(preset), 58)
		_expand(dps, button)
		_debug_dps_buttons.append(button)
	_debug.visible = false

func _build_statistics() -> void:
	_statistics = _scrim("AttemptStatistics", Color(0.015, 0.04, 0.065, 0.96))
	var panel := _fixed_panel(_statistics, Rect2(28, 115, 664, 1050))
	var column := _column(_margin(panel, 24), 18)
	var heading := _row(column, 10)
	_expand(heading, _label("LOCAL STATISTICS", 27, GREEN))
	heading.add_child(_button("CLOSE", _close_modal.bind(_statistics), 58))
	_stats_boss = OptionButton.new()
	_stats_boss.custom_minimum_size.y = 62
	_stats_boss.add_theme_font_size_override("font_size", 19)
	for profile in session.profiles:
		_stats_boss.add_item(profile.display_name)
		_stats_boss.set_item_metadata(_stats_boss.item_count - 1, profile.id)
	_stats_boss.item_selected.connect(_refresh_statistics.unbind(1))
	column.add_child(_stats_boss)
	_stats_mode = OptionButton.new()
	_stats_mode.custom_minimum_size.y = 60
	_stats_mode.add_item("NORMAL TEST · REAL ATTEMPTS")
	_stats_mode.add_item("PRACTICE · SEPARATE HISTORY")
	_stats_mode.item_selected.connect(_refresh_statistics.unbind(1))
	column.add_child(_stats_mode)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_stats_readout = _label("", 22, INK)
	_stats_readout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(_stats_readout)
	var note := _label("Lifetime summaries are local to this device. The newest 500 detailed attempts are retained. Practice has separate results.", 17, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	_statistics.visible = false

func _selection_changed() -> void:
	if session == null or _menu == null:
		return
	if _last_boss != session.selected.id:
		_last_boss = session.selected.id
		_practice_phase = 1
		_attack_choice.clear()
		_attack_choice.add_item("Automatic attack rotation")
		_attack_choice.set_item_metadata(0, "")
		for attack_id in session.selected.attacks:
			var data: Dictionary = session.selected.attacks[attack_id]
			var name := str(data.get("name", " ".join(str(attack_id).split("_")).capitalize()))
			_attack_choice.add_item(name)
			_attack_choice.set_item_metadata(_attack_choice.item_count - 1, str(attack_id))
		for index in range(_phase_buttons.size()):
			_phase_buttons[index].visible = index < session.selected.phase_thresholds.size() + 1
	for id in _boss_buttons:
		var button: Button = _boss_buttons[id]
		var selected: bool = id == session.selected.id
		button.add_theme_stylebox_override("normal", _style(Color("244a48") if selected else PANEL, GREEN if selected else Color("345362")))
		button.add_theme_color_override("font_color", GREEN if selected else INK)
	_normal_button.add_theme_stylebox_override("normal", _style(Color("244a48") if session.mode == "normal" else PANEL, GREEN if session.mode == "normal" else Color("345362")))
	_practice_mode_button.add_theme_stylebox_override("normal", _style(Color("244a48") if session.mode == "practice" else PANEL, GREEN if session.mode == "practice" else Color("345362")))
	_practice_button.visible = session.mode == "practice"
	_start_button.text = "START PRACTICE" if session.mode == "practice" else "START ENCOUNTER"
	_profile_hint.text = "%s\n%s" % [session.selected.subtitle, "Practice tools are enabled. Learn one pattern at a time." if session.mode == "practice" else "Real encounter. No cheats. Every completed attempt counts."]
	_refresh_pending = true
	_refresh_values()

func _refresh_values() -> void:
	var state: Dictionary = session.snapshot()
	var running: bool = session.running
	if running and _death.visible:
		_death.visible = false
	_menu.visible = not running and not _death.visible
	_hud.visible = running and not _death.visible
	_set_text(_title, session.selected.display_name.to_upper())
	var boss_hp := float(state.get("boss_hp", session.selected.max_hp))
	var boss_max := maxf(1.0, float(state.get("boss_max_hp", session.selected.max_hp)))
	_boss_bar.max_value = boss_max
	_boss_bar.value = boss_hp
	_player_bar.max_value = float(state.get("player_max_hp", session.balance.player_hp))
	_player_bar.value = float(state.get("player_hp", session.balance.player_hp))
	var phase := int(state.get("phase", _practice_phase))
	var cooldown := maxf(0.0, float(state.get("dash_cooldown", 0.0)))
	var mode_label := "PRACTICE" if session.mode == "practice" else "NORMAL"
	_set_text(_fight_line, "PHASE %d  ·  %s  ·  %s  ·  BOSS %d%%" % [phase, _time(session.elapsed), mode_label, roundi(100.0 * boss_hp / boss_max)])
	_set_text(_player_line, "HP %d / %d   ·   DASH %s" % [roundi(_player_bar.value), roundi(_player_bar.max_value), "READY" if cooldown <= 0.0 else "%.1fs" % cooldown])
	_set_text(_footer_line, "ATTEMPT %d · %s\n%s\n\n%s DPS: %.0f\nR = RETRY" % [session.attempt, mode_label, str(state.get("attack", "")), session.dps_preset, float(state.get("dps", session.balance.team_dps))])
	_dash.text = "DASH" if cooldown <= 0.0 else "DASH\n%.1fs" % cooldown
	_dash.disabled = not running or cooldown > 0.0 or session.ui_paused
	_god.set_pressed_no_signal(session.god_mode)
	_hitboxes.set_pressed_no_signal(session.show_hitboxes)
	_telegraphs.set_pressed_no_signal(session.show_telegraphs)
	var practice: bool = session.mode == "practice"
	for control in _practice_controls:
		control.disabled = not practice
	_force_button.disabled = not practice or not running
	for button in _dps_buttons:
		button.add_theme_color_override("font_color", GREEN if button.text.begins_with(session.dps_preset) else INK)
	for button in _debug_dps_buttons:
		button.disabled = not practice and running
		button.add_theme_color_override("font_color", GREEN if button.text == session.dps_preset else INK)
	for index in range(_phase_buttons.size()):
		_phase_buttons[index].add_theme_color_override("font_color", GREEN if index + 1 == (phase if running else _practice_phase) else INK)
	for index in range(_speed_buttons.size()):
		_speed_buttons[index].add_theme_color_override("font_color", GREEN if is_equal_approx(session.speed_scale, 0.5 if index == 0 else 1.0) else INK)
	if _debug.visible:
		_set_text(_debug_readout, "BOSS HP  %.0f / %.0f\nPHASE  %d\nATTACK  %s\nPLAYER HP  %.0f / %.0f\nDASH COOLDOWN  %.2fs\nELAPSED  %s   |   ATTEMPT  %d\nDAMAGE TAKEN  %.0f   |   HITS  %d\nTEAM DPS  %.0f   |   DASHES  %d\nATTACK SEED  %s\nMODE  %s" % [boss_hp, boss_max, phase, str(state.get("attack", "Ready")), _player_bar.value, _player_bar.max_value, cooldown, _time(session.elapsed), session.attempt, session.damage_taken, session.hits, float(state.get("dps", session.balance.team_dps)), session.dash_count, str(state.get("seed", 0)), mode_label])

func _attempt_ended(record: Dictionary) -> void:
	_debug.visible = false
	_statistics.visible = false
	session.ui_paused = false
	_joystick.reset()
	_death.visible = true
	_death_title.text = "BOSS CLEARED!" if bool(record.get("victory", false)) else "KEEP LEARNING"
	_death_title.add_theme_color_override("font_color", GREEN if bool(record.get("victory", false)) else Color("ffa886"))
	var ending := "VICTORY" if bool(record.get("victory", false)) else "Killed by: %s" % str(record.get("death_attack", "Unknown attack"))
	_death_details.text = "Attempt %d  ·  %s\n\nSurvived: %s\n%s\nBoss HP remaining: %.1f%%\n\nPhase reached: %d\nHits taken: %d  ·  Dashes: %d\n\n%s" % [int(record.get("attempt", session.attempt)), str(record.get("mode", session.mode)).to_upper(), _time(float(record.get("duration", session.elapsed))), ending, float(record.get("boss_hp_remaining", 100.0)), int(record.get("phase", 1)), int(record.get("hits", 0)), int(record.get("dash_count", 0)), "PRACTICE RESULT · SEPARATE HISTORY" if str(record.get("mode", "normal")) == "practice" else "Tap Retry or press R. No loading or intro."]
	refresh()

func _start() -> void:
	_close_all()
	_death.visible = false
	if session.mode == "practice":
		session.set_phase(_practice_phase)
	session.start_attempt()
	if session.mode == "practice":
		if _attack_choice.selected > 0:
			session.force_attack(str(_attack_choice.get_item_metadata(_attack_choice.selected)))
	refresh()

func _retry() -> void:
	_close_all()
	_death.visible = false
	_joystick.reset()
	session.retry()
	refresh()

func _return_to_menu() -> void:
	_close_all()
	_death.visible = false
	_joystick.reset()
	session.return_to_menu()
	refresh()

func _select_boss(id: String) -> void:
	session.select_boss(id)

func _set_normal() -> void:
	session.set_practice(false)
	_selection_changed()

func _set_practice() -> void:
	session.set_practice(true)
	_selection_changed()

func _set_dps(preset: String) -> void:
	if session.mode == "normal" and session.running:
		return
	session.set_dps(preset)
	refresh()

func _set_god(enabled: bool) -> void:
	if session.mode == "practice":
		session.god_mode = enabled
	refresh()

func _set_hitboxes(enabled: bool) -> void:
	if session.mode == "practice":
		session.show_hitboxes = enabled
	refresh()

func _set_telegraphs(enabled: bool) -> void:
	if session.mode == "practice":
		session.show_telegraphs = enabled
	refresh()

func _set_phase(phase: int) -> void:
	if session.mode != "practice":
		return
	_practice_phase = phase
	session.set_phase(phase)
	refresh()

func _force_attack() -> void:
	if session.mode != "practice" or not session.running:
		return
	session.force_attack(str(_attack_choice.get_item_metadata(_attack_choice.selected)))
	refresh()

func _set_speed(scale: float) -> void:
	if session.mode == "practice":
		session.speed_scale = scale
	refresh()

func _show_statistics() -> void:
	for index in range(_stats_boss.item_count):
		if str(_stats_boss.get_item_metadata(index)) == session.selected.id:
			_stats_boss.select(index)
	_stats_mode.select(1 if session.mode == "practice" else 0)
	_open_modal(_statistics)
	_refresh_statistics()

func _refresh_statistics() -> void:
	var boss_id := str(_stats_boss.get_item_metadata(_stats_boss.selected))
	var mode := "practice" if _stats_mode.selected == 1 else "normal"
	var data: Dictionary = session.stats.summary(boss_id, mode)
	var clear_text := "Not cleared yet" if int(data.first_clear_attempt) == 0 else "Attempt %d" % int(data.first_clear_attempt)
	var text := "ATTEMPTS  %d\nWINS  %d\nAVERAGE SURVIVAL  %s\nFIRST CLEAR  %s\n\nMOST COMMON DEATH\n%s\n\nBEST BOSS HP BEFORE FIRST CLEAR\n%.1f%% remaining\n\nTOTAL HITS  %d\nTOTAL DASHES  %d" % [data.attempts, data.wins, _time(data.average_survival_seconds), clear_text, data.most_common_death_attack, data.best_hp_before_first_clear, data.hits, data.dash_count]
	if not data.damage_by_attack.is_empty():
		text += "\n\nDAMAGE TAKEN BY ATTACK"
		var names: Array = data.damage_by_attack.keys()
		names.sort_custom(func(a: Variant, b: Variant) -> bool: return float(data.damage_by_attack[a]) > float(data.damage_by_attack[b]))
		for name in names:
			text += "\n%s: %.0f" % [name, float(data.damage_by_attack[name])]
	if not session.stats.last_storage_error.is_empty():
		text += "\n\n" + session.stats.last_storage_error
	_set_text(_stats_readout, text)

func _open_modal(modal: Control) -> void:
	_debug.visible = false
	_statistics.visible = false
	modal.visible = true
	session.ui_paused = true
	_joystick.reset()
	refresh()

func _close_modal(modal: Control) -> void:
	modal.visible = false
	session.ui_paused = is_modal_open()
	_joystick.reset()
	refresh()

func _close_all() -> void:
	_debug.visible = false
	_statistics.visible = false
	session.ui_paused = false

func _touch_direction(direction: Vector2) -> void:
	if is_instance_valid(session.player):
		session.player.touch_direction = direction if session.running and not session.ui_paused else Vector2.ZERO

func _request_dash() -> void:
	if session.running and not session.ui_paused and is_instance_valid(session.player):
		session.player.request_dash()

func _dash_gui_input(event: InputEvent) -> void:
	# A second touch must work while the first finger is captured by the joystick.
	# Normal Button mouse emulation tracks only one finger, so Dash handles touch directly.
	if event is InputEventScreenTouch and event.pressed:
		_request_dash()
		_dash.accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_request_dash()
		_dash.accept_event()

func _time(seconds: float) -> String:
	var whole := maxi(0, floori(seconds))
	return "%d:%02d" % [whole / 60, whole % 60]

func _set_text(label: Label, value: String) -> void:
	if label.text != value:
		label.text = value

func _scrim(node_name: String, color: Color) -> Control:
	var scrim := ColorRect.new()
	scrim.name = node_name
	scrim.color = color
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(scrim)
	return scrim

func _fixed_panel(parent: Control, rect: Rect2) -> PanelContainer:
	var panel := PanelContainer.new()
	var panel_style := _style(PANEL, Color("345362"), 18)
	panel_style.content_margin_left = 0
	panel_style.content_margin_right = 0
	panel_style.content_margin_top = 0
	panel_style.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)
	return panel

func _margin(parent: Control, amount: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", amount)
	margin.add_theme_constant_override("margin_right", amount)
	margin.add_theme_constant_override("margin_top", amount)
	margin.add_theme_constant_override("margin_bottom", amount)
	parent.add_child(margin)
	return margin

func _column(parent: Control, separation: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	parent.add_child(column)
	return column

func _row(parent: Control, separation: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	parent.add_child(row)
	return row

func _expand(parent: Control, control: Control) -> void:
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(control)

func _label(value: String, font_size: int = 20, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(value: String, action: Callable, height: int = 60, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = height
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	if primary:
		button.add_theme_stylebox_override("normal", _style(Color("81deb0"), Color("caffdd")))
		button.add_theme_stylebox_override("hover", _style(Color("a3f7c0"), Color("e8ffef")))
		button.add_theme_stylebox_override("pressed", _style(Color("59b991"), Color("caffdd")))
		button.add_theme_color_override("font_color", BG)
		button.add_theme_color_override("font_hover_color", BG)
		button.add_theme_color_override("font_pressed_color", BG)
	return button

func _check(value: String, action: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.text = value
	check.custom_minimum_size.y = 60
	check.focus_mode = Control.FOCUS_NONE
	check.add_theme_font_size_override("font_size", 18)
	check.toggled.connect(action)
	return check

func _bar(fill: Color, height: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = height
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _style(Color("0c1922"), Color("345362"), 6))
	bar.add_theme_stylebox_override("fill", _style(fill, fill.lightened(0.2), 6))
	return bar

func _style(fill: Color, border: Color, radius: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 3)
	return style

func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 20
	theme.set_stylebox("panel", "PanelContainer", _style(PANEL, Color("345362"), 18))
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, _style(PANEL, Color("345362")))
		theme.set_stylebox("hover", type, _style(Color("23404b"), CYAN))
		theme.set_stylebox("pressed", type, _style(Color("244a48"), GREEN))
		theme.set_stylebox("disabled", type, _style(Color("101d25"), Color("253b46")))
		theme.set_stylebox("focus", type, _style(Color(0, 0, 0, 0), CYAN))
		theme.set_color("font_color", type, INK)
		theme.set_color("font_hover_color", type, INK)
		theme.set_color("font_pressed_color", type, GREEN)
		theme.set_color("font_disabled_color", type, Color("506671"))
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "CheckButton", INK)
	theme.set_color("font_disabled_color", "CheckButton", Color("506671"))
	theme.set_constant("h_separation", "CheckButton", 12)
	theme.set_constant("outline_size", "Label", 1)
	theme.set_color("font_outline_color", "Label", BG)
	return theme
