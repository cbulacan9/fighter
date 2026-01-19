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
			if _click_pet():
				_pet_click_timer = _pet_click_delay
				return  # Successfully clicked, wait for next cycle

		# Priority 2: Check for ultimate activation
		if _should_use_ultimate():
			if _activate_ultimate():
				return  # Successfully clicked, wait for next cycle

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


## Multi-tree combo-aware move evaluation for Hunter character.
## Uses the new SequenceTracker multi-tree system where multiple combo trees
## can be active simultaneously and advance/die independently.
func _evaluate_sequence_moves() -> Array[Move]:
	var valid_moves: Array[Move] = []

	if not _sequence_tracker:
		return _evaluate_standard_moves()

	# Evaluate row moves
	for row in range(Grid.ROWS):
		for offset in range(1, Grid.COLS):
			# Positive offset
			var move_pos := Move.new(InputHandler.DragAxis.HORIZONTAL, row, offset)
			move_pos.score = _score_hunter_combo_move(move_pos)
			if move_pos.score > 0:
				valid_moves.append(move_pos)

			# Negative offset
			var move_neg := Move.new(InputHandler.DragAxis.HORIZONTAL, row, -offset)
			move_neg.score = _score_hunter_combo_move(move_neg)
			if move_neg.score > 0:
				valid_moves.append(move_neg)

	# Evaluate column moves
	for col in range(Grid.COLS):
		for offset in range(1, Grid.ROWS):
			# Positive offset
			var move_pos := Move.new(InputHandler.DragAxis.VERTICAL, col, offset)
			move_pos.score = _score_hunter_combo_move(move_pos)
			if move_pos.score > 0:
				valid_moves.append(move_pos)

			# Negative offset
			var move_neg := Move.new(InputHandler.DragAxis.VERTICAL, col, -offset)
			move_neg.score = _score_hunter_combo_move(move_neg)
			if move_neg.score > 0:
				valid_moves.append(move_neg)

	return valid_moves


## Scores a move using the multi-tree combo system for Hunter.
## Evaluates both base match value and combo tree advancement potential.
func _score_hunter_combo_move(move: Move) -> float:
	# Get base score from standard evaluation
	var base_score := evaluate_move(move)

	# Apply sequence awareness (sometimes ignore sequence scoring based on difficulty)
	if randf() > _sequence_awareness:
		return base_score

	if base_score <= 0:
		return 0.0

	# Add Hunter combo value based on multi-tree system
	var combo_value := _evaluate_hunter_combo_value(move, board)

	return base_score + combo_value


## Evaluates a move's value for Hunter combo building using the multi-tree system.
## Considers both advancing existing trees and starting new ones.
func _evaluate_hunter_combo_value(move: Move, board_mgr: BoardManager) -> float:
	var score := 0.0

	if not _sequence_tracker:
		return score

	# Simulate which tile types would be matched by this move
	var simulated_types := _simulate_move_match_types(move, board_mgr)

	if simulated_types.is_empty():
		return score

	# Score tree advancement - advancing existing trees is valuable
	var active_trees := _sequence_tracker.get_active_trees()
	var advancing_tree_patterns: Array[SequencePattern] = []

	for tree in active_trees:
		var next_required := tree.next_required()
		if next_required >= 0 and next_required in simulated_types:
			# Reward advancing trees - more for trees closer to completion
			var pattern_length: int = tree.pattern.pattern.size()
			var completion_ratio := float(tree.progress) / float(pattern_length)
			# Base 10 points + up to 20 more based on how close to completion
			score += 10.0 + (completion_ratio * 20.0)
			advancing_tree_patterns.append(tree.pattern)

			# Bonus for completing a tree (last tile needed)
			if tree.progress + 1 >= pattern_length:
				score += 25.0  # Completion bonus
		else:
			# Penalty for killing an active tree (move doesn't have required tile)
			# Only penalize if there are matches that would trigger tree evaluation
			if not simulated_types.is_empty():
				var tree_progress_ratio := float(tree.progress) / float(tree.pattern.pattern.size())
				# More penalty for killing trees that have more progress
				score -= 5.0 + (tree_progress_ratio * 15.0)

	# Score starting new trees (only for patterns not already advancing)
	var valid_patterns := _sequence_tracker.get_valid_patterns()
	for pattern in valid_patterns:
		if pattern.pattern.is_empty():
			continue

		var first_tile: int = pattern.pattern[0]
		if first_tile in simulated_types:
			# Check if we're already advancing this pattern
			var already_advancing := false
			for advancing_pattern in advancing_tree_patterns:
				if advancing_pattern.sequence_id == pattern.sequence_id:
					already_advancing = true
					break

			if not already_advancing:
				# Starting a new tree is worth some points
				score += 5.0

	return score


