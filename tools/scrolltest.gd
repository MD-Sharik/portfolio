extends Node
## godot --path . res://tools/scrolltest.tscn   (window needed so input events flow)
var picked := 0

func _mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = get_viewport().get_final_transform() * pos
	e.global_position = e.position
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(e)

func _move(pos: Vector2, rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = get_viewport().get_final_transform() * pos
	e.global_position = e.position
	e.relative = rel * get_viewport().get_final_transform().get_scale()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)

func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame

func _ready() -> void:
	Save.max_level = 1000
	Save.current_level = 1
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await _frames(4)
	var g: Control = menu.grid_view
	g.level_pressed.disconnect(menu._on_level_pressed)   # a real tap would change scene
	g.level_pressed.connect(func(n): picked = n)
	print("grid at ", g.position, " size ", g.size, " scroll_y=", g.scroll_y, " max=", g._max_scroll())
	# 1) finger drag starting ON a level cell must scroll (this is what used to be impossible with Buttons)
	var start := g.position + Vector2(200, 700)
	_mouse(start, true)
	await _frames(2)
	var y := 0.0
	for i in 10:
		y -= 60.0
		_move(start + Vector2(0, y), Vector2(0, -60))
		await _frames(1)
	_mouse(start + Vector2(0, y), false)
	await _frames(2)
	var after_drag: float = g.scroll_y
	print("drag up 600px: scroll_y=%.0f  %s  (tap fired: %s)" % [after_drag, "OK" if after_drag > 300.0 else "FAILED", picked != 0])
	# 2) momentum keeps it moving after release
	await _frames(20)
	print("momentum: scroll_y=%.0f  %s" % [g.scroll_y, "OK" if g.scroll_y > after_drag + 5.0 else "(no momentum)"])
	# 3) a plain tap selects the level under the finger
	await _frames(120)
	g.scroll_to_level(12, true)
	await _frames(2)
	var cell := g.position + Vector2(g.cell_w() * 0.5, g.size.y * 0.5)
	var expect: int = g.level_at(Vector2(g.cell_w() * 0.5, g.size.y * 0.5))
	_mouse(cell, true)
	await _frames(2)
	_mouse(cell, false)
	await _frames(2)
	print("tap on level %d -> level_pressed(%d)  %s" % [expect, picked, "OK" if picked == expect and expect > 0 else "FAILED"])
	# 4) scroll to the end, no overscroll
	g.scroll_y = 1e9
	g._scroll_by(0.0)
	print("clamped to max: %s" % ["OK" if is_equal_approx(g.scroll_y, g._max_scroll()) else "FAILED"])
	get_tree().quit()
