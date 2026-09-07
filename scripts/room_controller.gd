extends Node2D

signal question_answered(correct: bool)
signal game_over_triggered
signal victory_triggered

enum GameState {
	INTRO,
	IDLE,
	BED_DIALOGUE,
	QUESTIONING,
	MINIGAME_SNAKE,
	MINIGAME_CHAIR,
	MINIGAME_CHASE,
	VICTORY,
	GAME_OVER
}

var current_state: GameState = GameState.INTRO
var questions: Array = []
var current_question_index: int = 0
var dialogue_manager: Node = null
var camera: Camera2D = null
var player: Node2D = null
var snake_minigame: Node = null
var hot_chair_minigame: Node = null
var chase_minigame: Node = null

@onready var wall_top: StaticBody2D = $Walls/WallTop
@onready var wall_bottom: StaticBody2D = $Walls/WallBottom
@onready var wall_left: StaticBody2D = $Walls/WallLeft
@onready var wall_right: StaticBody2D = $Walls/WallRight

var original_positions: Dictionary = {}
var current_shrink: int = 0
var max_shrink: int = 5
var shrink_amount: float = 32.0
var pending_minigame: bool = false
var consecutive_positive: int = 0
var forced_snake_pending: bool = false
var audio_manager: Node = null
var minigame_after_dialogue: String = ""

var games_won: int = 0
var min_games_required: int = 2
var apple_item: Node2D = null
var apple_spawned: bool = false

func _ready():
	add_to_group("room_controller")
	dialogue_manager = get_tree().get_first_node_in_group("dialogue_manager")
	camera = $Camera2D
	player = get_tree().get_first_node_in_group("player")
	
	if has_node("SnakeMinigame"):
		snake_minigame = $SnakeMinigame
		snake_minigame.snake_game_completed.connect(_on_snake_completed)
	
	if has_node("HotChairMinigame"):
		hot_chair_minigame = $HotChairMinigame
		hot_chair_minigame.chair_game_completed.connect(_on_chair_completed)
	
	if has_node("ChaseMinigame"):
		chase_minigame = $ChaseMinigame
		chase_minigame.chase_completed.connect(_on_chase_completed)
		# Connect bed's chase victory signal
		var bed = get_tree().get_first_node_in_group("bed")
		if bed and bed.has_signal("chase_victory"):
			bed.chase_victory.connect(_on_bed_chase_victory)
	
	audio_manager = get_node_or_null("AudioManager")
	if audio_manager:
		audio_manager.setup($BackgroundMusic, $HUD/MuteButton, dialogue_manager)
	
	GameManager.hearts_changed.connect(_on_hearts_changed)
	_update_hearts_display()
	_save_original_positions()
	_init_questions()
	_change_state(GameState.INTRO)

func _change_state(new_state: GameState):
	var old_state = current_state
	current_state = new_state
	
	match new_state:
		GameState.INTRO:
			_play_intro_dialogue()
		GameState.IDLE:
			if player:
				if player.has_method("clear_override"):
					player.clear_override()
				player.set_can_move(true)
			var bed = get_tree().get_first_node_in_group("bed")
			if bed:
				bed.can_interact = true
				bed.push_enabled = true
		GameState.BED_DIALOGUE:
			pass
		GameState.QUESTIONING:
			if current_question_index == 0:
				current_question_index = 0
				consecutive_positive = 0
			_show_question()
		GameState.MINIGAME_SNAKE:
			_start_snake_sequence()
		GameState.MINIGAME_CHAIR:
			_start_chair_sequence()
		GameState.MINIGAME_CHASE:
			_start_chase_sequence()
		GameState.VICTORY:
			_show_victory()
		GameState.GAME_OVER:
			_show_game_over()

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
	_change_state(GameState.IDLE)

func _save_original_positions():
	original_positions = {
		"top": wall_top.position,
		"bottom": wall_bottom.position,
		"left": wall_left.position,
		"right": wall_right.position
	}

