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
	if dialogue_manager:
		var intro = [
			{"speaker": "Jugador", "text": "Creo que ya jugué mucho... debo dormir aunque no quiera."},
			{"speaker": "Jugador", "text": "Esa cama ahí se ve rara, pero no tengo otra opción."},
			{"speaker": "Sistema", "text": "Acércate a la cama y presiona [E] para interactuar."}
		]
		dialogue_manager.start_dialogue(intro)
		dialogue_manager.dialogue_finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)

func _on_intro_finished():
	if player:
		player.set_can_move(true)

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
			"text": "Mira, ya es tarde. Mañana tienes ese evento que tanto te preocupa.",
			"choices": [
				{"text": "Si, estoy nervioso pero dormiré bien", "value": 2, "response": "Dormir bien? Con esa cara de preocupación? Ja."},
				{"text": "Supongo que tengo que descansar", "value": 1, "response": "Tienes que? Que obligado suenas. Patético."},
				{"text": "No puedo parar de pensar en ello", "value": 0, "response": "Obvio. Eres un desastre. Mirate."}
			],
			"positive_value": 2,
			"negative_value": 0
		},
		{
			"speaker": "Cama",
			"text": "Sabes qué es lo peor? Que mañana vas a llegar ahí y todos van a notar que no dormiste.",
			"choices": [
				{"text": "No importa lo que piensen, haré lo mejor que pueda", "value": 2, "response": "Lo mejor que puedas... no es mucho, ¿no?"},
				{"text": "Tienes razón, voy a parecer un desastre", "value": 0, "response": "Al menos sabes la verdad. Qué vas a hacer al respecto?"},
				{"text": "Prefiero no pensar en eso ahora", "value": 1, "response": "Claro, es más fácil ignorar las cosas. Como siempre."}
			],
			"positive_value": 2,
			"negative_value": 0
		},
		{
			"speaker": "Cama",
			"text": "¿Y si mañana todo sale mal? ¿Qué vas a hacer entonces?",
			"choices": [
				{"text": "Si sale mal, aprenderé para la próxima vez", "value": 2, "response": "Aprender? Eso suena a quien no se rinde fácilmente..."},
				{"text": "No lo sé, pero no puedo controlar todo", "value": 1, "response": "Al menos admites que no controlas nada. Eso es algo."},
				{"text": "Sería el fin del mundo para mí", "value": 0, "response": "El fin del mundo? Exagerado. Pero eso eres tú, ¿no? Un exagerado."}
			],
			"positive_value": 2,
			"negative_value": 0
		},
		{
			"speaker": "Cama",
			"text": "Última pregunta antes de la difícil. ¿Crees que mereces un descanso después de todo lo que has pasado esta semana?",
			"choices": [
				{"text": "Sí, he trabajado duro y lo merezco", "value": 2, "response": "Trabajado duro? Hmm... tal vez tengas razón."},
				{"text": "No lo sé, siento que podría haber hecho más", "value": 1, "response": "Siempre piensas que podrías hacer más. Eso te destruye."},
				{"text": "No, siempre puedo esforzarme más", "value": 0, "response": "Siempre más, más, más. Nunca es suficiente para ti, ¿verdad?"}
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
			{"speaker": "Cama", "text": "Sabes cuál es la diferencia entre rendirse y descansar? A veces, lo que sientes como derrota, solo es tu cuerpo pidiendo que intentes de otra forma."},
			{"speaker": "Cama", "text": "No necesitas ser perfecto. Solo necesitas intentarlo. Es así de simple y así de difícil."},
			{"speaker": "Cama", "text": "¿Entiendes que intentar ya es ganar?", "choices": [
				{"text": "Sí, intentar ya es suficiente", "value": 3, "response": "Entonces... puedes dormir. Buenas noches, valiente."},
				{"text": "Pero y si fallo otra vez...", "value": 1, "response": "Y si fallas? Pues lo intentas otra vez. No hay secreto. Solo hazlo."},
				{"text": "No entiendo por qué debería intentar", "value": 0, "response": "No entiendes? Mira la pared... ya no hay donde ir."}
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
				{"speaker": "Cama", "text": "Sabes qué? Eres demasiado correcto. Me aburres."},
				{"speaker": "Cama", "text": "Nadie es tan perfecto. O mientes o no tienes personalidad."},
				{"speaker": "Cama", "text": "Vamos a jugar algo más divertido. Si ganas, tal vez te deje dormir."},
				{"speaker": "Cama", "text": "Come las manzanas sin chocar. ¡Y no me decepciones!"}
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
				{"speaker": "Cama", "text": "¿No querías jugar? Bueno... ahí tienes."},
				{"speaker": "Cama", "text": "Si no puedes responder bien, al menos demuestras que sirves para algo. Come las manzanas sin chocar."},
				{"speaker": "Cama", "text": "Si fallas esto también... qué patético eres."}
			]
			dialogue_manager.start_dialogue(taunt)
			dialogue_manager.dialogue_finished.connect(_on_taunt_finished, CONNECT_ONE_SHOT)
	else:
		_show_question()

func _on_taunt_finished():
	if snake_minigame:
		snake_minigame.start_snake_game()

func _on_snake_completed(success: bool):
	if player:
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
				{"speaker": "Cama", "text": "¿Ganaste? Bien. Al menos sirves para algo."},
				{"speaker": "Cama", "text": "Ahora vuelve a intentar dormir. Y esta vez, responde mejor."}
			])
			dialogue_manager.dialogue_finished.connect(_on_snake_result.bind(true), CONNECT_ONE_SHOT)
	else:
		if dialogue_manager:
			dialogue_manager.start_dialogue([
				{"speaker": "Cama", "text": "¡JAJAJA! ¡Ni siquiera puedes ganar un jueguito!"},
				{"speaker": "Cama", "text": "Mira como se cierra la habitación..."}
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
			{"speaker": "Sistema", "text": "Moraleja: Intentar ya es ganar. No importa cuantas veces falles, lo importante es que sigas intentando."}
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
			{"speaker": "Cama", "text": "¡JAJAJA! No pudiste ni responder una pregunta correctamente."},
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
