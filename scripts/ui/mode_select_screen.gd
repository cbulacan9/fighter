class_name ModeSelectScreen
extends CanvasLayer

signal mode_selected(mode: GameMode, difficulty: Difficulty)

enum GameMode {
	PLAYER_VS_AI,
	AI_VS_AI
}

enum Difficulty {
	EASY,
	MEDIUM,
	HARD
}

@onready var panel: Control = $Panel
@onready var title_label: Label = $Panel/VBox/Title
@onready var easy_button: Button = $Panel/VBox/EasyButton
@onready var medium_button: Button = $Panel/VBox/MediumButton
@onready var hard_button: Button = $Panel/VBox/HardButton
@onready var observe_button: Button = $Panel/VBox/ObserveButton


func _ready() -> void:
	visible = true
	_connect_buttons()


func _connect_buttons() -> void:
	if easy_button:
		easy_button.pressed.connect(_on_easy_pressed)
	if medium_button:
		medium_button.pressed.connect(_on_medium_pressed)
	if hard_button:
		hard_button.pressed.connect(_on_hard_pressed)
	if observe_button:
		observe_button.pressed.connect(_on_observe_pressed)


func show_screen() -> void:
	visible = true


func hide_screen() -> void:
	visible = false


func _on_easy_pressed() -> void:
	hide_screen()
	mode_selected.emit(GameMode.PLAYER_VS_AI, Difficulty.EASY)


func _on_medium_pressed() -> void:
	hide_screen()
	mode_selected.emit(GameMode.PLAYER_VS_AI, Difficulty.MEDIUM)


func _on_hard_pressed() -> void:
	hide_screen()
	mode_selected.emit(GameMode.PLAYER_VS_AI, Difficulty.HARD)


func _on_observe_pressed() -> void:
	hide_screen()
	mode_selected.emit(GameMode.AI_VS_AI, Difficulty.MEDIUM)
