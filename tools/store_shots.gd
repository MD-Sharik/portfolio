extends Node
## Renders the Play Store phone screenshots (1080x1920) from the real game:
##   godot --path . res://tools/store_shots.tscn     (needs a window; output: store/screenshots/*.png)

const W := 1080
const H := 1920
const OUT := "res://store/screenshots/"
const Decor := preload("res://tools/store_decor.gd")

# [file, caption, scene, theme, level, mode]
const SHOTS := [
	["01_hardest_arrow_game", "HARDEST ARROW GAME", "game", 0, 1, "hint"],
	["02_tap_to_slide_out", "TAP ARROWS TO SLIDE THEM OUT", "game", 2, 40, "slide"],
	["03_1000_levels", "1000 BRAIN-BURNING LEVELS", "menu", 0, 15, ""],
	["04_blocked", "BLOCKED? YOU LOSE A DROP!", "game", 1, 150, "wrong"],
	["05_black_and_white", "BLACK & WHITE MODE", "game", 5, 8, "hint"],
	["06_level_clear", "CLEAR THE BOARD - CONFETTI!", "game", 3, 3, "win"],
]


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for shot in SHOTS:
		await _make(shot)
	print("screenshots done")
	get_tree().quit()


func _make(shot: Array) -> void:
	# game state for this shot (in memory only)
	Save.theme = shot[3]
	Save.hints = 3
	Save.completed = {}
	Save.current_level = shot[4]
	Save.max_level = maxi(shot[4], 15)
	if shot[2] == "menu":
		for n in range(1, 15):
			Save.completed[n] = true

	var outer := SubViewport.new()
	outer.size = Vector2i(W, H)
	outer.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(outer)
	var root := Control.new()
	root.size = Vector2(W, H)
	outer.add_child(root)

	var bgc := ColorRect.new()
	bgc.color = Color.WHITE
	bgc.size = Vector2(W, H)
	root.add_child(bgc)
	var decor := Decor.new()
	decor.size = Vector2(W, H)
	root.add_child(decor)

	# phone: black bezel -> rounded mask -> scaled sub viewport with the real game
	var scale_f := 0.74
	var sw := W * scale_f
	var sh := H * scale_f
	var pad := 26.0
	var frame := Panel.new()
	frame.position = Vector2((W - sw) * 0.5 - pad, 380.0)
	frame.size = Vector2(sw + pad * 2, sh + pad * 2)
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color("111111")
	fs.set_corner_radius_all(78)
	fs.shadow_size = 28
	fs.shadow_color = Color(0, 0, 0, 0.35)
	fs.shadow_offset = Vector2(0, 14)
	frame.add_theme_stylebox_override("panel", fs)
	root.add_child(frame)
	var mask := Panel.new()
	mask.position = Vector2(pad, pad)
	mask.size = Vector2(sw, sh)
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color.WHITE
	ms.set_corner_radius_all(54)
	mask.add_theme_stylebox_override("panel", ms)
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	frame.add_child(mask)
	var svc := SubViewportContainer.new()
	svc.size = Vector2(W, H)
	svc.scale = Vector2(scale_f, scale_f)
	mask.add_child(svc)
	var inner := SubViewport.new()
	inner.size = Vector2i(W, H)
	inner.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(inner)
	var game: Control = load("res://scenes/%s.tscn" % shot[2]).instantiate()
	inner.add_child(game)

	# caption ribbon
	var ribbon := ColorRect.new()
	ribbon.color = Color("e11313")
	ribbon.size = Vector2(1500, 214)
	ribbon.pivot_offset = ribbon.size * 0.5
	ribbon.position = Vector2(W * 0.5, 205) - ribbon.size * 0.5
	ribbon.rotation = deg_to_rad(-3.0)
	root.add_child(ribbon)
	var shine := ColorRect.new()
	shine.color = Color(1, 1, 1, 0.22)
	shine.size = Vector2(1500, 34)
	ribbon.add_child(shine)
	var cap := Label.new()
	cap.text = shot[1]
	cap.size = ribbon.size
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var font := cap.get_theme_default_font()
	var fsz := 104
	while fsz > 40 and font.get_string_size(cap.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x > 880.0:
		fsz -= 4
	cap.add_theme_font_size_override("font_size", fsz)
	cap.add_theme_color_override("font_color", Color.WHITE)
	cap.add_theme_constant_override("outline_size", 22)
	cap.add_theme_color_override("font_outline_color", Color.BLACK)
	ribbon.add_child(cap)

	# scene setup
	await _frames(10)
	if shot[2] == "game":
		var b: Control = game.board
		match shot[5]:
			"hint":
				b.show_hint()
			"slide":
				var tapped := 0
				while tapped < 4:
					var id: int = b.any_free_arrow()
					if id < 0:
						break
					b.tap_arrow(id)
					tapped += 1
				await _frames(3)
			"wrong":
				for i in b.arrows.size():
					if b._ray_info(i).blocker != -1:
						b.tap_arrow(i)
						break
				await _frames(10)
			"win":
				while b.alive_count > 0:
					b.tap_arrow(b.any_free_arrow())
				var waited := 0.0
				while not b._clear_sent and waited < 12.0:
					await get_tree().create_timer(0.1).timeout
					waited += 0.1
				await get_tree().create_timer(1.0).timeout      # dialog pops in, confetti falling
	await _frames(8)
	var img := outer.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(OUT + shot[0] + ".png")
	# raw in-app frame (no phone / ribbon) for the website
	var raw := inner.get_texture().get_image()
	raw.convert(Image.FORMAT_RGB8)
	raw.resize(540, 960, Image.INTERPOLATE_LANCZOS)
	var n: int = SHOTS.find(shot) + 1
	raw.save_png("res://docs/assets/img/app%d.png" % n)
	print("saved ", shot[0], " ", img.get_size())
	outer.queue_free()
	await _frames(2)
