extends Node
## godot --headless --path . res://tools/adtest.tscn
## Exercises the lives / hint reward flows with the built-in ad simulator.
func _ready() -> void:
	Save.hints = 0
	Save.current_level = 5
	Save.max_level = 5
	var game: Control = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for _i in 4:
		await get_tree().process_frame
	var b: Control = game.board
	print("start: lives=%d slots=%d ads_active=%s" % [game.lives, game.life_slots, Ads.is_active()])
	var guard := 0
	while game.lives > 0 and guard < 30:
		guard += 1
		for i in b.arrows.size():
			if b.arrows[i].state == b.ST_IDLE and b._ray_info(i).blocker != -1:
				b.tap_arrow(i)
				break
		for _f in 40:
			await get_tree().process_frame
	await get_tree().create_timer(1.3).timeout
	print("out of drops: lives=%d locked=%s dialog_nodes=%d" % [game.lives, b.locked, game.modal.get_child_count()])
	game._watch_life_ad()
	await get_tree().create_timer(3.6).timeout
	print("after ad: lives=%d slots=%d locked=%s" % [game.lives, game.life_slots, b.locked])
	game._on_hint()
	print("hint dialog shown: %s (hints=%d)" % [game.modal.get_child_count() > 0, Save.hints])
	game._watch_hint_ad()
	await get_tree().create_timer(3.6).timeout
	print("after hint ad: hint_id=%d hints=%d" % [b.hint_id, Save.hints])
	var next_called := [false]
	Ads._levels_since = 5
	Ads._last_inter_time = -1000.0
	Ads.maybe_interstitial(func(): next_called[0] = true)
	await get_tree().create_timer(2.6).timeout
	print("interstitial then-callback ran: %s" % next_called[0])
	get_tree().quit()
