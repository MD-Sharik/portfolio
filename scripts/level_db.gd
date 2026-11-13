extends RefCounted
## Loads data/levels.json (metadata) + data/layouts.bin (zstd-compressed baked layouts), both
## written by tools/level_maker.gd. Past the last baked level the game keeps going with endless
## procedural levels.

const LevelGen := preload("res://scripts/level_gen.gd")
const Difficulty := preload("res://scripts/difficulty.gd")

const PATH := "res://data/levels.json"
const BIN_PATH := "res://data/layouts.bin"
const ENDLESS_MAX_SIZE := 80   # keep runtime generation on phones quick

static var _levels: Array = []
static var _loaded := false
static var _cache := {}


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	_levels = []
	if not FileAccess.file_exists(PATH):
		push_warning("levels.json missing - using on-the-fly levels. Run tools/level_maker.gd")
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) == TYPE_DICTIONARY and data.has("levels"):
		_levels = data.levels


static func count() -> int:
	load_all()
	return maxi(_levels.size(), 1000)


static func baked_count() -> int:
	load_all()
	return _levels.size()


## Frozen params + seed for level n (1-based).
static func meta(n: int) -> Dictionary:
	load_all()
	if n >= 1 and n <= _levels.size():
		return _levels[n - 1]
	# Fallback / endless mode: hardest curve (size capped), deterministic seed.
	var params := Difficulty.params_for(mini(n, 1000))
	params["w"] = mini(int(params.w), ENDLESS_MAX_SIZE)
	params["h"] = mini(int(params.h), ENDLESS_MAX_SIZE)
	params["n"] = n
	params["seed"] = "endless-%d" % n
	return params


## Reads the baked arrows of a level entry (strings "tail:moves:dir") from layouts.bin.
static func read_layout(m: Dictionary, bin_path: String = BIN_PATH) -> Array:
	var f := FileAccess.open(bin_path, FileAccess.READ)
	if f == null:
		return []
	f.seek(int(m.o))
	var comp := f.get_buffer(int(m.c))
	f.close()
	var raw := comp.decompress(int(m.r), FileAccess.COMPRESSION_ZSTD)
	return raw.get_string_from_utf8().split(";", false)


static func build(n: int) -> Dictionary:
	if _cache.has(n):
		return _cache[n]
	var m := meta(n)
	var level: Dictionary
	if m.has("o"):
		level = LevelGen.decode(int(m.w), int(m.h), Array(read_layout(m)))   # baked layout (fast)
	else:
		level = LevelGen.generate(m, String(m.seed))                          # endless / dev fallback
	level["n"] = n
	if _cache.size() > 4:
		_cache.clear()
	_cache[n] = level
	return level
