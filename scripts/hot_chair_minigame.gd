extends Node2D

signal chair_game_completed(success: bool)

var is_active: bool = false
var clone_node: Node2D = null
var bed_node: Node2D = null
var player_node: Node2D = null
var round_number: int = 0
var player_wins: int = 0
var clone_wins: int = 0
var max_rounds: int = 3
var clone_speed: float = 60.0
var clone_target: Vector2 = Vector2.ZERO
var bed_label: Label = null

func _ready():
	$CanvasLayer.visible = false

func start_chair_game():
	is_active = true
	round_number = 0
	player_wins = 0
	clone_wins = 0
	$CanvasLayer.visible = true
	
	clone_node = Node2D.new()
	clone_node.name = "Clone"
	add_child(clone_node)
	
	var clone_body = ColorRect.new()
	clone_body.color = Color(0.8, 0.2, 0.2)
	clone_body.offset_left = -6.0
	clone_body.offset_top = -8.0
	clone_body.offset_right = 6.0
	clone_body.offset_bottom = 8.0
	clone_node.add_child(clone_body)
	
	var clone_head = ColorRect.new()
	clone_head.color = Color(0.9, 0.3, 0.3)
	clone_head.offset_left = -4.0
	clone_head.offset_top = -14.0
	clone_head.offset_right = 4.0
	clone_head.offset_bottom = -8.0
	clone_node.add_child(clone_head)
	
	clone_node.position = Vector2(240, 16)
	clone_node.visible = false
	
	player_node = get_tree().get_first_node_in_group("player")
	bed_node = get_tree().get_first_node_in_group("bed")
	
	_start_round()

func _start_round():
	round_number += 1
	_update_hud()
	
	if player_node:
		player_node.set_can_move(false)
		player_node.position = Vector2(240, 350)
		await get_tree().create_timer(0.5).timeout
		player_node.set_can_move(true)
	
	var bed_pos = _get_random_bed_position()
	if bed_node:
		bed_node.position = bed_pos
		bed_node.can_interact = false
		bed_node.push_enabled = false
		if bed_node.bed_solid:
			bed_node.bed_solid.position = bed_pos
	
	clone_node.position = Vector2(240, 16)
	clone_node.visible = true
	clone_target = bed_pos
	
	$CanvasLayer/RoundLabel.text = "Ronda %d - ¡Primero a la cama!" % round_number
	$CanvasLayer/RoundLabel.visible = true
	
	await get_tree().create_timer(1.0).timeout
	$CanvasLayer/RoundLabel.visible = false

func _process(delta):
	if not is_active:
		return
	
	if not clone_node or not bed_node:
		return
	
	var dist_to_bed = clone_node.position.distance_to(clone_target)
	if dist_to_bed > 5.0:
		var dir = (clone_target - clone_node.position).normalized()
		clone_node.position += dir * clone_speed * delta
	
	if bed_node:
		var player_dist = player_node.position.distance_to(bed_node.position) if player_node else 999
		var clone_dist = clone_node.position.distance_to(bed_node.position)
		
		if player_dist < 20.0:
			_end_round(true)
		elif clone_dist < 20.0:
			_end_round(false)

func _end_round(player_won: bool):
	if player_won:
		player_wins += 1
	else:
		clone_wins += 1
	
	$CanvasLayer/ScoreLabel.text = "Tú: %d | Clon: %d" % [player_wins, clone_wins]
	$CanvasLayer/ScoreLabel.visible = true
	
	if player_node:
		player_node.set_can_move(false)
	
	clone_node.visible = false
	
	await get_tree().create_timer(1.5).timeout
	$CanvasLayer/ScoreLabel.visible = false
	
	if player_wins >= 2:
		_end_game(true)
	elif clone_wins >= 2:
		_end_game(false)
	else:
		_start_round()

func _end_game(success: bool):
	is_active = false
	$CanvasLayer.visible = false
	
	if clone_node:
		clone_node.queue_free()
		clone_node = null
	
	chair_game_completed.emit(success)

func _get_random_bed_position() -> Vector2:
	var rc = get_tree().get_first_node_in_group("room_controller")
	if rc and rc.has_method("get_bed_random_position"):
		return rc.get_bed_random_position()
	return Vector2(randf_range(80, 400), randf_range(80, 350))

func _update_hud():
	$CanvasLayer/RoundLabel.text = "Ronda %d" % round_number
	$CanvasLayer/ScoreLabel.text = "Tú: %d | Clon: %d" % [player_wins, clone_wins]
