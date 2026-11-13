extends Control
## Game screen: top bar, drops (lives), board, bottom buttons, win / fail / settings dialogs.

const LevelDB := preload("res://scripts/level_db.gd")
const Board := preload("res://scripts/board.gd")
const IconButton := preload("res://scripts/icon_button.gd")
const UIKit := preload("res://scripts/ui_kit.gd")
const BgDeco := preload("res://scripts/bg_deco.gd")

const MAX_LIVES := 4        # drops at the start of every level
const MAX_DROPS := 6        # watching ads can add drops, up to this many

var level_n := 1
var level_seed := ""
var lives := MAX_LIVES
var life_slots := MAX_LIVES
var mistakes := 0
var plus_btn: Button

var bg: ColorRect
var back_btn: Control
var title_lbl: Label
var palette_btn: Control
var settings_btn: Control
var rule: ColorRect
var drops: Array = []
var board: Control
var zoom_btn: Control
var hint_btn: Control
var footer: ColorRect
var footer_lbl: Label
var modal: Control


func _ready() -> void:
	_build()
	resized.connect(_layout)
	Save.theme_changed.connect(_apply_theme)
	_layout()
	_apply_theme()
	_start_level(Save.current_level)
	Ads.show_banner(true)


# ----------------------------------------------------------------- building

func _build() -> void:
	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(BgDeco.new())

	back_btn = _icon("back", false)
	back_btn.pressed.connect(_on_back)
	title_lbl = UIKit.make_label("Level 1", 84, Color.WHITE, 12, Color.WHITE)
	add_child(title_lbl)
	palette_btn = _icon("palette", false)
	palette_btn.pressed.connect(func(): Save.cycle_theme())
	settings_btn = _icon("settings", false)
	settings_btn.pressed.connect(_show_settings)

	rule = ColorRect.new()
	add_child(rule)

	for i in MAX_DROPS:
		var d := _icon("drop", false)
		d.interactive = false
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drops.append(d)

	plus_btn = Button.new()
	plus_btn.text = "+1 LIFE  (AD)"
	plus_btn.focus_mode = Control.FOCUS_NONE
	plus_btn.add_theme_font_size_override("font_size", 38)
	plus_btn.pressed.connect(_offer_life_ad)
	plus_btn.visible = Ads.is_active()
	add_child(plus_btn)

	board = Board.new()
	add_child(board)
	board.arrow_escaped.connect(_on_escaped)
	board.arrow_blocked.connect(_on_blocked)
	board.cleared.connect(_on_cleared)

	zoom_btn = _icon("fit", true)
	zoom_btn.pressed.connect(func(): board.reset_view(); Sfx.play("tap"))
	hint_btn = _icon("hint", true)
	hint_btn.pressed.connect(_on_hint)

	footer = ColorRect.new()
	add_child(footer)
	footer_lbl = UIKit.make_label("TAP TO SLIDE OUT  -  PINCH TO ZOOM", 40, Color.WHITE, 1)
	footer.add_child(footer_lbl)

	modal = Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal)


func _icon(kind: String, circle: bool) -> Control:
	var b: Control = IconButton.new()
	b.kind = kind
	add_child(b)
	return b


func _layout() -> void:
	var w := size.x
	var h := size.y
	var top := 40.0
	back_btn.position = Vector2(54, top + 10)
	back_btn.size = Vector2(100, 100)
	palette_btn.position = Vector2(w - 54 - 100 - 28 - 100, top + 10)
	palette_btn.size = Vector2(100, 100)
	settings_btn.position = Vector2(w - 54 - 100, top + 10)
	settings_btn.size = Vector2(100, 100)
	title_lbl.position = Vector2(180, top)
	title_lbl.size = Vector2(w - 360, 120)
	rule.position = Vector2(30, 190)
	rule.size = Vector2(w - 60, 4)
	for i in drops.size():
		drops[i].position = Vector2(60 + i * 90, 232)
		drops[i].size = Vector2(76, 76)
	plus_btn.position = Vector2(w - 60 - 400, 224)
	plus_btn.size = Vector2(400, 92)
	var footer_h := 170.0
	footer.position = Vector2(0, h - footer_h)
	footer.size = Vector2(w, footer_h)
	footer_lbl.position = Vector2(0, 0)
	footer_lbl.size = Vector2(w, footer_h)
	var btn := 176.0
	var btn_y := h - footer_h - 70.0 - btn
	zoom_btn.size = Vector2(btn, btn)
	hint_btn.size = Vector2(btn, btn)
	zoom_btn.position = Vector2(w * 0.5 - 70 - btn, btn_y)
	hint_btn.position = Vector2(w * 0.5 + 70, btn_y)
	var board_top := 330.0
	board.position = Vector2(30, board_top)
	board.size = Vector2(w - 60, maxf(300.0, btn_y - 30.0 - board_top))


