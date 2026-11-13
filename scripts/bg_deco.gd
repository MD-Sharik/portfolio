extends Control
## Soft, colourful background bubbles (pure decoration, ignores the mouse).


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Save.theme_changed.connect(queue_redraw)
	resized.connect(queue_redraw)


func _draw() -> void:
	var cols: Array = Save.colors().deco
	# fixed pseudo-random layout (fractions of the screen) so it never jumps around
	var spots := [
		Vector3(0.08, 0.30, 0.16), Vector3(0.92, 0.22, 0.12), Vector3(0.80, 0.55, 0.20),
		Vector3(0.14, 0.62, 0.13), Vector3(0.50, 0.40, 0.09), Vector3(0.90, 0.85, 0.15),
		Vector3(0.20, 0.90, 0.18), Vector3(0.62, 0.72, 0.08), Vector3(0.35, 0.18, 0.07),
	]
	for i in spots.size():
		var s: Vector3 = spots[i]
		var c: Color = cols[i % cols.size()]
		c.a = 0.55
		draw_circle(Vector2(s.x * size.x, s.y * size.y), s.z * size.x, c)
