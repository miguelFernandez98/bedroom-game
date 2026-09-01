extends Node2D

@onready var eye_left: ColorRect = $EyeLeft
@onready var eye_right: ColorRect = $EyeRight
@onready var timer: Timer = $WindowTimer

var normal_color: Color = Color(1, 1, 1)
var red_color: Color = Color(0.8, 0.1, 0.1)
var star_color: Color = Color(0.878, 0.878, 0.776, 0.6)
var is_red: bool = false
var showing_stars: bool = true
var star_phase: int = 0

func _ready():
	eye_left.visible = false
	eye_right.visible = false

func _process(_delta):
	if showing_stars:
		_animate_stars()

func _on_timer_timeout():
	if showing_stars:
		timer.wait_time = randf_range(1.0, 2.5)
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
	timer.wait_time = randf_range(2.0, 4.0)
	timer.start()

func _animate_stars():
	star_phase = (star_phase + 1) % 3
	match star_phase:
		0:
			eye_left.color = Color(0.878, 0.878, 0.776, 0.3)
			eye_right.color = Color(0.878, 0.878, 0.776, 0.1)
		1:
			eye_left.color = Color(0.878, 0.878, 0.776, 0.1)
			eye_right.color = Color(0.878, 0.878, 0.776, 0.6)
		2:
			eye_left.color = Color(0.878, 0.878, 0.776, 0.6)
			eye_right.color = Color(0.878, 0.878, 0.776, 0.3)
	eye_left.visible = true
	eye_right.visible = true
