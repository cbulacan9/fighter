class_name BoardManager
extends Node2D

signal state_changed(new_state: BoardState)
signal matches_resolved(result: CascadeHandler.CascadeResult)
signal immediate_matches(matches: Array)  # Fires immediately when matches detected, before animations
signal ready_for_input
signal snap_back_started
signal snap_back_finished

# Sequence tracking signals
signal sequence_progressed(current: Array, possible: Array)
signal sequence_completed(pattern: SequencePattern)
signal sequence_banked(pattern: SequencePattern, stacks: int)
signal sequence_broken()
signal sequence_activated(pattern: SequencePattern, stacks: int)

# Click activation signals
signal tile_activated(tile: Tile, effect: EffectData)
signal tile_click_failed(tile: Tile, reason: String)

# Tile hiding signals (for Smoke Bomb effects)
signal tiles_hidden(positions: Array, duration: float)
signal tiles_revealed(positions: Array)

# PET ability activation signal (for UI feedback)
signal pet_ability_activated(pattern: SequencePattern, stacks: int, is_player: bool)

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
var _match_detector: MatchDetector
var _tile_spawner: TileSpawner
var _cascade_handler: CascadeHandler
var _stun_timer: float = 0.0

# Sequence tracking
var sequence_tracker: SequenceTracker

# Pet spawning (Hunter combo system)
var pet_spawner: PetSpawner
var _pending_pet_spawns: Array[Dictionary] = []  # Queue of {pet_type, column} to spawn after cascade

# Click handling
var _click_condition_checker: ClickConditionChecker
var _owner_fighter: Fighter  # Reference to the fighter who owns this board
var _combat_manager: CombatManager  # Reference for forwarding tile activations

# Tile hiding state (for Smoke Bomb effects)
var _hidden_tiles: Dictionary = {}  # {Vector2i: remaining_time}

# Character data for character-based initialization
var _character_data: CharacterData

# Drag preview state
var _drag_axis: InputHandler.DragAxis = InputHandler.DragAxis.NONE
var _drag_index: int = -1
var _original_positions: Dictionary = {}
var _snap_back_tween: Tween

# Clickable highlight optimization - dirty flag pattern
var _clickable_dirty: bool = true

# Alpha Command tile tracking (only one on board at a time)
var _alpha_command_on_board: bool = false
var _alpha_command_tile_data: PuzzleTileData
const ULTIMATE_COOLDOWN_DURATION: float = 60.0  # 1 minute cooldown after using ultimate

# Predator's Trance tile tracking (Assassin ultimate)
var _predators_trance_on_board: bool = false
var _predators_trance_tile_data: PuzzleTileData
const PREDATORS_TRANCE_COOLDOWN: float = 20.0  # 20 second cooldown for Assassin ultimate

# Invincibility tile tracking (Mirror Warden ultimate)
var _invincibility_on_board: bool = false
var _invincibility_tile_data: PuzzleTileData


func _ready() -> void:
	# Add to board_managers group for effect processor to find boards
	add_to_group("board_managers")

	grid = $ClipContainer/Grid
	_tiles_container = $ClipContainer/Grid/Tiles
	_input_handler = $InputHandler
	_match_detector = $MatchDetector
	_tile_spawner = $TileSpawner
	_cascade_handler = $CascadeHandler
	_setup_systems()


func _process(delta: float) -> void:
	if state == BoardState.STUNNED:
		_stun_timer -= delta
		if _stun_timer <= 0:
			set_state(BoardState.IDLE)

	# Tick click condition checker for cooldown timers
	if _click_condition_checker:
		_click_condition_checker.tick(delta)

	# Process hidden tile timers
	_process_hidden_tiles(delta)

	# Update clickable tile highlights only when dirty
	if _clickable_dirty:
		_update_clickable_highlights()
		_clickable_dirty = false


func _setup_systems() -> void:
	_input_handler.setup(grid, global_position)
	_input_handler.drag_started.connect(_on_drag_started)
	_input_handler.drag_moved.connect(_on_drag_moved)
	_input_handler.drag_ended.connect(_on_drag_ended)

	_cascade_handler.setup(grid, _tile_spawner, _match_detector, _tiles_container)
	_cascade_handler.cascade_complete.connect(_on_cascade_complete)
	_cascade_handler.matches_processed.connect(_on_matches_processed)
	_cascade_handler.tiles_fell.connect(_on_tiles_fell)

	# Set grid reference on tile spawner for spawn rules
	_tile_spawner.set_grid(grid)

	_setup_click_handling()


## Call this after the board position has been changed to update input handling
func update_input_position() -> void:
	if _input_handler and grid:
		_input_handler.setup(grid, global_position)


func _setup_click_handling() -> void:
	_click_condition_checker = ClickConditionChecker.new()

	# Connect input handler click signals
	if _input_handler:
		_input_handler.tile_clicked.connect(_on_tile_clicked)

	# Connect tile activation to forward to combat manager
	tile_activated.connect(_on_tile_activated)


func _setup_sequence_tracker(patterns: Array[SequencePattern]) -> void:
	if patterns.is_empty():
		sequence_tracker = null
		pet_spawner = null
		return

	sequence_tracker = SequenceTracker.new()
	sequence_tracker.setup(patterns)

	# Connect sequence tracker signals
	sequence_tracker.sequence_progressed.connect(_on_sequence_progressed)
	sequence_tracker.sequence_broken.connect(_on_sequence_broken)
	sequence_tracker.sequence_banked.connect(_on_sequence_banked)
	sequence_tracker.sequence_activated.connect(_on_sequence_activated)

	# Connect to click condition checker
	if _click_condition_checker:
		_click_condition_checker.set_sequence_tracker(sequence_tracker)

	# Setup PetSpawner for Hunter combo system
	_setup_pet_spawner(patterns)


func _setup_pet_spawner(patterns: Array[SequencePattern]) -> void:
	# Check if any pattern has a pet_type (Hunter-style combos)
	var has_pet_patterns := false
	for pattern in patterns:
		if pattern.pet_type >= 0:
			has_pet_patterns = true
			break

	if not has_pet_patterns:
		pet_spawner = null
		# Connect legacy sequence_completed signal for non-pet patterns
		if sequence_tracker and not sequence_tracker.sequence_completed.is_connected(_on_sequence_completed):
			sequence_tracker.sequence_completed.connect(_on_sequence_completed)
		return

	# Create PetSpawner
	pet_spawner = PetSpawner.new()
	pet_spawner.name = "PetSpawner"
	add_child(pet_spawner)

	# Connect SequenceTracker.sequence_completed -> PetSpawner.on_sequence_completed
	if sequence_tracker:
		sequence_tracker.sequence_completed.connect(pet_spawner.on_sequence_completed)

	# Connect PetSpawner.pet_spawned -> BoardManager to spawn the tile
	pet_spawner.pet_spawned.connect(_on_pet_spawned)


## Sets up spawn rules from character data
## Configures min/max tile counts for specialty tiles
func _setup_spawn_rules(char_data: CharacterData) -> void:
	if not _tile_spawner or not char_data:
		return

	# Clear existing rules
	_tile_spawner.clear_spawn_rules()

	# Setup rules for specialty tiles
	for tile_data in char_data.specialty_tiles:
		if tile_data:
			_tile_spawner.set_spawn_rules(tile_data)

	# Also check basic tiles for any with spawn rules
	for tile_data in char_data.basic_tiles:
		if tile_data and (tile_data.min_on_board > 0 or tile_data.max_on_board > 0):
			_tile_spawner.set_spawn_rules(tile_data)


