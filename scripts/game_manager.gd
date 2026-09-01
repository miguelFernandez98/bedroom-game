extends Node

signal stress_changed(new_stress: int)
signal shrink_changed(new_shrink: int)
signal game_over
signal victory

var stress_level: int = 0
var shrink_level: int = 0
var positive_answers: int = 0
var negative_answers: int = 0
var is_game_over: bool = false
var is_victory: bool = false
var first_snake_completed: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func add_positive_answer():
	positive_answers += 1
	stress_level = maxi(stress_level - 10, 0)
	stress_changed.emit(stress_level)

func add_negative_answer():
	negative_answers += 1
	stress_level = mini(stress_level + 20, 100)
	stress_changed.emit(stress_level)

func add_stress(amount: int):
	stress_level = mini(stress_level + amount, 100)
	stress_changed.emit(stress_level)
	if stress_level >= 100:
		trigger_game_over()

func reduce_stress(amount: int):
	stress_level = maxi(stress_level - amount, 0)
	stress_changed.emit(stress_level)

func add_shrink(amount: int = 1):
	shrink_level = mini(shrink_level + amount, 5)
	shrink_changed.emit(shrink_level)

func trigger_game_over():
	if is_game_over or is_victory:
		return
	is_game_over = true
	game_over.emit()

func trigger_victory():
	if is_game_over or is_victory:
		return
	is_victory = true
	victory.emit()

func reset_game():
	stress_level = 0
	shrink_level = 0
	positive_answers = 0
	negative_answers = 0
	is_game_over = false
	is_victory = false
	first_snake_completed = false

func get_stress_color() -> Color:
	if stress_level < 30:
		return Color(0.2, 0.8, 0.2)
	elif stress_level < 60:
		return Color(0.8, 0.8, 0.2)
	else:
		return Color(0.8, 0.2, 0.2)

func get_shrink_offset() -> float:
	return shrink_level * 32.0
