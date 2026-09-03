extends Area2D

var is_player_near: bool = false
var can_interact: bool = true
var interact_range: float = 90.0
var is_pushing: bool = false
var e_held: bool = false
var bed_solid: StaticBody2D = null
var window_position: Vector2 = Vector2(240, 16)
var push_reached_window: bool = false
var cooldown: float = 0.0
var _dialogue_just_ended: bool = false

func _ready():
	add_to_group("bed")
	bed_solid = get_parent().get_node_or_null("BedSolid")

func _process(delta):
	if cooldown > 0:
		cooldown -= delta
		return
	
	if _dialogue_just_ended:
		return
	
	if push_reached_window:
		return
	
	if is_pushing:
		_process_push(delta)
		return
	
	if not can_interact:
		return
	var p = _get_player()
	if not p:
		return
	var dist = global_position.distance_to(p.global_position)
	var was_near = is_player_near
	is_player_near = dist < interact_range
	if is_player_near and not was_near:
		var dm = _get_dm()
		if dm:
			dm.show_interact_prompt()
	elif not is_player_near and was_near:
		var dm = _get_dm()
		if dm:
			dm.hide_interact_prompt()
	
	if e_held and is_player_near and can_interact and not is_pushing:
		if p.is_moving:
			is_pushing = true
			var dm = _get_dm()
			if dm:
				dm.hide_interact_prompt()

func _get_dm():
	return get_tree().get_first_node_in_group("dialogue_manager")

func _get_rc():
	return get_tree().get_first_node_in_group("room_controller")

func _get_player():
	return get_tree().get_first_node_in_group("player")

func _input(event):
	if cooldown > 0:
		return
	if _dialogue_just_ended:
		if event.is_action_pressed("interact"):
			_dialogue_just_ended = false
		return
	if not is_player_near:
		return
	if not can_interact:
		return
	if event.is_action_pressed("interact"):
		e_held = true
	elif event.is_action_released("interact"):
		e_held = false
		if is_pushing:
			is_pushing = false
		elif can_interact and is_player_near:
			_try_sleep()

func _process_push(_delta):
	var p = _get_player()
	if not p or not p.is_moving:
		return
	
	var move_dir = Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		move_dir.y -= 1
	if Input.is_action_pressed("move_down"):
		move_dir.y += 1
	if Input.is_action_pressed("move_left"):
		move_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		move_dir.x += 1
	
	if move_dir == Vector2.ZERO:
		return
	
	move_dir = move_dir.normalized()
	var new_pos = position + move_dir * 40.0 * _delta
	
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
	e_held = false
	is_pushing = false
	
	var p = _get_player()
	if p:
		p.set_can_move(false)
	
	var dm = _get_dm()
	if dm:
		dm.hide_interact_prompt()
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
	var dm = _get_dm()
	if dm:
		dm.hide_interact_prompt()
	
	var p = _get_player()
	if p:
		p.set_can_move(false)
	
	if dm:
		var opening = [
			{"speaker": "Cama", "text": "¿Quieres dormir? Ja ja ja... no tan rápido."},
			{"speaker": "Cama", "text": "No puedes simplemente acostarte. Primero tienes que responder algunas preguntas."},
			{"speaker": "Cama", "text": "Si respondes bien, podrás dormir. Si no... bueno, ya veremos."},
			{"speaker": "Cama", "text": "¿Estás listo? Empecemos."}
		]
		dm.start_dialogue(opening)
		dm.dialogue_finished.connect(_on_opening_finished, CONNECT_ONE_SHOT)

func _on_opening_finished():
	cooldown = 2.0
	_dialogue_just_ended = true
	var p = _get_player()
	if p:
		p.set_can_move(true)
	var rc = _get_rc()
	if rc:
		rc.start_questions()
	await get_tree().create_timer(2.0).timeout
	_dialogue_just_ended = false