func initialize(fighter: FighterData, is_player: bool) -> void:
	fighter_data = fighter
	is_player_controlled = is_player

	# Configure spawner with fighter weights
	if fighter_data and fighter_data.tile_weights:
		_tile_spawner.set_weights(fighter_data.tile_weights)

	# Setup sequence tracker if fighter has sequences
	if fighter_data and fighter_data.sequences.size() > 0:
		_setup_sequence_tracker(fighter_data.sequences)
	else:
		sequence_tracker = null

	grid.initialize()
	generate_initial_board()
	_input_handler.set_enabled(is_player)


## Initializes the board with character-specific data.
## Uses CharacterData for tile spawning configuration and sequences.
func initialize_with_character(char_data: CharacterData, is_player: bool) -> void:
	is_player_controlled = is_player
	_character_data = char_data

	# Setup tile spawner with character-specific weights and tiles
	if _tile_spawner and char_data:
		# Set spawn weights from character data
		_tile_spawner.set_weights(char_data.spawn_weights)

		# Set available tiles from character (basic + specialty)
		var all_tiles := char_data.get_all_tiles()
		if not all_tiles.is_empty():
			_tile_spawner.set_available_tiles(all_tiles)

		# Setup spawn rules for specialty tiles (min/max counts)
		_setup_spawn_rules(char_data)

	# Setup sequence tracker if character has sequences
	if char_data and char_data.has_sequences():
		_setup_sequence_tracker(char_data.sequences)
	else:
		sequence_tracker = null

	grid.initialize()
	generate_initial_board()
	_input_handler.set_enabled(is_player)


func generate_initial_board() -> void:
	_clear_all_tiles()

	for row in range(Grid.ROWS):
		for col in range(Grid.COLS):
			var tile := _tile_spawner.spawn_tile()
			tile.grid_position = Vector2i(row, col)
			_place_tile(tile, row, col)

	_remove_initial_matches()


func reset() -> void:
	"""Fully reset the board for a new match."""
	# Disconnect signals from previous fighter to prevent memory leaks
	_disconnect_fighter_signals()

	# Reset board state
	state = BoardState.IDLE

	# Reset sequence tracker
	if sequence_tracker:
		sequence_tracker.reset()

	# Reset pet spawner
	if pet_spawner:
		pet_spawner.reset()

	# Reset Predator's Trance cascade counter
	if _tile_spawner:
		_tile_spawner.reset_predators_trance()

	# Clear pending pet spawns from previous game
	_pending_pet_spawns.clear()

	# Clear any stun state
	_stun_timer = 0.0

	# Clear hidden tiles
	_hidden_tiles.clear()

	# Reset Alpha Command state
	_alpha_command_on_board = false

	# Reset Predator's Trance state
	_predators_trance_on_board = false

	# Reset Invincibility state
	_invincibility_on_board = false

	# Reset dirty flag to ensure highlights update
	_clickable_dirty = true

	# Re-enable input for player boards
	if _input_handler:
		_input_handler.set_enabled(is_player_controlled)

	# Generate fresh board
	generate_initial_board()


func _disconnect_fighter_signals() -> void:
	"""Disconnect signals from the owner fighter to prevent memory leaks."""
	if _owner_fighter:
		if _owner_fighter.mana_changed.is_connected(_on_fighter_mana_changed):
			_owner_fighter.mana_changed.disconnect(_on_fighter_mana_changed)
		if _owner_fighter.ultimate_ready.is_connected(_on_fighter_ultimate_ready):
			_owner_fighter.ultimate_ready.disconnect(_on_fighter_ultimate_ready)


func get_state() -> BoardState:
	return state


func set_state(new_state: BoardState) -> void:
	if state != new_state:
		state = new_state
		state_changed.emit(new_state)
		_clickable_dirty = true

		match new_state:
			BoardState.IDLE:
				_sync_visuals_to_grid()
				_clear_drag_state()
				_input_handler.set_enabled(is_player_controlled)
				_input_handler.set_clicks_enabled(is_player_controlled)
				ready_for_input.emit()
			BoardState.DRAGGING:
				pass  # Keep input enabled to track ongoing drag
			BoardState.RESOLVING:
				# Disable drags but allow clicks for pet activation during cascade
				_input_handler.set_enabled(false)
				_input_handler.set_clicks_enabled(is_player_controlled)
			BoardState.STUNNED:
				_input_handler.set_enabled(false)
				_input_handler.set_clicks_enabled(false)


func lock_input() -> void:
	if state == BoardState.IDLE:
		set_state(BoardState.RESOLVING)


func unlock_input() -> void:
	if state == BoardState.RESOLVING:
		set_state(BoardState.IDLE)


func disable_all_input() -> void:
	## Completely disables all input including clicks (for game over state)
	if _input_handler:
		_input_handler.set_enabled(false)
		_input_handler.set_clicks_enabled(false)


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
		_clear_drag_state()
		set_state(BoardState.IDLE)
		return

	if _drag_axis == InputHandler.DragAxis.HORIZONTAL:
		grid.shift_row(_drag_index, cells_moved)
	else:
		grid.shift_column(_drag_index, cells_moved)

	_sync_visuals_to_grid()
	_clear_drag_state()

	# Find and process matches
	set_state(BoardState.RESOLVING)
	var matches := _match_detector.find_matches(grid)
	if matches.size() > 0:
		_cascade_handler.process_matches(matches)
	else:
		set_state(BoardState.IDLE)


func revert_preview() -> void:
	_sync_visuals_to_grid()
	_clear_drag_state()


func check_move_validity() -> bool:
	var cells_moved := _calculate_cells_moved()
	if cells_moved == 0:
		return false

	return _match_detector.preview_match(grid, _drag_axis, _drag_index, cells_moved)


func animate_snap_back() -> void:
	snap_back_started.emit()

	if _original_positions.is_empty():
		_on_snap_back_finished()
		return

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


func _on_matches_processed(matches: Array[MatchDetector.MatchResult]) -> void:
	# Tag matches that contain hidden (smoke-obscured) tiles
	_tag_hidden_tile_matches(matches)

	# Clean up hidden tile tracking for matched positions
	_clear_hidden_tiles_at_matches(matches)

	# Emit immediately for combat effects (damage applied before animations)
	immediate_matches.emit(matches)

	# Process only PLAYER_INITIATED matches for sequence tracking
	# CASCADE matches should not advance combo trees
	if sequence_tracker:
		var initiating_types: Array[int] = []
		for match_result in matches:
			if match_result.origin == TileTypes.MatchOrigin.PLAYER_INITIATED:
				var tile_type: int = match_result.tile_type
				if tile_type not in initiating_types:
					initiating_types.append(tile_type)

		if initiating_types.size() > 0:
			sequence_tracker.process_initiating_matches(initiating_types)


func _on_cascade_complete(result: CascadeHandler.CascadeResult) -> void:
	# Note: Match recording is now handled immediately by _on_matches_processed
	# for more responsive UI updates

	# Process any pending pet spawns (Hunter combo system)
	# This must happen after cascade when there's space on the board,
	# but BEFORE _ensure_minimum_tiles fills empty spaces
	_process_pending_pet_spawns()

	# Ensure minimum tile counts are maintained after cascade
	_ensure_minimum_tiles()

	matches_resolved.emit(result)
	set_state(BoardState.IDLE)


