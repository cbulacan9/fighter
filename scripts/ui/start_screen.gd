class_name StartScreen
extends CanvasLayer

signal play_pressed()
signal settings_pressed()
signal library_pressed()

@onready var panel: Control = $Panel
@onready var background: ColorRect = $Panel/Background
@onready var background_texture_rect: TextureRect = $Panel/BackgroundTexture
@onready var title_label: Label = $Panel/VBox/Title
@onready var play_button: Button = $Panel/VBox/PlayButton
@onready var settings_button: Button = $Panel/VBox/SettingsButton
@onready var library_button: Button = $Panel/VBox/LibraryButton


func _ready() -> void:
	visible = true
	_connect_buttons()


func _connect_buttons() -> void:
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if library_button:
		library_button.pressed.connect(_on_library_pressed)


func show_screen() -> void:
	visible = true


func hide_screen() -> void:
	visible = false


func _on_play_pressed() -> void:
	hide_screen()
	play_pressed.emit()


func _on_settings_pressed() -> void:
	settings_pressed.emit()


func _on_library_pressed() -> void:
	library_pressed.emit()


## Sets the background image for the start screen
func set_background_image(texture: Texture2D) -> void:
	if background_texture_rect:
		background_texture_rect.texture = texture
		background_texture_rect.visible = true
		if background:
			background.visible = false


## Clears the background image and returns to solid color
func clear_background_image() -> void:
	if background_texture_rect:
		background_texture_rect.texture = null
		background_texture_rect.visible = false
		if background:
			background.visible = true


## Sets the background color
func set_background_color(color: Color) -> void:
	if background:
		background.color = color