func _apply_theme() -> void:
	var c: Dictionary = Save.colors()
	bg.color = c.bg
	title_lbl.add_theme_color_override("font_color", c.title)
	title_lbl.add_theme_color_override("font_outline_color", c.panel)
	rule.color = c.rule
	footer.color = c.footer
	_style_plus()
	footer_lbl.add_theme_color_override("font_color", c.footer_text)
	footer_lbl.add_theme_color_override("font_outline_color", c.footer_text)
	board.queue_redraw()


# --------------------------------------------------------------------- flow

func _start_level(n: int) -> void:
	_close_modal()
	level_n = n
	Save.current_level = n
	var level := LevelDB.build(n)
	level_seed = String(LevelDB.meta(n).get("seed", ""))
	lives = MAX_LIVES
	life_slots = MAX_LIVES
	mistakes = 0
	title_lbl.text = "Level %d" % n
	board.load_level(level)
	_refresh_drops()
	_refresh_hint_badge()


func _refresh_drops() -> void:
	for i in drops.size():
		drops[i].visible = i < life_slots
		drops[i].set_filled(i < lives)


func _refresh_hint_badge() -> void:
	if Save.hints > 0:
		hint_btn.set_badge(Save.hints)
	else:
		hint_btn.set_badge_text("AD")      # out of hints: tapping offers a rewarded ad


func _style_plus() -> void:
	var c: Dictionary = Save.colors()
	var bgc: Color = c.get("btn", Color("2fbf71"))
	var fg: Color = c.get("btn_glyph", Color.WHITE)
	var normal := UIKit.flat(bgc, 46, 0, Color.TRANSPARENT, 6)
	var pressed := UIKit.flat(bgc.darkened(0.15), 46)
	for k in ["normal", "hover", "focus", "disabled"]:
		plus_btn.add_theme_stylebox_override(k, normal)
	plus_btn.add_theme_stylebox_override("pressed", pressed)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		plus_btn.add_theme_color_override(k, fg)


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _on_escaped() -> void:
	Sfx.play("slide")
	Sfx.haptic("light")


func _on_blocked() -> void:
	lives -= 1
	mistakes += 1
	Sfx.play("wrong")
	Sfx.haptic("heavy")
	_refresh_drops()
	if lives <= 0:
		board.locked = true
		get_tree().create_timer(0.9).timeout.connect(_show_fail)


func _on_hint() -> void:
	if board.locked:
		return
	if Save.hints <= 0:
		_offer_hint_ad()
		return
	if board.show_hint():
		Save.use_hint()
		_refresh_hint_badge()
		Sfx.play("hint")
		Sfx.haptic("medium")


func _on_cleared() -> void:
	var flawless := mistakes == 0
	Save.complete_level(level_n)
	Sfx.play("win")
	Sfx.haptic("win")
	_confetti()
	_refresh_hint_badge()
	get_tree().create_timer(0.35).timeout.connect(func(): _show_win(flawless))


# ------------------------------------------------------------------- dialogs

func _close_modal() -> void:
	for ch in modal.get_children():
		ch.queue_free()
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Builds a centred dialog. buttons: [[text, Callable, is_primary], ...]
func _dialog(title: String, body: String, buttons: Array, extra: Control = null) -> void:
	_close_modal()
	var c: Dictionary = Save.colors()
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.flat(c.bg, 48, 4, c.rule, 20))
	panel.custom_minimum_size = Vector2(840, 0)
	modal.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 48)
	panel.add_child(pad)
	pad.add_child(box)
	box.add_child(UIKit.make_label(title, 72, c.title, 2))
	if body != "":
		var bl := UIKit.make_label(body, 42, c.line)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.custom_minimum_size = Vector2(700, 0)
		box.add_child(bl)
	if extra != null:
		box.add_child(extra)
	for b in buttons:
		var primary: bool = b[2]
		var btn := UIKit.make_button(b[0], c.gold if primary else c.panel, c.get("on_gold", Color.WHITE) if primary else c.line, 50)
		btn.pressed.connect(b[1])
		box.add_child(btn)
	panel.reset_size()
	panel.position = (size - panel.size) * 0.5
	panel.resized.connect(func(): panel.position = (size - panel.size) * 0.5)
	# little pop-in
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.85, 0.85)
	create_tween().tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------ rewarded ads

func _offer_life_ad() -> void:
	if board.alive_count == 0:
		return                                   # level already cleared
	if lives >= MAX_DROPS:
		_toast("Drops are full!")
		return
	_dialog("Extra drop?", "Watch a short ad to get +1 drop.", [
		["Watch ad   +1 drop", _watch_life_ad, true],
		["No thanks", _close_modal, false],
	])


