extends Node
## godot --path . res://tools/pinchtest.tscn   (needs a window/viewport that processes input)
const LevelDB := preload("res://scripts/level_db.gd")
const Board := preload("res://scripts/board.gd")

func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = get_viewport().get_final_transform() * pos   # viewport coords -> window coords
	e.pressed = pressed
	Input.parse_input_event(e)

func _drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = get_viewport().get_final_transform() * pos   # viewport coords -> window coords
	e.relative = rel
	Input.parse_input_event(e)

func _ready() -> void:
	var board: Control = Board.new()
	board.size = Vector2(900, 1000)
	board.position = Vector2(50, 50)
	add_child(board)
	board.load_level(LevelDB.build(100))     # ~19x21 board -> starts fit (zoom 1)
	for _i in 3:
		await get_tree().process_frame
	var z0: float = board.zoom
	var c := Vector2(500, 550)
	_touch(0, c - Vector2(40, 0), true)
	_touch(1, c + Vector2(40, 0), true)
	for _i in 2:
		await get_tree().process_frame
	for step in range(1, 9):
		var o := 40.0 + step * 30.0
		_drag(0, c - Vector2(o, 0), Vector2(-30, 0))
		_drag(1, c + Vector2(o, 0), Vector2(30, 0))
		await get_tree().process_frame
		await get_tree().process_frame
	var z1: float = board.zoom
	_touch(0, c - Vector2(280, 0), false)
	_touch(1, c + Vector2(280, 0), false)
	await get_tree().process_frame
	await get_tree().process_frame
	print("pinch out: zoom %.2f -> %.2f  %s" % [z0, z1, "OK" if z1 > z0 * 2.0 else "FAILED"])
	# pinch back in
	_touch(0, c - Vector2(280, 0), true)
	_touch(1, c + Vector2(280, 0), true)
	for _i in 2:
		await get_tree().process_frame
	for step in range(1, 9):
		var o := 280.0 - step * 30.0
		_drag(0, c - Vector2(o, 0), Vector2(30, 0))
		_drag(1, c + Vector2(o, 0), Vector2(-30, 0))
		await get_tree().process_frame
		await get_tree().process_frame
	print("pinch in:  zoom %.2f -> %.2f  %s" % [z1, board.zoom, "OK" if board.zoom < z1 * 0.6 else "FAILED"])
	get_tree().quit()
