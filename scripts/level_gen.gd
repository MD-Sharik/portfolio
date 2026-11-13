extends RefCounted
## Procedural level generator for Arrow Escape.
##
## Rules of the game
##   * Every arrow is a path of grid cells (tail -> head). The head points in the
##     direction of the last segment (single-cell arrows have a free direction).
##   * Tapping an arrow slides it forward out of the board. It can only leave if
##     every cell in a straight line from its head to the board edge is empty.
##
## Guaranteed solvable: every arrow gets a "removal label". A new arrow may be inserted at
## any point of the removal order as long as
##   * every arrow sitting on its exit ray has a smaller label (it leaves first), and
##   * every arrow whose exit ray crosses its cells has a larger label (it leaves later).
## Both bounds always leave a consistent order, so the level can never contain a cycle.
## This packs boards far more densely than "reverse placement" and scales to 128x128.
##
## generate(params, seed) is fully deterministic (see seed_rng.gd).

const SeedRng := preload("res://scripts/seed_rng.gd")

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const INF_LABEL := 1 << 60

var w: int = 0
var h: int = 0
var rng
var allowed := PackedByteArray()
var owner := PackedInt32Array()
var arrows: Array = []             # [{cells: Array[Vector2i], dir: Vector2i}]
var cover: Array = []              # cover[cell] = Array[int] of arrow ids whose exit ray crosses it
var labels := PackedInt64Array()   # removal order key per arrow (smaller = leaves earlier)
var cell_list: Array[Vector2i] = []
var free_list: Array[Vector2i] = []
var free_pos := PackedInt32Array()
var _stamp := PackedInt32Array()
var _stamp_id := 0

var p_straight := 0.7
var p_max_len := 6
var p_min_len := 1


# ---------------------------------------------------------------- public API

static func generate(params: Dictionary, seed_text: String) -> Dictionary:
	var g = new()
	return g._build(params, seed_text)


## Plays the level out with the real game rule (an arrow leaves when its ray is
## clear). Returns {solvable, depth, free0, arrows, cells, fill}.
static func analyze(level: Dictionary) -> Dictionary:
	var lw: int = int(level.w)
	var lh: int = int(level.h)
	var lar: Array = level.arrows
	var grid := PackedInt32Array()
	grid.resize(lw * lh)
	grid.fill(-1)
	var occupied := 0
	for i in lar.size():
		for c in lar[i].cells:
			grid[c.y * lw + c.x] = i
			occupied += 1
	var alive: Array = []
	alive.resize(lar.size())
	alive.fill(true)
	var remaining := lar.size()
	var depth := 0
	var free0 := 0
	while remaining > 0:
		var removable: Array = []
		for i in lar.size():
			if alive[i] and ray_clear(grid, lw, lh, lar[i]):
				removable.append(i)
		if removable.is_empty():
			return {"solvable": false, "depth": depth, "free0": free0, "arrows": lar.size(), "cells": occupied, "fill": 0.0}
		if depth == 0:
			free0 = removable.size()
		for i in removable:
			alive[i] = false
			for c in lar[i].cells:
				grid[c.y * lw + c.x] = -1
		remaining -= removable.size()
		depth += 1
	var allowed_count: int = int(level.get("allowed", lw * lh))
	return {
		"solvable": true, "depth": depth, "free0": free0, "arrows": lar.size(),
		"cells": occupied, "fill": float(occupied) / float(maxi(1, allowed_count)),
	}


static func ray_clear(grid: PackedInt32Array, lw: int, lh: int, arrow: Dictionary) -> bool:
	var head: Vector2i = arrow.cells[arrow.cells.size() - 1]
	var d: Vector2i = arrow.dir
	var c := head + d
	while c.x >= 0 and c.y >= 0 and c.x < lw and c.y < lh:
		if grid[c.y * lw + c.x] != -1:
			return false
		c += d
	return true


## Short fingerprint of the layout. Stored in levels.json to detect drift.
static func checksum(level: Dictionary) -> String:
	var s := "%dx%d" % [level.w, level.h]
	for a in level.arrows:
		s += "|"
		for c in a.cells:
			s += "%d,%d;" % [c.x, c.y]
	return "%08x" % SeedRng.fnv1a(s)


## Compact string form used for baked levels:  "tailIndex:moves:headDir"  (moves/dir are R D L U)
const LETTERS := {Vector2i(1, 0): "R", Vector2i(0, 1): "D", Vector2i(-1, 0): "L", Vector2i(0, -1): "U"}


