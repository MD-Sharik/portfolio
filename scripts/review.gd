extends Node
## Autoload "Review": asks for a Google Play review at a good moment, using Google's In-App Review
## API (the small rating card appears on top of the game - the player never leaves the app).
##
##   Review.maybe_request()   call after something happy (e.g. a cleared level); it decides by itself
##   Review.open_store_page() "Rate the game" button: opens the Play Store listing
##
## Works only in builds installed from Google Play. Elsewhere (desktop, sideloaded APK) it just logs.

const Config := preload("res://scripts/app_config.gd")
const REVIEW_SCRIPT := "res://addons/InappReviewPlugin/InappReview.gd"

signal requested        # emitted when a review request really starts (also in the simulator)

var _node: Node = null
var _busy := false
var _sim := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() == "Android":
		if ResourceLoader.exists(REVIEW_SCRIPT) and Engine.has_singleton("InappReviewPlugin"):
			var script: GDScript = load(REVIEW_SCRIPT)
			_node = script.new()
			add_child(_node)
			_node.review_info_generated.connect(_on_info_ready)
			_node.review_info_generation_failed.connect(func(): _busy = false)
			_node.review_flow_launched.connect(func(): _busy = false)
			_node.review_flow_launch_failed.connect(func(): _busy = false)
		else:
			push_warning("In-app review plugin missing in this build")
	else:
		_sim = true


## True when every condition in app_config.gd is met right now.
func is_due() -> bool:
	if not Config.REVIEW_ENABLED:
		return false
	if Save.review_count >= Config.REVIEW_MAX_PROMPTS:
		return false
	if Save.completed.size() < Config.REVIEW_MIN_LEVELS:
		return false
	var now := int(Time.get_unix_time_from_system())
	if Save.first_launch_unix > 0 and now - Save.first_launch_unix < Config.REVIEW_MIN_DAYS * 86400:
		return false
	if Save.review_last_unix > 0 and now - Save.review_last_unix < Config.REVIEW_COOLDOWN_DAYS * 86400:
		return false
	return true


func maybe_request() -> bool:
	if _busy or not is_due():
		return false
	return request()


func request() -> bool:
	if _busy:
		return false
	if _node == null and not _sim:
		return false
	_busy = true
	if _node != null:
		_node.generate_review_info()
	else:
		print("[review] simulator: would show the Google Play review card now")
		_on_info_ready()
		_busy = false
	return true


func _on_info_ready() -> void:
	# Count the attempt only once Google actually handed us a review flow.
	Save.review_count += 1
	Save.review_last_unix = int(Time.get_unix_time_from_system())
	Save.save_game()
	requested.emit()
	if _node != null:
		_node.launch_review_flow()


func open_store_page() -> void:
	if OS.get_name() == "Android":
		OS.shell_open("market://details?id=" + Config.PACKAGE_ID)
	else:
		OS.shell_open("https://play.google.com/store/apps/details?id=" + Config.PACKAGE_ID)