## Simulates what tile types would be in the initiating matches for a move.
## Only considers the direct matches from the move, not cascades.
func _simulate_move_match_types(move: Move, board_mgr: BoardManager) -> Array[int]:
	var types: Array[int] = []

	if not board_mgr or not board_mgr.grid:
		return types

	var grid := board_mgr.grid

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

	# Extract unique tile types from matches
	for match_result in matches:
		var tile_type: int = match_result.tile_type
		if tile_type not in types:
			types.append(tile_type)

	return types


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

	# Store original positions for animation
	var tiles_to_animate: Array[Dictionary] = []
	if move.axis == InputHandler.DragAxis.HORIZONTAL:
		for col in range(Grid.COLS):
			var tile: Tile = board.grid.get_tile(move.index, col)
			if tile:
				tiles_to_animate.append({
					"tile": tile,
					"from": tile.position
				})
	else:
		for row in range(Grid.ROWS):
			var tile: Tile = board.grid.get_tile(row, move.index)
			if tile:
				tiles_to_animate.append({
					"tile": tile,
					"from": tile.position
				})

	# Apply the shift to the grid data
	if move.axis == InputHandler.DragAxis.HORIZONTAL:
		board.grid.shift_row(move.index, move.offset)
	else:
		board.grid.shift_column(move.index, move.offset)

	# Calculate target positions and animate
	_animate_move(tiles_to_animate, move)

	move_executed.emit(move)


