extends Node
## Headless self-test:  godot --headless --path . res://tools/selftest.tscn [-- --all]
## Plays levels with the real Board logic: solves them by tapping free arrows, checks that
## blocked taps bump, that the hit-test finds arrows and that 'cleared' fires.
## With --all the huge boards (>500 arrows) are only played on every 7th level, add --full to play all.

const LevelDB := preload("res://scripts/level_db.gd")
const Board := preload("res://scripts/board.gd")

var cleared_count := 0


func _ready() -> void:
	var board: Control = Board.new()
	board.size = Vector2(1000, 1100)
	add_child(board)
	board.cleared.connect(func(): cleared_count += 1)
	var levels: Array = []
	if OS.get_cmdline_user_args().has("--all"):
		for n in range(1, LevelDB.baked_count() + 1):
			levels.append(n)
	else:
		levels = [1, 2, 3, 5, 10, 50, 100, 250, 500, 750, 1000, 1001]
	var problems := 0
	var blocked_tests := 0
	for n in levels:
		await get_tree().process_frame      # like the real game: let freed arrow nodes / redraws flush
		var lvl := LevelDB.build(n)
		board.load_level(lvl)
		var total: int = board.arrows.size()
		var play_it: bool = total <= 500 or n % 7 == 0 or OS.get_cmdline_user_args().has("--full") or levels.size() < 50
		# hit-test: tapping the centre of (up to 80 sampled) arrows' cells finds the owner
		var step := maxi(1, total / 80)
		for i in range(0, total, step):
			for c in board.arrows[i].cells:
				var pos: Vector2 = board.view_offset + (Vector2(c) + Vector2(0.5, 0.5)) * board.base_cs * board.zoom
				if board._hit(pos) != i:
					problems += 1
					print("level %d: hit-test mismatch arrow %d cell %s" % [n, i, c])
		# a blocked arrow must bump and keep its place
		for i in total:
			if board._ray_info(i).blocker != -1:
				var before: int = board.alive_count
				if board.tap_arrow(i) != 0 or board.alive_count != before:
					problems += 1
					print("level %d: blocked tap misbehaved" % n)
				blocked_tests += 1
				for _f in 60:
					board._process(0.05)
				if board.arrows[i].state != board.ST_IDLE:
					problems += 1
					print("level %d: bump did not finish" % n)
				break
		if not play_it:
			continue
		# solve it
		var guard := 0
		var before_clear := cleared_count
		while board.alive_count > 0 and guard < 10000:
			guard += 1
			var id: int = board.any_free_arrow()
			if id < 0:
				problems += 1
				print("level %d: STUCK with %d arrows left" % [n, board.alive_count])
				break
			board.tap_arrow(id)
		for _f in 80:
			board._process(0.05)
		if board.alive_count == 0 and cleared_count != before_clear + 1:
			problems += 1
			print("level %d: cleared signal missing" % n)
	print("selftest: %d levels, %d blocked-tap checks, %d problems" % [levels.size(), blocked_tests, problems])
	get_tree().quit(1 if problems > 0 else 0)