func _on_tiles_fell(moves: Array[CascadeHandler.TileMove]) -> void:
	## Update hidden tile tracking when tiles move due to gravity.
	## This ensures smoke-obscured tiles stay hidden even after cascading.
	if _hidden_tiles.is_empty():
		return

	var updates: Dictionary = {}  # {old_pos: new_pos}

	for move in moves:
		var old_pos := Vector2i(move.from_row, move.col)
		var new_pos := Vector2i(move.to_row, move.col)

		if _hidden_tiles.has(old_pos):
			# This hidden tile moved - track the update
			updates[old_pos] = {"new_pos": new_pos, "time": _hidden_tiles[old_pos]}

	# Apply the position updates
	for old_pos in updates.keys():
		var update: Dictionary = updates[old_pos]
		_hidden_tiles.erase(old_pos)
		_hidden_tiles[update.new_pos] = update.time


# --- Sequence Signal Handlers ---

func _on_sequence_progressed(current: Array, possible: Array) -> void:
	sequence_progressed.emit(current, possible)
	_clickable_dirty = true


func _on_sequence_completed(pattern: SequencePattern) -> void:
	sequence_completed.emit(pattern)
	_clickable_dirty = true


func _on_sequence_banked(pattern: SequencePattern, stacks: int) -> void:
	sequence_banked.emit(pattern, stacks)
	_clickable_dirty = true


func _on_sequence_broken() -> void:
	sequence_broken.emit()
	_clickable_dirty = true


func _on_sequence_activated(pattern: SequencePattern, stacks: int) -> void:
	sequence_activated.emit(pattern, stacks)
	_clickable_dirty = true


# --- Pet Spawner Signal Handlers ---

func _on_pet_spawned(pet_type: int, column: int) -> void:
	## Queues a pet tile spawn. The actual spawn happens after the cascade completes
	## to ensure there's space on the board.
	_pending_pet_spawns.append({"pet_type": pet_type, "column": column})


## Actually spawns queued pet tiles after cascade is complete
func _process_pending_pet_spawns() -> void:
	if _pending_pet_spawns.is_empty():
		return

	# Track actual positions that have been used for pet spawns this cycle
	# This prevents multiple pets from spawning at the same position
	var used_positions: Array[Vector2i] = []

	for spawn_data in _pending_pet_spawns:
		var pet_type: int = spawn_data["pet_type"]
		var preferred_column: int = spawn_data["column"]

		var actual_pos := _spawn_pet_tile_at_available(pet_type, preferred_column, used_positions)
		if actual_pos.x >= 0:
			used_positions.append(actual_pos)

	_pending_pet_spawns.clear()


## Spawns a pet tile at an available position, avoiding used_positions
## Returns the actual position used, or Vector2i(-1, -1) if spawn failed
func _spawn_pet_tile_at_available(pet_type: int, preferred_column: int, used_positions: Array[Vector2i]) -> Vector2i:
	var tile_data := _get_pet_tile_data(pet_type)
	if not tile_data:
		push_warning("BoardManager: Could not find tile data for pet type %d" % pet_type)
		return Vector2i(-1, -1)

	# Find a valid position - prefer top tile, but any non-special tile will do
	var target_pos := _find_spawn_position(preferred_column, used_positions)

	if target_pos.x < 0:
		push_error("BoardManager: Cannot spawn pet tile - no valid position found!")
		return Vector2i(-1, -1)

	var target_row := target_pos.x
	var target_column := target_pos.y

	# Remove the existing tile at this position (if any)
	var existing_tile := grid.get_tile(target_row, target_column)
	if existing_tile:
		grid.set_tile(target_row, target_column, null)
		# Remove from parent immediately to prevent visual overlap
		if existing_tile.get_parent():
			existing_tile.get_parent().remove_child(existing_tile)
		existing_tile.queue_free()

	# Create the pet tile
	var tile: Tile = _tile_spawner.tile_scene.instantiate()
	tile.setup(tile_data, Vector2i(target_row, target_column))

	# Place the tile
	_place_tile(tile, target_row, target_column)

	# Confirm the spawn so PetSpawner updates its count
	if pet_spawner:
		pet_spawner.confirm_spawn(pet_type)

	return target_pos


## Finds a valid position for spawning a pet tile
## Avoids special tiles and already-used positions
func _find_spawn_position(preferred_column: int, used_positions: Array[Vector2i]) -> Vector2i:
	# Helper to check if position is valid
	var is_valid_pos := func(row: int, col: int) -> bool:
		var pos := Vector2i(row, col)
		if pos in used_positions:
			return false
		var tile := grid.get_tile(row, col)
		if not tile or not tile.tile_data:
			return false
		return not TileTypeHelper.is_special_tile(tile.tile_data.tile_type)

	# Try preferred column first - check top tile
	var row := _find_top_tile_row(preferred_column)
	if row >= 0 and is_valid_pos.call(row, preferred_column):
		return Vector2i(row, preferred_column)

	# Try other columns' top tiles
	for col in range(Grid.COLS):
		if col == preferred_column:
			continue
		row = _find_top_tile_row(col)
		if row >= 0 and is_valid_pos.call(row, col):
			return Vector2i(row, col)

	# If all top tiles are special/used, find ANY valid tile on the board
	for r in range(Grid.ROWS):
		for c in range(Grid.COLS):
			if is_valid_pos.call(r, c):
				return Vector2i(r, c)

	# Last resort: find empty space
	for col in range(Grid.COLS):
		for r in range(Grid.ROWS):
			var pos := Vector2i(r, col)
			if pos not in used_positions and grid.get_tile(r, col) == null:
				return pos

	return Vector2i(-1, -1)


## Helper to find the first empty row in a column (from top to bottom)
## Returns -1 if the column is full
func _find_empty_row_in_column(col: int) -> int:
	for row in range(Grid.ROWS):
		if grid.get_tile(row, col) == null:
			return row
	return -1


## Helper to find the top-most tile in a column (row 0 is top)
## Returns -1 if the column is empty
func _find_top_tile_row(col: int) -> int:
	for row in range(Grid.ROWS):
		if grid.get_tile(row, col) != null:
			return row
	return -1


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


# --- Click Handlers ---

func _on_tile_clicked(tile: Tile) -> void:
	# During RESOLVING state, only allow pet tile, Alpha Command, and ultimate tile clicks
	if state == BoardState.RESOLVING:
		if tile and tile.tile_data:
			var tile_type: TileTypes.Type = tile.tile_data.tile_type
			if TileTypeHelper.is_hunter_pet_type(tile_type) or tile_type == TileTypes.Type.ALPHA_COMMAND or tile_type == TileTypes.Type.PREDATORS_TRANCE or tile_type == TileTypes.Type.INVINCIBILITY_TILE:
				if _can_click_tile(tile):
					_activate_tile(tile)
					_input_handler.tile_click_attempted.emit(tile, true)
					return
		_input_handler.tile_click_attempted.emit(tile, false)
		tile_click_failed.emit(tile, "board_resolving")
		return

	# Block all clicks during STUNNED or DRAGGING states
	if state != BoardState.IDLE:
		_input_handler.tile_click_attempted.emit(tile, false)
		tile_click_failed.emit(tile, "board_not_idle")
		return

	if not _can_click_tile(tile):
		_input_handler.tile_click_attempted.emit(tile, false)
		tile_click_failed.emit(tile, "condition_not_met")
		return

	_activate_tile(tile)
	_input_handler.tile_click_attempted.emit(tile, true)


