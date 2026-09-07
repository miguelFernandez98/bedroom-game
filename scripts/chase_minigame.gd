extends Node2D

signal chase_completed(success: bool)

var is_active: bool = false
var clone_node: Node2D = null
var player_node: Node2D = null
var clone_speed: float = 55.0
var catch_distance: float = 24.0
var clone_start_position: Vector2 = Vector2(240, 80)

func start_chase():
	is_active = true
	
	# Create clone
	clone_node = Node2D.new()
	clone_node.name = "ChaseClone"
	add_child(clone_node)
	
	var sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	var sf = load("res://assets/sprites/player.tres")
	sprite.sprite_frames = sf
	sprite.animation = &"idle_down"
	sprite.scale = Vector2(3, 3)
	sprite.modulate = Color(1.0, 0.2, 0.2)
	clone_node.add_child(sprite)
	
	clone_node.position = clone_start_position
	clone_node.visible = true
	
	player_node = get_tree().get_first_node_in_group("player")

func _process(delta):
	if not is_active or not clone_node or not player_node:
		return
	
	# Move clone toward player
	var dir = (player_node.global_position - clone_node.global_position).normalized()
	clone_node.position += dir * clone_speed * delta
	
	# Update clone facing
	if clone_node.get_child(0) is AnimatedSprite2D:
		var sprite = clone_node.get_child(0)
		if abs(dir.x) > abs(dir.y):
			if dir.x > 0:
				sprite.play("walk_right")
			else:
				sprite.play("walk_left")
		else:
			if dir.y > 0:
				sprite.play("walk_down")
			else:
				sprite.play("walk_up")
	
	# Check catch
	var dist = clone_node.global_position.distance_to(player_node.global_position)
	if dist < catch_distance:
		end_game(false)

func end_game(success: bool):
	is_active = false
	if clone_node:
		clone_node.queue_free()
		clone_node = null
	chase_completed.emit(success)

func _exit_tree():
	if clone_node:
		clone_node.queue_free()
		clone_node = null
	is_active = false
