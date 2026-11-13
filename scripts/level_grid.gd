extends Control
## Level-select grid with its own touch scrolling.
##
## Why not ScrollContainer + 1000 Buttons? Buttons swallow touch drags (so the list would not
## scroll when you start the swipe on a level), and 1000 nodes are heavy. This control draws only
## the visible rows, scrolls with finger drag + momentum + mouse wheel, and tells apart a tap from
## a swipe.

signal level_pressed(n: int)

const COLS := 5
const GAP := 16.0
const TAP_SLOP := 14.0          # px a finger may move and still count as a tap
const FRICTION := 0.93          # momentum decay per 1/60 s
const FONT_SIZE := 44

var count := 1000
var scroll_y := 0.0
var _velocity := 0.0
var _pressing := false
var _dragging := false
var _press_pos := Vector2.ZERO
var _press_level := 0
var _moving_at_press := false
var _last_pos := Vector2.ZERO
var _last_t := 0.0
var _scroll_flash := 0.0
var _styles := {}               # cache: tint+state -> StyleBoxFlat


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	resized.connect(_on_resized)
	Save.theme_changed.connect(func(): _styles.clear(); queue_redraw())


func _on_resized() -> void:
	scroll_y = clampf(scroll_y, 0.0, _max_scroll())
	queue_redraw()


func cell_w() -> float:
	return (size.x - GAP * (COLS - 1)) / COLS


func cell_h() -> float:
	return cell_w() * 0.9


func row_h() -> float:
	return cell_h() + GAP


func _rows() -> int:
	return int(ceil(float(count) / COLS))


func _max_scroll() -> float:
	return maxf(0.0, _rows() * row_h() - GAP - size.y + 8.0)


func scroll_to_level(n: int, center: bool = true) -> void:
	var row := (clampi(n, 1, count) - 1) / COLS
	var y := row * row_h()
	if center:
		y -= (size.y - cell_h()) * 0.5
	scroll_y = clampf(y, 0.0, _max_scroll())
	_velocity = 0.0
	queue_redraw()


func level_at(pos: Vector2) -> int:
	var x := pos.x
	var y := pos.y + scroll_y
	var col := int(x / (cell_w() + GAP))
	var row := int(y / row_h())
	if col < 0 or col >= COLS or row < 0:
		return 0
	# inside the gap between cells?
	if x - col * (cell_w() + GAP) > cell_w() or y - row * row_h() > cell_h():
		return 0
	var n := row * COLS + col + 1
	return n if n <= count else 0


# ------------------------------------------------------------------ input

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if ev.pressed:
					_scroll_by(-row_h() * 1.5)
			MOUSE_BUTTON_WHEEL_DOWN:
				if ev.pressed:
					_scroll_by(row_h() * 1.5)
			MOUSE_BUTTON_LEFT:
				if ev.pressed:
					_pressing = true
					_dragging = false
					_press_pos = ev.position
					_last_pos = ev.position
					_last_t = Time.get_ticks_msec() / 1000.0
					_moving_at_press = absf(_velocity) > 60.0   # a tap only stops a fling
					_velocity = 0.0
					_press_level = level_at(ev.position)
					queue_redraw()
				else:
					if _pressing and not _dragging and not _moving_at_press and _press_level > 0 \
							and level_at(ev.position) == _press_level:
						level_pressed.emit(_press_level)
					_pressing = false
					_press_level = 0
					if _dragging and absf(_velocity) > 40.0:
						set_process(true)
					_dragging = false
					queue_redraw()
	elif ev is InputEventMouseMotion and _pressing:
		if not _dragging and ev.position.distance_to(_press_pos) > TAP_SLOP:
			_dragging = true
			_press_level = 0          # swipe, not a tap
		if _dragging:
			var now := Time.get_ticks_msec() / 1000.0
			var dy: float = ev.position.y - _last_pos.y
			scroll_y = clampf(scroll_y - dy, 0.0, _max_scroll())
			var dt := maxf(0.001, now - _last_t)
			_velocity = lerpf(_velocity, -dy / dt, 0.5)
			_last_pos = ev.position
			_last_t = now
			_scroll_flash = 1.0
			queue_redraw()
	elif ev is InputEventPanGesture:
		_scroll_by(ev.delta.y * 30.0)


func _scroll_by(dy: float) -> void:
	scroll_y = clampf(scroll_y + dy, 0.0, _max_scroll())
	_scroll_flash = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if _pressing:
		return
	scroll_y += _velocity * delta
	if scroll_y <= 0.0 or scroll_y >= _max_scroll():
		scroll_y = clampf(scroll_y, 0.0, _max_scroll())
		_velocity = 0.0
	_velocity *= pow(FRICTION, delta * 60.0)
	_scroll_flash = maxf(_scroll_flash, 0.6)
	if absf(_velocity) < 12.0:
		_velocity = 0.0
		set_process(false)
	queue_redraw()


# ------------------------------------------------------------------ drawing

func _style(kind: String, tint: Color) -> StyleBoxFlat:
	var key := "%s%s" % [kind, tint.to_html()]
	if _styles.has(key):
		return _styles[key]
	var c: Dictionary = Save.colors()
	var s: StyleBoxFlat
	match kind:
		"locked":
			s = _flat(c.rule, 0, tint)
		"done":
			s = _flat(tint, 0, tint)
		"current":
			s = _flat(c.panel, 10, tint)
		"pressed":
			s = _flat(tint.lightened(0.55), 4, tint)
		_:
			s = _flat(c.panel, 4, tint)
	_styles[key] = s
	return s


func _flat(bg: Color, border_w: int, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(28)
	if border_w > 0:
		s.set_border_width_all(border_w)
		s.border_color = border
	s.shadow_size = 4
	s.shadow_color = Color(0, 0, 0, 0.12)
	s.shadow_offset = Vector2(0, 4)
	return s


func _draw() -> void:
	var c: Dictionary = Save.colors()
	var pal: Array = c.arrows
	var cw := cell_w()
	var ch := cell_h()
	var first_row := maxi(0, int(scroll_y / row_h()) - 1)
	var last_row := mini(_rows() - 1, int((scroll_y + size.y) / row_h()) + 1)
	var font := get_theme_default_font()
	for row in range(first_row, last_row + 1):
		for col in COLS:
			var n := row * COLS + col + 1
			if n > count:
				break
			var r := Rect2(col * (cw + GAP), row * row_h() - scroll_y, cw, ch)
			var tint: Color = pal[(n - 1) % pal.size()]
			var kind := "open"
			var fg: Color = tint.darkened(0.25)
			if n > Save.max_level:
				kind = "locked"
				fg = c.dim
			elif Save.completed.has(n):
				kind = "done"
				fg = Color.WHITE if tint.get_luminance() < 0.8 else Color.BLACK
			elif n == Save.current_level:
				kind = "current"
			if _pressing and not _dragging and n == _press_level and n <= Save.max_level:
				kind = "pressed"
			draw_style_box(_style(kind, tint), r)
			var txt := str(n)
			var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
			draw_string(font, Vector2(r.position.x + (cw - ts.x) * 0.5, r.position.y + (ch + ts.y * 0.62) * 0.5), txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, fg)
	# slim scrollbar
	var max_s := _max_scroll()
	if max_s > 0.0:
		var bar_h := maxf(60.0, size.y * size.y / (size.y + max_s))
		var bar_y := (size.y - bar_h) * (scroll_y / max_s)
		var sc: Color = c.line
		sc.a = 0.35
		draw_rect(Rect2(size.x - 7.0, bar_y, 5.0, bar_h), sc, true)
