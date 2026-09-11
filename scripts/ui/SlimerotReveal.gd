class_name SlimerotReveal
extends Control

var card: PanelContainer
var label: Label
var portrait: SlimerotPortrait
var sting: AudioStreamPlayer
var time := 0.0
var duration := 0.0
var tier := 0
var active := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	portrait = SlimerotPortrait.new()
	portrait.custom_minimum_size = Vector2(120, 120)
	column.add_child(portrait)
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(label)
	sting = AudioStreamPlayer.new()
	sting.stream = make_sting()
	add_child(sting)
	RollManager.revealed.connect(show_result)
	RollManager.reveal_finished.connect(hide_result)
	hide()

func show_result(slime_id: String, variant: String, first: bool) -> void:
	var data := SlimeDatabase.get_slime(slime_id)
	tier = data.aura_tier
	duration = RollManager.reveal_remaining
	time = 0.0
	active = true
	card.scale = Vector2.ONE
	portrait.slime_id = slime_id
	portrait.variant = variant
	portrait.visible = tier > 0
	var is_new: bool = RollManager.active_reveal.first_discovery
	label.text = ("FIRST SLIME · EQUIPPED\n" if first else ("NEW DISCOVERY\n" if is_new else "")) + data.display_name + " · " + variant.capitalize() + "\n" + SlimeDatabase.threshold_label(slime_id)
	if RollManager.active_reveal.get("super_roll", false): label.text = "SUPER ROLL · LUCK ×5\n" + label.text
	if RollManager.active_reveal.get("auto_sold_coins", 0) > 0: label.text += "\nAuto-sold duplicate · +%d Coins" % RollManager.active_reveal.auto_sold_coins
	label.add_theme_font_size_override("font_size", 19 if tier == 0 else 25)
	label.add_theme_color_override("font_color", SlimerotBalance.VARIANT_DATA[variant].color)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.075, 0.10, 0.96)
	style.border_color = SlimerotBalance.VARIANT_DATA[variant].color
	style.set_border_width_all(1 if tier < 2 else 3)
	style.set_corner_radius_all(18)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", style)
	card.position = Vector2(30, 255) if tier == 0 else Vector2(55, 340)
	card.size = Vector2(660, 108) if tier == 0 else Vector2(610, 300)
	if tier >= 3:
		card.position = Vector2(12, 350)
		card.size = Vector2(696, 340)
	if tier == 4:
		card.position.y = 420
		label.text = "JACKPOT\n" + label.text + ("\nFirst discovery · enjoy the moment" if is_new else "\nTap the card to skip")
	if tier >= 3 and DisplayServer.get_name() != "headless":
		sting.volume_db = linear_to_db(maxf(0.0001, GameState.settings.master_audio * GameState.settings.sfx_audio * 0.2))
		sting.play()
	show()

func hide_result() -> void:
	active = false
	sting.stop()
	hide()
	queue_redraw()

func _exit_tree() -> void:
	sting.stop()
	sting.stream = null

func _process(delta: float) -> void:
	if not active or GameState.is_paused(): return
	time += delta
	if tier > 0:
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2.ONE * (1.0 + sin(minf(time / 0.2, 1.0) * PI) * 0.035)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventScreenTouch and event.pressed and card.get_global_rect().has_point(event.position):
		RollManager.skip_reveal()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and card.get_global_rect().has_point(event.position):
		RollManager.skip_reveal()

func _draw() -> void:
	if not active: return
	if tier == 4:
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.13, 0.10, 0.03, 0.76))
	elif tier >= 2:
		draw_rect(Rect2(0, 0, 720, 1280), Color(1, 0.9, 0.6, maxf(0.0, 0.12 * (1.0 - time / 0.3))))
	if tier >= 1:
		for index in (10 if tier == 1 else 26):
			var angle := float(index) * 2.4
			var point := Vector2(360, 480) + Vector2.from_angle(angle) * (90 + time * 110 + index * 3)
			draw_circle(point, 2 + index % 3, Color(1, 0.91, 0.65, maxf(0, 1 - time / duration)))

func make_sting() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(11025 * 2)
	for index in 11025:
		var seconds := float(index) / 22050.0
		var envelope := sin(seconds * PI * 2) * exp(-seconds * 5)
		samples.encode_s16(index * 2, int(sin(seconds * TAU * (660.0 if seconds < 0.18 else 880.0)) * envelope * 14000))
	stream.data = samples
	return stream