static func encode(level: Dictionary) -> Array:
	var out: Array = []
	for a in level.arrows:
		var cells: Array = a.cells
		var moves := ""
		for i in range(1, cells.size()):
			moves += LETTERS[cells[i] - cells[i - 1]]
		out.append("%d:%s:%s" % [cells[0].y * int(level.w) + cells[0].x, moves, LETTERS[a.dir]])
	return out


static func decode(lw: int, lh: int, encoded: Array) -> Dictionary:
	var by_letter := {}
	for k in LETTERS:
		by_letter[LETTERS[k]] = k
	var arrows: Array = []
	for s in encoded:
		var parts: PackedStringArray = String(s).split(":")
		var idx := int(parts[0])
		var cur := Vector2i(idx % lw, idx / lw)
		var cells: Array[Vector2i] = [cur]
		for ch in parts[1]:
			cur += by_letter[ch]
			cells.append(cur)
		arrows.append({"cells": cells, "dir": by_letter[parts[2]]})
	return {"w": lw, "h": lh, "arrows": arrows}


# ------------------------------------------------------------------ masks

static func make_mask(shape: String, mw: int, mh: int) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(mw * mh)
	for y in mh:
		for x in mw:
			var u: float = ((x + 0.5) / mw) * 2.0 - 1.0     # -1..1 left->right
			var v: float = (y + 0.5) / mh                    # 0..1 top->bottom
			var s: float = v * 2.0 - 1.0                     # -1..1 top->bottom
			var inside := true
			match shape:
				"ellipse":
					inside = u * u + s * s <= 1.0
				"diamond":
					inside = absf(u) + absf(s) <= 1.0
				"ring":
					var r2 := u * u + s * s
					inside = r2 <= 1.0 and r2 >= 0.22
				"cross":
					inside = absf(u) < 0.4 or absf(s) < 0.4
				"triangle":
					inside = absf(u) <= v * 1.0
				"hourglass":
					inside = absf(u) <= absf(s) * 0.92 + 0.12
				"heart":
					var hx: float = u * 1.25
					var hy: float = -s * 1.25 + 0.15
					var a: float = hx * hx + hy * hy - 1.0
					inside = a * a * a - hx * hx * hy * hy * hy <= 0.0
				"trophy":
					inside = _trophy(u, v)
				_:
					inside = true
			m[y * mw + x] = 1 if inside else 0
	return m


static func _trophy(u: float, v: float) -> bool:
	var au := absf(u)
	if v < 0.56:
		var t := v / 0.56
		var half := 0.62 - 0.32 * t * t
		if au <= half:
			return true
		# handles
		return v > 0.06 and v < 0.42 and au >= 0.7 and au <= 0.97 and not (au > 0.79 and au < 0.88 and v > 0.14 and v < 0.34)
	if v < 0.8:
		return au <= 0.11
	return au <= 0.42


# ------------------------------------------------------------- generation

func _idx(c: Vector2i) -> int:
	return c.y * w + c.x


func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func _build(params: Dictionary, seed_text: String) -> Dictionary:
	rng = SeedRng.new(seed_text)
	w = int(params.w)
	h = int(params.h)
	p_straight = float(params.get("straight", 0.7))
	p_max_len = maxi(1, int(params.get("max_len", 6)))
	p_min_len = clampi(int(params.get("min_len", 1)), 1, p_max_len)
	var bias: float = float(params.get("bias", 0.0))
	var k: int = maxi(1, int(params.get("k", 1)))
	var fill: float = float(params.get("fill", 0.9))
	var shape: String = String(params.get("shape", "rect"))

	allowed = make_mask(shape, w, h)
	owner.resize(w * h)
	owner.fill(-1)
	cover.resize(w * h)
	for i in w * h:
		cover[i] = []
	_stamp.resize(w * h)
	_stamp.fill(0)
	free_pos.resize(w * h)
	free_pos.fill(-1)
	cell_list.clear()
	for y in h:
		for x in w:
			if allowed[y * w + x] == 1:
				cell_list.append(Vector2i(x, y))
	free_list = cell_list.duplicate()
	for i in free_list.size():
		free_pos[_idx(free_list[i])] = i
	var allowed_count := cell_list.size()
	var target := int(round(fill * allowed_count))
	var occupied := 0

	# Phase 1: random placement. With 'bias' the best of k candidates is kept, where "best" =
	# most entangled with existing arrows (many blockers / blocked arrows -> deeper puzzles).
	var fails := 0
	var fail_limit := 30 + allowed_count / 6
	while occupied < target and fails < fail_limit and not free_list.is_empty():
		var steered: bool = rng.chance(bias)
		var tries: int = k if steered else 1
		var best := {}
		var best_score := -1
		for _i in tries:
			var head: Vector2i = free_list[rng.int_range(0, free_list.size() - 1)]
			var d: Vector2i = DIRS[rng.int_range(0, 3)]
			var a := _try_build(head, d, rng.int_range(p_min_len, p_max_len), p_min_len)
			if a.is_empty():
				continue
			var sc: int = a.entangle if steered else 0
			if sc > best_score:
				best = a
				best_score = sc
		if best.is_empty():
			fails += 1
			continue
		_place(best)
		occupied += best.cells.size()

	# Phase 2: sweep the leftovers with short arrows until the fill target is reached.
	if occupied < target:
		var left := free_list.duplicate()
		rng.shuffle(left)
		for c in left:
			if occupied >= target:
				break
			if owner[_idx(c)] != -1:
				continue
			var dirs := DIRS.duplicate()
			rng.shuffle(dirs)
			for d in dirs:
				var a := _try_build(c, d, rng.int_range(1, maxi(1, p_max_len / 2)), 1)
				if not a.is_empty():
					_place(a)
					occupied += a.cells.size()
					break

	var out_arrows: Array = []
	for a in arrows:
		out_arrows.append({"cells": a.cells, "dir": a.dir})
	return {"w": w, "h": h, "arrows": out_arrows, "seed": seed_text, "allowed": allowed_count}


