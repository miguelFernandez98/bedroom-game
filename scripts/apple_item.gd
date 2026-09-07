extends Node2D

signal apple_collected

var is_player_near: bool = false
var interact_range: float = 50.0

func _ready():
	add_to_group("apple")
	$Sprite2D.visible = true

func _process(_delta):
	var p = get_tree().get_first_node_in_group("player")
	if not p:
		return
	
	var dist = global_position.distance_to(p.global_position)
	var was_near = is_player_near
	is_player_near = dist < interact_range
	
	if is_player_near and not was_near:
		var dm = get_tree().get_first_node_in_group("dialogue_manager")
		if dm:
			dm.show_interact_prompt("[E] Recoger manzana")
	elif not is_player_near and was_near:
		var dm = get_tree().get_first_node_in_group("dialogue_manager")
		if dm:
			dm.hide_interact_prompt()

func _input(event):
	if not is_player_near:
		return
	if event.is_action_pressed("interact"):
		_collect()

func _collect():
	var dm = get_tree().get_first_node_in_group("dialogue_manager")
	if dm:
		dm.hide_interact_prompt()
	GameManager.gain_heart()
	apple_collected.emit()
	queue_free()
