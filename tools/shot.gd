extends Node
## Screenshot helper:  godot --path . res://tools/shot.tscn -- --level 10 --out C:/x.png [--scene menu] [--theme 1] [--hint] [--wrong]
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var level := 10
	var out := "user://shot.png"
	var scene := "game"
	var theme := 0
	for i in a.size():
		if a[i] == "--level": level = int(a[i + 1])
		if a[i] == "--out": out = a[i + 1]
		if a[i] == "--scene": scene = a[i + 1]
		if a[i] == "--theme": theme = int(a[i + 1])
	Save.current_level = level
	Save.max_level = maxi(Save.max_level, level)
	Save.theme = theme
	var inst: Node = load("res://scenes/%s.tscn" % scene).instantiate()
	add_child(inst)
	for _i in 8:
		await get_tree().process_frame
	if a.has("--wrong") and scene == "game":
		var b = inst.board
		for i in b.arrows.size():
			if b._ray_info(i).blocker != -1:
				b.tap_arrow(i)
				break
		for _i in 10:
			await get_tree().process_frame
	if a.has("--hint") and scene == "game":
		inst.board.show_hint()
		for _i in 6:
			await get_tree().process_frame
	if a.has("--win") and scene == "game":
		var b = inst.board
		while b.alive_count > 0:
			b.tap_arrow(b.any_free_arrow())
		for _i in 60:
			await get_tree().process_frame
		await get_tree().create_timer(0.8).timeout
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	get_tree().quit()
