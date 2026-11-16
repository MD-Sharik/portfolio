extends Node
## Autoload "Updates": Google Play In-App Updates.
##
## A few seconds after launch the game asks Google Play whether a newer version exists.
##   * optional update  -> Google's own "Update app?" sheet; if the player agrees, the update downloads
##                         in the background WHILE they keep playing, then we show
##                         "Update ready - restart now?" (tap = installed + game restarts)
##   * high priority    -> the full-screen "immediate" update flow
## Works only in builds installed from Google Play. On desktop nothing happens.

const Config := preload("res://scripts/app_config.gd")
const UIKit := preload("res://scripts/ui_kit.gd")

signal update_ready            # a flexible update finished downloading

var _plugin: Object = null
var _layer: CanvasLayer = null
var _shown_ready := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Config.UPDATE_ENABLED or OS.get_name() != "Android":
		return
	if not Engine.has_singleton("InAppUpdatePlugin"):
		push_warning("In-app update plugin missing in this build")
		return
	_plugin = Engine.get_singleton("InAppUpdatePlugin")
	_plugin.connect("update_available", _on_available)
	_plugin.connect("update_downloaded", _on_downloaded)
	_plugin.connect("update_failed", func(code: int): print("[updates] update flow ended, code ", code))
	_plugin.connect("check_failed", func(msg: String): print("[updates] check failed: ", msg))
	get_tree().create_timer(Config.UPDATE_CHECK_DELAY).timeout.connect(check)


func check() -> void:
	if _plugin != null:
		_plugin.checkForUpdate()


func _on_available(priority: int, staleness_days: int) -> void:
	var immediate: bool = priority >= Config.UPDATE_IMMEDIATE_PRIORITY
	var now := int(Time.get_unix_time_from_system())
	if not immediate and now - Save.update_last_prompt_unix < Config.UPDATE_PROMPT_COOLDOWN_HOURS * 3600:
		return                                     # asked recently - don't nag
	Save.update_last_prompt_unix = now
	Save.save_game()
	_plugin.startUpdate(immediate)


func _on_downloaded() -> void:
	if _shown_ready:
		return
	_shown_ready = true
	update_ready.emit()
	show_restart_dialog()


## Installs the downloaded update and restarts the game.
func install_now() -> void:
	if _plugin != null:
		_plugin.completeUpdate()


# --------------------------------------------------------------------------------- dialog

func show_restart_dialog() -> void:
	if _layer != null:
		return
	var c: Dictionary = Save.colors()
	_layer = CanvasLayer.new()
	_layer.layer = 110
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.flat(c.bg, 48, 4, c.rule, 20))
	panel.custom_minimum_size = Vector2(820, 0)
	center.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 48)
	panel.add_child(pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
	pad.add_child(box)
	box.add_child(UIKit.make_label("Update ready!", 72, c.title, 2))
	var body := UIKit.make_label("A new version of Arrow Escape has been downloaded. Restart now to get it?", 42, c.line)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(700, 0)
	box.add_child(body)
	var yes := UIKit.make_button("Restart now", c.gold, c.get("on_gold", Color.WHITE), 50)
	yes.pressed.connect(func(): _close(); install_now())
	box.add_child(yes)
	var later := UIKit.make_button("Later", c.panel, c.line, 50)
	later.pressed.connect(func(): _close(); _shown_ready = false)   # asks again next time the app resumes
	box.add_child(later)


func _close() -> void:
	if _layer != null:
		_layer.queue_free()
		_layer = null