func _can_click_tile(tile: Tile) -> bool:
	if not tile or not tile.tile_data:
		return false

	if not tile.tile_data.is_clickable:
		return false

	# Use condition checker to validate click conditions
	var fighter := _get_owner_fighter()
	if _click_condition_checker:
		return _click_condition_checker.can_click(tile, fighter)

	return false


func _activate_tile(tile: Tile) -> void:
	var data := tile.tile_data as PuzzleTileData
	if not data:
		return

	# Check if this is the Alpha Command tile (Hunter ultimate)
	if data.tile_type == TileTypes.Type.ALPHA_COMMAND:
		_activate_alpha_command(tile)
		return

	# Check if this is the Predator's Trance tile (Assassin ultimate)
	if data.tile_type == TileTypes.Type.PREDATORS_TRANCE:
		_activate_predators_trance(tile)
		return

	# Check if this is the Invincibility tile (Mirror Warden ultimate)
	if data.tile_type == TileTypes.Type.INVINCIBILITY_TILE:
		_activate_invincibility(tile)
		return

	# Check if this is a Hunter-style pet tile (BEAR_PET, HAWK_PET, SNAKE_PET)
	if TileTypeHelper.is_hunter_pet_type(data.tile_type):
		_activate_hunter_pet(tile, data)
		return

	# Check if this is a sequence terminator (legacy Pet tile) with banked sequences
	if sequence_tracker and data.tile_type == TileTypes.Type.PET:
		var banked := sequence_tracker.get_banked_sequences()
		if banked.size() > 0:
			# Activate first banked sequence (most recent)
			var pattern := banked[0]
			var stacks := sequence_tracker.get_banked_stacks(pattern)
			var multiplier := _get_alpha_command_multiplier()

			if sequence_tracker.activate_sequence(pattern):
				# Process pet ability effects with multiplier
				_process_pet_ability(pattern, stacks, multiplier)

				# Emit signal for UI feedback (announcements)
				# Use _is_player_board() to check ownership, not is_player_controlled (which is about input)
				pet_ability_activated.emit(pattern, stacks, _is_player_board())

				# Visual feedback for sequence activation
				tile.play_activation_animation()

				# Consume the PET tile - removes it and triggers column fall
				_consume_pet_tile(tile)
				return

	# Start cooldown if applicable
	if _click_condition_checker:
		_click_condition_checker.start_cooldown(tile)

	# Get click effect and emit activation signal
	var effect := data.click_effect
	if effect:
		tile_activated.emit(tile, effect)

	# Visual feedback
	tile.play_activation_animation()

	# Some tiles are consumed on activation
	if _should_consume_tile(tile):
		_consume_tile(tile)


func _activate_hunter_pet(tile: Tile, data: PuzzleTileData) -> void:
	## Activates a Hunter-style pet tile (BEAR_PET, HAWK_PET, SNAKE_PET).
	## These tiles have their effects defined in click_effect and are consumed on use.
	## Requires GameConstants.PET_MANA_COST mana to activate.

	# Check mana requirement
	var fighter := _get_owner_fighter()
	if not fighter or not fighter.can_activate_pet():
		tile_click_failed.emit(tile, "not_enough_mana")
		tile.play_reject_animation()  # Visual feedback for failed click
		return

	# Drain mana cost
	_drain_pet_mana_cost(fighter)

	# Notify PetSpawner to decrement count
	if pet_spawner:
		pet_spawner.on_pet_activated(data.tile_type)

	# Get the pattern for this pet type to find its effects
	var pattern := _get_pattern_for_pet_type(data.tile_type)
	if pattern:
		var multiplier := _get_alpha_command_multiplier()
		# Hunter pets don't have stacks in the new system
		_process_pet_ability(pattern, 1, multiplier)

		# Emit signal for UI feedback
		pet_ability_activated.emit(pattern, 1, _is_player_board())

	# Visual feedback
	tile.play_activation_animation()

	# Consume the pet tile
	_consume_pet_tile(tile)


func _drain_pet_mana_cost(fighter: Fighter) -> void:
	## Drains the pet activation mana cost from the fighter.
	## Uses free activation from Alpha Command if available.
	if not fighter:
		return
	# Use free activation if available
	if fighter.use_free_pet_activation():
		return
	# Otherwise drain mana
	if fighter.mana_system:
		fighter.mana_system.drain(fighter, GameConstants.PET_MANA_COST, 0)


# --- Alpha Command (Ultimate) Methods ---

func _activate_alpha_command(tile: Tile) -> void:
	## Activates the Alpha Command tile (Hunter ultimate).
	## Calls CombatManager.activate_ultimate() and consumes the tile.
	var fighter := _get_owner_fighter()
	var combat_mgr := _get_combat_manager()

	if not combat_mgr or not fighter:
		tile_click_failed.emit(tile, "no_combat_manager")
		return

	# Activate the ultimate ability
	var success := combat_mgr.activate_ultimate(fighter)
	if not success:
		tile_click_failed.emit(tile, "ultimate_activation_failed")
		return

	# Visual feedback
	tile.play_activation_animation()

	# Start cooldown on the fighter before spawning another ultimate
	fighter.start_ultimate_cooldown(ULTIMATE_COOLDOWN_DURATION)

	# Consume the Alpha Command tile
	_consume_alpha_command_tile(tile)


func _consume_alpha_command_tile(tile: Tile) -> void:
	## Consume the Alpha Command tile after activation.
	_alpha_command_on_board = false

	# Find tile position
	var tile_row := -1
	var tile_col := -1
	for row in range(Grid.ROWS):
		for col in range(Grid.COLS):
			if grid.get_tile(row, col) == tile:
				tile_row = row
				tile_col = col
				break
		if tile_row >= 0:
			break

	if tile_row < 0:
		return

	# Clean up any references to this tile before freeing
	_original_positions.erase(tile)

	# Remove the tile from grid
	grid.clear_tile(tile_row, tile_col)
	tile.queue_free()

	# Trigger column fall and refill
	set_state(BoardState.RESOLVING)
	_process_alpha_command_tile_removal(tile_row, tile_col)


func _process_alpha_command_tile_removal(row: int, col: int) -> void:
	## Async handler for Alpha Command tile removal cascade.
	var _result := await _cascade_handler.process_single_removal(row, col)
	set_state(BoardState.IDLE)


# --- Predator's Trance (Assassin Ultimate) Methods ---

func _activate_predators_trance(tile: Tile) -> void:
	## Activates the Predator's Trance tile (Assassin ultimate).
	## Calls CombatManager.activate_ultimate() and consumes the tile.
	var fighter := _get_owner_fighter()
	var combat_mgr := _get_combat_manager()

	if not combat_mgr or not fighter:
		tile_click_failed.emit(tile, "no_combat_manager")
		return

	# Activate the ultimate ability
	var success := combat_mgr.activate_ultimate(fighter)
	if not success:
		tile_click_failed.emit(tile, "ultimate_activation_failed")
		return

	# Signal that trance has started (for UI tracking)
	if _tile_spawner:
		_tile_spawner.start_predators_trance()

	# Visual feedback
	tile.play_activation_animation()

	# Start cooldown on the fighter before spawning another ultimate
	fighter.start_ultimate_cooldown(PREDATORS_TRANCE_COOLDOWN)

	# Consume the Predator's Trance tile
	_consume_predators_trance_tile(tile)


