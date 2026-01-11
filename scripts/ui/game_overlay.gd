class_name GameOverlay
extends CanvasLayer

signal countdown_finished
signal resume_pressed
signal quit_pressed
signal continue_pressed

@onready var countdown_panel: Control = $CountdownPanel
@onready var countdown_label: Label = $CountdownPanel/CountdownLabel
@onready var pause_panel: Control = $PausePanel
@onready var resume_button: Button = $PausePanel/VBoxContainer/ResumeButton
@onready var pause_quit_button: Button = $PausePanel/VBoxContainer/QuitButton
@onready var result_panel: Control = $ResultPanel
@onready var result_label: Label = $ResultPanel/VBoxContainer/ResultLabel
@onready var continue_button: Button = $ResultPanel/VBoxContainer/ContinueButton


func _ready() -> void:
	hide_all()
	_connect_buttons()


func _connect_buttons() -> void:
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if pause_quit_button:
		pause_quit_button.pressed.connect(_on_quit_pressed)
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)


func show_countdown() -> void:
	hide_all()
	countdown_panel.visible = true
	await _run_countdown()


func _run_countdown() -> void:
	for num in [3, 2, 1]:
		countdown_label.text = str(num)
		await get_tree().create_timer(1.0).timeout

	countdown_label.text = "GO!"
	await get_tree().create_timer(0.5).timeout

	countdown_panel.visible = false
	countdown_finished.emit()


func show_pause() -> void:
	hide_all()
	pause_panel.visible = true


func hide_pause() -> void:
	pause_panel.visible = false


func show_result(winner_id: int) -> void:
	hide_all()
	result_panel.visible = true

	match winner_id:
		1:  # Player wins
			result_label.text = "VICTORY!"
			result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		2:  # Enemy wins
			result_label.text = "DEFEAT!"
			result_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		3:  # Draw
			result_label.text = "DRAW!"
			result_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))


func hide_all() -> void:
	countdown_panel.visible = false
	pause_panel.visible = false
	result_panel.visible = false


func _on_resume_pressed() -> void:
	hide_pause()
	resume_pressed.emit()


func _on_quit_pressed() -> void:
	quit_pressed.emit()


func _on_continue_pressed() -> void:
	result_panel.visible = false
	continue_pressed.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if pause_panel.visible:
			_on_resume_pressed()
