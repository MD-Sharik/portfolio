extends Node
## Autoload "Save": progress + settings persisted to user://save.json

const Palette := preload("res://scripts/palette.gd")
const PATH := "user://save.json"
const MAX_HINTS := 9

signal theme_changed

var current_level: int = 1      # level the Play button opens
var max_level: int = 1          # highest unlocked level
var hints: int = 3
var theme: int = 0
var sound: bool = true
var vibrate: bool = true
var completed := {}             # level number -> true
var first_launch_unix: int = 0  # when the game was first opened (used to time the review prompt)
var review_last_unix: int = 0   # last time we asked for a Play Store review
var review_count: int = 0       # how many times we asked
var update_last_prompt_unix: int = 0   # last time we offered an in-app update


func _ready() -> void:
	load_game()
	if first_launch_unix == 0:
		first_launch_unix = int(Time.get_unix_time_from_system())
		save_game()


func colors() -> Dictionary:
	return Palette.get_theme(theme)


func load_game() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return
	current_level = int(d.get("current_level", 1))
	max_level = int(d.get("max_level", 1))
	hints = int(d.get("hints", 3))
	theme = int(d.get("theme", 0))
	sound = bool(d.get("sound", true))
	vibrate = bool(d.get("vibrate", true))
	completed = {}
	for k in d.get("completed", []):
		completed[int(k)] = true
	first_launch_unix = int(d.get("first_launch_unix", 0))
	review_last_unix = int(d.get("review_last_unix", 0))
	review_count = int(d.get("review_count", 0))
	update_last_prompt_unix = int(d.get("update_last_prompt_unix", 0))


func save_game() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"current_level": current_level, "max_level": max_level, "hints": hints,
		"theme": theme, "sound": sound, "vibrate": vibrate, "completed": completed.keys(),
		"first_launch_unix": first_launch_unix, "review_last_unix": review_last_unix,
		"review_count": review_count, "update_last_prompt_unix": update_last_prompt_unix,
	}))


func cycle_theme() -> void:
	theme = (theme + 1) % Palette.THEMES.size()
	save_game()
	theme_changed.emit()


## Called when a level is solved. Every 3rd completion rewards a hint.
func complete_level(n: int) -> void:
	var first_time := not completed.has(n)
	completed[n] = true
	if first_time and completed.size() % 3 == 0:
		hints = mini(MAX_HINTS, hints + 1)
	if n >= max_level:
		max_level = n + 1
	current_level = n + 1
	save_game()


func add_hint() -> void:
	hints = mini(MAX_HINTS, hints + 1)
	save_game()


func use_hint() -> bool:
	if hints <= 0:
		return false
	hints -= 1
	save_game()
	return true


func reset_progress() -> void:
	current_level = 1
	max_level = 1
	hints = 3
	completed = {}
	save_game()
