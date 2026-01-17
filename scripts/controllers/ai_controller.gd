class_name AIController
extends Node

signal move_executed(move: Move)

enum Difficulty { EASY, MEDIUM, HARD }

@export var decision_delay: float = 1.0
@export var look_ahead: int = 1
@export var randomness: float = 0.2

var board: BoardManager
var match_detector: MatchDetector

# Character and sequence tracking for Hunter support
var _character_data: CharacterData
var _sequence_tracker: SequenceTracker
var _owner_fighter: Fighter
var _combat_manager: CombatManager

# Difficulty and sequence-related settings
var _difficulty: Difficulty = Difficulty.MEDIUM
var _sequence_awareness: float = 0.6  # 0.0-1.0, how often AI considers sequences
var _pet_click_delay: float = 1.0  # Delay before clicking pet
var _pet_click_timer: float = 0.0  # Timer for pet click delay

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

	# Get sequence tracker from board if available
	if board:
		_sequence_tracker = board.sequence_tracker


## Sets the character data for this AI controller.
## This enables character-specific AI behavior like sequence building for Hunter.
func set_character(char_data: CharacterData) -> void:
	_character_data = char_data

	# Update sequence tracker from board if character has sequences
	if board and char_data and char_data.has_sequences():
		_sequence_tracker = board.sequence_tracker


## Sets the owner fighter reference for status effect checks.
func set_owner_fighter(fighter: Fighter) -> void:
	_owner_fighter = fighter


## Sets the combat manager reference for ultimate activation.
func set_combat_manager(combat_mgr: CombatManager) -> void:
	_combat_manager = combat_mgr


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if enabled:
		_decision_timer = decision_delay


func _process(delta: float) -> void:
	if not _enabled or not board or not match_detector:
		return

	if board.get_state() != BoardManager.BoardState.IDLE:
		return

	# Update pet click timer
	if _pet_click_timer > 0:
		_pet_click_timer -= delta

	_decision_timer -= delta
	if _decision_timer <= 0:
		_decision_timer = decision_delay

		# Priority 1: Check for Pet click (sequence completion)
		if _should_click_pet() and _pet_click_timer <= 0:
			_click_pet()
			_pet_click_timer = _pet_click_delay
			return

		# Priority 2: Check for ultimate activation
		if _should_use_ultimate():
			_activate_ultimate()
			return

		# Priority 3: Normal move evaluation
		_make_decision()


func _make_decision() -> void:
	var moves := evaluate_all_moves()
	if moves.size() > 0:
		var move := select_move(moves)
		execute_move(move)


func evaluate_all_moves() -> Array[Move]:
	# Use sequence-aware evaluation if character has sequences
	if _character_data and _character_data.has_sequences() and _sequence_tracker:
		return _evaluate_sequence_moves()

	return _evaluate_standard_moves()


## Standard move evaluation for non-Hunter characters
func _evaluate_standard_moves() -> Array[Move]:
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


## Sequence-aware move evaluation for Hunter character
func _evaluate_sequence_moves() -> Array[Move]:
	var valid_moves: Array[Move] = []

	if not _sequence_tracker:
		return _evaluate_standard_moves()

	# Get current sequence state
	var current: Array[int] = _sequence_tracker.get_current_sequence()
	var possible: Array[SequencePattern] = _sequence_tracker._get_possible_completions()

	# Evaluate row moves
	for row in range(Grid.ROWS):
		for offset in range(1, Grid.COLS):
			# Positive offset
			var move_pos := Move.new(InputHandler.DragAxis.HORIZONTAL, row, offset)
			move_pos.score = _score_sequence_move(move_pos, current, possible)
			if move_pos.score > 0:
				valid_moves.append(move_pos)

			# Negative offset
			var move_neg := Move.new(InputHandler.DragAxis.HORIZONTAL, row, -offset)
			move_neg.score = _score_sequence_move(move_neg, current, possible)
			if move_neg.score > 0:
				valid_moves.append(move_neg)

	# Evaluate column moves
	for col in range(Grid.COLS):
		for offset in range(1, Grid.ROWS):
			# Positive offset
			var move_pos := Move.new(InputHandler.DragAxis.VERTICAL, col, offset)
			move_pos.score = _score_sequence_move(move_pos, current, possible)
			if move_pos.score > 0:
				valid_moves.append(move_pos)

			# Negative offset
			var move_neg := Move.new(InputHandler.DragAxis.VERTICAL, col, -offset)
			move_neg.score = _score_sequence_move(move_neg, current, possible)
			if move_neg.score > 0:
				valid_moves.append(move_neg)

	return valid_moves


## Scores a move considering sequence building for Hunter
func _score_sequence_move(move: Move, current: Array[int], possible: Array[SequencePattern]) -> float:
	# Get base score from standard evaluation
	var base_score := evaluate_move(move)

	# Apply sequence awareness (sometimes ignore sequence scoring based on difficulty)
	if randf() > _sequence_awareness:
		return base_score

	if base_score <= 0:
		return 0.0

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

	var sequence_bonus: float = 0.0
	var breaks_sequence: bool = false
	var next_index := current.size()

	for match_result in matches:
		var tile_type: int = match_result.tile_type

		# Check if this advances any sequence
		var advances_sequence := false
		for pattern in possible:
			if next_index < pattern.pattern.size():
				if tile_type == pattern.pattern[next_index]:
					sequence_bonus += 50.0  # Bonus for advancing sequence
					advances_sequence = true
					break

		# Check if this would break the sequence (wrong tile type when building)
		if not advances_sequence and not current.is_empty() and not possible.is_empty():
			# Only penalize if we're currently building and this isn't the expected type
			var expected_types: Array[int] = []
			for pattern in possible:
				if next_index < pattern.pattern.size():
					expected_types.append(pattern.pattern[next_index])

			if not expected_types.is_empty() and not (tile_type in expected_types):
				breaks_sequence = true

	# Apply bonuses and penalties
	var final_score := base_score + sequence_bonus

	# Penalty for breaking sequence
	if breaks_sequence:
		final_score -= 100.0

	return maxf(0.0, final_score)


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
	_difficulty = Difficulty.EASY
	decision_delay = 2.0
	look_ahead = 0
	randomness = 0.5
	_apply_difficulty_modifiers()


