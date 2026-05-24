extends Node

var current_theme: String = "dark"
var dark_theme: Theme
var light_theme: Theme

func _ready() -> void:
	load_themes()
	apply_theme(current_theme)

func load_themes() -> void:
	dark_theme = preload("res://assets/themes/dark.tres") if ResourceLoader.exists("res://assets/themes/dark.tres") else Theme.new()
	light_theme = preload("res://assets/themes/light.tres") if ResourceLoader.exists("res://assets/themes/light.tres") else Theme.new()

func toggle_theme() -> void:
	if current_theme == "dark":
		apply_theme("light")
	else:
		apply_theme("dark")

func apply_theme(theme_name: String) -> void:
	var target = get_window()
	if theme_name == "dark":
		target.theme = dark_theme
		current_theme = "dark"
	elif theme_name == "light":
		target.theme = light_theme
		current_theme = "light"
	EventBus.emit_theme_changed(theme_name)

func get_theme_name() -> String:
	return current_theme
