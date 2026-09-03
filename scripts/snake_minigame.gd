extends Node2D

signal snake_game_completed(success: bool)

var is_active: bool = false
var snake_body: Array = []
var food_position: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var next_direction: Vector2 = Vector2.RIGHT
var game_speed: float = 0.2
var grid_size: int = 12
var grid_width: int = 20
var grid_height: int = 16
var score: int = 0
var target_score: int = 5

@onready var timer: Timer = $Timer
@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var draw_node: Node2D = $CanvasLayer/DrawNode

func _ready():
	canvas_layer.visible = false
	timer.wait_time = game_speed
	timer.timeout.connect(_on_game_tick)
	seed(randi())
	draw_node.snake_minigame = self

func start_snake_game():
	var attempts = GameManager.snake_attempts
	if attempts == 0:
		game_speed = 0.14
		target_score = 8
	elif attempts == 1:
		game_speed = 0.20
		target_score = 5
	else:
		game_speed = 0.30
		target_score = 3
	
	is_active = true
	canvas_layer.visible = true
	score = 0
	direction = Vector2.RIGHT
	next_direction = Vector2.RIGHT
	timer.wait_time = game_speed
	
	var start_x = grid_width / 2
	var start_y = grid_height / 2
	snake_body = [
		Vector2(start_x, start_y),
		Vector2(start_x - 1, start_y),
		Vector2(start_x - 2, start_y)
	]
	
	_spawn_food()
	_update_score()
	timer.start()
	draw_node.queue_redraw()

func _on_game_tick():
	if not is_active:
		return
	
	direction = next_direction
	
	var head = snake_body[0] + direction
	
	if head.x < 0 or head.x >= grid_width or head.y < 0 or head.y >= grid_height:
		_end_game(false)
		return
	
	for segment in snake_body:
		if head == segment:
			_end_game(false)
			return
	
	snake_body.insert(0, head)
	
	if head == food_position:
		score += 1
		_update_score()
		_spawn_food()
		if score >= target_score:
			_end_game(true)
			return
		if score % 3 == 0:
			game_speed = maxf(game_speed - 0.01, 0.08)
			timer.wait_time = game_speed
	else:
		snake_body.pop_back()
	
	draw_node.queue_redraw()

func _spawn_food():
	var valid = false
	while not valid:
		food_position = Vector2(randi() % grid_width, randi() % grid_height)
		valid = true
		for segment in snake_body:
			if food_position == segment:
				valid = false
				break

func _update_score():
	if score_label:
		score_label.text = "Come %d manzanas (vas: %d)" % [target_score, score]

func _end_game(success: bool):
	is_active = false
	timer.stop()
	canvas_layer.visible = false
	snake_game_completed.emit(success)

func _input(event):
	if not is_active:
		return
	
	if event.is_action_pressed("move_up") and direction != Vector2.DOWN:
		next_direction = Vector2.UP
	elif event.is_action_pressed("move_down") and direction != Vector2.UP:
		next_direction = Vector2.DOWN
	elif event.is_action_pressed("move_left") and direction != Vector2.RIGHT:
		next_direction = Vector2.LEFT
	elif event.is_action_pressed("move_right") and direction != Vector2.LEFT:
		next_direction = Vector2.RIGHT
