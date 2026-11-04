@tool
extends EditorPlugin

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = preload("res://addons/raw_store/export_plugin.gd").new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	if _export != null:
		remove_export_plugin(_export)
		_export = null