func _watch_life_ad() -> void:
	_close_modal()
	Ads.show_rewarded(_on_life_ad_result)


func _on_life_ad_result(earned: bool) -> void:
	if earned:
		lives += 1
		life_slots = maxi(life_slots, lives)
		board.locked = false
		_refresh_drops()
		Sfx.play("hint")
		Sfx.haptic("medium")
		_toast("+1 drop!")
	else:
		_toast("Ad not ready - try again in a moment")
		if lives <= 0:
			get_tree().create_timer(1.0).timeout.connect(_show_fail)


func _offer_hint_ad() -> void:
	if not Ads.is_active():
		_toast("No hints left - finish levels to earn more")
		return
	_dialog("Out of hints", "Watch a short ad to get 1 hint.", [
		["Watch ad   +1 hint", _watch_hint_ad, true],
		["No thanks", _close_modal, false],
	])


func _watch_hint_ad() -> void:
	_close_modal()
	Ads.show_rewarded(_on_hint_ad_result)


func _on_hint_ad_result(earned: bool) -> void:
	if earned:
		Save.add_hint()
		_refresh_hint_badge()
		_on_hint()                               # use it right away
	else:
		_toast("Ad not ready - try again in a moment")


func _show_win(flawless: bool) -> void:
	var msg := "Flawless! No drops lost." if flawless else "Solved with %d drop%s left." % [lives, "" if lives == 1 else "s"]
	_dialog("Level %d clear!" % level_n, msg, [
		["Next level", func(): Ads.maybe_interstitial(func(): _start_level(level_n + 1)), true],
		["Menu", _on_back, false],
	])


func _show_fail() -> void:
	Sfx.play("lose")
	Sfx.haptic("lose")
	var buttons: Array = []
	if Ads.is_active() and lives < MAX_DROPS:
		buttons.append(["Watch ad   +1 drop", _watch_life_ad, true])
		buttons.append(["Try again", func(): _start_level(level_n), false])
	else:
		buttons.append(["Try again", func(): _start_level(level_n), true])
	buttons.append(["Menu", _on_back, false])
	_dialog("Out of drops", "The arrows won this round.", buttons)


func _show_settings() -> void:
	var c: Dictionary = Save.colors()
	var sound_btn: Button
	var vib_btn: Button
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 20)
	sound_btn = UIKit.make_button("", c.panel, c.line, 46, 104)
	vib_btn = UIKit.make_button("", c.panel, c.line, 46, 104)
	var refresh := func():
		sound_btn.text = "Sound: " + ("ON" if Save.sound else "OFF")
		vib_btn.text = "Vibration: " + ("ON" if Save.vibrate else "OFF")
	refresh.call()
	sound_btn.pressed.connect(func(): Save.sound = not Save.sound; Save.save_game(); refresh.call())
	vib_btn.pressed.connect(func(): Save.vibrate = not Save.vibrate; Save.save_game(); refresh.call())
	holder.add_child(sound_btn)
	holder.add_child(vib_btn)
	var seed_lbl := UIKit.make_label("Level seed: %s" % level_seed, 34, c.dim)
	holder.add_child(seed_lbl)
	_dialog("Settings", "", [
		["Restart level", func(): _start_level(level_n), false],
		["Level select", _on_back, false],
		["Close", _close_modal, true],
	], holder)


## Colourful confetti burst for a cleared level.
func _confetti() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(size.x * 0.5, -20.0)
	p.emitting = true
	p.one_shot = true
	p.amount = 110
	p.lifetime = 2.6
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(size.x * 0.5, 10.0)
	p.direction = Vector2(0, 1)
	p.spread = 35.0
	p.gravity = Vector2(0, 650)
	p.initial_velocity_min = 350.0
	p.initial_velocity_max = 900.0
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = 9.0
	p.scale_amount_max = 17.0
	var g := Gradient.new()
	var cols: Array = Save.colors().get("confetti", Save.colors().arrows)
	var stops := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in cols.size():
		stops.append(float(i) / float(maxi(1, cols.size() - 1)))
		colors.append(cols[i])
	g.offsets = stops
	g.colors = colors
	p.color_initial_ramp = g
	p.z_index = 100
	add_child(p)
	get_tree().create_timer(4.0).timeout.connect(p.queue_free)


func _toast(text: String) -> void:
	var c: Dictionary = Save.colors()
	var l := UIKit.make_label(text, 40, Color.WHITE)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.flat(c.line, 40))
	p.add_child(l)
	add_child(p)
	p.reset_size()
	p.position = Vector2((size.x - p.size.x) * 0.5, size.y - 520.0)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
