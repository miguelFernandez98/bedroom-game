extends Node

signal hearts_changed(new_hearts: int)
signal shrink_changed(new_shrink: int)
signal game_over
signal victory

var hearts: int = 3
var max_hearts: int = 3
var shrink_level: int = 0
var positive_answers: int = 0
var negative_answers: int = 0
var is_game_over: bool = false
var is_victory: bool = false
var first_snake_completed: bool = false
var snake_attempts: int = 0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func lose_heart():
	hearts = maxi(hearts - 1, 0)
	hearts_changed.emit(hearts)
	if hearts <= 0:
		trigger_game_over()

func gain_heart():
	hearts = mini(hearts + 1, max_hearts)
	hearts_changed.emit(hearts)

func add_positive_answer():
	positive_answers += 1

func add_negative_answer():
	negative_answers += 1

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
	hearts = 3
	shrink_level = 0
	positive_answers = 0
	negative_answers = 0
	is_game_over = false
	is_victory = false
	first_snake_completed = false
	snake_attempts = 0

func get_shrink_offset() -> float:
	return shrink_level * 32.0
