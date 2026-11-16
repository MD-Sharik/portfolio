@tool
extends EditorPlugin
## Adds the InAppUpdatePlugin AAR + Google's app-update library to Android exports.

const PLUGIN_NAME := "InAppUpdatePlugin"
const ANDROID_DEPENDENCIES := ["com.google.android.play:app-update:2.1.0"]

var _export_plugin: AndroidExportPlugin


func _enter_tree() -> void:
	_export_plugin = AndroidExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray(["%s/bin/debug/%s-debug.aar" % [PLUGIN_NAME, PLUGIN_NAME]])
		return PackedStringArray(["%s/bin/release/%s-release.aar" % [PLUGIN_NAME, PLUGIN_NAME]])

	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray(ANDROID_DEPENDENCIES)

	func _get_name() -> String:
		return PLUGIN_NAME
