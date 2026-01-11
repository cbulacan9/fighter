class_name BoardManager
extends Node2D

signal state_changed(new_state: BoardState)
signal matches_resolved(match_results: Array)
signal ready_for_input
signal snap_back_started
signal snap_back_finished

enum BoardState {
	IDLE,
	DRAGGING,
	RESOLVING,
	STUNNED
}

const SNAP_BACK_DURATION: float = 0.2

@export var tile_scene: PackedScene
@export var fighter_data: FighterData

var grid: Grid
var state: BoardState = BoardState.IDLE
var is_player_controlled: bool = true

var _tiles_container: Node2D
var _input_handler: InputHandler
var _tile_resources: Array[TileData] = []
var _stun_timer: float = 0.0

# Drag preview state
var _drag_axis: InputHandler.DragAxis = InputHandler.DragAxis.NONE
var _drag_index: int = -1
var _original_positions: Dictionary = {}
var _snap_back_tween: Tween


func _ready() -> void:
	grid = $Grid
	_tiles_container = $Grid/Tiles
	_input_handler = $InputHandler
	_setup_input_handler()


func _process(delta: float) -> void:
	if state == BoardState.STUNNED:
		_stun_timer -= delta
		if _stun_timer <= 0:
			set_state(BoardState.IDLE)


func _setup_input_handler() -> void:
	_input_handler.setup(grid, global_position)
	_input_handler.drag_started.connect(_on_drag_started)
	_input_handler.drag_moved.connect(_on_drag_moved)
	_input_handler.drag_ended.connect(_on_drag_ended)


func initialize(fighter: FighterData, is_player: bool) -> void:
	fighter_data = fighter
	is_player_controlled = is_player
	_load_tile_resources()
	grid.initialize()
	generate_initial_board()
	_input_handler.set_enabled(is_player)


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

		match new_state:
			BoardState.IDLE:
				_input_handler.set_enabled(is_player_controlled)
				ready_for_input.emit()
			BoardState.DRAGGING, BoardState.RESOLVING, BoardState.STUNNED:
				_input_handler.set_enabled(false)


func lock_input() -> void:
	if state == BoardState.IDLE:
		set_state(BoardState.RESOLVING)


func unlock_input() -> void:
	if state == BoardState.RESOLVING:
		set_state(BoardState.IDLE)


func apply_stun(duration: float) -> void:
	_stun_timer = duration
	set_state(BoardState.STUNNED)


# --- Drag Preview Methods ---

func preview_row_shift(row: int, offset: float) -> void:
	var grid_width := Grid.COLS * Grid.CELL_SIZE.x
	for col in range(Grid.COLS):
		var tile := grid.get_tile(row, col)
		if tile:
			var base_x: float = _original_positions.get(tile, tile.position).x
			var new_x := fposmod(base_x + offset, grid_width)
			tile.position.x = new_x


func preview_column_shift(col: int, offset: float) -> void:
	var grid_height := Grid.ROWS * Grid.CELL_SIZE.y
	for row in range(Grid.ROWS):
		var tile := grid.get_tile(row, col)
		if tile:
			var base_y: float = _original_positions.get(tile, tile.position).y
			var new_y := fposmod(base_y + offset, grid_height)
			tile.position.y = new_y


func commit_shift() -> void:
	var cells_moved := _calculate_cells_moved()

	if cells_moved == 0:
		_sync_visuals_to_grid()
		set_state(BoardState.IDLE)
		return

	if _drag_axis == InputHandler.DragAxis.HORIZONTAL:
		grid.shift_row(_drag_index, cells_moved)
	else:
		grid.shift_column(_drag_index, cells_moved)

	_sync_visuals_to_grid()
	_clear_drag_state()

	# TODO: Trigger match detection in Phase 4
	set_state(BoardState.IDLE)


func revert_preview() -> void:
	_sync_visuals_to_grid()
	_clear_drag_state()


