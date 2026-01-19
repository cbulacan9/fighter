class_name Tile
extends Node2D

signal animation_finished
signal clicked
signal activation_started
signal activation_finished

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var tile_data: PuzzleTileData
var grid_position: Vector2i
var is_clickable_highlighted: bool = false
var is_hidden: bool = false
var is_dimmed: bool = false  # For tiles that can't be activated (e.g., no mana)

var _highlight_tween: Tween
var _activation_tween: Tween
var _hidden_tween: Tween
var _dimmed_tween: Tween
var _reject_tween: Tween


func _ready() -> void:
	_update_visual()


func _notification(what: int) -> void:
	# Kill all tweens when the node is being freed to prevent orphaned tweens
	if what == NOTIFICATION_PREDELETE:
		if _highlight_tween:
			_highlight_tween.kill()
			_highlight_tween = null
		if _activation_tween:
			_activation_tween.kill()
			_activation_tween = null
		if _hidden_tween:
			_hidden_tween.kill()
			_hidden_tween = null
		if _dimmed_tween:
			_dimmed_tween.kill()
			_dimmed_tween = null
		if _reject_tween:
			_reject_tween.kill()
			_reject_tween = null


func setup(data: PuzzleTileData, pos: Vector2i) -> void:
	tile_data = data
	grid_position = pos
	_update_visual()


func get_type() -> TileTypes.Type:
	if tile_data:
		return tile_data.tile_type
	return TileTypes.Type.FILLER


func get_match_value(count: int) -> int:
	if tile_data:
		return tile_data.get_value(count)
	return 0


func play_match_animation() -> void:
	animation_player.play("match")


func play_spawn_animation() -> void:
	animation_player.play("spawn")


func _update_visual() -> void:
	if sprite and tile_data:
		if tile_data.sprite:
			sprite.texture = tile_data.sprite
		else:
			sprite.modulate = tile_data.color

		# Scale sprite to fill the cell (base sprite is 64x64)
		const BASE_SPRITE_SIZE := 64.0
		var scale_factor := Grid.CELL_SIZE.x / BASE_SPRITE_SIZE
		sprite.scale = Vector2(scale_factor, scale_factor)


func _on_animation_player_animation_finished(_anim_name: String) -> void:
	animation_finished.emit()


# --- Clickable State Management ---

func update_clickable_state(can_click: bool) -> void:
	if can_click and not is_clickable_highlighted:
		_show_clickable_highlight()
	elif not can_click and is_clickable_highlighted:
		_hide_clickable_highlight()


func _show_clickable_highlight() -> void:
	is_clickable_highlighted = true

	if _highlight_tween:
		_highlight_tween.kill()

	# Bright highlight color for more visibility
	var highlight_color := Color(1.5, 1.5, 0.5)  # Bright yellow-white
	if tile_data and tile_data.clickable_highlight_color != Color.TRANSPARENT:
		# Use a much brighter version for the pulse effect
		highlight_color = tile_data.clickable_highlight_color + Color(0.5, 0.5, 0.5, 0)

	# Get base scale for the sprite
	const BASE_SPRITE_SIZE := 64.0
	var base_scale_factor := Grid.CELL_SIZE.x / BASE_SPRITE_SIZE
	var base_scale := Vector2(base_scale_factor, base_scale_factor)
	var enlarged_scale := base_scale * 1.15  # 15% larger when highlighted

	# Pulsing glow + scale effect for more visibility
	_highlight_tween = create_tween()
	_highlight_tween.set_loops()
	_highlight_tween.set_parallel(true)
	_highlight_tween.tween_property(self, "modulate", highlight_color, 0.5)
	_highlight_tween.tween_property(sprite, "scale", enlarged_scale, 0.5)
	_highlight_tween.set_parallel(false)
	_highlight_tween.set_parallel(true)
	_highlight_tween.tween_property(self, "modulate", Color.WHITE, 0.5)
	_highlight_tween.tween_property(sprite, "scale", base_scale, 0.5)


func _hide_clickable_highlight() -> void:
	is_clickable_highlighted = false

	if _highlight_tween:
		_highlight_tween.kill()
		_highlight_tween = null

	modulate = Color.WHITE

	# Reset scale to base
	if sprite:
		const BASE_SPRITE_SIZE := 64.0
		var base_scale_factor := Grid.CELL_SIZE.x / BASE_SPRITE_SIZE
		sprite.scale = Vector2(base_scale_factor, base_scale_factor)