func set_difficulty_medium() -> void:
	_difficulty = Difficulty.MEDIUM
	decision_delay = 1.0
	look_ahead = 1
	randomness = 0.2
	_apply_difficulty_modifiers()


func set_difficulty_hard() -> void:
	_difficulty = Difficulty.HARD
	decision_delay = 0.5
	look_ahead = 2
	randomness = 0.05
	_apply_difficulty_modifiers()


## Sets the difficulty level and applies modifiers
func set_difficulty(difficulty: Difficulty) -> void:
	_difficulty = difficulty
	_apply_difficulty_modifiers()


## Applies difficulty-specific modifiers for sequence play
func _apply_difficulty_modifiers() -> void:
	match _difficulty:
		Difficulty.EASY:
			_sequence_awareness = 0.3  # Rarely completes sequences
			_pet_click_delay = 1.5
			decision_delay = 2.0
			look_ahead = 0
			randomness = 0.5

		Difficulty.MEDIUM:
			_sequence_awareness = 0.6
			_pet_click_delay = 1.0
			decision_delay = 1.0
			look_ahead = 1
			randomness = 0.2

		Difficulty.HARD:
			_sequence_awareness = 0.9  # Actively builds sequences
			_pet_click_delay = 0.5
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


# --- Pet Click Decision Logic ---

## Determines if the AI should click the Pet tile to activate a banked sequence
func _should_click_pet() -> bool:
	if not _sequence_tracker:
		return false

	if not _sequence_tracker.has_completable_sequence():
		return false

	var banked: Array[SequencePattern] = _sequence_tracker.get_banked_sequences()
	if banked.is_empty():
		return false

	# Get the first banked sequence for decision making
	var pattern: SequencePattern = banked[0]

	# Always use Snake if we're poisoned (cleanse self)
	if pattern.sequence_id == "snake":
		if _owner_fighter and _owner_fighter.has_status(StatusTypes.StatusType.POISON):
			return true

	# Use Hawk if beneficial (usually good for damage/tile replacement)
	if pattern.sequence_id == "hawk":
		return true

	# Use Bear for damage
	if pattern.sequence_id == "bear":
		return true

	# Default: use when available
	return true


## Clicks the Pet tile to activate a banked sequence
func _click_pet() -> void:
	var pet_tiles := _get_tiles_of_type(TileTypes.Type.PET)
	if pet_tiles.size() > 0:
		# Simulate a click on the Pet tile through BoardManager
		board._on_tile_clicked(pet_tiles[0])


# --- Ultimate Activation Decision Logic ---

## Determines if the AI should activate their ultimate ability
func _should_use_ultimate() -> bool:
	if not _owner_fighter:
		return false

	if not _combat_manager:
		return false

	var mana_system: ManaSystem = _combat_manager.mana_system
	if not mana_system or not mana_system.can_use_ultimate(_owner_fighter):
		return false

	# Use ultimate when we have sequences banked (maximize Hunter potential)
	if _sequence_tracker and _sequence_tracker.has_completable_sequence():
		return true

	# Consider using ultimate when low on health for self-preservation
	if _owner_fighter.get_hp_percent() < 0.3:
		return true

	return false


## Activates the ultimate ability
func _activate_ultimate() -> void:
	if not _combat_manager or not _owner_fighter:
		return

	_combat_manager.activate_ultimate(_owner_fighter)


# --- Helper Methods ---

## Gets the owner fighter (from board or direct reference)
func _get_owner_fighter() -> Fighter:
	if _owner_fighter:
		return _owner_fighter
	if board:
		return board._get_owner_fighter()
	return null


## Gets the combat manager (from board or direct reference)
func _get_combat_manager() -> CombatManager:
	if _combat_manager:
		return _combat_manager
	if board:
		return board._get_combat_manager()
	return null


## Gets all tiles of a specific type from the board
func _get_tiles_of_type(tile_type: TileTypes.Type) -> Array[Tile]:
	var tiles: Array[Tile] = []

	if not board or not board.grid:
		return tiles

	for row in range(Grid.ROWS):
		for col in range(Grid.COLS):
			var tile: Tile = board.grid.get_tile(row, col)
			if tile and tile.tile_data and tile.tile_data.tile_type == tile_type:
				tiles.append(tile)

	return tiles


## Gets the current difficulty level
func get_difficulty() -> Difficulty:
	return _difficulty


## Gets the sequence awareness level (0.0-1.0)
func get_sequence_awareness() -> float:
	return _sequence_awareness


## Sets the sequence awareness level (0.0-1.0)
func set_sequence_awareness(awareness: float) -> void:
	_sequence_awareness = clampf(awareness, 0.0, 1.0)
