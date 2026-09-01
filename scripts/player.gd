extends CharacterBody2D

const SPEED = 80.0

var facing_direction: String = "down"
var is_moving: bool = false
var can_move: bool = true

@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var override_sprite: Sprite2D = $OverrideSprite

func _ready():
	add_to_group("player")
	sprite.play("idle_down")
	override_sprite.visible = false

func _physics_process(_delta: float):
	if not can_move:
		velocity = Vector2.ZERO
		return
	
	if not override_sprite.visible:
		sprite.visible = true
	
	var input_dir := Vector2.ZERO
	
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	
	input_dir = input_dir.normalized()
	
	if input_dir != Vector2.ZERO:
		is_moving = true
		_update_facing(input_dir)
		_play_walk_animation()
		velocity = input_dir * SPEED
	else:
		is_moving = false
		velocity = Vector2.ZERO
		_play_idle_animation()
	
	move_and_slide()

func set_override_texture(tex: Texture2D):
	sprite.visible = false
	override_sprite.texture = tex
	override_sprite.visible = true

func clear_override():
	override_sprite.visible = false
	sprite.visible = true

func _update_facing(dir: Vector2):
	if dir.x == 0 and dir.y < 0:
		facing_direction = "up"
	elif dir.x == 0 and dir.y > 0:
		facing_direction = "down"
	elif dir.x < 0:
		facing_direction = "left"
	elif dir.x > 0:
		facing_direction = "right"

func _play_walk_animation():
	var anim_name = "walk_" + facing_direction
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)

func _play_idle_animation():
	var anim_name = "idle_" + facing_direction
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	else:
		sprite.play("idle_down")

func set_can_move(value: bool):
	can_move = value
	if not can_move:
		velocity = Vector2.ZERO
		_play_idle_animation()

func get_facing_direction() -> String:
	return facing_direction
