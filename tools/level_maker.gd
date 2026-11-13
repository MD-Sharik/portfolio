extends SceneTree
## LEVEL MAKER
## Generates / finalizes levels and writes res://data/levels.json (+ layouts.bin).
##
## Each level is described by a random unique base64 seed + frozen generator params.
## The generator is deterministic, so the seed always rebuilds the exact layout; the layout is
## also baked (zstd-compressed) into layouts.bin so phones never have to generate big boards.
##
## Run from the project folder:
##   godot --headless --path . --script res://tools/level_maker.gd -- [options]
##
## Options
##   --count N          number of levels to have in the file (default 1000)
##   --force            regenerate everything, ignoring existing seeds
##   --reroll 5,17,42   draw fresh seeds for just these levels
##   --master TEXT      derive seeds from TEXT instead of true randomness (reproducible)
##   --tries N          candidate seeds per level; the closest-to-target one wins
##   --preview N        print level N (ascii) and exit; use with --seed to try a seed
##   --verify           regenerate every level and check solvable + checksum (--from/--to limit it)
##   --bench            time the generator along the difficulty curve
##
## Parallel build (8 cores = ~8x faster; see tools/build_levels.ps1):
##   --from A --to B --part FILE     generate only levels A..B into a part file
##   --merge a.json,b.json,...       combine part files into levels.json + layouts.bin
##
##   --out PATH         final json (default res://data/levels.json)
##   --bin PATH         final layouts file (default res://data/layouts.bin)

const LevelGen := preload("res://scripts/level_gen.gd")
const Difficulty := preload("res://scripts/difficulty.gd")
const SeedRng := preload("res://scripts/seed_rng.gd")
const LevelDB := preload("res://scripts/level_db.gd")

const B64 := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

var opts := {}
var out_path := "res://data/levels.json"
var bin_path := "res://data/layouts.bin"


func _init() -> void:
	opts = _parse(OS.get_cmdline_user_args())
	out_path = String(opts.get("out", out_path))
	bin_path = String(opts.get("bin", bin_path))
	var ok := true
	if opts.has("bench"):
		_bench()
	elif opts.has("preview"):
		_preview(int(opts.preview), String(opts.get("seed", "preview")))
	elif opts.has("verify"):
		ok = _verify()
	elif opts.has("merge"):
		ok = _merge(String(opts.merge).split(",", false))
	elif opts.has("part"):
		ok = _make_part()
	else:
		ok = _make_all()
	quit(0 if ok else 1)


func _parse(args: PackedStringArray) -> Dictionary:
	var o := {}
	var i := 0
	while i < args.size():
		var a := args[i]
		if a.begins_with("--"):
			var key := a.substr(2)
			if i + 1 < args.size() and not args[i + 1].begins_with("--"):
				o[key] = args[i + 1]
				i += 1
			else:
				o[key] = true
		i += 1
	return o


# ------------------------------------------------------------------ seeds

func _seed_for(n: int, attempt: int) -> String:
	var bytes := PackedByteArray()
	if opts.has("master"):
		var r := SeedRng.new("%s:%d:%d" % [opts.master, n, attempt])
		for _i in 8:
			bytes.append(r.next_u32() & 0xFF)
	else:
		bytes = Crypto.new().generate_random_bytes(8)
	return _b64(bytes)


func _b64(bytes: PackedByteArray) -> String:
	# URL-safe base64, no padding.
	var s := ""
	var i := 0
	while i < bytes.size():
		var b0: int = bytes[i]
		var b1: int = bytes[i + 1] if i + 1 < bytes.size() else 0
		var b2: int = bytes[i + 2] if i + 2 < bytes.size() else 0
		var n := (b0 << 16) | (b1 << 8) | b2
		s += B64[(n >> 18) & 63] + B64[(n >> 12) & 63]
		if i + 1 < bytes.size():
			s += B64[(n >> 6) & 63]
		if i + 2 < bytes.size():
			s += B64[n & 63]
		i += 3
	return s


# ------------------------------------------------------------- generation

