extends Control
## The puzzle board: draws arrows, handles taps, slide / bump animation, hints, pan + zoom.
##
## Rule: tapping an arrow slides it forward (its body follows its own path like a snake)
## and off the board - but only if every cell in a straight line in front of its head is
## empty. Otherwise it bumps into the blocker and the player loses a drop.
##
## Every arrow is its own Node2D (arrow_node.gd) under `world`; panning/zooming only changes
## world's transform, so 128x128 boards with thousands of arrows stay smooth.

signal arrow_escaped
signal arrow_blocked
signal cleared

const ArrowNode := preload("res://scripts/arrow_node.gd")

const ST_IDLE := 0
const ST_OUT := 1
const ST_BUMP := 2
const ST_GONE := 3

const BASE_LINE_W := 0.085 # line thickness in cells (grows on huge boards so lines stay visible)
const MIN_LINE_PX := 1.3
const HEAD_TIP := 0.40     # arrow head: tip distance ahead of the path end (cells)
const HEAD_HALF := 0.25    # arrow head half width (cells)
const COLOR_SLOTS := 10    # colours handed out per board (mapped onto the theme palette)
const MAX_CELL := 150.0    # px, so tiny boards don't become giant
const MAX_ZOOM := 16.0
const COMFY_CELL := 44.0   # px per cell we start huge boards at

var gw := 0
var gh := 0
var arrows: Array = []
var nodes: Array = []
var grid := PackedInt32Array()
var alive_count := 0
var locked := false
var hint_id := -1
var line_w := BASE_LINE_W

var base_cs := 40.0
var zoom := 1.0
var view_offset := Vector2.ZERO
var world: Node2D

var _active := {}          # arrow ids that are animating / flashing
var _clear_sent := false
var _time := 0.0

# input
var _pressing := false
var _press_pos := Vector2.ZERO
var _dragged := false
var _gesture := false
var _touches := {}
var _pinch_prev := 0.0
var _pinch_center := Vector2.ZERO


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	world = Node2D.new()
	add_child(world)
	resized.connect(_on_resized)
	Save.theme_changed.connect(_redraw_all)


func _redraw_all() -> void:
	for n in nodes:
		n.queue_redraw()


# ------------------------------------------------------------------ level

func load_level(level: Dictionary) -> void:
	for ch in world.get_children():
		world.remove_child(ch)
		ch.free()
	nodes.clear()
	_active.clear()
	gw = int(level.w)
	gh = int(level.h)
	grid.resize(gw * gh)
	grid.fill(-1)
	arrows.clear()
	for i in level.arrows.size():
		var src: Dictionary = level.arrows[i]
		var cells: Array = src.cells
		var dir: Vector2i = src.dir
		var pts := PackedVector2Array()
		for c in cells:
			pts.append(Vector2(c.x + 0.5, c.y + 0.5))
		if cells.size() == 1:
			pts.insert(0, pts[0] - Vector2(dir) * 0.34)   # stub so 1-cell arrows have a tail
		var body_len := 0.0
		for j in range(1, pts.size()):
			body_len += pts[j].distance_to(pts[j - 1])
		var ext := pts.duplicate()
		ext.append(pts[pts.size() - 1] + Vector2(dir) * float(gw + gh + 8) + Vector2(dir) * body_len)
		var head: Vector2i = cells[cells.size() - 1]
		var ray_len := 0
		var rc := head + dir
		while rc.x >= 0 and rc.y >= 0 and rc.x < gw and rc.y < gh:
			ray_len += 1
			rc += dir
		arrows.append({
			"cells": cells, "dir": dir, "ext": ext, "pts": pts, "body_len": body_len,
			"ray_len": ray_len, "state": ST_IDLE, "s": 0.0, "limit": 0.0, "phase": 0,
			"flash": 0.0, "speed": 0.0, "ci": 0,
		})
		for c in cells:
			grid[c.y * gw + c.x] = i
		var nd := ArrowNode.new()
		nd.board = self
		nd.id = i
		world.add_child(nd)
		nodes.append(nd)
	_assign_colors()
	alive_count = arrows.size()
	hint_id = -1
	locked = false
	_clear_sent = false
	_fit_view()


