extends Node2D

signal question_answered(correct: bool)
signal game_over_triggered
signal victory_triggered

var questions: Array = []
var current_question_index: int = 0
var dialogue_manager: Node = null
var camera: Camera2D = null
var player: Node2D = null
var snake_minigame: Node = null

@onready var wall_top: StaticBody2D = $Walls/WallTop
@onready var wall_bottom: StaticBody2D = $Walls/WallBottom
@onready var wall_left: StaticBody2D = $Walls/WallLeft
@onready var wall_right: StaticBody2D = $Walls/WallRight

var original_positions: Dictionary = {}
var current_shrink: int = 0
var max_shrink: int = 5
var shrink_amount: float = 32.0
var base_pitch: float = 1.0
var pending_minigame: bool = false
var consecutive_positive: int = 0
var forced_snake_pending: bool = false
var audio_manager: Node = null

func _ready():
	add_to_group("room_controller")
	dialogue_manager = get_tree().get_first_node_in_group("dialogue_manager")
	camera = $Camera2D
	player = get_tree().get_first_node_in_group("player")
	
	if has_node("SnakeMinigame"):
		snake_minigame = $SnakeMinigame
		snake_minigame.snake_game_completed.connect(_on_snake_completed)
	
	audio_manager = get_node_or_null("AudioManager")
	if audio_manager:
		audio_manager.setup($BackgroundMusic, $HUD/MuteButton, dialogue_manager)
	
	_save_original_positions()
	_init_questions()
	_play_intro_dialogue()

func _play_intro_dialogue():
	if player:
		player.set_can_move(false)
		if player.has_method("set_override_texture"):
			var atlas = AtlasTexture.new()
			atlas.atlas = load("res://assets/sprites/player.png")
			atlas.region = Rect2(80, 32, 16, 16)
			player.set_override_texture(atlas)
	if dialogue_manager:
		var intro = [
			{"speaker": "Jugador", "text": "Creo que ya jugué mucho... debería dormir aunque no quiera."},
			{"speaker": "Jugador", "text": "Esa cama se ve rara, pero no tengo otra opción."},
			{"speaker": "Sistema", "text": "Acércate a la cama y presiona [E] para interactuar."}
		]
		dialogue_manager.start_dialogue(intro)
		dialogue_manager.dialogue_finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)

func _on_intro_finished():
	if player:
		if player.has_method("clear_override"):
			player.clear_override()
		player.set_can_move(true)
	var bed = get_tree().get_first_node_in_group("bed")
	if bed:
		bed.cooldown = 0.5

func _input(event):
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
		GameManager.reset_game()

func _save_original_positions():
	original_positions = {
		"top": wall_top.position,
		"bottom": wall_bottom.position,
		"left": wall_left.position,
		"right": wall_right.position
	}

func _init_questions():
	questions = [
		{
			"speaker": "Cama",
			"text": "Mañana tienes ese evento. ¿Ya estás pensando en todas las cosas que pueden salir mal?",
			"choices": [
				{"text": "Sí, pero voy a intentar dormir de todos modos", "value": 2, "response": "Intentar dormir... ¿con esa cara de preocupación? Va, al menos lo intentas."},
				{"text": "No puedo evitar pensarlo", "value": 1, "response": "Claro, es más fácil quedarse dormido en el worry-train. Todo el mundo lo hace."},
				{"text": "Prefiero no pensar en eso ahora", "value": 0, "response": "¿Ah sí? Pues justito eso es lo que vas a hacer toda la noche. Pensar."}
			],
			"positive_value": 2,
			"negative_value": 0
		},
		{
			"speaker": "Cama",
			"text": "¿Y si mañana llegas y todos notan que no dormiste? ¿Qué cara vas a poner?",
			"choices": [
				{"text": "La que me salga, pero haré lo mejor que pueda", "value": 2, "response": "Lo mejor que puedas... no es mucho, ¿eh? Pero bueno, algo es algo."},
				{"text": "Tienes razón, voy a parecer un desastre", "value": 0, "response": "Al menos eres honesto. Eso no te salva, pero es algo."},
				{"text": "No me importa lo que piensen los demás", "value": 1, "response": "Ah, el clásico 'no me importa'. Spoiler: sí te importa. Mucho."}
			],
			"positive_value": 2,
			"negative_value": 0
		},
		{
			"speaker": "Cama",
			"text": "Dime una cosa: ¿cuántas veces has tenido un mal-presentimiento y al final todo salió bien?",
			"choices": [
				{"text": "Bastantes, supongo que debería recordar eso", "value": 2, "response": "¿Ves? Tu cerebro te miente. Pero tú le haces caso como si fuera un oráculo."},
				{"text": "No lo sé, nunca presto atención a eso", "value": 1, "response": "Claro, ignorar los datos es una estrategia válida... para los toros."},
				{"text": "Nunca, siempre sale mal", "value": 0, "response": "Siempre sale mal? Eso se llama selective thinking, caminante. Y es un veneno."}
			],
			"positive_value": 2,
			"negative_value": 0
		},
		{
			"speaker": "Cama",
			"text": "Última antes de lo difícil. ¿Crees que mereces descansar, o sientes que siempre puedes dar más?",
			"choices": [
				{"text": "He trabajado duro, merezco un descanso", "value": 2, "response": "Mereces un descanso... Hmm. Tal vez tengas razón. Tal vez."},
				{"text": "Siento que podría haber hecho más", "value": 1, "response": "Siempre 'más, más, más'. Eso no te hace/productivo, te hace agotado."},
				{"text": "Nunca es suficiente, siempre puedo mejorar", "value": 0, "response": "¿Mejorar? O ¿autodestruirte disfrazado de.superación? Piénsalo."}
			],
			"positive_value": 2,
			"negative_value": 0
		}
	]

