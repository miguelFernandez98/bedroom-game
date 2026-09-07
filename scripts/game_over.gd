extends Control

func _ready():
	$VBoxContainer/RestartButton.pressed.connect(_on_restart_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

func _on_restart_pressed():
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/game_room.tscn")

func _on_quit_pressed():
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
