@tool
extends EditorPlugin

func _enter_tree():
	var plugin_dir = get_script().resource_path.get_base_dir()
	add_autoload_singleton("CrazyGamesBridge", plugin_dir + "/Utils/CrazyGamesBridge.gd")
	add_autoload_singleton("CrazyGames", plugin_dir + "/CrazyGames.gd")


func _exit_tree():
	remove_autoload_singleton("CrazyGames")
	remove_autoload_singleton("CrazyGamesBridge")
