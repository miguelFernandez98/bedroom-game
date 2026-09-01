extends Node

signal mute_changed(is_muted: bool)

var audio_player: AudioStreamPlayer = null
var mute_button: Button = null
var is_muted: bool = false
var normal_volume: float = 0.5
var current_volume: float = 0.5
var punishment_volume: float = 1.0
var is_punishing: bool = false
var dialogue_manager: Node = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(player_ref: AudioStreamPlayer, button_ref: Button, dm_ref: Node):
	audio_player = player_ref
	mute_button = button_ref
	dialogue_manager = dm_ref
	if audio_player:
		audio_player.volume_db = linear_to_db(normal_volume)
		audio_player.play()
	if mute_button:
		mute_button.pressed.connect(_on_mute_pressed)

func _on_mute_pressed():
	if not audio_player:
		return
	
	if is_punishing:
		_bed_reacts_to_mute()
		return
	
	is_muted = not is_muted
	if is_muted:
		audio_player.volume_db = linear_to_db(0.0)
		if mute_button:
			mute_button.text = "♪ OFF"
	else:
		audio_player.volume_db = linear_to_db(normal_volume)
		if mute_button:
			mute_button.text = "♪ ON"
	mute_changed.emit(is_muted)

func _bed_reacts_to_mute():
	if not dialogue_manager:
		return
	
	var react_dialogue = [
		{"speaker": "Cama", "text": "¿Qué haces? ¿Quieres mutear la música?"},
		{"speaker": "Cama", "text": "Tú no decides eso. Esto es MI juego."},
		{"speaker": "Cama", "text": "...está bien, ponla. Pero si no la escuchas, no puedes quejarte de que no entiendes nada."},
		{"speaker": "Cama", "text": "Además, ¿para qué lees los diálogos si no escuchas la música? Eso daña la inmersión."},
		{"speaker": "Cama", "text": "Bueno... ya está al volumen normal. No la vuelvas a mutear."}
	]
	dialogue_manager.start_dialogue(react_dialogue)
	dialogue_manager.dialogue_finished.connect(_on_react_finished, CONNECT_ONE_SHOT)

func _on_react_finished():
	is_muted = false
	if audio_player:
		audio_player.volume_db = linear_to_db(normal_volume)
	if mute_button:
		mute_button.text = "♪ ON"

func start_punishment_volume():
	is_punishing = true
	if audio_player:
		var tween = audio_player.create_tween()
		tween.tween_property(audio_player, "volume_db", linear_to_db(punishment_volume), 0.3)

func stop_punishment_volume():
	is_punishing = false
	if audio_player:
		var tween = audio_player.create_tween()
		tween.tween_property(audio_player, "volume_db", linear_to_db(normal_volume), 0.5)