## Gives every arrow a colour slot that differs from the (already coloured) arrows next to it.
func _assign_colors() -> void:
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for i in arrows.size():
		var used := {}
		for c in arrows[i].cells:
			for d in dirs:
				var n: Vector2i = c + d
				if n.x < 0 or n.y < 0 or n.x >= gw or n.y >= gh:
					continue
				var o := grid[n.y * gw + n.x]
				if o != -1 and o < i:
					used[arrows[o].ci] = true
		var start := (i * 7 + 3) % COLOR_SLOTS
		var pick := start
		for t in COLOR_SLOTS:
			var cand := (start + t) % COLOR_SLOTS
			if not used.has(cand):
				pick = cand
				break
		arrows[i].ci = pick


func _on_resized() -> void:
	_fit_view()


## Fit the whole board; huge boards then start zoomed in to a playable cell size.
func _fit_view() -> void:
	_fit()
	if gw > 0 and base_cs < COMFY_CELL * 0.6:
		_zoom_at(size * 0.5, minf(MAX_ZOOM, COMFY_CELL / base_cs))


func _fit() -> void:
	if gw == 0:
		return
	base_cs = minf(MAX_CELL, minf(size.x / (gw + 0.7), size.y / (gh + 0.7)))
	line_w = maxf(BASE_LINE_W, MIN_LINE_PX / base_cs)
	zoom = 1.0
	view_offset = (size - Vector2(gw, gh) * base_cs) * 0.5
	_apply_view()
	_redraw_all()


func _apply_view() -> void:
	world.position = view_offset
	world.scale = Vector2.ONE * base_cs * zoom


func _clamp_view() -> void:
	var gsz := Vector2(gw, gh) * base_cs * zoom
	var margin := minf(base_cs * zoom * 0.6, 120.0)
	for ax in 2:
		if gsz[ax] <= size[ax]:
			view_offset[ax] = (size[ax] - gsz[ax]) * 0.5
		else:
			view_offset[ax] = clampf(view_offset[ax], size[ax] - gsz[ax] - margin, margin)


func _zoom_at(pos: Vector2, factor: float) -> void:
	var z2 := clampf(zoom * factor, 1.0, MAX_ZOOM)
	var ratio := z2 / zoom
	view_offset = pos - (pos - view_offset) * ratio
	zoom = z2
	_clamp_view()
	_apply_view()


## Zoom button: fit -> comfortable -> close -> fit
func cycle_zoom() -> void:
	var comfy := clampf(COMFY_CELL / base_cs, 1.0, MAX_ZOOM)
	var steps: Array = [1.0, comfy, minf(MAX_ZOOM, maxf(comfy * 2.5, 2.5))]
	var target: float = steps[0]
	for s in steps:
		if s > zoom * 1.08:
			target = s
			break
	_zoom_at(size * 0.5, target / zoom)


func reset_view() -> void:
	_fit_view()


## Centres the view on an arrow (zooming in if the board is huge).
func focus_on(id: int) -> void:
	var head: Vector2i = arrows[id].cells[arrows[id].cells.size() - 1]
	var screen := view_offset + (Vector2(head) + Vector2(0.5, 0.5)) * base_cs * zoom
	var visible_ok := Rect2(Vector2.ZERO, size).grow(-60.0).has_point(screen)
	var comfy := clampf(COMFY_CELL / base_cs, 1.0, MAX_ZOOM)
	if visible_ok and zoom >= comfy * 0.9:
		return
	var z2 := maxf(zoom, comfy)
	zoom = z2
	view_offset = size * 0.5 - (Vector2(head) + Vector2(0.5, 0.5)) * base_cs * zoom
	_clamp_view()
	_apply_view()


# ------------------------------------------------------------------ logic

func _ray_info(id: int) -> Dictionary:
	var a: Dictionary = arrows[id]
	var head: Vector2i = a.cells[a.cells.size() - 1]
	var d: Vector2i = a.dir
	var c := head + d
	var free := 0
	while c.x >= 0 and c.y >= 0 and c.x < gw and c.y < gh:
		var o := grid[c.y * gw + c.x]
		if o != -1:
			return {"free": free, "blocker": o}
		free += 1
		c += d
	return {"free": free, "blocker": -1}


func _touch(id: int) -> void:
	_active[id] = true


## Returns 1 = escaped, 0 = blocked (mistake), -1 = ignored.
func tap_arrow(id: int) -> int:
	if locked or id < 0 or id >= arrows.size():
		return -1
	var a: Dictionary = arrows[id]
	if a.state != ST_IDLE:
		return -1
	var r := _ray_info(id)
	if r.blocker == -1:
		a.state = ST_OUT
		a.s = 0.0
		a.speed = 7.0
		for c in a.cells:
			grid[c.y * gw + c.x] = -1
		alive_count -= 1
		if hint_id == id:
			hint_id = -1
		_touch(id)
		arrow_escaped.emit()
		return 1
	a.state = ST_BUMP
	a.limit = float(r.free) + 0.3
	a.phase = 0
	a.flash = 0.75
	var b: Dictionary = arrows[r.blocker]
	b.flash = 0.75
	_touch(id)
	_touch(r.blocker)
	arrow_blocked.emit()
	return 0