func _consume_predators_trance_tile(tile: Tile) -> void:
	## Consume the Predator's Trance tile after activation.
	_predators_trance_on_board = false

	# Find tile position
	var tile_row := -1
	var tile_col := -1
	for row in range(Grid.ROWS):
		for col in range(Grid.COLS):
			if grid.get_tile(row, col) == tile:
				tile_row = row
				tile_col = col
				break
		if tile_row >= 0:
			break

	if tile_row < 0:
		return

	# Remove the tile from grid
	grid.clear_tile(tile_row, tile_col)
	tile.queue_free()

	# Trigger column fall and refill
	set_state(BoardState.RESOLVING)
	_process_predators_trance_tile_removal(tile_row, tile_col)


func _process_predators_trance_tile_removal(row: int, col: int) -> void:
	## Async handler for Predator's Trance tile removal cascade.
	var _result := await _cascade_handler.process_single_removal(row, col)
	set_state(BoardState.IDLE)


func spawn_alpha_command_tile() -> void:
	## Spawns an Alpha Command tile at a random column (drops from top of board).
	## Only spawns if there isn't already an Alpha Command tile on the board or on cooldown.
	if _alpha_command_on_board:
		return

	# Check if ultimate is on cooldown
	var fighter := _get_owner_fighter()
	if fighter and fighter.is_ultimate_on_cooldown():
		return

	# Load tile data if not cached
	if not _alpha_command_tile_data:
		_alpha_command_tile_data = preload("res://resources/tiles/alpha_command.tres")
	if not _alpha_command_tile_data:
		push_warning("BoardManager: Could not load Alpha Command tile data")
		return

	# Find a random column to spawn in
	var col := randi() % Grid.COLS

	# Find the top-most row that has a non-pet, non-alpha-command tile to replace
	var target_row := _find_top_tile_row(col)
	if target_row < 0:
		# Try other columns
		for c in range(Grid.COLS):
			if c == col:
				continue
			target_row = _find_top_tile_row(c)
			if target_row >= 0:
				col = c
				break

	if target_row < 0:
		push_warning("BoardManager: No valid position to spawn Alpha Command tile")
		return

	# Check if the top tile is a special tile (pet or alpha command)
	var existing_tile := grid.get_tile(target_row, col)
	if existing_tile and existing_tile.tile_data:
		var existing_type: int = existing_tile.tile_data.tile_type
		if TileTypeHelper.is_hunter_pet_type(existing_type) or existing_type == TileTypes.Type.ALPHA_COMMAND:
			# Find a column without a special tile at the top
			for c in range(Grid.COLS):
				var row := _find_top_tile_row(c)
				if row >= 0:
					var t := grid.get_tile(row, c)
					if t and t.tile_data:
						var tt: int = t.tile_data.tile_type
						if not TileTypeHelper.is_hunter_pet_type(tt) and tt != TileTypes.Type.ALPHA_COMMAND:
							target_row = row
							col = c
							existing_tile = t
							break

	# Remove the existing tile
	if existing_tile:
		grid.clear_tile(target_row, col)
		existing_tile.queue_free()

	# Create the Alpha Command tile
	var tile: Tile = _tile_spawner.tile_scene.instantiate()
	tile.setup(_alpha_command_tile_data, Vector2i(target_row, col))
	_place_tile(tile, target_row, col)

	_alpha_command_on_board = true
	_clickable_dirty = true


func has_alpha_command_on_board() -> bool:
	## Returns true if an Alpha Command tile is currently on the board.
	return _alpha_command_on_board


func spawn_predators_trance_tile() -> void:
	## Spawns a Predator's Trance tile at a random column (Assassin ultimate).
	## Only spawns if there isn't already one on the board.
	if _predators_trance_on_board:
		return

	# Check if ultimate is on cooldown
	var fighter := _get_owner_fighter()
	if fighter and fighter.is_ultimate_on_cooldown():
		return

	# Load tile data if not cached
	if not _predators_trance_tile_data:
		_predators_trance_tile_data = preload("res://resources/tiles/predators_trance.tres")
	if not _predators_trance_tile_data:
		push_warning("BoardManager: Could not load Predator's Trance tile data")
		return

	# Find a random column to spawn in
	var col := randi() % Grid.COLS

	# Find the top-most row that has a tile to replace
	var target_row := _find_top_tile_row(col)
	if target_row < 0:
		# Try other columns
		for c in range(Grid.COLS):
			if c == col:
				continue
			target_row = _find_top_tile_row(c)
			if target_row >= 0:
				col = c
				break

	if target_row < 0:
		push_warning("BoardManager: No valid position to spawn Predator's Trance tile")
		return

	# Remove the existing tile
	var existing_tile := grid.get_tile(target_row, col)
	if existing_tile:
		grid.clear_tile(target_row, col)
		existing_tile.queue_free()

	# Create the Predator's Trance tile
	var tile: Tile = _tile_spawner.tile_scene.instantiate()
	tile.setup(_predators_trance_tile_data, Vector2i(target_row, col))
	_place_tile(tile, target_row, col)

	_predators_trance_on_board = true
	_clickable_dirty = true


func has_predators_trance_on_board() -> bool:
	## Returns true if a Predator's Trance tile is currently on the board.
	return _predators_trance_on_board


# --- Invincibility (Mirror Warden Ultimate) Methods ---

func _activate_invincibility(tile: Tile) -> void:
	## Activates the Invincibility tile (Mirror Warden ultimate).
	## Calls CombatManager.activate_ultimate() and consumes the tile.
	var fighter := _get_owner_fighter()
	var combat_mgr := _get_combat_manager()

	if not combat_mgr or not fighter:
		tile_click_failed.emit(tile, "no_combat_manager")
		return

	# Activate the ultimate ability
	var success := combat_mgr.activate_ultimate(fighter)
	if not success:
		tile_click_failed.emit(tile, "ultimate_activation_failed")
		return

	# Visual feedback
	tile.play_activation_animation()

	# Start cooldown on the fighter before spawning another ultimate
	fighter.start_ultimate_cooldown(ULTIMATE_COOLDOWN_DURATION)

	# Consume the Invincibility tile
	_consume_invincibility_tile(tile)


func _consume_invincibility_tile(tile: Tile) -> void:
	## Consume the Invincibility tile after activation.
	_invincibility_on_board = false

	# Find tile position
	var tile_row := -1
	var tile_col := -1
	for row in range(Grid.ROWS):
		for col in range(Grid.COLS):
			if grid.get_tile(row, col) == tile:
				tile_row = row
				tile_col = col
				break
		if tile_row >= 0:
			break

	if tile_row < 0:
		return

	# Remove the tile from grid
	grid.clear_tile(tile_row, tile_col)
	tile.queue_free()

	# Trigger column fall and refill
	set_state(BoardState.RESOLVING)
	_process_invincibility_tile_removal(tile_row, tile_col)


func _process_invincibility_tile_removal(row: int, col: int) -> void:
	## Async handler for Invincibility tile removal cascade.
	var _result := await _cascade_handler.process_single_removal(row, col)
	set_state(BoardState.IDLE)


