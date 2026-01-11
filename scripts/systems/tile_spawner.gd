class_name TileSpawner
extends Node

@export var tile_scene: PackedScene
@export var tile_resources: Array[PuzzleTileData] = []

var weights: Dictionary = {}
var _cumulative_weights: Array[float] = []
var _total_weight: float = 0.0


func _ready() -> void:
	if tile_resources.is_empty():
		_load_default_resources()
	_rebuild_cumulative_weights()


func set_weights(new_weights: Dictionary) -> void:
	weights = new_weights.duplicate()
	_rebuild_cumulative_weights()


func spawn_tile() -> Tile:
	var tile_data := _select_random_tile_data()
	var tile: Tile = tile_scene.instantiate()
	tile.setup(tile_data, Vector2i(-1, -1))
	return tile


func spawn_tiles(count: int) -> Array[Tile]:
	var tiles: Array[Tile] = []
	for i in range(count):
		tiles.append(spawn_tile())
	return tiles


func get_tile_data(type: TileTypes.Type) -> PuzzleTileData:
	for tile_data in tile_resources:
		if tile_data.tile_type == type:
			return tile_data
	return null


func _load_default_resources() -> void:
	tile_resources.clear()
	tile_resources.append(preload("res://resources/tiles/sword.tres"))
	tile_resources.append(preload("res://resources/tiles/shield.tres"))
	tile_resources.append(preload("res://resources/tiles/potion.tres"))
	tile_resources.append(preload("res://resources/tiles/lightning.tres"))
	tile_resources.append(preload("res://resources/tiles/filler.tres"))


func _rebuild_cumulative_weights() -> void:
	_cumulative_weights.clear()
	_total_weight = 0.0

	for tile_data in tile_resources:
		var weight := _get_weight_for_type(tile_data.tile_type)
		_total_weight += weight
		_cumulative_weights.append(_total_weight)


func _get_weight_for_type(type: TileTypes.Type) -> float:
	if weights.has(type):
		return weights[type]

	# Default weights
	match type:
		TileTypes.Type.SWORD:
			return 20.0
		TileTypes.Type.SHIELD:
			return 20.0
		TileTypes.Type.POTION:
			return 15.0
		TileTypes.Type.LIGHTNING:
			return 10.0
		TileTypes.Type.FILLER:
			return 35.0
		_:
			return 1.0


func _select_random_tile_data() -> PuzzleTileData:
	if tile_resources.is_empty() or _total_weight <= 0:
		return null

	var roll := randf() * _total_weight

	for i in range(_cumulative_weights.size()):
		if roll < _cumulative_weights[i]:
			return tile_resources[i]

	return tile_resources[tile_resources.size() - 1]