func _make_all() -> bool:
	var count: int = int(opts.get("count", 1000))
	var existing: Array = []
	if not opts.has("force") and FileAccess.file_exists(out_path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(out_path))
		if typeof(d) == TYPE_DICTIONARY and d.has("levels"):
			existing = d.levels
	var reroll := {}
	if opts.has("reroll"):
		for part in String(opts.reroll).split(","):
			reroll[int(part)] = true

	var used_seeds := {}
	var used_chk := {}
	var levels: Array = []
	var t0 := Time.get_ticks_msec()
	for n in range(1, count + 1):
		var entry: Dictionary
		if n <= existing.size() and not reroll.has(n):
			entry = existing[n - 1].duplicate()
			entry["a"] = Array(LevelDB.read_layout(entry, bin_path))   # keep the finalized level
		else:
			entry = _find_level(n, used_seeds, used_chk)
			if entry.is_empty():
				push_error("Could not generate level %d" % n)
				return false
			_log_level(entry)
		used_seeds[entry.seed] = true
		used_chk[entry.chk] = true
		levels.append(entry)
	var ok := _write_final(levels)
	print("done in %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return ok


func _log_level(e: Dictionary) -> void:
	print("level %4d  %3dx%-3d %-9s arrows=%4d free=%3d depth=%3d fill=%.2f rating=%2d seed=%s" % [
		e.n, e.w, e.h, e.shape, e.arrows, e.free, e.depth, e.fillr, e.rating, e.seed])


func _make_part() -> bool:
	var a: int = int(opts.get("from", 1))
	var b: int = int(opts.get("to", a))
	var used_seeds := {}
	var used_chk := {}
	var levels: Array = []
	for n in range(a, b + 1):
		var entry := _find_level(n, used_seeds, used_chk)
		if entry.is_empty():
			push_error("Could not generate level %d" % n)
			return false
		used_seeds[entry.seed] = true
		used_chk[entry.chk] = true
		levels.append(entry)
		_log_level(entry)
	var f := FileAccess.open(String(opts.part), FileAccess.WRITE)
	if f == null:
		push_error("cannot write part file %s" % opts.part)
		return false
	f.store_string(JSON.stringify({"levels": levels}))
	f.close()
	print("part %d-%d written (%d levels)" % [a, b, levels.size()])
	return true


func _merge(files: PackedStringArray) -> bool:
	var by_n := {}
	for fp in files:
		var d = JSON.parse_string(FileAccess.get_file_as_string(fp))
		if typeof(d) != TYPE_DICTIONARY:
			push_error("bad part file %s" % fp)
			return false
		for e in d.levels:
			by_n[int(e.n)] = e
	var levels: Array = []
	var seeds := {}
	var chks := {}
	for n in range(1, by_n.size() + 1):
		if not by_n.has(n):
			push_error("merge: level %d missing" % n)
			return false
		var e: Dictionary = by_n[n]
		if seeds.has(e.seed) or chks.has(e.chk):
			push_error("merge: level %d duplicates another level" % n)
			return false
		seeds[e.seed] = true
		chks[e.chk] = true
		levels.append(e)
	return _write_final(levels)


## Writes levels.json (metadata) + layouts.bin (zstd blobs of the baked arrows).
func _write_final(levels: Array) -> bool:
	var bin := PackedByteArray()
	var lines := PackedStringArray()
	for e in levels:
		var raw := ";".join(PackedStringArray(e.a)).to_utf8_buffer()
		var comp := raw.compress(FileAccess.COMPRESSION_ZSTD)
		var meta: Dictionary = e.duplicate()
		meta.erase("a")
		meta["o"] = bin.size()
		meta["c"] = comp.size()
		meta["r"] = raw.size()
		bin.append_array(comp)
		lines.append("  " + JSON.stringify(meta))
	var fb := FileAccess.open(bin_path, FileAccess.WRITE)
	var fj := FileAccess.open(out_path, FileAccess.WRITE)
	if fb == null or fj == null:
		push_error("Cannot write %s / %s" % [out_path, bin_path])
		return false
	fb.store_buffer(bin)
	fb.close()
	fj.store_string("{\n \"version\": 2,\n \"levels\": [\n" + ",\n".join(lines) + "\n ]\n}\n")
	var json_kb := fj.get_length() / 1024.0
	fj.close()
	print("Wrote %d levels: %s (%.0f KB) + %s (%.1f MB)" % [levels.size(), out_path, json_kb, bin_path, bin.size() / 1048576.0])
	return true


## Generates `tries` candidate seeds and keeps the valid one whose difficulty rating is
## closest to the target curve for this level number.
func _find_level(n: int, used_seeds: Dictionary, used_chk: Dictionary) -> Dictionary:
	var tries: int = int(opts.get("tries", Difficulty.tries_for(n)))
	var params := Difficulty.params_for(n)
	var target := Difficulty.target_rating(n)
	var best := {}
	var best_dist := 1e9
	var fallback := {}
	var fallback_fill := -1.0
	for attempt in tries:
		var s := _seed_for(n, attempt)
		if used_seeds.has(s):
			continue
		var level := LevelGen.generate(params, s)
		var stats := LevelGen.analyze(level)
		if not bool(stats.solvable):
			continue
		var chk := LevelGen.checksum(level)
		if used_chk.has(chk):
			continue
		var entry := params.duplicate()
		entry["n"] = n
		entry["seed"] = s
		entry["chk"] = chk
		entry["arrows"] = stats.arrows
		entry["free"] = stats.free0
		entry["depth"] = stats.depth
		entry["fillr"] = snappedf(stats.fill, 0.01)
		entry["rating"] = Difficulty.rating(stats)
		entry["a"] = LevelGen.encode(level)
		if Difficulty.accepts(n, stats, params):
			var dist := absf(float(entry.rating) - target)
			if dist < best_dist:
				best_dist = dist
				best = entry
		elif float(stats.fill) > fallback_fill:
			fallback_fill = float(stats.fill)
			fallback = entry
	if best.is_empty():
		best = fallback
		if not best.is_empty():
			push_warning("level %d: quality gate not met, using best fallback" % n)
	return best


# ---------------------------------------------------------------- tools

func _verify() -> bool:
	if not FileAccess.file_exists(out_path):
		push_error("%s not found" % out_path)
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(out_path))
	if typeof(d) != TYPE_DICTIONARY:
		push_error("bad json")
		return false
	var a: int = int(opts.get("from", 1))
	var b: int = int(opts.get("to", d.levels.size()))
	var bad := 0
	var seeds := {}
	for e in d.levels:
		if seeds.has(e.seed):
			push_error("level %d duplicate seed" % int(e.n))
			bad += 1
		seeds[e.seed] = true
	var checked := 0
	for e in d.levels:
		var n := int(e.n)
		if n < a or n > b:
			continue
		checked += 1
		# 1) the baked layout the game actually plays must be solvable
		var baked_a: Array = Array(LevelDB.read_layout(e, bin_path))
		var baked := LevelGen.decode(int(e.w), int(e.h), baked_a)
		if not LevelGen.analyze(baked).solvable:
			push_error("level %d NOT solvable" % n)
			bad += 1
		# 2) the seed must still regenerate the identical layout (detects generator drift)
		var level := LevelGen.generate(e, String(e.seed))
		var chk := LevelGen.checksum(level)
		if chk != String(e.chk) or LevelGen.encode(level) != baked_a:
			push_error("level %d seed no longer reproduces the baked layout (%s vs %s)" % [n, chk, e.chk])
			bad += 1
	print("verified %d levels (%d-%d), %d problems" % [checked, a, b, bad])
	return bad == 0


