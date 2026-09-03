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
	
	audio_manager = get_node_or_null("AudioManager")
	if audio_manager:
		audio_manager.setup($BackgroundMusic, $HUD/MuteButton, dialogue_manager)
	
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
				{"text": "Siento que podría haber hecho más", "value": 1, "response": "Siempre 'más, más, más'. Eso no te hace productivo, te hace agotado."},
				{"text": "Nunca es suficiente, siempre puedo mejorar", "value": 0, "response": "¿Mejorar? O ¿autodestruirte disfrazado de superación? Piénsalo."}
			],
			"positive_value": 2,
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
	if success:
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
			{"speaker": "Cama", "text": "¿Recuerdas la serpiente? Ahora viene lo realmente malo."},
			{"speaker": "Cama", "text": "La serpiente ya no quiere manzanas. Quiere TÍ."},
			{"speaker": "Cama", "text": "Espera... si logras empujar la cama por la ventana, tal vez puedas escapar."},
			{"speaker": "Cama", "text": "¡Corre!"}
		])
		dialogue_manager.dialogue_finished.connect(_on_chase_taunt_finished, CONNECT_ONE_SHOT)

func _on_chase_taunt_finished():
	if snake_minigame and snake_minigame.has_method("start_chase_mode"):
		var bed = get_tree().get_first_node_in_group("bed")
		if bed:
			bed.push_enabled = true
			bed.can_interact = true
		snake_minigame.start_chase_mode()
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

func get_bed_random_position() -> Vector2:
	var min_x = original_positions["left"].x + 48
	var max_x = original_positions["right"].x - 48
	var min_y = original_positions["top"].y + 48
	var max_y = original_positions["bottom"].y - 48
	return Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
