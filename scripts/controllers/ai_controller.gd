class_name AIController
extends Node

signal move_executed(move: Move)

@export var decision_delay: float = 1.0
@export var look_ahead: int = 1
@export var randomness: float = 0.2

var board: BoardManager
var match_detector: MatchDetector

var _decision_timer: float = 0.0
var _enabled: bool = false
var _tile_data_cache: Dictionary = {}


class Move:
	var axis: InputHandler.DragAxis
	var index: int
	var offset: int
	var score: float = 0.0

	func _init(a: InputHandler.DragAxis, i: int, o: int) -> void:
		axis = a
		index = i
		offset = o


func _ready() -> void:
	_load_tile_data()


func setup(board_manager: BoardManager, detector: MatchDetector) -> void:
	board = board_manager
	match_detector = detector
	_decision_timer = decision_delay


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if enabled:
		_decision_timer = decision_delay


func _process(delta: float) -> void:
	if not _enabled or not board or not match_detector:
		return

	if board.get_state() != BoardManager.BoardState.IDLE:
		return

	_decision_timer -= delta
	if _decision_timer <= 0:
		_decision_timer = decision_delay
		_make_decision()


func _make_decision() -> void:
	var moves := evaluate_all_moves()
	if moves.size() > 0:
		var move := select_move(moves)
		execute_move(move)


func evaluate_all_moves() -> Array[Move]:
	var valid_moves: Array[Move] = []

	# Evaluate row moves
	for row in range(Grid.ROWS):
		for offset in range(1, Grid.COLS):
			# Positive offset
			var move_pos := Move.new(InputHandler.DragAxis.HORIZONTAL, row, offset)
			move_pos.score = evaluate_move(move_pos)
			if move_pos.score > 0:
				valid_moves.append(move_pos)

			# Negative offset
			var move_neg := Move.new(InputHandler.DragAxis.HORIZONTAL, row, -offset)
			move_neg.score = evaluate_move(move_neg)
			if move_neg.score > 0:
				valid_moves.append(move_neg)

	# Evaluate column moves
	for col in range(Grid.COLS):
		for offset in range(1, Grid.ROWS):
			# Positive offset
			var move_pos := Move.new(InputHandler.DragAxis.VERTICAL, col, offset)
			move_pos.score = evaluate_move(move_pos)
			if move_pos.score > 0:
				valid_moves.append(move_pos)

			# Negative offset
			var move_neg := Move.new(InputHandler.DragAxis.VERTICAL, col, -offset)
			move_neg.score = evaluate_move(move_neg)
			if move_neg.score > 0:
				valid_moves.append(move_neg)

	return valid_moves


func evaluate_move(move: Move) -> float:
	var grid := board.grid

	# Temporarily apply the move
	if move.axis == InputHandler.DragAxis.HORIZONTAL:
		grid.shift_row(move.index, move.offset)
	else:
		grid.shift_column(move.index, move.offset)

	# Find matches
	var matches := match_detector.find_matches(grid)

	# Revert the move
	if move.axis == InputHandler.DragAxis.HORIZONTAL:
		grid.shift_row(move.index, -move.offset)
	else:
		grid.shift_column(move.index, -move.offset)

	if matches.is_empty():
		return 0.0

	var score := 0.0
	var match_count := matches.size()

	for match_result in matches:
		var value := float(_get_effect_value(match_result.tile_type, match_result.count))

		# Sword bonus - prioritize damage
		if match_result.tile_type == TileTypes.Type.SWORD:
			value *= 1.5

		# Lightning bonus - stun is valuable
		if match_result.tile_type == TileTypes.Type.LIGHTNING:
			value *= 1.3

		score += value

	# Multi-match bonus
	if match_count > 1:
		score *= 1.0 + (0.2 * (match_count - 1))

	return score


func select_move(moves: Array[Move]) -> Move:
	if moves.is_empty():
		return null

	# Sort by score descending
	moves.sort_custom(_compare_moves_by_score)

	# Randomness check - pick from top moves instead of best
	if randf() < randomness and moves.size() > 1:
		var top_count := mini(3, moves.size())
		return moves[randi() % top_count]

	return moves[0]


func execute_move(move: Move) -> void:
	if not move or not board:
		return

	# Apply the shift directly to the grid
	if move.axis == InputHandler.DragAxis.HORIZONTAL:
		board.grid.shift_row(move.index, move.offset)
	else:
		board.grid.shift_column(move.index, move.offset)

	# Sync visuals
	_sync_board_visuals()

	# Trigger match processing
	board.set_state(BoardManager.BoardState.RESOLVING)
	var matches := match_detector.find_matches(board.grid)
	if matches.size() > 0:
		board._cascade_handler.process_matches(matches)
	else:
		board.set_state(BoardManager.BoardState.IDLE)

	move_executed.emit(move)


func set_difficulty_easy() -> void:
	decision_delay = 2.0
	look_ahead = 0
	randomness = 0.5


func set_difficulty_medium() -> void:
	decision_delay = 1.0
	look_ahead = 1
	randomness = 0.2


func set_difficulty_hard() -> void:
	decision_delay = 0.5
	look_ahead = 2
	randomness = 0.05


func _compare_moves_by_score(a: Move, b: Move) -> bool:
	return a.score > b.score


func _sync_board_visuals() -> void:
	for row in range(Grid.ROWS):
		for col in range(Grid.COLS):
			var tile := board.grid.get_tile(row, col)
			if tile:
				tile.position = board.grid.grid_to_world(row, col)


func _load_tile_data() -> void:
	_tile_data_cache[TileTypes.Type.SWORD] = preload("res://resources/tiles/sword.tres")
	_tile_data_cache[TileTypes.Type.SHIELD] = preload("res://resources/tiles/shield.tres")
	_tile_data_cache[TileTypes.Type.POTION] = preload("res://resources/tiles/potion.tres")
	_tile_data_cache[TileTypes.Type.LIGHTNING] = preload("res://resources/tiles/lightning.tres")
	_tile_data_cache[TileTypes.Type.FILLER] = preload("res://resources/tiles/filler.tres")


func _get_effect_value(tile_type: TileTypes.Type, count: int) -> int:
	if _tile_data_cache.has(tile_type):
		var tile_data: PuzzleTileData = _tile_data_cache[tile_type]
		return tile_data.get_value(count)
	return 0
