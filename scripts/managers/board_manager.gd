class_name BoardManager
extends Node2D

signal state_changed(new_state: BoardState)
signal matches_resolved(match_results: Array)
signal ready_for_input

enum BoardState {
	IDLE,
	DRAGGING,
	RESOLVING,
	STUNNED
}

@export var tile_scene: PackedScene
@export var fighter_data: FighterData

var grid: Grid
var state: BoardState = BoardState.IDLE
var is_player_controlled: bool = true

var _tiles_container: Node2D
var _tile_resources: Array[TileData] = []
var _stun_timer: float = 0.0


func _ready() -> void:
	grid = $Grid
	_tiles_container = $Grid/Tiles


func _process(delta: float) -> void:
	if state == BoardState.STUNNED:
		_stun_timer -= delta
		if _stun_timer <= 0:
			set_state(BoardState.IDLE)


func initialize(fighter: FighterData, is_player: bool) -> void:
	fighter_data = fighter
	is_player_controlled = is_player
	_load_tile_resources()
	grid.initialize()
	generate_initial_board()


func generate_initial_board() -> void:
	_clear_all_tiles()

	for row in range(Grid.ROWS):
		for col in range(Grid.COLS):
			var tile := _create_random_tile(row, col)
			_place_tile(tile, row, col)

	_remove_initial_matches()


func get_state() -> BoardState:
	return state


func set_state(new_state: BoardState) -> void:
	if state != new_state:
		state = new_state
		state_changed.emit(new_state)
		if new_state == BoardState.IDLE:
			ready_for_input.emit()


func lock_input() -> void:
	if state == BoardState.IDLE:
		set_state(BoardState.RESOLVING)


func unlock_input() -> void:
	if state == BoardState.RESOLVING:
		set_state(BoardState.IDLE)


func apply_stun(duration: float) -> void:
	_stun_timer = duration
	set_state(BoardState.STUNNED)


func _load_tile_resources() -> void:
	_tile_resources.clear()
	_tile_resources.append(preload("res://resources/tiles/sword.tres"))
	_tile_resources.append(preload("res://resources/tiles/shield.tres"))
	_tile_resources.append(preload("res://resources/tiles/potion.tres"))
	_tile_resources.append(preload("res://resources/tiles/lightning.tres"))
	_tile_resources.append(preload("res://resources/tiles/filler.tres"))


func _create_random_tile(row: int, col: int) -> Tile:
	var tile: Tile = tile_scene.instantiate()
	var tile_data := _get_weighted_random_tile()
	tile.setup(tile_data, Vector2i(row, col))
	return tile


func _get_weighted_random_tile() -> TileData:
	# TODO: Use fighter_data.tile_weights when TileSpawner is implemented
	var total_weight := 0.0
	var weights: Array[float] = []

	for tile_res in _tile_resources:
		var weight := 1.0
		if fighter_data and fighter_data.tile_weights.has(tile_res.tile_type):
			weight = fighter_data.tile_weights[tile_res.tile_type]
		weights.append(weight)
		total_weight += weight

	var roll := randf() * total_weight
	var cumulative := 0.0

	for i in range(_tile_resources.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return _tile_resources[i]

	return _tile_resources[0]


func _place_tile(tile: Tile, row: int, col: int) -> void:
	grid.set_tile(row, col, tile)
	_tiles_container.add_child(tile)
	tile.position = grid.grid_to_world(row, col)


func _clear_all_tiles() -> void:
	for tile in grid.get_all_tiles():
		if tile:
			tile.queue_free()
	grid.initialize()


func _remove_initial_matches() -> void:
	var max_iterations := 100
	var iteration := 0

	while iteration < max_iterations:
		var has_match := false

		for row in range(Grid.ROWS):
			for col in range(Grid.COLS):
				if _has_match_at(row, col):
					has_match = true
					_replace_tile_at(row, col)

		if not has_match:
			break
		iteration += 1


func _has_match_at(row: int, col: int) -> bool:
	var tile := grid.get_tile(row, col)
	if not tile:
		return false

	var tile_type := tile.get_type()

	# Check horizontal (3 in a row)
	var h_count := 1
	for offset in [1, 2]:
		var neighbor := grid.get_tile(row, col + offset)
		if neighbor and neighbor.get_type() == tile_type:
			h_count += 1
		else:
			break

	if h_count >= 3:
		return true

	# Check vertical (3 in a column)
	var v_count := 1
	for offset in [1, 2]:
		var neighbor := grid.get_tile(row + offset, col)
		if neighbor and neighbor.get_type() == tile_type:
			v_count += 1
		else:
			break

	return v_count >= 3


func _replace_tile_at(row: int, col: int) -> void:
	var old_tile := grid.clear_tile(row, col)
	if old_tile:
		old_tile.queue_free()

	var new_tile := _create_random_tile(row, col)
	_place_tile(new_tile, row, col)