func _animate_move(tiles_data: Array[Dictionary], _move: Move) -> void:
	## Animates tiles to their new positions, then processes matches
	const ANIM_DURATION := 0.15

	var tween := board.create_tween()
	tween.set_parallel(true)

	# Find each tile's new position in the grid and animate to it
	for row in range(Grid.ROWS):
		for col in range(Grid.COLS):
			var tile: Tile = board.grid.get_tile(row, col)
			if not tile or not is_instance_valid(tile):
				continue

			var target_pos: Vector2 = board.grid.grid_to_world(row, col)

			# Only animate if position changed
			if tile.position.distance_to(target_pos) > 1.0:
				tween.tween_property(tile, "position", target_pos, ANIM_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			else:
				tile.position = target_pos

			# Update grid_position
			tile.grid_position = Vector2i(row, col)

	# After animation completes, process matches
	tween.set_parallel(false)
	tween.tween_callback(_on_move_animation_complete)


func _on_move_animation_complete() -> void:
	## Called when move animation finishes - triggers match processing
	if not board or not match_detector:
		return

	board.set_state(BoardManager.BoardState.RESOLVING)
	var matches := match_detector.find_matches(board.grid)
	if matches.size() > 0:
		board._cascade_handler.process_matches(matches)
	else:
		board.set_state(BoardManager.BoardState.IDLE)


func set_difficulty_easy() -> void:
	_difficulty = Difficulty.EASY
	decision_delay = 6.0
	look_ahead = 0
	randomness = 0.7
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
			_sequence_awareness = 0.1  # Almost never completes sequences
			_pet_click_delay = 2.5
			decision_delay = 3.0
			look_ahead = 0
			randomness = 0.7  # Very random/suboptimal moves

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

## Determines if the AI should click a Pet tile (legacy or Hunter-style).
## For Hunter with multi-tree system, this checks for clickable Hunter pet tiles.
## For legacy characters, this checks for banked sequences with the old Pet tile.
func _should_click_pet() -> bool:
	# First, check for Hunter-style pet tiles (BEAR_PET, HAWK_PET, SNAKE_PET)
	if _consider_hunter_pet_clicks():
		return true

	# Legacy path: check for banked sequences with classic Pet tile
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


## Clicks the Pet tile to activate a banked sequence (legacy or Hunter-style)
## Returns true if a pet was successfully clicked
func _click_pet() -> bool:
	if not board or board.get_state() != BoardManager.BoardState.IDLE:
		return false

	# First, try to click Hunter-style pet tiles
	var hunter_pets := _get_clickable_hunter_pet_tiles()
	if not hunter_pets.is_empty():
		# Find the best pet to click based on difficulty
		for pet_tile in hunter_pets:
			var pet_type: int = pet_tile.tile_data.tile_type
			if _should_click_hunter_pet(pet_type):
				board._on_tile_clicked(pet_tile)
				return true

	# Legacy path: click classic Pet tile
	var pet_tiles := _get_tiles_of_type(TileTypes.Type.PET)
	if pet_tiles.size() > 0:
		# Simulate a click on the Pet tile through BoardManager
		board._on_tile_clicked(pet_tiles[0])
		return true

	return false


## Checks if any Hunter pet tiles should be clicked this turn.
## Returns true if there's a pet tile that should be activated based on difficulty.
func _consider_hunter_pet_clicks() -> bool:
	var hunter_pets := _get_clickable_hunter_pet_tiles()
	if hunter_pets.is_empty():
		return false

	# Check each pet tile to see if we should click it
	for pet_tile in hunter_pets:
		var pet_type: int = pet_tile.tile_data.tile_type
		if _should_click_hunter_pet(pet_type):
			return true

	return false


## Decides whether AI should click a Hunter Pet tile based on difficulty.
## Uses strategic timing for harder difficulties.
func _should_click_hunter_pet(pet_type: int) -> bool:
	var fighter := _get_owner_fighter()
	var enemy := _get_enemy_fighter()

	match _difficulty:
		Difficulty.EASY:
			# Click immediately when available - no strategy
			return true

		Difficulty.MEDIUM:
			# Click based on basic situation analysis
			match pet_type:
				TileTypes.Type.BEAR_PET:
					# Damage is usually good
					return true
				TileTypes.Type.HAWK_PET:
					# Board disruption - use when available
					return true
				TileTypes.Type.SNAKE_PET:
					# Use for healing when HP below 50% or to cleanse poison
					if fighter:
						if fighter.has_status(StatusTypes.StatusType.POISON):
							return true
						return fighter.current_hp < fighter.max_hp * 0.5
					return true

		Difficulty.HARD:
			# Strategic timing based on game state
			match pet_type:
				TileTypes.Type.BEAR_PET:
					# Save for when enemy has low armor for maximum damage
					if enemy:
						return enemy.armor < 10
					return true
				TileTypes.Type.HAWK_PET:
					# Use for board disruption - could analyze enemy board state
					# For now, use when enemy is doing well
					if enemy and fighter:
						# Use when enemy has more HP percentage than us
						var our_hp_pct := fighter.get_hp_percent()
						var enemy_hp_pct := enemy.get_hp_percent()
						return enemy_hp_pct >= our_hp_pct
					return true
				TileTypes.Type.SNAKE_PET:
					# Use when HP below 40% or poisoned
					if fighter:
						if fighter.has_status(StatusTypes.StatusType.POISON):
							return true
						return fighter.current_hp < fighter.max_hp * 0.4
					return true

	# Default: click when available
	return true


## Gets all clickable Hunter pet tiles (BEAR_PET, HAWK_PET, SNAKE_PET) on the board.
## Only returns tiles that can actually be clicked (have enough mana).
func _get_clickable_hunter_pet_tiles() -> Array[Tile]:
	if not board:
		return []

	# Check if we have enough mana to activate pets (cost is 33)
	const PET_MANA_COST := 33
	var fighter := _get_owner_fighter()
	if fighter and fighter.mana_system:
		var current_mana: int = fighter.mana_system.get_mana(fighter, 0)
		if current_mana < PET_MANA_COST:
			return []  # Not enough mana to click any pet

	# Use BoardManager's helper method if available
	if board.has_method("get_hunter_pet_tiles"):
		return board.get_hunter_pet_tiles()

	# Fallback implementation
	var pet_tiles: Array[Tile] = []

	if not board.grid:
		return pet_tiles

	var hunter_pet_types := [
		TileTypes.Type.BEAR_PET,
		TileTypes.Type.HAWK_PET,
		TileTypes.Type.SNAKE_PET
	]

	for row in range(Grid.ROWS):
		for col in range(Grid.COLS):
			var tile: Tile = board.grid.get_tile(row, col)
			if tile and tile.tile_data:
				if tile.tile_data.tile_type in hunter_pet_types:
					# Check if the tile is actually clickable
					if tile.tile_data.is_clickable:
						pet_tiles.append(tile)

	return pet_tiles


## Gets the enemy fighter from combat manager
func _get_enemy_fighter() -> Fighter:
	if not _combat_manager:
		return null

	# The AI controls the enemy board, so its enemy is the player
	if _owner_fighter == _combat_manager.enemy_fighter:
		return _combat_manager.player_fighter
	else:
		return _combat_manager.enemy_fighter


# --- Ultimate Activation Decision Logic ---

## Determines if the AI should activate their ultimate ability (click Alpha Command tile)
func _should_use_ultimate() -> bool:
	if not board:
		return false

	# Check if Alpha Command tile is on the board
	var alpha_tile := _get_alpha_command_tile()
	if not alpha_tile:
		return false

	# Use ultimate when we have pet tiles to boost (maximize Hunter potential)
	var pet_tiles := _get_clickable_hunter_pet_tiles()
	if not pet_tiles.is_empty():
		return true

	# Consider using ultimate when low on health for self-preservation
	if _owner_fighter and _owner_fighter.get_hp_percent() < 0.3:
		return true

	# Default: use it when available (it's powerful!)
	return true


## Activates the ultimate ability by clicking the Alpha Command tile
## Returns true if the click was successful (tile was consumed)
func _activate_ultimate() -> bool:
	if not board:
		return false

	# Can only click when board is IDLE
	if board.get_state() != BoardManager.BoardState.IDLE:
		return false

	var alpha_tile := _get_alpha_command_tile()
	if not alpha_tile:
		return false

	board._on_tile_clicked(alpha_tile)

	# Check if the tile was actually consumed (click succeeded)
	var tile_after := _get_alpha_command_tile()
	return tile_after == null  # True if tile was consumed


## Gets the Alpha Command tile if it exists on the board
func _get_alpha_command_tile() -> Tile:
	if not board or not board.grid:
		return null

	for row in range(Grid.ROWS):
		for col in range(Grid.COLS):
			var tile: Tile = board.grid.get_tile(row, col)
			if tile and tile.tile_data:
				if tile.tile_data.tile_type == TileTypes.Type.ALPHA_COMMAND:
					return tile

	return null


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
