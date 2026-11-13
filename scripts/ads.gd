extends Node
## Autoload "Ads": banner + interstitial + rewarded ads.
##   * Android with the AdMob plugin  -> real (or Google test) ads
##   * Desktop / editor                -> a small simulator so every flow can be tested
##
## Usage from the game:
##   Ads.show_banner(true)
##   Ads.show_rewarded(func(earned: bool): ...)
##   Ads.maybe_interstitial(func(): ...)      # call when the player moves to the next level

const Config := preload("res://scripts/ads_config.gd")
const ADMOB_SCRIPT := "res://addons/AdmobPlugin/Admob.gd"

var _admob: Node = null
var _sdk_ready := false
var _rewarded_loaded := false
var _interstitial_loaded := false
var _banner_loaded := false
var _want_banner := false
var _reward_cb := Callable()
var _reward_earned := false
var _inter_cb := Callable()
var _levels_since := 0
var _last_inter_time := -1000.0
var _sim := false
var _sim_layer: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Config.ENABLED:
		return
	if OS.get_name() == "Android":
		if ResourceLoader.exists(ADMOB_SCRIPT) and Engine.has_singleton("AdmobPlugin"):
			_setup_admob()
		else:
			push_warning("AdMob plugin missing in this build - ads disabled")
	elif Config.SIMULATE_ON_DESKTOP:
		_sim = true


## True when a rewarded ad can be shown right now.
func rewarded_available() -> bool:
	if _sim:
		return true
	return _admob != null and _rewarded_loaded


func is_active() -> bool:
	return _sim or _admob != null


# ------------------------------------------------------------------ setup

func _setup_admob() -> void:
	var script: GDScript = load(ADMOB_SCRIPT)
	_admob = script.new()
	_admob.is_real = Config.IS_REAL
	_admob.android_real_banner_id = Config.REAL_BANNER_ID
	_admob.android_real_interstitial_id = Config.REAL_INTERSTITIAL_ID
	_admob.android_real_rewarded_id = Config.REAL_REWARDED_ID
	_admob.banner_position = 1          # LoadAdRequest.AdPosition.BOTTOM
	_admob.banner_size = 5              # LoadAdRequest.RequestedAdSize.ADAPTIVE
	_admob.child_directed = Config.CHILD_DIRECTED
	_admob.max_ad_content_rating = 0    # G
	add_child(_admob)
	_admob.initialization_completed.connect(_on_initialized)
	_admob.banner_ad_loaded.connect(_on_banner_loaded)
	_admob.banner_ad_failed_to_load.connect(func(_a = null, _b = null): _retry(_load_banner))
	_admob.rewarded_ad_loaded.connect(func(_a = null, _b = null): _rewarded_loaded = true)
	_admob.rewarded_ad_failed_to_load.connect(func(_a = null, _b = null): _rewarded_loaded = false; _retry(_load_rewarded))
	_admob.rewarded_ad_user_earned_reward.connect(func(_a = null, _b = null): _reward_earned = true)
	_admob.rewarded_ad_dismissed_full_screen_content.connect(func(_a = null): _finish_rewarded())
	_admob.rewarded_ad_failed_to_show_full_screen_content.connect(func(_a = null, _b = null): _reward_earned = false; _finish_rewarded())
	_admob.interstitial_ad_loaded.connect(func(_a = null, _b = null): _interstitial_loaded = true)
	_admob.interstitial_ad_failed_to_load.connect(func(_a = null, _b = null): _interstitial_loaded = false; _retry(_load_interstitial))
	_admob.interstitial_ad_dismissed_full_screen_content.connect(func(_a = null): _finish_interstitial())
	_admob.interstitial_ad_failed_to_show_full_screen_content.connect(func(_a = null, _b = null): _finish_interstitial())
	_admob.initialize()


func _on_initialized(_status = null) -> void:
	_sdk_ready = true
	_load_rewarded()
	_load_interstitial()
	if _want_banner:
		_load_banner()


func _retry(fn: Callable) -> void:
	get_tree().create_timer(25.0).timeout.connect(fn)


func _load_banner() -> void:
	if _admob and _sdk_ready and not _banner_loaded:
		_admob.load_banner_ad()


func _load_rewarded() -> void:
	if _admob and _sdk_ready:
		_rewarded_loaded = false
		_admob.load_rewarded_ad()


func _load_interstitial() -> void:
	if _admob and _sdk_ready:
		_interstitial_loaded = false
		_admob.load_interstitial_ad()


func _on_banner_loaded(_a = null, _b = null) -> void:
	_banner_loaded = true
	if _want_banner:
		_admob.show_banner_ad()


# ------------------------------------------------------------------- banner

func show_banner(on: bool) -> void:
	_want_banner = on
	if _admob == null or not _sdk_ready:
		return
	if on:
		if _banner_loaded:
			_admob.show_banner_ad()
		else:
			_load_banner()
	elif _banner_loaded:
		_admob.hide_banner_ad()


# ----------------------------------------------------------------- rewarded

## cb(earned: bool) is called once the ad is closed (earned = the player should get the reward).
func show_rewarded(cb: Callable) -> void:
	if not rewarded_available() or _reward_cb.is_valid():
		cb.call(false)
		return
	_reward_cb = cb
	_reward_earned = false
	if _sim:
		_sim_overlay("Rewarded test ad", Config.SIM_REWARDED_SECONDS, func(): _reward_earned = true; _finish_rewarded())
	else:
		_admob.show_rewarded_ad()


func _finish_rewarded() -> void:
	var cb := _reward_cb
	var earned := _reward_earned
	_reward_cb = Callable()
	_reward_earned = false
	if _admob:
		_load_rewarded()
	if cb.is_valid():
		cb.call_deferred(earned)


# ------------------------------------------------------------ interstitial

## Call when the player is about to start the next level. Shows an interstitial every
## Config.INTERSTITIAL_EVERY levels (with a cool-down); `then` runs afterwards either way.
func maybe_interstitial(then: Callable) -> void:
	_levels_since += 1
	var now := Time.get_ticks_msec() / 1000.0
	var due: bool = Config.INTERSTITIAL_EVERY > 0 and _levels_since >= Config.INTERSTITIAL_EVERY \
		and now - _last_inter_time >= Config.INTERSTITIAL_MIN_SECONDS
	if not due or not is_active():
		then.call()
		return
	if _sim:
		_levels_since = 0
		_last_inter_time = now
		_sim_overlay("Test interstitial", 2.0, then)
	elif _interstitial_loaded:
		_levels_since = 0
		_last_inter_time = now
		_inter_cb = then
		_admob.show_interstitial_ad()
	else:
		then.call()


func _finish_interstitial() -> void:
	var cb := _inter_cb
	_inter_cb = Callable()
	_load_interstitial()
	if cb.is_valid():
		cb.call_deferred()


# --------------------------------------------------------------- simulator

func _sim_overlay(title: String, seconds: float, on_done: Callable) -> void:
	if _sim_layer:
		_sim_layer.queue_free()
	_sim_layer = CanvasLayer.new()
	_sim_layer.layer = 120
	add_child(_sim_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.1, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_sim_layer.add_child(dim)
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 64)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	_sim_layer.add_child(lbl)
	var left := seconds
	while left > 0.0:
		lbl.text = "%s\n\n%d" % [title, int(ceil(left))]
		await get_tree().create_timer(0.25).timeout
		left -= 0.25
	_sim_layer.queue_free()
	_sim_layer = null
	on_done.call()