func start_bed_dialogue():
	if current_state != GameState.IDLE:
		return
	_change_state(GameState.BED_DIALOGUE)
	if player:
		player.set_can_move(false)
	var bed = get_tree().get_first_node_in_group("bed")
	if bed:
		bed.can_interact = false
		bed.push_enabled = false
	if dialogue_manager:
		var opening = [
			{"speaker": "Cama", "text": "¿Quieres dormir? Ja ja ja... no tan rápido."},
			{"speaker": "Cama", "text": "No puedes simplemente acostarte. Primero tienes que responder algunas preguntas."},
			{"speaker": "Cama", "text": "Si respondes bien, podrás dormir. Si no... bueno, ya veremos."},
			{"speaker": "Cama", "text": "¿Estás listo? Empecemos."}
		]
		dialogue_manager.start_dialogue(opening)
		dialogue_manager.dialogue_finished.connect(_on_bed_dialogue_finished, CONNECT_ONE_SHOT)

func _on_bed_dialogue_finished():
	_change_state(GameState.QUESTIONING)

func _init_questions():
	questions = [
		{
			"speaker": "Cama",
			"text": "Cuéntame algo: ¿cuántas veces te has dormido pensando en algo que al día siguiente no importaba?",
			"is_random": false,
			"choices": [
				{"text": "Muchas, supongo", "value": 1, "response": "¿Ves? Tu cerebro te tortura por nada."},
				{"text": "No lo sé, nunca presto atención", "value": 0, "response": "Ignorar los datos no los hace desaparecer."},
				{"text": "Siempre me importa todo", "value": 2, "response": "Todo no puede importar. Eso se llama ansiedad, no dedicación."}
			],
			"positive_value": 1,
			"negative_value": 0
		},
		{
			"speaker": "Cama",
			"text": "¿Cuántos lados tiene un triángulo?",
			"is_random": true,
			"choices": [
				{"text": "3", "value": 1, "response": "Correcto. Pero eso no te hace listo."},
				{"text": "4", "value": 0, "response": "Incorrecto. ¿En serio?"},
				{"text": "No lo sé", "value": 0, "response": "Patético. Es trigonometría básica."}
			],
			"positive_value": 1,
			"negative_value": 0
		},
		{
			"speaker": "Cama",
			"text": "Si tuvieras que elegir entre no dormir nunca o no comer nunca, ¿qué elegirías?",
			"is_random": false,
			"choices": [
				{"text": "No dormir, al menos aprovecho el tiempo", "value": 0, "response": "¿En serio? Sin dormir enloqueces en 3 días."},
				{"text": "No comer, puedo aguantar más", "value": 1, "response": "Hmm, médicamente cuestionable, pero al menos piensas."},
				{"text": "No lo sé, ambas suenan terribles", "value": 2, "response": "Al menos eres honesto con tu ignorancia."}
			],
			"positive_value": 1,
			"negative_value": 0
		},
		{
			"speaker": "Cama",
			"text": "¿Cuánto es 7 × 8?",
			"is_random": true,
			"choices": [
				{"text": "56", "value": 1, "response": "Aunque sea sabes multiplicar."},
				{"text": "54", "value": 0, "response": "Casi. Casi no cuenta."},
				{"text": "No sé multiplicar", "value": 0, "response": "Qué nivel de confianza para alguien que no sabe multiplicar."}
			],
			"positive_value": 1,
			"negative_value": 0
		},
		{
			"speaker": "Cama",
			"text": "Dime una cosa: ¿cuántas veces has tenido un mal-presentimiento y al final todo salió bien?",
			"is_random": false,
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
			"text": "¿Cuál es la capital de Francia?",
			"is_random": true,
			"choices": [
				{"text": "París", "value": 1, "response": "Bien, al menos eso sabes."},
				{"text": "Lyon", "value": 0, "response": "Lyon es bonita, pero no es la capital."},
				{"text": "No tengo idea", "value": 0, "response": "Viaja un poco, seriously."}
			],
			"positive_value": 1,
			"negative_value": 0
		},
		{
			"speaker": "Cama",
			"text": "¿Crees que mereces descansar, o sientes que siempre puedes dar más?",
			"is_random": false,
			"choices": [
				{"text": "He trabajado duro, merezco un descanso", "value": 2, "response": "Mereces un descanso... Hmm. Tal vez tengas razón. Tal vez."},
				{"text": "Siento que podría haber hecho más", "value": 1, "response": "Siempre 'más, más, más'. Eso no te hace productivo, te hace agotado."},
				{"text": "Nunca es suficiente, siempre puedo mejorar", "value": 0, "response": "¿Mejorar? O ¿autodestruirte disfrazado de superación? Piénsalo."}
			],
			"positive_value": 2,
			"negative_value": 0
		},
		{
			"speaker": "Cama",
			"text": "¿Cuántos continentes hay en la Tierra?",
			"is_random": true,
			"choices": [
				{"text": "7", "value": 1, "response": "Impresionante, sabes geografía básica."},
				{"text": "5", "value": 0, "response": "Cinco... ¿te olvidaste de dos?"},
				{"text": "No sé, no me importa", "value": 0, "response": "La ignorancia no es virtue, friend."}
			],
			"positive_value": 1,
			"negative_value": 0
		}
	]

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
		if not q.get("is_random", false):
			# Real question answered correctly
			if games_won < min_games_required:
				# Not enough games won yet — force minigame with mocking
				pending_minigame = true
				consecutive_positive = 0
				question_answered.emit(false)
				current_question_index += 1
				if dialogue_manager:
					dialogue_manager.dialogue_finished.connect(_on_mocking_dialogue_closed, CONNECT_ONE_SHOT)
				return
			else:
				consecutive_positive += 1
				GameManager.add_positive_answer()
				# Chance to spawn apple after correct random question
				if q.get("is_random", false) and not apple_spawned:
					_spawn_apple()
		else:
			# Random question — always counts, chance for apple
			consecutive_positive += 1
			GameManager.add_positive_answer()
			if not apple_spawned and randf() < 0.4:
				_spawn_apple()
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
		dialogue_manager.dialogue_finished.connect(_on_question_dialogue_closed, CONNECT_ONE_SHOT)