func start_questions():
	current_question_index = 0
	consecutive_positive = 0
	_show_question()

func _show_question():
	if current_question_index >= questions.size():
		_show_final_question()
		return
	_show_regular_question(questions[current_question_index])

func _show_regular_question(q: Dictionary):
	if dialogue_manager:
		var dialogue = [
			{"speaker": q["speaker"], "text": q["text"]},
			{"speaker": "Cama", "text": "Piénsalo bien...", "choices": q["choices"]}
		]
		dialogue_manager.start_dialogue(dialogue)
		dialogue_manager.choice_selected.connect(_on_answer_selected.bind(q), CONNECT_ONE_SHOT)

func _show_final_question():
	if dialogue_manager:
		var dialogue = [
			{"speaker": "Cama", "text": "Ahora viene lo difícil..."},
			{"speaker": "Cama", "text": "¿Sabes cuál es la diferencia entre rendirse y descansar? A veces, lo que sientes como derrota, solo es tu cuerpo pidiendo que intentes de otra forma."},
			{"speaker": "Cama", "text": "No necesitas ser perfecto. Solo necesitas intentarlo. Es así de simple y así de difícil."},
			{"speaker": "Cama", "text": "¿Entiendes que intentar ya es ganar?", "choices": [
				{"text": "Sí, intentar ya es suficiente", "value": 3, "response": "Entonces... puedes dormir. Buenas noches, valiente."},
				{"text": "Pero y si fallo otra vez...", "value": 1, "response": "¿Y si fallas? Pues lo intentas otra vez. No hay secreto. Solo hazlo."},
				{"text": "No entiendo por qué debería intentar", "value": 0, "response": "¿No entiendes? Mira la pared... ya no hay donde ir."}
			]}
		]
		dialogue_manager.start_dialogue(dialogue)
		dialogue_manager.choice_selected.connect(_on_final_answer_selected, CONNECT_ONE_SHOT)

func _on_answer_selected(value: int, q: Dictionary):
	var correct = value >= q["positive_value"]
	
	if correct:
		consecutive_positive += 1
		GameManager.add_positive_answer()
	else:
		consecutive_positive = 0
		GameManager.add_negative_answer()
		_shrink_room()
		pending_minigame = true
	
	if consecutive_positive >= 2 and not forced_snake_pending:
		forced_snake_pending = true
		pending_minigame = true
	
	question_answered.emit(correct)
	current_question_index += 1
	
	if dialogue_manager:
		dialogue_manager.dialogue_finished.connect(_on_dialogue_closed, CONNECT_ONE_SHOT)

func _on_final_answer_selected(value: int):
	if value >= 3:
		GameManager.trigger_victory()
		victory_triggered.emit()
		_show_victory()
	elif value > 0:
		GameManager.add_negative_answer()
		_shrink_room()
		_show_hint()
	else:
		GameManager.trigger_game_over()
		game_over_triggered.emit()
		_show_game_over()

func _on_dialogue_closed():
	if pending_minigame:
		pending_minigame = false
		if forced_snake_pending:
			forced_snake_pending = false
			_start_forced_minigame()
		else:
			_start_punishment_minigame()
	else:
		_show_question()

func _start_forced_minigame():
	if snake_minigame:
		if audio_manager and audio_manager.has_method("start_punishment_volume"):
			audio_manager.start_punishment_volume()
		if player:
			player.set_can_move(false)
		if dialogue_manager:
			var taunt = [
				{"speaker": "Cama", "text": "¿Sabes qué? Eres demasiado perfecto. Me aburres."},
				{"speaker": "Cama", "text": "Nadie es tan correcto. O mientes o no tienes personalidad."},
				{"speaker": "Cama", "text": "Juguemos algo más interesante. Come las manzanas sin chocar."},
				{"speaker": "Cama", "text": "Si ganas, tal vez te deje dormir. Si no... bueno, ya veremos."}
			]
			dialogue_manager.start_dialogue(taunt)
			dialogue_manager.dialogue_finished.connect(_on_taunt_finished, CONNECT_ONE_SHOT)
	else:
		_show_question()