func spawn_invincibility_tile() -> void:
	## Spawns an Invincibility tile at a random column (Mirror Warden ultimate).
	## Only spawns if there isn't already one on the board.
	if _invincibility_on_board:
		return

	# Check if ultimate is on cooldown
	var fighter := _get_owner_fighter()
	if fighter and fighter.is_ultimate_on_cooldown():
		return

	# Load tile data if not cached
	if not _invincibility_tile_data:
		_invincibility_tile_data = preload("res://resources/tiles/invincibility_tile.tres")
	if not _invincibility_tile_data:
		push_warning("BoardManager: Could not load Invincibility tile data")
		return

	# Find a random column to spawn in
	var col := randi() % Grid.COLS

	# Find the top-most row that has a tile to replace
	var target_row := _find_top_tile_row(col)
	if target_row < 0:
		# Try other columns
		for c in range(Grid.COLS):
			if c == col:
				continue
			target_row = _find_top_tile_row(c)
			if target_row >= 0:
				col = c
				break

	if target_row < 0:
		push_warning("BoardManager: No valid position to spawn Invincibility tile")
		return

	# Remove the existing tile
	var existing_tile := grid.get_tile(target_row, col)
	if existing_tile:
		grid.clear_tile(target_row, col)
		existing_tile.queue_free()

	# Create the Invincibility tile
	var tile: Tile = _tile_spawner.tile_scene.instantiate()
	tile.setup(_invincibility_tile_data, Vector2i(target_row, col))
	_place_tile(tile, target_row, col)

	_invincibility_on_board = true
	_clickable_dirty = true


func has_invincibility_on_board() -> bool:
	## Returns true if an Invincibility tile is currently on the board.
	return _invincibility_on_board


func _get_pattern_for_pet_type(pet_type: TileTypes.Type) -> SequencePattern:
	## Finds the sequence pattern associated with a pet type.
	if not sequence_tracker:
		return null

	for pattern in sequence_tracker.get_valid_patterns():
		if pattern.pet_type == pet_type:
			return pattern

	return null


## Static preloads for pet tile data - required for Android export compatibility
const PET_TILE_DATA := {
	TileTypes.Type.BEAR_PET: preload("res://resources/tiles/bear_pet.tres"),
	TileTypes.Type.HAWK_PET: preload("res://resources/tiles/hawk_pet.tres"),
	TileTypes.Type.SNAKE_PET: preload("res://resources/tiles/snake_pet.tres"),
}

func _get_pet_tile_data(pet_type: int) -> PuzzleTileData:
	## Gets the PuzzleTileData for a Hunter pet type.
	## Uses static preloads for Android export compatibility.

	# Try to get from tile spawner first
	var tile_data := _tile_spawner.get_tile_data(pet_type)
	if tile_data:
		return tile_data

	# Fall back to static preloads
	if PET_TILE_DATA.has(pet_type):
		return PET_TILE_DATA[pet_type]

	return null


## Returns the Alpha Command multiplier for pet abilities with decay.
## Returns a value between 1.0 and 2.0 based on remaining duration.
## At full duration: 2.0x, decays linearly to 1.0x when expired.
func _get_alpha_command_multiplier() -> float:
	var fighter := _get_owner_fighter()
	# Alpha Command gives 2x multiplier while free activations remain
	if fighter and fighter.is_alpha_command_active():
		return 2.0
	return 1.0


## Processes pet ability effects from a sequence with optional multiplier
func _process_pet_ability(pattern: SequencePattern, stacks: int, multiplier: float) -> void:
	if not pattern:
		return

	var combat_mgr := _get_combat_manager()
	var fighter := _get_owner_fighter()

	if not combat_mgr or not fighter:
		return

	# Apply on_complete_effect (offensive effect) with multiplier
	if pattern.on_complete_effect:
		combat_mgr.apply_sequence_effect(pattern.on_complete_effect, fighter, stacks, multiplier)

	# Apply self_buff_effect with multiplier
	if pattern.self_buff_effect:
		combat_mgr.apply_sequence_effect(pattern.self_buff_effect, fighter, stacks, multiplier, true)


func _should_consume_tile(tile: Tile) -> bool:
	if not tile or not tile.tile_data:
		return false

	# Pet tiles are not consumed, just trigger effect
	# Other clickable tiles might be consumed based on type
	var data := tile.tile_data as PuzzleTileData
	if data and data.tile_type == TileTypes.Type.PET:
		return false

	# Default: don't consume clickable tiles
	# This can be extended based on specific tile type requirements
	return false


func _consume_tile(tile: Tile) -> void:
	# Find tile position and remove it
	for row in range(Grid.ROWS):
		for col in range(Grid.COLS):
			if grid.get_tile(row, col) == tile:
				grid.clear_tile(row, col)
				tile.queue_free()
				# Trigger cascade/refill after consumption
				set_state(BoardState.RESOLVING)
				var matches := _match_detector.find_matches(grid)
				if matches.size() > 0:
					_cascade_handler.process_matches(matches)
				else:
					set_state(BoardState.IDLE)
				return


func _consume_pet_tile(tile: Tile) -> void:
	"""Consume a PET tile after sequence activation - removes tile and triggers column fall."""
	# Find tile position
	var tile_row := -1
	var tile_col := -1
	for row in range(Grid.ROWS):
		for col in range(Grid.COLS):
			if grid.get_tile(row, col) == tile:
				tile_row = row
				tile_col = col
				break
		if tile_row >= 0:
			break

	if tile_row < 0:
		return

	# Remove the tile from grid
	grid.clear_tile(tile_row, tile_col)
	tile.queue_free()

	# Trigger column fall and refill (async)
	set_state(BoardState.RESOLVING)
	_process_pet_tile_removal(tile_row, tile_col)


func _process_pet_tile_removal(row: int, col: int) -> void:
	"""Async handler for pet tile removal cascade."""
	# Note: Match recording is handled by _on_matches_processed signal
	var _result := await _cascade_handler.process_single_removal(row, col)
	set_state(BoardState.IDLE)


func _get_owner_fighter() -> Fighter:
	return _owner_fighter


func _is_player_board() -> bool:
	# Check if this board belongs to the player (not the enemy)
	# by comparing owner fighter to combat manager's player_fighter
	if _owner_fighter and _combat_manager:
		return _owner_fighter == _combat_manager.player_fighter
	# Fallback to is_player_controlled if references aren't set
	return is_player_controlled


func set_owner_fighter(fighter: Fighter) -> void:
	_owner_fighter = fighter

	# Update click condition checker with related systems
	if _click_condition_checker:
		if sequence_tracker:
			_click_condition_checker.set_sequence_tracker(sequence_tracker)
		if fighter and fighter.mana_system:
			_click_condition_checker.set_mana_system(fighter.mana_system)

	# Update tile spawner with fighter reference for Predator's Trance
	if _tile_spawner and fighter and _combat_manager:
		_tile_spawner.set_fighter_references(fighter, _combat_manager.status_effect_manager)

	# Connect to mana changes to mark highlights dirty
	if fighter:
		if not fighter.mana_changed.is_connected(_on_fighter_mana_changed):
			fighter.mana_changed.connect(_on_fighter_mana_changed)
		# Connect to ultimate ready signal to spawn Alpha Command tile
		if not fighter.ultimate_ready.is_connected(_on_fighter_ultimate_ready):
			fighter.ultimate_ready.connect(_on_fighter_ultimate_ready)


func _on_fighter_mana_changed(_bar_index: int, _current: int, _max_value: int) -> void:
	_clickable_dirty = true


func _on_fighter_ultimate_ready() -> void:
	## Called when the fighter's mana bars are all full (ultimate ready).
	## Spawns the appropriate ultimate tile based on character.
	if _character_data:
		match _character_data.character_id:
			"hunter":
				spawn_alpha_command_tile()
			"assassin":
				spawn_predators_trance_tile()
			"mirror_warden":
				spawn_invincibility_tile()
			_:
				# Default to alpha command for unknown characters
				spawn_alpha_command_tile()
	else:
		# Fallback when no character data is available
		spawn_alpha_command_tile()


