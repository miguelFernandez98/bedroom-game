extends Node2D

@onready var eye_left: ColorRect = $EyeLeft
@onready var eye_right: ColorRect = $EyeRight
@onready var timer: Timer = $WindowTimer

var normal_color: Color = Color(1, 1, 1)
var red_color: Color = Color(0.8, 0.1, 0.1)
var is_red: bool = false
var showing_stars: bool = true
var star_positions: Array = []
var star_alphas: Array = []
var star_count: int = 6

func _ready():
	eye_left.visible = false
	eye_right.visible = false
	_generate_stars()

func _process(_delta):
	if showing_stars:
		_animate_stars()
		queue_redraw()

func _draw():
	if not showing_stars:
		return
	for i in range(star_positions.size()):
		var pos = star_positions[i]
		var alpha = star_alphas[i]
		draw_circle(pos, 1.0, Color(0.878, 0.878, 0.776, alpha))

func _on_timer_timeout():
	if showing_stars:
		timer.wait_time = randf_range(0.8, 2.0)
		timer.start()
		return
	
	if randf() < 0.3:
		is_red = true
		_set_eyes_color(red_color)
		await get_tree().create_timer(0.5).timeout
		_set_eyes_color(normal_color)
		is_red = false
	
	timer.wait_time = randf_range(1.5, 4.0)
	timer.start()

func _set_eyes_color(color: Color):
	eye_left.color = color
	eye_right.color = color

func show_eyes():
	showing_stars = false
	eye_left.visible = true
	eye_right.visible = true
	_set_eyes_color(normal_color)
	queue_redraw()
	timer.wait_time = randf_range(2.0, 4.0)
	timer.start()

func _generate_stars():
	star_positions.clear()
	star_alphas.clear()
	for i in range(star_count):
		var x = randf_range(-34.0, 34.0)
		var y = randf_range(-8.0, 8.0)
		star_positions.append(Vector2(x, y))
		star_alphas.append(randf_range(0.2, 0.8))

func _animate_stars():
	for i in range(star_alphas.size()):
		star_alphas[i] += randf_range(-0.15, 0.15)
		star_alphas[i] = clampf(star_alphas[i], 0.05, 0.9)
