extends Node2D

var snake_minigame: Node2D = null

func _draw():
	if not snake_minigame or not snake_minigame.is_active:
		return
	
	var origin = Vector2(0, 0)
	var cell_size = Vector2(snake_minigame.grid_size, snake_minigame.grid_size)
	var border = 2
	
	if snake_minigame.chase_mode:
		origin = Vector2(0, 0)
		var grid_w = snake_minigame.grid_width * snake_minigame.grid_size
		var grid_h = snake_minigame.grid_height * snake_minigame.grid_size
		
		draw_rect(Rect2(origin - Vector2(border, border), Vector2(grid_w + border * 2, grid_h + border * 2)), Color(0.3, 0.05, 0.05))
		draw_rect(Rect2(origin, Vector2(grid_w, grid_h)), Color(0.15, 0.05, 0.05))
	else:
		origin = Vector2(20, 60)
		var grid_w = snake_minigame.grid_width * snake_minigame.grid_size
		var grid_h = snake_minigame.grid_height * snake_minigame.grid_size
		
		draw_rect(Rect2(origin - Vector2(border, border), Vector2(grid_w + border * 2, grid_h + border * 2)), Color(0.078, 0.176, 0.133))
		draw_rect(Rect2(origin, Vector2(grid_w, grid_h)), Color(0.125, 0.282, 0.22))
	
	for i in range(snake_minigame.snake_body.size()):
		var segment = snake_minigame.snake_body[i]
		var pos = origin + segment * cell_size
		var color: Color
		if snake_minigame.chase_mode:
			color = Color(0.9, 0.2, 0.2) if i == 0 else Color(0.7, 0.1, 0.1)
		else:
			color = Color(0.545, 0.765, 0.290) if i == 0 else Color(0.361, 0.522, 0.180)
		draw_rect(Rect2(pos + Vector2(1, 1), cell_size - Vector2(2, 2)), color)
	
	if not snake_minigame.chase_mode:
		var food_pos = origin + snake_minigame.food_position * cell_size
		draw_rect(Rect2(food_pos + Vector2(2, 2), cell_size - Vector2(4, 4)), Color(0.945, 0.769, 0.059))
