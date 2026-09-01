extends CanvasLayer

signal dialogue_finished
signal choice_selected(choice_index: int)

var is_active: bool = false
var current_dialogue: Array = []
var current_index: int = 0
var is_typing: bool = false
var full_text: String = ""
var displayed_chars: int = 0
var typewriter_speed: float = 0.03
var choices_shown: bool = false

@onready var panel: PanelContainer = $PanelContainer
@onready var speaker_label: Label = $PanelContainer/MarginContainer/VBoxContainer/SpeakerLabel
@onready var text_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TextLabel
@onready var choices_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ChoicesContainer
@onready var typewriter_timer: Timer = $TypewriterTimer
@onready var interact_prompt: Label = $InteractPrompt

func _ready():
	add_to_group("dialogue_manager")
	hide_dialogue()
	typewriter_timer.wait_time = typewriter_speed
	typewriter_timer.timeout.connect(_on_typewriter_tick)
	interact_prompt.visible = false

func _input(event):
	if not is_active:
		return
	
	if event.is_action_pressed("interact"):
		if is_typing:
			_finish_typing()
		elif not choices_shown:
			_advance_dialogue()

func start_dialogue(dialogue_data: Array):
	current_dialogue = dialogue_data.duplicate(true)
	current_index = 0
	is_active = true
	choices_shown = false
	show_dialogue()
	_show_current_line()

func show_dialogue():
	panel.visible = true

func hide_dialogue():
	panel.visible = false
	choices_container.visible = false
	is_active = false
	choices_shown = false

func _show_current_line():
	if current_index >= current_dialogue.size():
		_end_dialogue()
		return
	
	choices_shown = false
	var line = current_dialogue[current_index]
	speaker_label.text = line.get("speaker", "")
	
	if line.has("text") and line.has("choices"):
		full_text = line["text"]
		displayed_chars = 0
		text_label.text = ""
		is_typing = true
		typewriter_timer.start()
		set_meta("pending_choices", line["choices"])
	elif line.has("text"):
		full_text = line["text"]
		displayed_chars = 0
		text_label.text = ""
		is_typing = true
		typewriter_timer.start()
	elif line.has("choices"):
		_show_choices(line["choices"])

func _on_typewriter_tick():
	if displayed_chars < full_text.length():
		displayed_chars += 1
		text_label.text = full_text.substr(0, displayed_chars)
	else:
		is_typing = false
		typewriter_timer.stop()
		if has_meta("pending_choices"):
			_show_choices(get_meta("pending_choices"))
			remove_meta("pending_choices")

func _finish_typing():
	is_typing = false
	typewriter_timer.stop()
	text_label.text = full_text
	if has_meta("pending_choices"):
		_show_choices(get_meta("pending_choices"))
		remove_meta("pending_choices")

func _advance_dialogue():
	current_index += 1
	_show_current_line()

func _show_choices(choices: Array):
	choices_shown = true
	choices_container.visible = true
	
	for child in choices_container.get_children():
		child.queue_free()
	await get_tree().process_frame
	
	for i in range(choices.size()):
		var btn = Button.new()
		btn.text = choices[i]["text"]
		btn.pressed.connect(_on_choice_pressed.bind(i, choices[i]))
		btn.add_theme_font_size_override("font_size", 14)
		choices_container.add_child(btn)

func _on_choice_pressed(index: int, choice: Dictionary):
	choice_selected.emit(choice.get("value", index))
	
	if choice.has("response"):
		current_dialogue.insert(current_index + 1, {"speaker": "Cama", "text": choice["response"]})
	
	choices_container.visible = false
	choices_shown = false
	current_index += 1
	_show_current_line()

func _end_dialogue():
	is_active = false
	hide_dialogue()
	dialogue_finished.emit()

func show_interact_prompt(text: String = "[E] Intentar dormir"):
	interact_prompt.text = text
	interact_prompt.visible = true

func hide_interact_prompt():
	interact_prompt.visible = false
