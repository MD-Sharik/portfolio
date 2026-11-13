extends RefCounted
## Deterministic 32-bit PRNG (mulberry32).
## Same seed string -> same sequence on every platform and Godot version,
## so a level is fully described by its seed + params.

var _s: int = 0


func _init(seed_text: String = "") -> void:
	_s = fnv1a(seed_text)


static func fnv1a(text: String) -> int:
	var h: int = 0x811C9DC5
	for b in text.to_utf8_buffer():
		h = ((h ^ int(b)) * 0x01000193) & 0xFFFFFFFF
	return h


func next_u32() -> int:
	_s = (_s + 0x6D2B79F5) & 0xFFFFFFFF
	var t: int = _s
	t = ((t ^ (t >> 15)) * (t | 1)) & 0xFFFFFFFF
	t = (t ^ ((t + (((t ^ (t >> 7)) * (t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF)) & 0xFFFFFFFF
	return (t ^ (t >> 14)) & 0xFFFFFFFF


func next_float() -> float:
	return float(next_u32()) / 4294967296.0


## Inclusive range.
func int_range(a: int, b: int) -> int:
	if b <= a:
		return a
	return a + (next_u32() % (b - a + 1))


func chance(p: float) -> bool:
	return next_float() < p


func pick(arr: Array):
	return arr[int_range(0, arr.size() - 1)]


## Fisher-Yates, in place.
func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = int_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
