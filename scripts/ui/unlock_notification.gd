class_name UnlockNotification
extends CanvasLayer

## Displays a notification when a character is unlocked.
## Shows the character portrait and name with a fade-in/out animation.

@onready var panel: Panel = $CenterContainer/Panel
@onready var portrait: TextureRect = $CenterContainer/Panel/VBoxContainer/Portrait
@onready var name_label: Label = $CenterContainer/Panel/VBoxContainer/NameLabel
@onready var message_label: Label = $CenterContainer/Panel/VBoxContainer/MessageLabel

var _is_showing: bool = false
var _pending_unlocks: Array[CharacterData] = []


func _ready() -> void:
	# Start hidden
	visible = false
	if panel:
		panel.modulate.a = 0


## Shows the unlock notification for a character.
func show_unlock(char_data: CharacterData) -> void:
	if _is_showing:
		# Queue this unlock to show after the current one
		_pending_unlocks.append(char_data)
		return

	_display_unlock(char_data)


## Internal method to display the unlock animation.
func _display_unlock(char_data: CharacterData) -> void:
	_is_showing = true

	# Set up the display - use placeholder texture generator for missing portraits
	if portrait:
		portrait.texture = PlaceholderTextures.get_or_generate_portrait(char_data, false)

	if name_label:
		name_label.text = char_data.display_name

	if message_label:
		message_label.text = "Character Unlocked!"

	# Make visible and run animation
	visible = true
	if panel:
		panel.modulate.a = 0

	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(2.5)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(_on_animation_finished)


## Called when the unlock animation finishes.
func _on_animation_finished() -> void:
	_is_showing = false
	visible = false

	# Check for pending unlocks
	if _pending_unlocks.size() > 0:
		var next_unlock := _pending_unlocks.pop_front()
		# Small delay between notifications
		await get_tree().create_timer(0.3).timeout
		_display_unlock(next_unlock)


## Hides the notification immediately (for skipping).
func hide_notification() -> void:
	var tween := get_tree().create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.1)
	tween.tween_callback(func():
		visible = false
		_is_showing = false
	)


## Returns true if currently showing a notification.
func is_showing() -> bool:
	return _is_showing


## Clears all pending unlock notifications.
func clear_pending() -> void:
	_pending_unlocks.clear()
