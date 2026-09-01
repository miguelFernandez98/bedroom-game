extends Node2D

var snake_minigame: Node2D = null

func _draw():
	if not snake_minigame or not snake_minigame.is_active:
		return
	
	var origin = Vector2(20, 60)
	var cell_size = Vector2(snake_minigame.grid_size, snake_minigame.grid_size)
	var border = 2
	
	draw_rect(Rect2(origin - Vector2(border, border), Vector2(snake_minigame.grid_width * snake_minigame.grid_size + border * 2, snake_minigame.grid_height * snake_minigame.grid_size + border * 2)), Color(0.078, 0.176, 0.133))
	draw_rect(Rect2(origin, Vector2(snake_minigame.grid_width * snake_minigame.grid_size, snake_minigame.grid_height * snake_minigame.grid_size)), Color(0.125, 0.282, 0.22))
	
	for i in range(snake_minigame.snake_body.size()):
		var segment = snake_minigame.snake_body[i]
		var pos = origin + segment * cell_size
		var color = Color(0.545, 0.765, 0.290) if i == 0 else Color(0.361, 0.522, 0.180)
		draw_rect(Rect2(pos + Vector2(1, 1), cell_size - Vector2(2, 2)), color)
	
	var food_pos = origin + snake_minigame.food_position * cell_size
	draw_rect(Rect2(food_pos + Vector2(2, 2), cell_size - Vector2(4, 4)), Color(0.945, 0.769, 0.059))
