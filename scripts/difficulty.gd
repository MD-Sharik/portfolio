extends RefCounted
## Difficulty curve: level number (1..1000) -> generator parameters.
## The level maker freezes the result into data/levels.json, so tweaking this file
## only affects levels you (re)generate afterwards.
##
## ALL_LEVELS_MAX = true  -> every level uses the level-1000 settings (128x128 boards, ~1500+
##                           arrows, long chains). Set it to false to get the gentle ramp
##                           3x3 (level 1) -> 128x128 (level ~875) back, then rebuild the levels.

const ALL_LEVELS_MAX := true
const MAX_SIZE := 128
const EARLY_LEVELS := 100      # levels 1..100 use a smaller board ...
const EARLY_SIZE := 96         # ... 96x96 instead of 128x128
const SHAPES := ["ellipse", "diamond", "heart", "hourglass", "cross", "triangle", "ring", "trophy"]


static func params_for(n: int) -> Dictionary:
	var t: float = 1.0 if ALL_LEVELS_MAX else clampf((float(n) - 1.0) / 999.0, 0.0, 1.0)
	var e: float = pow(t, 0.95)
	var size_e: float = minf(1.0, e * 1.12)       # reaches full size around level 875

	var w: float = lerpf(3.0, float(MAX_SIZE), size_e)
	var aspect: float = lerpf(1.0, 1.3, clampf(t * 3.0, 0.0, 1.0))

	var shape := "rect"
	# Shaped boards (heart, hourglass...) appear from level 20; every 50th level is a trophy.
	if ALL_LEVELS_MAX:
		# every 5th level is a shaped board for variety, every 50th is the trophy
		if n % 50 == 0:
			shape = "trophy"
		elif n % 5 == 3:
			shape = SHAPES[(n * 31) % (SHAPES.size() - 1)]
	elif n >= 20:
		var roll: int = (n * 7919) % 100
		var chance: int = int(lerpf(14.0, 40.0, e))
		if n % 50 == 0:
			shape = "trophy"
		elif roll < chance:
			shape = SHAPES[(n * 31) % (SHAPES.size() - 1)]  # not trophy (boss only)
	var scale := 1.0
	if shape != "rect":
		scale = 1.25
	# Breather: every 10th level is a little smaller.
	if n % 10 == 0 and n > 10 and shape == "rect" and not ALL_LEVELS_MAX:
		scale = 0.8

	var wi: int = maxi(3, int(round(w * scale)))
	var hi: int = maxi(3, int(round(w * scale * aspect)))
	if shape != "rect":
		wi = maxi(wi, 9)
		hi = maxi(hi, 9)
	var cap := EARLY_SIZE if (ALL_LEVELS_MAX and n <= EARLY_LEVELS) else MAX_SIZE
	wi = mini(wi, cap)
	hi = mini(hi, cap)

	var max_len: int = clampi(int(round(lerpf(3.0, 40.0, e))), 2, 40)
	var min_len: int = 1 if t < 0.03 else (2 if t < 0.3 else 3)
	var straight: float = lerpf(0.85, 0.45, e)
	var bias: float = 0.0 if (n <= 3 and not ALL_LEVELS_MAX) else clampf(lerpf(0.1, 0.85, minf(1.0, e * 1.5)), 0.0, 1.0)
	var k: int = 1 + int(e * 5.0)
	var fill: float = lerpf(0.55, 0.93, minf(1.0, e * 2.0))

	return {
		"w": wi, "h": hi, "shape": shape,
		"min_len": min_len, "max_len": max_len,
		"straight": roundf(straight * 100.0) / 100.0, "bias": roundf(bias * 100.0) / 100.0,
		"k": k, "fill": roundf(fill * 100.0) / 100.0,
	}


## How many candidate seeds the level maker tries for level n (big boards are slow to build).
static func tries_for(n: int) -> int:
	if ALL_LEVELS_MAX:
		return 3
	if n < 100:
		return 8
	if n < 400:
		return 5
	return 3


## Hard requirements a candidate must meet before it is even considered.
static func accepts(n: int, stats: Dictionary, params: Dictionary) -> bool:
	if not bool(stats.get("solvable", false)):
		return false
	if int(stats.arrows) < 3:
		return false
	if float(stats.fill) < float(params.fill) - 0.18:
		return false
	if n > 1 and int(stats.depth) < 2:
		return false  # must contain at least one blocked arrow
	return true


## Rating (0-100) the level maker aims for at level n; it picks the candidate closest to it.
static func target_rating(n: int) -> float:
	var t: float = 1.0 if ALL_LEVELS_MAX else clampf((float(n) - 1.0) / 999.0, 0.0, 1.0)
	return lerpf(4.0, 100.0 if ALL_LEVELS_MAX else 88.0, pow(t, 0.95))


## 0-100 rough difficulty rating: size, dependency depth and how few arrows start free.
static func rating(stats: Dictionary) -> int:
	var arrows: float = float(stats.arrows)
	var free_ratio: float = float(stats.free0) / maxf(1.0, arrows)
	var raw: float = 8.0 * log(arrows + 1.0) + 0.3 * float(stats.depth) + 20.0 * (1.0 - free_ratio)
	return clampi(int(round((raw - 15.0) * 0.75)), 1, 100)
