extends Node2D

@onready var eye_left: ColorRect = $EyeLeft
@onready var eye_right: ColorRect = $EyeRight
@onready var timer: Timer = $WindowTimer

var normal_color: Color = Color(1, 1, 1)
var red_color: Color = Color(0.8, 0.1, 0.1)
var is_red: bool = false

func _ready():
	_set_eyes_color(normal_color)

func _on_timer_timeout():
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
