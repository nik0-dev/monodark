@tool
extends EditorPlugin

func _enter_tree():
	add_autoload_singleton("Console", "res://addons/monodark/resources/scripts/console.gd")

func _exit_tree():
	remove_autoload_singleton("Console")