## Highlights an arrow that can leave right now (prefers ones that unblock the most others).
func show_hint() -> bool:
	var weight := {}
	for i in arrows.size():
		if arrows[i].state == ST_IDLE:
			var r := _ray_info(i)
			if r.blocker != -1:
				weight[r.blocker] = int(weight.get(r.blocker, 0)) + 1
	var best := -1
	var best_w := -1
	for i in arrows.size():
		if arrows[i].state == ST_IDLE and _ray_info(i).blocker == -1:
			var wt: int = int(weight.get(i, 0))
			if wt > best_w:
				best_w = wt
				best = i
	if best < 0:
		return false
	var old := hint_id
	hint_id = best
	if old >= 0:
		nodes[old].queue_redraw()
	focus_on(best)
	_touch(best)
	return true


## Index of any arrow that can leave now (used by the self-test).
func any_free_arrow() -> int:
	for i in arrows.size():
		if arrows[i].state == ST_IDLE and _ray_info(i).blocker == -1:
			return i
	return -1


func _process(delta: float) -> void:
	_time += delta
	if _active.is_empty() and hint_id < 0:
		_check_cleared()
		return
	var done: Array = []
	for id in _active:
		var a: Dictionary = arrows[id]
		match a.state:
			ST_OUT:
				a.speed += 75.0 * delta
				a.s += a.speed * delta
				if a.s > a.body_len + a.ray_len + 1.3:
					a.state = ST_GONE
					nodes[id].visible = false
			ST_BUMP:
				if a.phase == 0:
					a.s += maxf(16.0, a.limit / 0.22) * delta
					if a.s >= a.limit:
						a.s = a.limit
						a.phase = 1
				else:
					a.s -= maxf(11.0, a.limit / 0.3) * delta
					if a.s <= 0.0:
						a.s = 0.0
						a.state = ST_IDLE
		if a.flash > 0.0:
			a.flash -= delta
		nodes[id].queue_redraw()
		if (a.state == ST_IDLE or a.state == ST_GONE) and a.flash <= 0.0 and id != hint_id:
			done.append(id)
	for id in done:
		_active.erase(id)
	if hint_id >= 0:
		nodes[hint_id].queue_redraw()
	_check_cleared()


func _check_cleared() -> void:
	if alive_count == 0 and not _clear_sent and _active.is_empty() and gw > 0:
		_clear_sent = true
		cleared.emit()


# ------------------------------------------------------------------ drawing