func _on_mocking_dialogue_closed():
	if dialogue_manager:
		dialogue_manager.start_dialogue([
			{"speaker": "Cama", "text": "¿Ah sí? No pareces muy convencido."},
			{"speaker": "Cama", "text": "Demuéstralo jugando. Si ganas, tal vez te crea."},
			{"speaker": "Cama", "text": "Si no... bueno, ya sabes qué pasa."}
		])
		dialogue_manager.dialogue_finished.connect(_on_question_dialogue_closed, CONNECT_ONE_SHOT)

func _on_final_answer_selected(value: int):
	if value >= 3:
		GameManager.trigger_victory()
		victory_triggered.emit()
		_change_state(GameState.VICTORY)
	elif value > 0:
		GameManager.add_negative_answer()
		_shrink_room()
		_show_hint()
	else:
		GameManager.trigger_game_over()
		game_over_triggered.emit()
		_change_state(GameState.GAME_OVER)

func _on_question_dialogue_closed():
	if pending_minigame:
		pending_minigame = false
		if forced_snake_pending:
			forced_snake_pending = false
			minigame_after_dialogue = "snake_forced"
		else:
			minigame_after_dialogue = "snake_punishment"
		
		var which = (current_question_index - 1) % 3
		if which == 1 and current_state != GameState.MINIGAME_CHAIR:
			minigame_after_dialogue = "chair"
		
		if minigame_after_dialogue == "chair":
			_change_state(GameState.MINIGAME_CHAIR)
		else:
			_change_state(GameState.MINIGAME_SNAKE)
	else:
		_show_question()

func _start_snake_sequence():
	if not snake_minigame:
		_change_state(GameState.QUESTIONING)
		return
	if audio_manager and audio_manager.has_method("start_punishment_volume"):
		audio_manager.start_punishment_volume()
	if player:
		player.set_can_move(false)
	if dialogue_manager:
		var taunt_text = []
		if minigame_after_dialogue == "snake_forced":
			taunt_text = [
				{"speaker": "Cama", "text": "¿Sabes qué? Eres demasiado perfecto. Me aburres."},
				{"speaker": "Cama", "text": "Nadie es tan correcto. O mientes o no tienes personalidad."},
				{"speaker": "Cama", "text": "Juguemos algo más interesante. Come las manzanas sin chocar."},
				{"speaker": "Cama", "text": "Si ganas, tal vez te deje dormir. Si no... bueno, ya veremos."}
			]
		else:
			taunt_text = [
				{"speaker": "Cama", "text": "¿No querías jugar? Bueno, aquí tienes tu castigo."},
				{"speaker": "Cama", "text": "Come las manzanas sin chocar. Y si no puedes... qué patético."},
				{"speaker": "Cama", "text": "Tranquilo, si fallas esta vez la habitación se hace más pequeña. Nada personal."}
			]
		dialogue_manager.start_dialogue(taunt_text)
		dialogue_manager.dialogue_finished.connect(_on_snake_taunt_finished, CONNECT_ONE_SHOT)

