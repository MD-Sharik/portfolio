extends Control
## Main menu + level select (all 1000 levels; locked until reached).

const LevelDB := preload("res://scripts/level_db.gd")
const IconButton := preload("res://scripts/icon_button.gd")
const UIKit := preload("res://scripts/ui_kit.gd")
const BgDeco := preload("res://scripts/bg_deco.gd")

const COLS := 5


func _ready() -> void:
	Save.theme_changed.connect(func(): get_tree().reload_current_scene())
	_build()


func _build() -> void:
	var c: Dictionary = Save.colors()
	var w := size.x
	var bg := ColorRect.new()
	bg.color = c.bg
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(BgDeco.new())

	# multicolour logo: every letter in a different candy colour
	var pal: Array = c.arrows
	var bb := "[center]"
	var li := 0
	for ch in "ARROW ESCAPE":
		if ch == " ":
			bb += " "
		else:
			bb += "[color=#%s]%s[/color]" % [(pal[(li * 3) % pal.size()] as Color).to_html(false), ch]
			li += 1
	bb += "[/center]"
	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.text = bb
	title.scroll_active = false
	title.add_theme_font_size_override("normal_font_size", 112)
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_outline_color", c.panel)
	title.position = Vector2(0, 100)
	title.size = Vector2(w, 160)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	var sub := UIKit.make_label("tap an arrow  -  slide it out", 40, c.dim)
	sub.position = Vector2(0, 250)
	sub.size = Vector2(w, 60)
	add_child(sub)

	var pal_btn: Control = IconButton.new()
	pal_btn.kind = "palette"
	pal_btn.position = Vector2(w - 154, 40)
	pal_btn.size = Vector2(100, 100)
	pal_btn.pressed.connect(func(): Save.cycle_theme())
	add_child(pal_btn)

	var play := UIKit.make_button("PLAY   -   Level %d" % Save.current_level, c.gold, Color.WHITE, 64, 170)
	play.position = Vector2(60, 340)
	play.size = Vector2(w - 120, 170)
	play.pressed.connect(func(): _open(Save.current_level))
	add_child(play)

	var done := Save.completed.size()
	var stats := UIKit.make_label("%d / %d solved   -   %d hints" % [done, LevelDB.count(), Save.hints], 38, c.line)
	stats.position = Vector2(0, 535)
	stats.size = Vector2(w, 60)
	add_child(stats)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 620)
	scroll.size = Vector2(w - 60, size.y - 620 - 30)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)

	var cell_w := (scroll.size.x - 16.0 * (COLS - 1)) / COLS
	var st_lock := UIKit.flat(c.rule, 28)
	for n in range(1, LevelDB.count() + 1):
		var b := Button.new()
		b.text = str(n)
		b.custom_minimum_size = Vector2(cell_w, cell_w * 0.9)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 44)
		var locked := n > Save.max_level
		var tint: Color = pal[(n - 1) % pal.size()]
		var st: StyleBoxFlat
		if locked:
			st = st_lock
		elif Save.completed.has(n):
			st = UIKit.flat(tint, 28, 0, Color.TRANSPARENT, 6)
		elif n == Save.current_level:
			st = UIKit.flat(c.panel, 28, 10, tint, 6)
		else:
			st = UIKit.flat(c.panel, 28, 4, tint, 4)
		for k in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(k, st)
		var fg: Color = c.dim if locked else (Color.WHITE if Save.completed.has(n) else tint.darkened(0.25))
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			b.add_theme_color_override(k, fg)
		b.disabled = locked
		b.pressed.connect(_open.bind(n))
		grid.add_child(b)

	# scroll so the current level is visible
	var row := (mini(Save.current_level, LevelDB.count()) - 1) / COLS
	var row_h := cell_w * 0.9 + 16.0
	scroll.set_deferred("scroll_vertical", int(maxf(0.0, (row - 1) * row_h)))


func _open(n: int) -> void:
	Save.current_level = n
	Save.save_game()
	get_tree().change_scene_to_file("res://scenes/game.tscn")
