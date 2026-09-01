extends Node2D

@onready var eye_left: ColorRect = $EyeLeft
@onready var eye_right: ColorRect = $EyeRight
@onready var timer: Timer = $WindowTimer

var normal_color: Color = Color(1, 1, 1)
var red_color: Color = Color(0.8, 0.1, 0.1)
var is_red: bool = false
var showing_stars: bool = true
var star_nodes: Array = []
var star_count: int = 8

func _ready():
	eye_left.visible = false
	eye_right.visible = false
	_generate_stars()

func _process(_delta):
	if showing_stars:
		_animate_stars()

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
	for star in star_nodes:
		star.queue_free()
	star_nodes.clear()
	eye_left.visible = true
	eye_right.visible = true
	_set_eyes_color(normal_color)
	timer.wait_time = randf_range(2.0, 4.0)
	timer.start()

func _generate_stars():
	for star in star_nodes:
		star.queue_free()
	star_nodes.clear()
	for i in range(star_count):
		var star = ColorRect.new()
		star.color = Color(0.878, 0.878, 0.776, randf_range(0.3, 0.9))
		star.offset_left = randf_range(-34.0, 34.0)
		star.offset_top = randf_range(-8.0, 8.0)
		star.offset_right = star.offset_left + 1.5
		star.offset_bottom = star.offset_top + 1.5
		add_child(star)
		star_nodes.append(star)

func _animate_stars():
	for star in star_nodes:
		var c = star.color
		c.a += randf_range(-0.08, 0.08)
		c.a = clampf(c.a, 0.05, 0.95)
		star.color = c