func _update_clickable_highlights() -> void:
	# Hide all highlights when board is not in IDLE state
	if state != BoardState.IDLE:
		for tile in grid.get_all_tiles():
			if tile:
				tile.update_clickable_state(false)
		return

	# Update each tile's clickable highlight based on current conditions
	var fighter := _get_owner_fighter()
	var has_pet_mana := fighter.can_activate_pet() if fighter else false

	for tile in grid.get_all_tiles():
		if not tile or not tile.tile_data:
			continue

		# Only check clickable tiles
		if tile.tile_data.is_clickable:
			var can_click := false
			if _click_condition_checker:
				can_click = _click_condition_checker.can_click(tile, fighter)
			tile.update_clickable_state(can_click)

			# Dim Hunter pet tiles when mana is insufficient
			if TileTypeHelper.is_hunter_pet_type(tile.tile_data.tile_type):
				tile.set_dimmed(not has_pet_mana)
			else:
				tile.set_dimmed(false)
		else:
			# Ensure non-clickable tiles don't have highlight
			tile.update_clickable_state(false)
			tile.set_dimmed(false)


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
	# Safety check: tile may have been freed (e.g., Alpha Command consumed)
	if not is_instance_valid(first_tile):
		_original_positions.clear()
		return 0

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


func _place_tile(tile: Tile, row: int, col: int) -> void:
	grid.set_tile(row, col, tile)
	_tiles_container.add_child(tile)
	tile.position = grid.grid_to_world(row, col)


func _clear_all_tiles() -> void:
	# Clear all tiles from the grid
	for tile in grid.get_all_tiles():
		if tile:
			tile.queue_free()

	# Also clear ALL children from the tiles container to catch any orphaned tiles
	# This ensures no tiles persist between games
	if _tiles_container:
		for child in _tiles_container.get_children():
			child.queue_free()

	grid.initialize()


func _remove_initial_matches() -> void:
	var max_iterations := 100
	var iteration := 0

	while iteration < max_iterations:
		var matches := _match_detector.find_matches(grid)
		if matches.is_empty():
			break

		# Replace tiles that are part of matches
		for match_result in matches:
			for pos in match_result.positions:
				_replace_tile_at(pos.x, pos.y)

		iteration += 1


func _replace_tile_at(row: int, col: int) -> void:
	var old_tile := grid.clear_tile(row, col)
	if old_tile:
		old_tile.queue_free()

	var new_tile := _tile_spawner.spawn_tile()
	new_tile.grid_position = Vector2i(row, col)
	_place_tile(new_tile, row, col)


## Ensures minimum tile counts are maintained after cascade
## Spawns required tiles at random empty positions if any type is below minimum
func _ensure_minimum_tiles() -> void:
	if not _tile_spawner:
		return

	var tiles_to_spawn := _tile_spawner.ensure_minimums()
	if tiles_to_spawn.is_empty():
		return

	# Get available empty positions
	var empty_positions := grid.get_empty_positions()
	if empty_positions.is_empty():
		# No empty positions - need to replace existing tiles
		# Get all non-specialty tile positions (excluding special tiles like pets and Alpha Command)
		var replaceable: Array[Vector2i] = []
		for r in range(Grid.ROWS):
			for col in range(Grid.COLS):
				var tile := grid.get_tile(r, col)
				if tile and tile.tile_data:
					# Never replace special tiles (pets, Alpha Command)
					if TileTypeHelper.is_special_tile(tile.tile_data.tile_type):
						continue
					# Only replace tiles without min/max rules
					if tile.tile_data.min_on_board == 0 and tile.tile_data.max_on_board <= 0:
						replaceable.append(Vector2i(r, col))

		if replaceable.is_empty():
			# Cannot place tiles - free the spawned ones
			for tile in tiles_to_spawn:
				tile.queue_free()
			return

		# Shuffle and use replaceable positions
		replaceable.shuffle()
		empty_positions = replaceable

	# Shuffle empty positions for random placement
	empty_positions.shuffle()

	# Place spawned tiles
	for i in range(mini(tiles_to_spawn.size(), empty_positions.size())):
		var tile := tiles_to_spawn[i]
		var pos := empty_positions[i]

		# If position has a tile (replacement case), remove it
		var existing := grid.get_tile(pos.x, pos.y)
		if existing:
			grid.clear_tile(pos.x, pos.y)
			existing.queue_free()

		tile.grid_position = pos
		_place_tile(tile, pos.x, pos.y)

	# Free any tiles that couldn't be placed
	for i in range(empty_positions.size(), tiles_to_spawn.size()):
		tiles_to_spawn[i].queue_free()


# --- Tile Activation Forwarding ---

func _on_tile_activated(tile: Tile, _effect: EffectData) -> void:
	# Forward tile activation to combat manager for effect processing
	var combat_mgr := _get_combat_manager()
	var fighter := _get_owner_fighter()

	if combat_mgr and fighter and tile:
		combat_mgr.process_tile_activation(tile, fighter)


func _get_combat_manager() -> CombatManager:
	return _combat_manager


func get_tile_spawner() -> TileSpawner:
	## Returns the TileSpawner for this board (used for Predator's Trance tracking)
	return _tile_spawner


func set_combat_manager(combat_manager: CombatManager) -> void:
	_combat_manager = combat_manager

	# Connect Predator's Trance signal for sword-only cascades
	if combat_manager and _tile_spawner:
		if not combat_manager.predators_trance_triggered.is_connected(_on_predators_trance_triggered):
			combat_manager.predators_trance_triggered.connect(_on_predators_trance_triggered)


func _on_predators_trance_triggered(fighter: Fighter, match_count: int) -> void:
	## Handle Predator's Trance sword match - queue bonus sword-only cascades.
	## Only respond if this is our owner fighter's board.
	if fighter != _owner_fighter:
		return
	_tile_spawner.trigger_predators_trance_chains(match_count)


# --- Tile Hiding Methods (for Smoke Bomb effects) ---

## Hide a number of random tiles for a duration
func hide_random_tiles(count: int, duration: float) -> void:
	var all_positions: Array[Vector2i] = []

	# Get all valid tile positions that aren't already hidden
	for row in range(Grid.ROWS):
		for col in range(Grid.COLS):
			var pos := Vector2i(row, col)
			if not _hidden_tiles.has(pos) and grid.get_tile(row, col):
				all_positions.append(pos)

	if all_positions.is_empty():
		return

	# Shuffle and pick random tiles
	all_positions.shuffle()
	var hide_count := mini(count, all_positions.size())
	var hidden_positions: Array = []

	for i in range(hide_count):
		var pos := all_positions[i]
		_hide_tile_at(pos, duration)
		hidden_positions.append(pos)

	if not hidden_positions.is_empty():
		tiles_hidden.emit(hidden_positions, duration)


## Hide a random row and column for a duration
func hide_random_row_and_column(duration: float) -> void:
	var random_row := randi() % Grid.ROWS
	var random_col := randi() % Grid.COLS
	var hidden_positions: Array = []

	# Hide entire row
	for col in range(Grid.COLS):
		var pos := Vector2i(random_row, col)
		if not _hidden_tiles.has(pos):
			_hide_tile_at(pos, duration)
			hidden_positions.append(pos)

	# Hide entire column (skip the intersection which is already hidden)
	for row in range(Grid.ROWS):
		if row == random_row:
			continue  # Already hidden as part of the row
		var pos := Vector2i(row, random_col)
		if not _hidden_tiles.has(pos):
			_hide_tile_at(pos, duration)
			hidden_positions.append(pos)

	if not hidden_positions.is_empty():
		tiles_hidden.emit(hidden_positions, duration)