func _free_remove(c: Vector2i) -> void:
	var ci := _idx(c)
	var pos := free_pos[ci]
	if pos < 0:
		return
	var last: Vector2i = free_list[free_list.size() - 1]
	free_list[pos] = last
	free_pos[_idx(last)] = pos
	free_list.pop_back()
	free_pos[ci] = -1


## Builds a candidate arrow with its head on `head` pointing along `d`. Returns {} when the
## cells are not free or no consistent removal label exists.
func _try_build(head: Vector2i, d: Vector2i, target_len: int, min_len: int) -> Dictionary:
	var head_idx := _idx(head)
	if allowed[head_idx] == 0 or owner[head_idx] != -1:
		return {}
	# Exit ray: reserve its cells (the body may not cross them) and collect the blockers.
	var ray: Array[Vector2i] = []
	_stamp_id += 1
	var lo := -INF_LABEL
	var blockers := {}
	var c := head + d
	while _in_bounds(c):
		var ci := _idx(c)
		ray.append(c)
		_stamp[ci] = _stamp_id
		var o := owner[ci]
		if o != -1 and not blockers.has(o):
			blockers[o] = true
			if labels[o] > lo:
				lo = labels[o]
		c += d
	# Grow the body backwards from the head.
	var cells: Array[Vector2i] = [head]
	_stamp[head_idx] = _stamp_id
	var cur := head
	var move := -d
	while cells.size() < target_len:
		var opts: Array[Vector2i] = []
		for dd in DIRS:
			if cells.size() == 1 and dd != -d:
				continue  # the segment before the head must run straight into it
			var n := cur + dd
			if not _in_bounds(n):
				continue
			var ni := _idx(n)
			if allowed[ni] == 0 or owner[ni] != -1 or _stamp[ni] == _stamp_id:
				continue
			opts.append(dd)
		if opts.is_empty():
			break
		var step: Vector2i
		if opts.has(move) and rng.chance(p_straight):
			step = move
		else:
			step = opts[rng.int_range(0, opts.size() - 1)]
		cur += step
		cells.append(cur)
		_stamp[_idx(cur)] = _stamp_id
		move = step
	if cells.size() < min_len:
		return {}
	cells.reverse()  # tail -> head
	# Arrows whose rays cross our cells must leave after us.
	var hi := INF_LABEL
	var victims := {}
	for cc in cells:
		for aid in cover[_idx(cc)]:
			if not victims.has(aid):
				victims[aid] = true
				if labels[aid] < hi:
					hi = labels[aid]
	if hi - lo < 2:
		return {}
	var label: int
	if lo == -INF_LABEL and hi == INF_LABEL:
		label = 0
	elif hi == INF_LABEL:
		label = lo + 1 + rng.int_range(0, 1 << 30)
	elif lo == -INF_LABEL:
		label = hi - 1 - rng.int_range(0, 1 << 30)
	else:
		var gap := hi - lo
		var span := mini(gap - 2, 1 << 30)
		label = lo + gap / 2 + rng.int_range(-span / 2, span / 2)
		label = clampi(label, lo + 1, hi - 1)
	return {"cells": cells, "dir": d, "ray": ray, "label": label, "entangle": blockers.size() + victims.size()}


func _place(a: Dictionary) -> void:
	var id := arrows.size()
	for c in a.cells:
		owner[_idx(c)] = id
		_free_remove(c)
	for r in a.ray:
		cover[_idx(r)].append(id)
	arrows.append({"cells": a.cells, "dir": a.dir})
	labels.append(a.label)