func _start_punishment_minigame():
	if snake_minigame:
		if audio_manager and audio_manager.has_method("start_punishment_volume"):
			audio_manager.start_punishment_volume()
		if player:
			player.set_can_move(false)
		if dialogue_manager:
			var taunt = [
				{"speaker": "Cama", "text": "¿No querías jugar? Bueno, aquí tienes tu castigo."},
				{"speaker": "Cama", "text": "Come las manzanas sin chocar. Y si no puedes... qué patético."},
				{"speaker": "Cama", "text": "Tranquilo, si fallas esta vez la habitación se hace más pequeña. Nada personal."}
			]
			dialogue_manager.start_dialogue(taunt)
			dialogue_manager.dialogue_finished.connect(_on_taunt_finished, CONNECT_ONE_SHOT)
	else:
		_show_question()

func _on_taunt_finished():
	if snake_minigame:
		if player and player.has_method("set_override_texture"):
			var atlas = AtlasTexture.new()
			atlas.atlas = load("res://assets/sprites/player.png")
			atlas.region = Rect2(96, 32, 16, 16)
			player.set_override_texture(atlas)
		snake_minigame.start_snake_game()

func _on_snake_completed(success: bool):
	GameManager.snake_attempts += 1
	if player:
		if player.has_method("clear_override"):
			player.clear_override()
		player.set_can_move(true)
	GameManager.first_snake_completed = true
	var window_node = get_node_or_null("Window")
	if window_node and window_node.has_method("show_eyes"):
		window_node.show_eyes()
	if audio_manager and audio_manager.has_method("stop_punishment_volume"):
		audio_manager.stop_punishment_volume()
	if success:
		if dialogue_manager:
			dialogue_manager.start_dialogue([
				{"speaker": "Cama", "text": "¿Ganaste? Vale. Al menos sirves para algo."},
				{"speaker": "Cama", "text": "Ahora vuelve a intentar dormir. Y esta vez, piensa antes de responder."}
			])
			dialogue_manager.dialogue_finished.connect(_on_snake_result.bind(true), CONNECT_ONE_SHOT)
	else:
		if dialogue_manager:
			dialogue_manager.start_dialogue([
				{"speaker": "Cama", "text": "¡Jajaja! Ni siquiera puedes ganar un jueguito."},
				{"speaker": "Cama", "text": "Mira como se cierra la habitación... cada vez más pequeño, ¿no?"}
			])
			dialogue_manager.dialogue_finished.connect(_on_snake_result.bind(false), CONNECT_ONE_SHOT)

func _on_snake_result(success: bool):
	if not success:
		_shrink_room()
	_show_question()

func _show_victory():
	if dialogue_manager:
		dialogue_manager.start_dialogue([
			{"speaker": "Cama", "text": "Bueno... ganaste. Te mereces dormir."},
			{"speaker": "Cama", "text": "Recuerda: no necesitas ser perfecto. Solo necesitas intentarlo."},
			{"speaker": "Sistema", "text": "FELICIDADES! Has completado el juego."},
			{"speaker": "Sistema", "text": "Moraleja: Intentar ya es ganar. No importa cuántas veces falles, lo importante es que sigas intentando."}
		])

func _show_hint():
	if dialogue_manager:
		dialogue_manager.start_dialogue([
			{"speaker": "Cama", "text": "Oye... esta es tu última oportunidad."},
			{"speaker": "Cama", "text": "Piénsalo bien. No necesitas ser perfecto. Solo necesitas intentarlo."},
			{"speaker": "Cama", "text": "Una vez más... ¿Entiendes que intentar ya es ganar?"}
		])
		dialogue_manager.dialogue_finished.connect(_on_hint_finished, CONNECT_ONE_SHOT)

func _on_hint_finished():
	_show_final_question()

func _show_game_over():
	if dialogue_manager:
		dialogue_manager.start_dialogue([
			{"speaker": "Cama", "text": "¡Jajaja! No pudiste ni responder una pregunta correctamente."},
			{"speaker": "Cama", "text": "La habitación se cierra... y tú te quedas ahí, perdido en tus pensamientos."},
			{"speaker": "Sistema", "text": "GAME OVER - Presiona R para reiniciar."},
			{"speaker": "Sistema", "text": "A veces hay que intentar muchas veces antes de lograrlo."}
		])

func _shrink_room():
	current_shrink = mini(current_shrink + 1, max_shrink)
	var offset = shrink_amount * current_shrink
	wall_top.position.y = original_positions["top"].y + offset
	wall_bottom.position.y = original_positions["bottom"].y - offset
	wall_left.position.x = original_positions["left"].x + offset
	wall_right.position.x = original_positions["right"].x - offset
	if camera:
		var zoom_val = 1.0 + (current_shrink * 0.08)
		camera.zoom = Vector2(zoom_val, zoom_val)