func _on_snake_taunt_finished():
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
	if dialogue_manager:
		if dialogue_manager.dialogue_finished.is_connected(_on_snake_result):
			dialogue_manager.dialogue_finished.disconnect(_on_snake_result)
	if success:
		games_won += 1
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
	_change_state(GameState.QUESTIONING)

func _start_chair_sequence():
	if not hot_chair_minigame:
		_change_state(GameState.QUESTIONING)
		return
	if audio_manager and audio_manager.has_method("start_punishment_volume"):
		audio_manager.start_punishment_volume()
	if player:
		player.set_can_move(false)
	var window_node = get_node_or_null("Window")
	if window_node and window_node.has_method("set_stars_red"):
		window_node.set_stars_red()
	if dialogue_manager:
		dialogue_manager.start_dialogue([
			{"speaker": "Cama", "text": "¿Ves esa ventana? Algo se acerca..."},
			{"speaker": "Cama", "text": "Es un clon tuyo. Pero no es amigable."},
			{"speaker": "Cama", "text": "La cama se moverá a un lugar aleatorio. El primero en llegar se la queda."},
			{"speaker": "Cama", "text": "¿Listo? ¡Que gane el mejor!"}
		])
		dialogue_manager.dialogue_finished.connect(_on_chair_taunt_finished, CONNECT_ONE_SHOT)

func _on_chair_taunt_finished():
	if hot_chair_minigame:
		hot_chair_minigame.start_chair_game()

func _on_chair_completed(success: bool):
	if player:
		if player.has_method("clear_override"):
			player.clear_override()
		player.set_can_move(true)
	var window_node = get_node_or_null("Window")
	if window_node and window_node.has_method("set_stars_normal"):
		window_node.set_stars_normal()
	if audio_manager and audio_manager.has_method("stop_punishment_volume"):
		audio_manager.stop_punishment_volume()
	if dialogue_manager:
		if dialogue_manager.dialogue_finished.is_connected(_on_chair_result):
			dialogue_manager.dialogue_finished.disconnect(_on_chair_result)
	if success:
		games_won += 1
		if dialogue_manager:
			dialogue_manager.start_dialogue([
				{"speaker": "Cama", "text": "¿Ganaste al clon? No está mal..."},
				{"speaker": "Cama", "text": "Pero eso no significa que puedas dormir. Vuelve a las preguntas."}
			])
			dialogue_manager.dialogue_finished.connect(_on_chair_result.bind(true), CONNECT_ONE_SHOT)
	else:
		if dialogue_manager:
			dialogue_manager.start_dialogue([
				{"speaker": "Cama", "text": "¡El clon te ganó! Qué patético."},
				{"speaker": "Cama", "text": "La habitación se cierra un poco más..."}
			])
			dialogue_manager.dialogue_finished.connect(_on_chair_result.bind(false), CONNECT_ONE_SHOT)

func _on_chair_result(success: bool):
	if not success:
		_shrink_room()
	_change_state(GameState.QUESTIONING)

func _start_chase_sequence():
	if player:
		player.set_can_move(false)
	if dialogue_manager:
		dialogue_manager.start_dialogue([
			{"speaker": "Cama", "text": "Tu peor enemigo eres tú mismo."},
			{"speaker": "Cama", "text": "Mira... ahí viene. Es tú, pero no eres tú."},
			{"speaker": "Cama", "text": "Si te alcanza, todo termina."},
			{"speaker": "Cama", "text": "Pero si logras empujar la cama por la ventana... tal vez puedas escapar."},
			{"speaker": "Cama", "text": "¿Listo? ¡Corre!"}
		])
		dialogue_manager.dialogue_finished.connect(_on_chase_taunt_finished, CONNECT_ONE_SHOT)

