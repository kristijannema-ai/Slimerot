class_name SlimerotReveal
extends Control

var card: PanelContainer
var label: Label
var details: Label
var portrait: SlimerotPortrait
var heading: Label
var skip_hint: Label
var time := 0.0
var duration := 0.0
var tier := 0
var active := false
var first_discovery := false
var combat_compact := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 30
	card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	# Text wrapping settles after container sorting. Reapply the intended size
	# when that minimum changes so a toast cannot retain a tall prior layout.
	card.minimum_size_changed.connect(func(): layout_card.call_deferred())
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	heading = Label.new()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color("ffd47d"))
	column.add_child(heading)
	portrait = SlimerotPortrait.new()
	column.add_child(portrait)
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color("f0f5ed"))
	column.add_child(label)
	details = Label.new()
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_theme_font_size_override("font_size", 18)
	column.add_child(details)
	skip_hint = Label.new()
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_hint.add_theme_font_size_override("font_size", 15)
	skip_hint.add_theme_color_override("font_color", Color("96aabd"))
	column.add_child(skip_hint)
	RollManager.revealed.connect(show_result)
	RollManager.reveal_finished.connect(hide_result)
	resized.connect(layout_card)
	hide()

func show_result(slime_id: String, variant: String, first: bool) -> void:
	var data := SlimeDatabase.get_slime(slime_id)
	tier = int(RollManager.active_reveal.get("tier", SlimerotPresentation.adaptive_tier(RollManager.active_reveal)))
	duration = RollManager.reveal_remaining
	time = 0.0
	active = true
	first_discovery = RollManager.active_reveal.get("first_discovery", false)
	card.scale = Vector2.ONE
	portrait.slime_id = slime_id
	portrait.variant = variant
	portrait.visible = tier > 0
	heading.visible = tier >= 2
	heading.text = ["", "", "RARE FIND!", "SLIME SENSATION!", "JACKPOT!"][tier]
	label.text = data.display_name + " · " + SlimerotVariants.label(variant)
	details.visible = tier > 0
	if tier == 0:
		if first: label.text = "FIRST SLIME · EQUIPPED\n" + label.text
		elif RollManager.active_reveal.get("auto_sold_coins", 0) > 0:
			label.text += " · +%d Coins" % RollManager.active_reveal.auto_sold_coins
	else:
		label.text = data.display_name
		details.text = ("NEW DISCOVERY · " if first_discovery else "") + SlimerotVariants.label(variant).to_upper() + "\nEffective rarity: 1 in " + SlimeDatabase.format_number(SlimeDatabase.get_effective_rarity(slime_id, variant)) + "\nDamage " + SlimeDatabase.format_number(SlimeDatabase.get_base_combat_damage(slime_id, variant))
		if RollManager.active_reveal.get("super_roll", false): details.text += "\nSUPER ROLL · LUCK ×%d" % int(RollManager.active_reveal.get("super_roll_multiplier", SlimerotRollTree.SUPER_ROLL_MULTIPLIER))
		if RollManager.active_reveal.get("auto_sold_coins", 0) > 0: details.text += "\nAuto-sold duplicate · +%d Coins" % RollManager.active_reveal.auto_sold_coins
	label.add_theme_font_size_override("font_size", 19 if tier == 0 else 24)
	details.add_theme_color_override("font_color", SlimerotBalance.VARIANT_DATA[variant].color)
	skip_hint.visible = tier > 0
	skip_hint.text = "First discovery · enjoy the moment" if tier == 4 and first_discovery else "Tap this card to skip"
	var appearance := StyleBoxFlat.new()
	appearance.bg_color = Color("172639")
	appearance.border_color = Color("42556c") if tier == 0 and variant == "normal" else SlimerotBalance.VARIANT_DATA[variant].color
	appearance.set_border_width_all(1 if tier < 2 else 2)
	appearance.set_corner_radius_all(20 if tier == 0 else 26)
	appearance.shadow_color = Color(0.01, 0.02, 0.05, 0.48)
	appearance.shadow_size = 12 if tier == 0 else 18
	appearance.shadow_offset = Vector2(0, 7)
	appearance.content_margin_left = 24
	appearance.content_margin_right = 24
	appearance.content_margin_top = 14
	appearance.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", appearance)
	layout_card()
	show()

func layout_card() -> void:
	if not is_instance_valid(card): return
	combat_compact = WorldManager.boss_active
	portrait.visible = tier > 0 and not combat_compact
	heading.visible = tier >= 2 and not combat_compact
	details.visible = tier > 0 and not combat_compact
	skip_hint.visible = tier > 0 and not combat_compact
	if combat_compact:
		card.scale = Vector2.ONE
		label.add_theme_font_size_override("font_size", 18)
		card.size = Vector2(size.x - 32, 62)
		card.position = Vector2(16, 138)
		return
	label.add_theme_font_size_override("font_size", 19 if tier == 0 else 24)
	var width := minf(520.0, size.x - 48)
	var height := 74.0
	if tier == 1: height = 280
	if tier == 2:
		width = size.x - 80
		height = 350
	if tier >= 3:
		width = size.x - 24
		height = 410 if tier == 3 else 500
	portrait.custom_minimum_size = Vector2(0, 110 if tier == 1 else (155 if tier == 2 else 220))
	card.size = Vector2(width, height)
	card.position = Vector2((size.x - width) * 0.5, 250 if tier == 0 else maxf(270, (size.y - height) * 0.42))

func hide_result() -> void:
	active = false
	hide()
	queue_redraw()

func _process(delta: float) -> void:
	if not active or GameState.is_paused(): return
	time += delta
	if combat_compact != WorldManager.boss_active: layout_card()
	if tier > 0 and not combat_compact:
		card.pivot_offset = card.size * 0.5
		var bounce := 1.0 + sin(minf(time / 0.2, 1.0) * PI) * 0.04
		card.scale = Vector2.ONE * minf(bounce, (size.x - 12.0) / card.size.x)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not active or tier == 0 or GameState.is_paused(): return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if pressed and card.get_global_rect().has_point(event.position):
		RollManager.skip_reveal()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	# Combat only uses the compact passive card; no darkening, rays or fireworks.
	if not active or combat_compact: return
	if tier == 4:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.07, 0.12, 0.93))
		for index in 12:
			var center := size * 0.5
			var angle := index * TAU / 12.0 + time * 0.15
			var points := PackedVector2Array([center, center + Vector2.from_angle(angle) * size.length(), center + Vector2.from_angle(angle + 0.12) * size.length()])
			draw_colored_polygon(points, Color(1, 0.83, 0.49, 0.075))
	elif tier >= 2:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.025, 0.05, 0.65))
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.9, 0.6, maxf(0.0, 0.22 * (1.0 - time / 0.3))))
	if tier >= 1:
		for index in (10 if tier == 1 else 26):
			var angle := float(index) * 2.4
			var point := card.position + card.size * 0.5 + Vector2.from_angle(angle) * (90 + time * 110 + index * 3)
			var alpha := maxf(0.0, 1.0 - time / maxf(duration, 0.001))
			var sparkle := Color(1, 0.83, 0.49, alpha)
			var extent := 2.0 + index % 3
			draw_line(point - Vector2(extent, 0), point + Vector2(extent, 0), sparkle, 1.5, true)
			draw_line(point - Vector2(0, extent), point + Vector2(0, extent), sparkle, 1.5, true)
