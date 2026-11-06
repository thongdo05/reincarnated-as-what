@tool
extends EditorExportPlugin

## Runs before the AdMob exporter when this plugin is first in the enabled list.
## App IDs are read from StoreConfig so scripts/store_config.gd stays the one spot.


func _get_name() -> String:
	return "RawStore"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformIOS or platform is EditorExportPlatformAndroid


func _export_begin(features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	if features.has("ios"):
		_apply_ios()
	elif features.has("android"):
		_apply_android()


func _apply_ios() -> void:
	var app_id := StoreConfig.ios_app_id()
	if app_id.is_empty():
		push_error("iOS export needs the real AdMob app id in scripts/store_config.gd.")
		return
	ProjectSettings.set_setting("admob/general/ios/enabled", true)
	ProjectSettings.set_setting("admob/general/ios/app_id", app_id)
	var plist := StoreConfig.att_plist()
	if has_method("add_apple_embedded_platform_plist_content"):
		call("add_apple_embedded_platform_plist_content", plist)
	elif has_method("add_ios_plist_content"):
		call("add_ios_plist_content", plist)


func _apply_android() -> void:
	var app_id := StoreConfig.android_app_id()
	if app_id.is_empty():
		push_error("Android export needs the real AdMob app id in scripts/store_config.gd.")
		return
	ProjectSettings.set_setting("admob/general/android/enabled", true)
	ProjectSettings.set_setting("admob/general/android/app_id", app_id)
