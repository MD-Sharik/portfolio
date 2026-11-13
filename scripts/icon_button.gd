extends Control
## Colourful round icon button (back, palette, settings, fit, hint) + the shiny life drop.
## Glyphs are drawn in code (white on a candy-coloured disc), so they stay crisp at any size.

signal pressed

@export var kind: String = "back"
@export var interactive: bool = true
@export var filled: bool = true       # drop: full / empty
var badge: int = -1                   # small number bubble (hint count); -1 = none
var badge_text := ""                  # or a word instead of a number (e.g. "AD")

const TINTS := {
	"back": Color("ff9f1c"), "palette": Color("ff5c8a"), "settings": Color("3da5f4"),
	"fit": Color("1fbfae"), "hint": Color("8b5cf6"),
}

var _down := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	Save.theme_changed.connect(queue_redraw)
	resized.connect(func(): pivot_offset = size * 0.5)
	pivot_offset = size * 0.5


func set_badge(v: int) -> void:
	badge = v
	badge_text = ""
	queue_redraw()


func set_badge_text(t: String) -> void:
	badge_text = t
	queue_redraw()


func set_filled(v: bool) -> void:
	filled = v
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if not interactive:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_down = true
			scale = Vector2(0.88, 0.88)
			Sfx.haptic("light")
		elif _down:
			_down = false
			create_tween().tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if Rect2(Vector2.ZERO, size).has_point(ev.position):
				pressed.emit()
		accept_event()


# white line with round caps
func _rl(a: Vector2, b: Vector2, w: float, c: Color) -> void:
	draw_line(a, b, c, w, true)
	draw_circle(a, w * 0.5, c)
	draw_circle(b, w * 0.5, c)


func _rpoly(pts: Array, w: float, c: Color) -> void:
	for i in range(pts.size() - 1):
		_rl(pts[i], pts[i + 1], w, c)


func _draw() -> void:
	var col: Dictionary = Save.colors()
	var m: float = minf(size.x, size.y)
	if kind == "drop":
		_draw_drop(col, m)
		return
	var tint: Color = col.get("btn", TINTS.get(kind, Color("ff9f1c")))
	var center := size * 0.5
	var r := m * 0.5
	# disc: soft shadow, darker rim, bright face, glossy highlight
	draw_circle(center + Vector2(0, m * 0.04), r, Color(0, 0, 0, 0.16))
	draw_circle(center, r, tint.darkened(0.18))
	draw_circle(center - Vector2(0, m * 0.025), r * 0.93, tint)
	draw_circle(center + Vector2(-r * 0.28, -r * 0.42), r * 0.2, Color(1, 1, 1, 0.28))
	var k := m / 100.0 * 0.56
	var off := (size - Vector2(100, 100) * k) * 0.5 - Vector2(0, m * 0.012)
	draw_set_transform(off, 0.0, Vector2(k, k))
	var w: Color = col.get("btn_glyph", Color.WHITE)
	match kind:
		"back":
			_rl(Vector2(86, 50), Vector2(20, 50), 14, w)
			_rpoly([Vector2(48, 20), Vector2(18, 50), Vector2(48, 80)], 14, w)
		"palette":
			draw_circle(Vector2(50, 52), 44, w)
			draw_circle(Vector2(70, 76), 10, tint)
			var dots: Array = col.arrows
			for i in 4:
				var p: Vector2 = [Vector2(30, 44), Vector2(46, 26), Vector2(68, 34), Vector2(26, 66)][i]
				draw_circle(p, 8.5, dots[i % dots.size()])
		"settings":
			var pts := PackedVector2Array()
			for t in 8:
				var a0 := float(t) * TAU / 8.0
				for pr in [[-0.30, 33.0], [-0.17, 46.0], [0.17, 46.0], [0.30, 33.0]]:
					var ang: float = a0 + pr[0]
					pts.append(Vector2(50, 50) + Vector2(cos(ang), sin(ang)) * pr[1])
			draw_colored_polygon(pts, w)
			draw_circle(Vector2(50, 50), 16, tint)
		"fit":
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var c0 := Vector2(50 + sx * 34, 50 + sy * 34)
					_rpoly([c0 + Vector2(-sx * 18, 0), c0, c0 + Vector2(0, -sy * 18)], 12, w)
			draw_circle(Vector2(50, 50), 8, w)
		"hint":
			draw_circle(Vector2(50, 40), 29, w)
			draw_colored_polygon(PackedVector2Array([Vector2(34, 58), Vector2(66, 58), Vector2(60, 80), Vector2(40, 80)]), w)
			_rl(Vector2(40, 90), Vector2(60, 90), 9, w)
			_rpoly([Vector2(39, 38), Vector2(45, 52), Vector2(50, 38), Vector2(55, 52), Vector2(61, 38)], 5.5, tint.darkened(0.1))
			for ray in [[Vector2(50, 0), Vector2(50, 7)], [Vector2(18, 12), Vector2(23, 17)], [Vector2(82, 12), Vector2(77, 17)]]:
				_rl(ray[0], ray[1], 6, w)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if badge >= 0 or badge_text != "":
		var is_text := badge_text != ""
		var br := m * (0.25 if is_text else 0.22)
		var p := Vector2(size.x * 0.84, size.y * 0.12)
		var fill: Color = Color("ff6a00") if is_text else (Color("2fbf71") if badge > 0 else col.dim)
		draw_circle(p, br * 1.12, Color.WHITE)
		draw_circle(p, br, fill)
		var f := ThemeDB.fallback_font
		var fs := int(br * (1.05 if is_text else 1.45))
		draw_string(f, p + Vector2(-br, fs * 0.34), badge_text if is_text else str(badge), HORIZONTAL_ALIGNMENT_CENTER, br * 2.0, fs, Color.WHITE)


func _draw_drop(col: Dictionary, m: float) -> void:
	var k := m / 100.0
	draw_set_transform((size - Vector2(100, 100) * k) * 0.5, 0.0, Vector2(k, k))
	var base: Color = col.drop
	var dc: Color = base if filled else Color(base.r, base.g, base.b, 0.22)
	draw_circle(Vector2(50, 64), 32.0, dc)
	draw_colored_polygon(PackedVector2Array([Vector2(50, 2), Vector2(19, 56), Vector2(81, 56)]), dc)
	if filled:
		draw_circle(Vector2(50, 64), 32.0, base.darkened(0.12))
		draw_circle(Vector2(50, 62), 27.0, base)
		draw_circle(Vector2(38, 56), 7.0, Color(1, 1, 1, 0.75))
		draw_circle(Vector2(31, 68), 3.2, Color(1, 1, 1, 0.55))
	draw_set_transform_matrix(Transform2D.IDENTITY)
