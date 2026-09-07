extends Area2D

signal chase_victory

var is_player_near: bool = false
var can_interact: bool = true
var push_enabled: bool = true
var interact_range: float = 90.0
var is_pushing: bool = false
var bed_solid: StaticBody2D = null
var window_position: Vector2 = Vector2(240, 16)
var push_reached_window: bool = false
var cooldown: float = 0.0

func _ready():
	add_to_group("bed")
	bed_solid = get_parent().get_node_or_null("BedSolid")

func _process(delta):
	if cooldown > 0:
		cooldown -= delta
		return
	if push_reached_window:
		return
	
	var p = _get_player()
	if not p:
		return
	
	var dist = global_position.distance_to(p.global_position)
	is_player_near = dist < interact_range
	
	# Auto-push: player near + bed pushable + player moving toward bed
	if is_player_near and push_enabled and p.is_moving and p.can_move:
		var to_bed = (global_position - p.global_position).normalized()
		var move_dir = _get_move_direction()
		if move_dir != Vector2.ZERO and move_dir.dot(to_bed) > 0.3:
			if not is_pushing:
				is_pushing = true
				var dm = _get_dm()
				if dm:
					dm.hide_interact_prompt()
			_apply_push(move_dir, delta)
			return
	
	# Stop pushing when conditions not met
	if is_pushing:
		is_pushing = false
	
	# Prompt logic
	if is_player_near:
		var dm = _get_dm()
		if dm:
			var rc = _get_rc()
			if rc and rc.current_state == rc.GameState.IDLE and can_interact:
				dm.show_interact_prompt("[E] Dormir")
			else:
				dm.hide_interact_prompt()
	else:
		var dm = _get_dm()
		if dm:
			dm.hide_interact_prompt()

func _input(event):
	if cooldown > 0 or push_reached_window or not is_player_near:
		return
	if event.is_action_pressed("interact") and can_interact and not is_pushing:
		var rc = _get_rc()
		if rc and rc.current_state == rc.GameState.IDLE:
			_try_sleep()

func _get_move_direction() -> Vector2:
	var dir = Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		dir.y -= 1
	if Input.is_action_pressed("move_down"):
		dir.y += 1
	if Input.is_action_pressed("move_left"):
		dir.x -= 1
	if Input.is_action_pressed("move_right"):
		dir.x += 1
	return dir.normalized()

func _apply_push(move_dir: Vector2, delta: float):
	var new_pos = position + move_dir * 40.0 * delta
	new_pos.x = clampf(new_pos.x, 48, 432)
	new_pos.y = clampf(new_pos.y, 48, 384)
	
	position = new_pos
	if bed_solid:
		bed_solid.position = new_pos
	
	if new_pos.y <= 55 and not push_reached_window:
		_trigger_window_ending()

func _trigger_window_ending():
	push_reached_window = true
	can_interact = false
	push_enabled = false
	is_pushing = false
	
	var p = _get_player()
	if p:
		p.set_can_move(false)
	
	var dm = _get_dm()
	if dm:
		dm.hide_interact_prompt()
	
	# Chase minigame victory — bed pushed to window
	var rc = _get_rc()
	if rc and rc.current_state == rc.GameState.MINIGAME_CHASE:
		chase_victory.emit()
		return
	
	# Secret ending (idle state)
	if dm:
		var ending = [
			{"speaker": "Cama", "text": "¿Qué haces? ¡Deja de empujarme! ¡Estoy en mi lugar!"},
			{"speaker": "Cama", "text": "No... no no no, ¿hacia dónde me llevas? ¡LA VENTANA!"},
			{"speaker": "Cama", "text": "¡NOOOO! ¡Estoy cayendo! ¡Aaaaaah!"},
			{"speaker": "Sistema", "text": "..."},
			{"speaker": "Sistema", "text": "La cama cae por la ventana y desaparece en la oscuridad."},
			{"speaker": "Jugador", "text": "...creo que desperté."},
			{"speaker": "Sistema", "text": "FINAL SECRETO: DESPERTAR"},
			{"speaker": "Sistema", "text": "A veces, para dejar de overthinkear, solo tienes que sacar el problema por la ventana."}
		]
		dm.start_dialogue(ending)
		dm.dialogue_finished.connect(_on_ending_finished, CONNECT_ONE_SHOT)

func _on_ending_finished():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	GameManager.reset_game()

func _try_sleep():
	can_interact = false
	push_enabled = false
	var dm = _get_dm()
	if dm:
		dm.hide_interact_prompt()
	var rc = _get_rc()
	if rc:
		rc.start_bed_dialogue()

func _get_dm():
	return get_tree().get_first_node_in_group("dialogue_manager")

func _get_rc():
	return get_tree().get_first_node_in_group("room_controller")

func _get_player():
	return get_tree().get_first_node_in_group("player")