func check_move_validity() -> bool:
	var cells_moved := _calculate_cells_moved()
	if cells_moved == 0:
		return false

	# Temporarily shift grid to check for matches
	if _drag_axis == InputHandler.DragAxis.HORIZONTAL:
		grid.shift_row(_drag_index, cells_moved)
	else:
		grid.shift_column(_drag_index, cells_moved)

	var has_match := _check_any_match()

	# Revert the temporary shift
	if _drag_axis == InputHandler.DragAxis.HORIZONTAL:
		grid.shift_row(_drag_index, -cells_moved)
	else:
		grid.shift_column(_drag_index, -cells_moved)

	return has_match


func animate_snap_back() -> void:
	snap_back_started.emit()

	if _snap_back_tween:
		_snap_back_tween.kill()

	_snap_back_tween = create_tween()
	_snap_back_tween.set_ease(Tween.EASE_OUT)
	_snap_back_tween.set_trans(Tween.TRANS_QUAD)
	_snap_back_tween.set_parallel(true)

	for tile in _original_positions:
		var original_pos: Vector2 = _original_positions[tile]
		_snap_back_tween.tween_property(tile, "position", original_pos, SNAP_BACK_DURATION)

	_snap_back_tween.chain().tween_callback(_on_snap_back_finished)


func _on_snap_back_finished() -> void:
	_clear_drag_state()
	snap_back_finished.emit()
	set_state(BoardState.IDLE)


# --- Input Signal Handlers ---

func _on_drag_started(axis: InputHandler.DragAxis, index: int, _start_pos: Vector2) -> void:
	if state != BoardState.IDLE:
		return

	set_state(BoardState.DRAGGING)
	_drag_axis = axis
	_drag_index = index
	_store_original_positions()


func _on_drag_moved(offset: float) -> void:
	if state != BoardState.DRAGGING:
		return

	if _drag_axis == InputHandler.DragAxis.HORIZONTAL:
		preview_row_shift(_drag_index, offset)
	else:
		preview_column_shift(_drag_index, offset)


func _on_drag_ended(_final_offset: float) -> void:
	if state != BoardState.DRAGGING:
		return

	if check_move_validity():
		commit_shift()
	else:
		animate_snap_back()


# --- Helper Methods ---

func _store_original_positions() -> void:
	_original_positions.clear()

	if _drag_axis == InputHandler.DragAxis.HORIZONTAL:
		for col in range(Grid.COLS):
			var tile := grid.get_tile(_drag_index, col)
			if tile:
				_original_positions[tile] = tile.position
	else:
		for row in range(Grid.ROWS):
			var tile := grid.get_tile(row, _drag_index)
			if tile:
				_original_positions[tile] = tile.position


func _calculate_cells_moved() -> int:
	if _original_positions.is_empty():
		return 0

	var first_tile: Tile = _original_positions.keys()[0]
	var original_pos: Vector2 = _original_positions[first_tile]
	var current_pos: Vector2 = first_tile.position

	var offset: float
	var cell_size: float

	if _drag_axis == InputHandler.DragAxis.HORIZONTAL:
		offset = current_pos.x - original_pos.x
		cell_size = Grid.CELL_SIZE.x
	else:
		offset = current_pos.y - original_pos.y
		cell_size = Grid.CELL_SIZE.y

	return int(round(offset / cell_size))


func _sync_visuals_to_grid() -> void:
	for row in range(Grid.ROWS):
		for col in range(Grid.COLS):
			var tile := grid.get_tile(row, col)
			if tile:
				tile.position = grid.grid_to_world(row, col)


func _clear_drag_state() -> void:
	_drag_axis = InputHandler.DragAxis.NONE
	_drag_index = -1
	_original_positions.clear()


func _check_any_match() -> bool:
	for row in range(Grid.ROWS):
		for col in range(Grid.COLS):
			if _has_match_at(row, col):
				return true
	return false


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
