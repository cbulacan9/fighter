class_name TileSpawner
extends Node

@export var tile_scene: PackedScene
@export var tile_resources: Array[PuzzleTileData] = []

var weights: Dictionary = {}
var _cumulative_weights: Array[float] = []
var _total_weight: float = 0.0

# Spawn rules for minimum/maximum tile counts
var _min_counts: Dictionary = {}  # {TileTypes.Type: int}
var _max_counts: Dictionary = {}  # {TileTypes.Type: int}
var _grid_ref: Grid  # Reference to the grid for counting tiles
var _anti_cascade_filter: AntiCascadeFilter = AntiCascadeFilter.new()

# Tile count caching (avoids repeated full-grid scans)
var _cached_type_counts: Dictionary = {}  # {TileTypes.Type: int}
var _counts_valid: bool = false

# Pre-allocated arrays for _select_random_tile_data() (avoids GC pressure)
var _available_resources: Array[PuzzleTileData] = []
var _available_weights: Array[float] = []


func _ready() -> void:
	if tile_resources.is_empty():
		_load_default_resources()
	_rebuild_cumulative_weights()


func set_weights(new_weights: Dictionary) -> void:
	weights = new_weights.duplicate()
	_rebuild_cumulative_weights()


## Sets the available tile resources for spawning.
## Replaces the default tile resources with character-specific tiles.
func set_available_tiles(tiles: Array[PuzzleTileData]) -> void:
	if tiles.is_empty():
		return

	tile_resources = tiles.duplicate()
	_rebuild_cumulative_weights()


## Clears current tiles and reloads the default tile resources.
func reset_to_defaults() -> void:
	weights.clear()
	_load_default_resources()
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


## Spawns a tile that won't immediately create a match at the given position.
## Uses retries to find a safe tile type, with graceful fallback to random.
func spawn_safe_tile(row: int, col: int) -> Tile:
	if not GameConstants.ANTI_CASCADE_ENABLED or not _grid_ref:
		return spawn_tile()

	var max_attempts := GameConstants.ANTI_CASCADE_MAX_RETRIES
	var attempts := 0
	var tile_data: PuzzleTileData = null

	while attempts < max_attempts:
		tile_data = _select_random_tile_data()
		if not tile_data:
			break

		# Check if this would create a match
		if not _anti_cascade_filter.would_create_match(_grid_ref, row, col, tile_data.tile_type):
			break  # Found a safe tile

		attempts += 1

	# Graceful degradation: use last selection if no safe option found
	if not tile_data:
		tile_data = _select_random_tile_data()

	var tile: Tile = tile_scene.instantiate()
	tile.setup(tile_data, Vector2i(-1, -1))

	# Update cached count for min/max tracking
	if tile_data:
		_increment_cached_count(tile_data.tile_type)

	return tile


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

	# First check if any tile type is below minimum
	var forced_type := _get_type_below_minimum()
	if forced_type != TileTypes.Type.NONE:
		var forced_data := get_tile_data(forced_type)
		if forced_data:
			return forced_data

	# Build a filtered selection that respects maximums (reuse pre-allocated arrays)
	_available_resources.clear()
	_available_weights.clear()
	var total_available_weight := 0.0

	for tile_data in tile_resources:
		# Skip types that are at maximum count
		if _is_type_at_maximum(tile_data.tile_type):
			continue

		_available_resources.append(tile_data)
		var weight := _get_weight_for_type(tile_data.tile_type)
		_available_weights.append(weight)
		total_available_weight += weight

	# If no tiles available (all at max), fall back to any tile
	if _available_resources.is_empty() or total_available_weight <= 0:
		var fallback_roll := randf() * _total_weight
		for i in range(_cumulative_weights.size()):
			if fallback_roll < _cumulative_weights[i]:
				return tile_resources[i]
		return tile_resources[tile_resources.size() - 1]

	# Select from available tiles
	var roll := randf() * total_available_weight
	var cumulative := 0.0

	for i in range(_available_resources.size()):
		cumulative += _available_weights[i]
		if roll < cumulative:
			return _available_resources[i]

	return _available_resources[_available_resources.size() - 1]


## Sets the grid reference for counting tiles on board
func set_grid(grid: Grid) -> void:
	_grid_ref = grid


## Sets spawn rules from a tile data resource
func set_spawn_rules(tile_data: PuzzleTileData) -> void:
	if not tile_data:
		return

	if tile_data.min_on_board > 0:
		_min_counts[tile_data.tile_type] = tile_data.min_on_board

	if tile_data.max_on_board > 0:
		_max_counts[tile_data.tile_type] = tile_data.max_on_board


## Clears all spawn rules
func clear_spawn_rules() -> void:
	_min_counts.clear()
	_max_counts.clear()


## Invalidates the tile count cache. Call before starting a batch of spawns.
func invalidate_counts() -> void:
	_counts_valid = false


## Rebuilds the tile count cache if invalid
func _ensure_counts_cached() -> void:
	if _counts_valid:
		return

	_cached_type_counts.clear()
	if not _grid_ref:
		_counts_valid = true
		return

	for tile in _grid_ref.get_all_tiles():
		if tile and tile.tile_data:
			var t: int = tile.tile_data.tile_type
			_cached_type_counts[t] = _cached_type_counts.get(t, 0) + 1

	_counts_valid = true


## Increments the cached count for a tile type (call after spawning)
func _increment_cached_count(tile_type: TileTypes.Type) -> void:
	if _counts_valid:
		_cached_type_counts[tile_type] = _cached_type_counts.get(tile_type, 0) + 1


## Counts how many tiles of a specific type are currently on the board (cached)
func _count_on_board(tile_type: TileTypes.Type) -> int:
	_ensure_counts_cached()
	return _cached_type_counts.get(tile_type, 0)


## Returns a tile type that is below its minimum count, or NONE if all are satisfied
func _get_type_below_minimum() -> TileTypes.Type:
	for tile_type in _min_counts:
		var min_count: int = _min_counts[tile_type]
		var current_count := _count_on_board(tile_type)
		if current_count < min_count:
			return tile_type
	return TileTypes.Type.NONE


## Checks if a tile type is at or above its maximum count
func _is_type_at_maximum(tile_type: TileTypes.Type) -> bool:
	if not _max_counts.has(tile_type):
		return false  # No maximum set

	var max_count: int = _max_counts[tile_type]
	var current_count := _count_on_board(tile_type)
	return current_count >= max_count


## Ensures minimum tile counts are met by spawning tiles at empty positions
## Returns array of spawned tiles (caller should add them to scene and grid)
func ensure_minimums() -> Array[Tile]:
	var spawned: Array[Tile] = []

	if not _grid_ref:
		return spawned

	# Check each type with a minimum requirement
	for tile_type in _min_counts:
		var min_count: int = _min_counts[tile_type]
		var current_count := _count_on_board(tile_type)
		var deficit := min_count - current_count

		if deficit > 0:
			var new_tiles := _spawn_minimum_tiles(tile_type, deficit)
			spawned.append_array(new_tiles)

	return spawned


## Spawns a specific number of tiles of a given type
func _spawn_minimum_tiles(tile_type: TileTypes.Type, count: int) -> Array[Tile]:
	var tiles: Array[Tile] = []
	var tile_data := get_tile_data(tile_type)

	if not tile_data:
		return tiles

	for i in range(count):
		var tile: Tile = tile_scene.instantiate()
		tile.setup(tile_data, Vector2i(-1, -1))
		tiles.append(tile)

	return tiles