func _slice(ext: PackedVector2Array, from_d: float, to_d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var acc := 0.0
	for i in range(ext.size() - 1):
		var p0 := ext[i]
		var p1 := ext[i + 1]
		var l := p0.distance_to(p1)
		var s0 := acc
		var s1 := acc + l
		if s1 > from_d and s0 < to_d and l > 0.0:
			var u0 := maxf(from_d, s0)
			var u1 := minf(to_d, s1)
			var q0 := p0.lerp(p1, (u0 - s0) / l)
			var q1 := p0.lerp(p1, (u1 - s0) / l)
			if out.is_empty() or out[out.size() - 1].distance_to(q0) > 0.0001:
				out.append(q0)
			out.append(q1)
		acc = s1
		if acc >= to_d:
			break
	return out


## Called from ArrowNode._draw() - draws arrow `id` into `node` in cell units.
func draw_arrow(node: Node2D, id: int) -> void:
	var a: Dictionary = arrows[id]
	if a.state == ST_GONE:
		return
	var col: Dictionary = Save.colors()
	var pal: Array = col.arrows
	var c: Color = pal[a.ci % pal.size()]
	var width := line_w
	if a.flash > 0.0:
		c = col.danger
	elif id == hint_id:
		var pulse := 0.5 + 0.5 * sin(_time * 7.0)
		var halo: Color = col.hint
		halo.a = 0.35 + 0.3 * pulse
		node.draw_polyline(a.pts, halo, line_w * (4.5 + 2.0 * pulse), true)
		width = line_w * 1.3
	var pts: PackedVector2Array = a.pts
	if a.s != 0.0:
		pts = _slice(a.ext, a.s, a.s + a.body_len)
	if pts.size() < 1:
		return
	if pts.size() >= 2:
		node.draw_polyline(pts, c, width, true)
		# round tail cap + round joins at real corners only
		node.draw_circle(pts[0], width * 0.5, c)
		for j in range(1, pts.size() - 1):
			if (pts[j] - pts[j - 1]).normalized().distance_to((pts[j + 1] - pts[j]).normalized()) > 0.01:
				node.draw_circle(pts[j], width * 0.5, c)
	var front := pts[pts.size() - 1]
	var d := Vector2(a.dir)
	var perp := Vector2(-d.y, d.x)
	var hs := minf(1.6, width / BASE_LINE_W)
	var tip := minf(0.5, HEAD_TIP * hs)
	var half := minf(0.42, HEAD_HALF * hs)
	var base := front - d * 0.04
	node.draw_colored_polygon(PackedVector2Array([front + d * tip, base + perp * half, base - perp * half]), c)


# -------------------------------------------------------------------- input

func _to_cell(pos: Vector2) -> Vector2:
	return (pos - view_offset) / (base_cs * zoom)


func _hit(pos: Vector2) -> int:
	var q := _to_cell(pos)
	var tol := clampf(34.0 / (base_cs * zoom), 0.5, 0.85)
	var cx := int(floor(q.x))
	var cy := int(floor(q.y))
	var best := -1
	var best_d := tol
	var seen := {}
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := cx + dx
			var y := cy + dy
			if x < 0 or y < 0 or x >= gw or y >= gh:
				continue
			var i := grid[y * gw + x]
			if i == -1 or seen.has(i):
				continue
			seen[i] = true
			var a: Dictionary = arrows[i]
			if a.state != ST_IDLE:
				continue
			var pts: PackedVector2Array = a.pts
			var dmin := 1e9
			if pts.size() == 1:
				dmin = q.distance_to(pts[0])
			for j in range(pts.size() - 1):
				var cp := Geometry2D.get_closest_point_to_segment(q, pts[j], pts[j + 1])
				dmin = minf(dmin, q.distance_to(cp))
			# the arrow head sticks out ahead of the last point
			dmin = minf(dmin, q.distance_to(pts[pts.size() - 1] + Vector2(a.dir) * 0.3))
			if dmin < best_d:
				best_d = dmin
				best = i
	return best


func _input(ev: InputEvent) -> void:
	# Manual two-finger pinch/pan (works on any touch device).
	if ev is InputEventScreenTouch:
		var e := make_input_local(ev) as InputEventScreenTouch
		if ev.pressed:
			if not Rect2(Vector2.ZERO, size).has_point(e.position):
				return        # finger went down outside the board (buttons etc.)
			_touches[ev.index] = e.position
			if _touches.size() >= 2:
				_gesture = true
				_pinch_prev = 0.0
		else:
			_touches.erase(ev.index)
			_pinch_prev = 0.0
	elif ev is InputEventScreenDrag and _touches.has(ev.index):
		var e := make_input_local(ev) as InputEventScreenDrag
		_touches[ev.index] = e.position
		if _touches.size() == 2 and gw > 0:
			var ps: Array = _touches.values()
			var dist: float = ps[0].distance_to(ps[1])
			var center: Vector2 = (ps[0] + ps[1]) * 0.5
			if _pinch_prev > 0.0 and dist > 1.0:
				_zoom_at(center, dist / _pinch_prev)
				view_offset += center - _pinch_center        # two-finger drag pans too
				_clamp_view()
				_apply_view()
			_pinch_prev = dist
			_pinch_center = center


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			_zoom_at(ev.position, 1.18)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			_zoom_at(ev.position, 1.0 / 1.18)
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_pressing = true
				_press_pos = ev.position
				_dragged = false
				if _touches.size() < 2:
					_gesture = false
			else:
				if _pressing and not _dragged and not _gesture:
					_on_tap(ev.position)
				_pressing = false
	elif ev is InputEventMouseMotion and _pressing:
		if not _dragged and ev.position.distance_to(_press_pos) > 16.0:
			_dragged = true
		if _dragged and zoom > 1.001 and not _gesture:
			view_offset += ev.relative
			_clamp_view()
			_apply_view()
	elif ev is InputEventMagnifyGesture:
		_gesture = true
		_zoom_at(ev.position, ev.factor)


func _on_tap(pos: Vector2) -> void:
	var id := _hit(pos)
	if id >= 0:
		tap_arrow(id)