func _bench() -> void:
	for n in [1, 3, 12, 37, 99, 201, 399, 601, 799, 997]:
		var params := Difficulty.params_for(n)
		var t0 := Time.get_ticks_msec()
		var level := LevelGen.generate(params, "bench%d" % n)
		var ms := Time.get_ticks_msec() - t0
		var st := LevelGen.analyze(level)
		print("n=%4d %3dx%-3d %-9s %5dms arrows=%4d free=%3d depth=%3d fill=%.2f rating=%2d (aim %d) solvable=%s" % [
			n, params.w, params.h, params.shape, ms, st.arrows, st.free0, st.depth, st.fill,
			Difficulty.rating(st), int(Difficulty.target_rating(n)), st.solvable])


func _preview(n: int, seed_text: String) -> void:
	var params := Difficulty.params_for(n)
	var level := LevelGen.generate(params, seed_text)
	var stats := LevelGen.analyze(level)
	print("level %d params=%s" % [n, params])
	print("stats=%s" % stats)
	if int(level.w) > 40:
		print("(board too wide for ascii preview)")
		return
	var grid: Array = []
	for y in level.h:
		var row: Array = []
		for x in level.w:
			row.append(" . ")
		grid.append(row)
	var glyph := {Vector2i(1, 0): ">", Vector2i(0, 1): "v", Vector2i(-1, 0): "<", Vector2i(0, -1): "^"}
	for i in level.arrows.size():
		var a = level.arrows[i]
		var label := char(65 + (i % 26))
		for j in a.cells.size():
			var c: Vector2i = a.cells[j]
			grid[c.y][c.x] = (" " + glyph[a.dir] + label) if j == a.cells.size() - 1 else (" " + label.to_lower() + " ")
	for row in grid:
		print("".join(row))
