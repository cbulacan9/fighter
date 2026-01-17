class_name ModeSelectScreen
extends CanvasLayer

signal mode_selected(mode: GameMode)

enum GameMode {
	PLAYER_VS_AI,
	AI_VS_AI
}

@onready var panel: Control = $Panel
@onready var title_label: Label = $Panel/VBox/Title
@onready var player_vs_ai_button: Button = $Panel/VBox/PlayerVsAIButton
@onready var ai_vs_ai_button: Button = $Panel/VBox/AIVsAIButton


func _ready() -> void:
	visible = true
	_connect_buttons()


func _connect_buttons() -> void:
	if player_vs_ai_button:
		player_vs_ai_button.pressed.connect(_on_player_vs_ai_pressed)
	if ai_vs_ai_button:
		ai_vs_ai_button.pressed.connect(_on_ai_vs_ai_pressed)


func show_screen() -> void:
	visible = true


func hide_screen() -> void:
	visible = false


func _on_player_vs_ai_pressed() -> void:
	hide_screen()
	mode_selected.emit(GameMode.PLAYER_VS_AI)


func _on_ai_vs_ai_pressed() -> void:
	hide_screen()
	mode_selected.emit(GameMode.AI_VS_AI)
