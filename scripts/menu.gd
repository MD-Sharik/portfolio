extends Control
## Main menu + level select (all 1000 levels; locked until reached).

const LevelDB := preload("res://scripts/level_db.gd")
const IconButton := preload("res://scripts/icon_button.gd")
const UIKit := preload("res://scripts/ui_kit.gd")
const BgDeco := preload("res://scripts/bg_deco.gd")
const LevelGrid := preload("res://scripts/level_grid.gd")

const FOOTER_H := 170.0

var grid_view: Control


func _ready() -> void:
	Save.theme_changed.connect(func(): get_tree().reload_current_scene())
	_build()
	Ads.show_banner(true)


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
	pal_btn.position = Vector2(w - 130, 22)
	pal_btn.size = Vector2(88, 88)
	pal_btn.pressed.connect(func(): Save.cycle_theme())
	add_child(pal_btn)

	var play := UIKit.make_button("PLAY   -   Level %d" % Save.current_level, c.gold, c.get("on_gold", Color.WHITE), 64, 170)
	play.position = Vector2(60, 340)
	play.size = Vector2(w - 120, 170)
	play.pressed.connect(func(): _open(Save.current_level))
	add_child(play)

	var done := Save.completed.size()
	var stats := UIKit.make_label("%d / %d solved   -   %d hints" % [done, LevelDB.count(), Save.hints], 38, c.line)
	stats.position = Vector2(0, 535)
	stats.size = Vector2(w, 60)
	add_child(stats)

	# colourful footer strip (also the spot where the banner ad sits)
	var footer := ColorRect.new()
	footer.color = c.footer
	footer.position = Vector2(0, size.y - FOOTER_H)
	footer.size = Vector2(w, FOOTER_H)
	add_child(footer)

	grid_view = LevelGrid.new()
	grid_view.position = Vector2(30, 620)
	grid_view.size = Vector2(w - 60, size.y - 620 - FOOTER_H - 20)
	grid_view.count = LevelDB.count()
	add_child(grid_view)
	grid_view.level_pressed.connect(_on_level_pressed)
	grid_view.scroll_to_level(Save.current_level)


func _on_level_pressed(n: int) -> void:
	if n > Save.max_level:
		Sfx.play("wrong")
		return
	Sfx.haptic("light")
	Sfx.play("tap")
	_open(n)


func _open(n: int) -> void:
	Save.current_level = n
	Save.save_game()
	get_tree().change_scene_to_file("res://scenes/game.tscn")
