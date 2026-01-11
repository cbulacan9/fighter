class_name Tile
extends Node2D

signal animation_finished

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var tile_data: PuzzleTileData
var grid_position: Vector2i


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


func _on_animation_player_animation_finished(_anim_name: String) -> void:
	animation_finished.emit()