func _on_chase_taunt_finished():
	if chase_minigame and chase_minigame.has_method("start_chase"):
		var bed = get_tree().get_first_node_in_group("bed")
		if bed:
			bed.push_enabled = true
			bed.can_interact = false
		chase_minigame.start_chase()
		if player:
			player.set_can_move(true)
	else:
		_change_state(GameState.QUESTIONING)

func _on_chase_completed(success: bool):
	if player:
		if player.has_method("clear_override"):
			player.clear_override()
		player.set_can_move(true)
	if audio_manager and audio_manager.has_method("stop_punishment_volume"):
		audio_manager.stop_punishment_volume()
	if success:
		_change_state(GameState.VICTORY)
	else:
		_change_state(GameState.GAME_OVER)

func _on_bed_chase_victory():
	if chase_minigame and chase_minigame.has_method("end_game"):
		chase_minigame.end_game(true)

func _show_victory():
	if player:
		player.set_can_move(false)
		if player.has_method("set_override_texture"):
			# Show lying down sprite
			var atlas = AtlasTexture.new()
			atlas.atlas = load("res://assets/sprites/player.png")
			atlas.region = Rect2(80, 0, 16, 32)
			player.set_override_texture(atlas)
	if dialogue_manager:
		dialogue_manager.start_dialogue([
			{"speaker": "Cama", "text": "Bueno... ganaste. Te mereces dormir."},
			{"speaker": "Cama", "text": "Recuerda: no necesitas ser perfecto. Solo necesitas intentarlo."},
			{"speaker": "Sistema", "text": "El jugador se acuesta en la cama y cierra los ojos..."},
			{"speaker": "Sistema", "text": "Todo había sido una pesadilla."},
			{"speaker": "Sistema", "text": "FELICIDADES! Has completado el juego."},
			{"speaker": "Sistema", "text": "Moraleja: Intentar ya es ganar. No importa cuántas veces falles, lo importante es que sigas intentando."}
		])
		dialogue_manager.dialogue_finished.connect(_on_victory_finished, CONNECT_ONE_SHOT)

func _on_victory_finished():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	GameManager.reset_game()

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
	if player:
		player.set_can_move(false)
	if dialogue_manager:
		dialogue_manager.start_dialogue([
			{"speaker": "Cama", "text": "¡Jajaja! No pudiste ni responder una pregunta correctamente."},
			{"speaker": "Cama", "text": "La habitación se cierra... y tú te quedas ahí, perdido en tus pensamientos."},
			{"speaker": "Sistema", "text": "GAME OVER"}
		])
		dialogue_manager.dialogue_finished.connect(_on_game_over_finished, CONNECT_ONE_SHOT)

func _on_game_over_finished():
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")

func _shrink_room():
	current_shrink = mini(current_shrink + 1, max_shrink)
	var offset = shrink_amount * current_shrink
	wall_top.position.y = original_positions["top"].y + offset
	wall_bottom.position.y = original_positions["bottom"].y - offset
	wall_left.position.x = original_positions["left"].x + offset
	wall_right.position.x = original_positions["right"].x - offset
	GameManager.lose_heart()

func get_bed_random_position() -> Vector2:
	var min_x = original_positions["left"].x + 48
	var max_x = original_positions["right"].x - 48
	var min_y = original_positions["top"].y + 48
	var max_y = original_positions["bottom"].y - 48
	return Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))

func _on_hearts_changed(new_hearts: int):
	_update_hearts_display()

func _update_hearts_display():
	var hearts_label = get_node_or_null("HUD/HeartsLabel")
	if hearts_label:
		var hearts_text = ""
		for i in range(GameManager.max_hearts):
			if i < GameManager.hearts:
				hearts_text += "♥ "
			else:
				hearts_text += "♡ "
		hearts_label.text = hearts_text.strip_edges()

func _spawn_apple():
	if apple_spawned:
		return
	apple_spawned = true
	var PackedApple = load("res://scenes/apple_item.tscn")
	if PackedApple:
		apple_item = PackedApple.instantiate()
		add_child(apple_item)
		var pos = get_bed_random_position()
		apple_item.position = pos
		if apple_item.has_signal("apple_collected"):
			apple_item.apple_collected.connect(_on_apple_collected)

func _on_apple_collected():
	apple_spawned = false
	apple_item = null
