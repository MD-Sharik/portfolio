extends Node
## godot --headless --path . res://tools/revtest.tscn
## Checks the review-prompt rules (with the desktop simulator) and the "update ready" dialog.
func _ready() -> void:
	var now := int(Time.get_unix_time_from_system())
	var fired := [0]
	Review.requested.connect(func(): fired[0] += 1)
	# fresh player: not due
	Save.completed = {}; Save.first_launch_unix = now; Save.review_count = 0; Save.review_last_unix = 0
	print("new player due:            ", Review.is_due(), "  (expect false)")
	# enough levels but installed just now
	for n in range(1, 8): Save.completed[n] = true
	print("7 levels, day 0 due:       ", Review.is_due(), "  (expect false)")
	# installed 3 days ago -> due
	Save.first_launch_unix = now - 3 * 86400
	print("7 levels, day 3 due:       ", Review.is_due(), "  (expect true)")
	var asked := Review.maybe_request()
	print("maybe_request asked:       ", asked, " fired=", fired[0], " count=", Save.review_count, "  (expect true 1 1)")
	print("right after, due:          ", Review.is_due(), "  (expect false - cooldown)")
	# 91 days later -> due again, third time is the last
	Save.review_last_unix = now - 91 * 86400
	print("91 days later due:         ", Review.is_due(), "  (expect true)")
	Save.review_count = 3
	print("3 prompts already, due:    ", Review.is_due(), "  (expect false - lifetime cap)")
	# update dialog
	Updates.show_restart_dialog()
	await get_tree().process_frame
	await get_tree().process_frame
	print("update dialog shown:       ", Updates._layer != null and Updates._layer.get_child_count() > 0)
	Updates._close()
	await get_tree().process_frame
	print("update dialog closed:      ", Updates._layer == null)
	# restore the dev save so test data does not stick
	Save.completed = {}; Save.review_count = 0; Save.review_last_unix = 0
	get_tree().quit()