func play_activation_animation() -> void:
	activation_started.emit()
	clicked.emit()

	# Kill any existing activation animation
	if _activation_tween:
		_activation_tween.kill()

	# Store the original scale in case it was modified
	var original_scale := scale

	# Pop effect animation
	_activation_tween = create_tween()
	_activation_tween.set_ease(Tween.EASE_OUT)
	_activation_tween.set_trans(Tween.TRANS_BACK)
	_activation_tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.1)
	_activation_tween.set_ease(Tween.EASE_IN)
	_activation_tween.set_trans(Tween.TRANS_QUAD)
	_activation_tween.tween_property(self, "scale", original_scale, 0.1)
	_activation_tween.tween_callback(_on_activation_finished)


func _on_activation_finished() -> void:
	_activation_tween = null
	activation_finished.emit()


func is_currently_clickable() -> bool:
	if not tile_data:
		return false
	return tile_data.can_be_clicked()


# --- Hidden State Management ---

## Set the hidden state of the tile (for Smoke Bomb effects)
func set_hidden(value: bool) -> void:
	if is_hidden == value:
		return

	is_hidden = value

	if _hidden_tween:
		_hidden_tween.kill()
		_hidden_tween = null

	if value:
		_show_hidden_state()
	else:
		_show_revealed_state()


func _show_hidden_state() -> void:
	# Animate to a dark, obscured state
	_hidden_tween = create_tween()
	_hidden_tween.set_ease(Tween.EASE_OUT)
	_hidden_tween.set_trans(Tween.TRANS_QUAD)

	# Darken and add slight scale effect
	var hidden_color := Color(0.1, 0.1, 0.15, 1.0)  # Very dark, slightly visible
	_hidden_tween.tween_property(self, "modulate", hidden_color, 0.2)


func _show_revealed_state() -> void:
	# Animate back to normal state
	_hidden_tween = create_tween()
	_hidden_tween.set_ease(Tween.EASE_OUT)
	_hidden_tween.set_trans(Tween.TRANS_QUAD)

	# Flash briefly then return to normal
	_hidden_tween.tween_property(self, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.1)
	_hidden_tween.tween_property(self, "modulate", Color.WHITE, 0.15)


# --- Dimmed State Management (for tiles without enough mana) ---

func set_dimmed(dimmed: bool) -> void:
	if is_dimmed == dimmed:
		return

	is_dimmed = dimmed

	if _dimmed_tween:
		_dimmed_tween.kill()
		_dimmed_tween = null

	if dimmed:
		_show_dimmed_state()
	else:
		_clear_dimmed_state()


func _show_dimmed_state() -> void:
	# Dim the tile to show it can't be clicked
	_dimmed_tween = create_tween()
	_dimmed_tween.set_ease(Tween.EASE_OUT)
	_dimmed_tween.set_trans(Tween.TRANS_QUAD)

	# Gray out the tile
	var dimmed_color := Color(0.4, 0.4, 0.5, 0.7)
	_dimmed_tween.tween_property(self, "modulate", dimmed_color, 0.2)


func _clear_dimmed_state() -> void:
	# Return to normal state
	_dimmed_tween = create_tween()
	_dimmed_tween.set_ease(Tween.EASE_OUT)
	_dimmed_tween.set_trans(Tween.TRANS_QUAD)
	_dimmed_tween.tween_property(self, "modulate", Color.WHITE, 0.2)


# --- Click Rejection Feedback ---

func play_reject_animation() -> void:
	## Plays a shake animation to indicate click was rejected (e.g., not enough mana)
	if _reject_tween:
		_reject_tween.kill()

	var original_pos := position

	_reject_tween = create_tween()
	_reject_tween.set_ease(Tween.EASE_OUT)
	_reject_tween.set_trans(Tween.TRANS_QUAD)

	# Quick shake left-right
	_reject_tween.tween_property(self, "position", original_pos + Vector2(-5, 0), 0.05)
	_reject_tween.tween_property(self, "position", original_pos + Vector2(5, 0), 0.05)
	_reject_tween.tween_property(self, "position", original_pos + Vector2(-3, 0), 0.05)
	_reject_tween.tween_property(self, "position", original_pos + Vector2(3, 0), 0.05)
	_reject_tween.tween_property(self, "position", original_pos, 0.05)

	# Flash red briefly
	_reject_tween.parallel().tween_property(self, "modulate", Color(1.5, 0.5, 0.5, 1.0), 0.1)
	_reject_tween.tween_property(self, "modulate", Color.WHITE if not is_dimmed else Color(0.4, 0.4, 0.5, 0.7), 0.15)
