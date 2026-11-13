extends Control
## Chunky black arrows for the Play Store screenshot background (same look as the artwork).

func _draw() -> void:
	var ink := Color("1b1b1b")
	# [x, y, angle(deg, 0 = right, -90 = up), length]
	for a in [[56, 1180, -90, 460], [1028, 800, 90, 430], [1030, 1560, -90, 260]]:
		var p := Vector2(a[0], a[1])
		var dir := Vector2.RIGHT.rotated(deg_to_rad(float(a[2])))
		var perp := Vector2(-dir.y, dir.x)
		var tail: Vector2 = p - dir * float(a[3])
		draw_line(tail, p, ink, 50.0, true)
		draw_circle(tail, 25.0, ink)
		draw_colored_polygon(PackedVector2Array([p + dir * 110.0, p + perp * 78.0, p - perp * 78.0]), ink)