## Hide a specific tile at a position
func _hide_tile_at(pos: Vector2i, duration: float) -> void:
	var tile := grid.get_tile(pos.x, pos.y)
	if tile:
		tile.set_hidden(true)
		_hidden_tiles[pos] = duration


## Tag matches that contain hidden (smoke-obscured) tiles
## Matches containing hidden tiles will have their effects negated
func _tag_hidden_tile_matches(matches: Array[MatchDetector.MatchResult]) -> void:
	if _hidden_tiles.is_empty():
		return

	for match_result in matches:
		for pos in match_result.positions:
			if _hidden_tiles.has(pos):
				match_result.contains_hidden_tile = true
				break  # No need to check more positions in this match


## Remove hidden tile tracking for positions that are being matched/cleared
func _clear_hidden_tiles_at_matches(matches: Array[MatchDetector.MatchResult]) -> void:
	if _hidden_tiles.is_empty():
		return

	for match_result in matches:
		for pos in match_result.positions:
			if _hidden_tiles.has(pos):
				_hidden_tiles.erase(pos)


## Process hidden tile timers
func _process_hidden_tiles(delta: float) -> void:
	if _hidden_tiles.is_empty():
		return

	var revealed_positions: Array = []

	for pos: Vector2i in _hidden_tiles.keys():
		_hidden_tiles[pos] -= delta

		if _hidden_tiles[pos] <= 0:
			# Reveal the tile
			var tile := grid.get_tile(pos.x, pos.y)
			if tile:
				tile.set_hidden(false)
			revealed_positions.append(pos)

	# Remove revealed tiles from tracking
	for pos in revealed_positions:
		_hidden_tiles.erase(pos)

	if not revealed_positions.is_empty():
		tiles_revealed.emit(revealed_positions)


## Reveal all hidden tiles immediately
func reveal_all_hidden_tiles() -> void:
	if _hidden_tiles.is_empty():
		return

	var revealed_positions: Array = []

	for pos: Vector2i in _hidden_tiles.keys():
		var tile := grid.get_tile(pos.x, pos.y)
		if tile:
			tile.set_hidden(false)
		revealed_positions.append(pos)

	_hidden_tiles.clear()

	if not revealed_positions.is_empty():
		tiles_revealed.emit(revealed_positions)


# --- Pet Tile Query Methods (for AI) ---

## Gets all clickable pet tiles on the board.
## Returns tiles of type BEAR_PET, HAWK_PET, SNAKE_PET, or legacy PET that are clickable.
## Used by AI to evaluate when to activate pet abilities.
func get_clickable_pet_tiles() -> Array[Tile]:
	var pet_tiles: Array[Tile] = []

	if not grid:
		return pet_tiles

	var pet_types := [
		TileTypes.Type.PET,        # Legacy pet tile
		TileTypes.Type.BEAR_PET,   # Hunter combo pet
		TileTypes.Type.HAWK_PET,   # Hunter combo pet
		TileTypes.Type.SNAKE_PET   # Hunter combo pet
	]

	for row in range(Grid.ROWS):
		for col in range(Grid.COLS):
			var tile := grid.get_tile(row, col)
			if tile and tile.tile_data:
				if tile.tile_data.tile_type in pet_types:
					# Check if the tile is clickable
					if tile.tile_data.is_clickable:
						# For legacy PET tiles, also check if there's a banked sequence
						if tile.tile_data.tile_type == TileTypes.Type.PET:
							if _click_condition_checker and _click_condition_checker.can_click(tile, _owner_fighter):
								pet_tiles.append(tile)
						else:
							# Hunter pet tiles are always clickable when present
							pet_tiles.append(tile)

	return pet_tiles


## Gets clickable Hunter-style pet tiles only (BEAR_PET, HAWK_PET, SNAKE_PET).
## Excludes legacy PET tiles.
func get_hunter_pet_tiles() -> Array[Tile]:
	var pet_tiles: Array[Tile] = []

	if not grid:
		return pet_tiles

	var hunter_pet_types := [
		TileTypes.Type.BEAR_PET,
		TileTypes.Type.HAWK_PET,
		TileTypes.Type.SNAKE_PET
	]

	for row in range(Grid.ROWS):
		for col in range(Grid.COLS):
			var tile := grid.get_tile(row, col)
			if tile and tile.tile_data:
				if tile.tile_data.tile_type in hunter_pet_types:
					if tile.tile_data.is_clickable:
						pet_tiles.append(tile)

	return pet_tiles


# --- Tile Replacement Methods (for Hawk ability) ---

## Get random matchable tile positions (tiles that can form matches, excluding PET and special tiles)
## Returns up to 'count' positions of tiles that are matchable (SWORD, SHIELD, POTION, LIGHTNING)
func get_random_matchable_positions(count: int) -> Array[Vector2i]:
	var matchable_positions: Array[Vector2i] = []

	# Collect all positions with matchable tiles
	for row in range(Grid.ROWS):
		for col in range(Grid.COLS):
			var tile := grid.get_tile(row, col)
			if tile and tile.tile_data:
				var tile_type: TileTypes.Type = tile.tile_data.tile_type
				# Only include matchable combat tiles (not filler, pet, or mana)
				if tile_type == TileTypes.Type.SWORD or \
				   tile_type == TileTypes.Type.SHIELD or \
				   tile_type == TileTypes.Type.POTION or \
				   tile_type == TileTypes.Type.LIGHTNING:
					matchable_positions.append(Vector2i(row, col))

	# Shuffle and return the requested number of positions
	matchable_positions.shuffle()
	var result: Array[Vector2i] = []
	var result_count := mini(count, matchable_positions.size())

	for i in range(result_count):
		result.append(matchable_positions[i])

	return result


## Replace a tile at the specified position with a new tile of the given type
## Returns true if successful, false otherwise
func replace_tile_at(pos: Vector2i, new_type: TileTypes.Type) -> bool:
	if not grid or not _tile_spawner:
		return false

	# Validate position
	if pos.x < 0 or pos.x >= Grid.ROWS or pos.y < 0 or pos.y >= Grid.COLS:
		return false

	var old_tile := grid.get_tile(pos.x, pos.y)
	if not old_tile:
		return false

	# Get the tile data for the new type
	var new_tile_data := _tile_spawner.get_tile_data(new_type)
	if not new_tile_data:
		return false

	# Remove old tile
	grid.clear_tile(pos.x, pos.y)
	old_tile.queue_free()

	# Create new tile
	var new_tile: Tile = _tile_spawner.tile_scene.instantiate()
	new_tile.setup(new_tile_data, pos)
	_place_tile(new_tile, pos.x, pos.y)

	return true


## Checks for matches on the board and processes them through the cascade system.
## Call this after making external tile changes (e.g., Hawk tile replacement).
## Returns true if matches were found and processing started.
func check_and_resolve_matches() -> bool:
	if not _match_detector or not _cascade_handler:
		return false

	var matches := _match_detector.find_matches(grid)
	if matches.is_empty():
		return false

	# Start resolution
	set_state(BoardState.RESOLVING)
	_process_external_matches(matches)
	return true


## Async handler for processing matches from external tile changes.
func _process_external_matches(matches: Array[MatchDetector.MatchResult]) -> void:
	# Tag all matches as CASCADE since they're from an external effect, not player input
	for match_result in matches:
		match_result.origin = TileTypes.MatchOrigin.CASCADE

	var _result := await _cascade_handler.process_matches(matches)
	set_state(BoardState.IDLE)
