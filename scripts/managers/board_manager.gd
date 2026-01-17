class_name BoardManager
extends Node2D

signal state_changed(new_state: BoardState)
signal matches_resolved(result: CascadeHandler.CascadeResult)
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


func _ready() -> void:
	# Add to board_managers group for effect processor to find boards
	add_to_group("board_managers")

	grid = $Grid
	_tiles_container = $Grid/Tiles
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

	# Update clickable tile highlights
	_update_clickable_highlights()


func _setup_systems() -> void:
	_input_handler.setup(grid, global_position)
	_input_handler.drag_started.connect(_on_drag_started)
	_input_handler.drag_moved.connect(_on_drag_moved)
	_input_handler.drag_ended.connect(_on_drag_ended)

	_cascade_handler.setup(grid, _tile_spawner, _match_detector, _tiles_container)
	_cascade_handler.cascade_complete.connect(_on_cascade_complete)

	# Set grid reference on tile spawner for spawn rules
	_tile_spawner.set_grid(grid)

	_setup_click_handling()


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
		return

	sequence_tracker = SequenceTracker.new()
	sequence_tracker.setup(patterns)

	# Connect sequence tracker signals
	sequence_tracker.sequence_progressed.connect(_on_sequence_progressed)
	sequence_tracker.sequence_completed.connect(_on_sequence_completed)
	sequence_tracker.sequence_broken.connect(_on_sequence_broken)
	sequence_tracker.sequence_banked.connect(_on_sequence_banked)
	sequence_tracker.sequence_activated.connect(_on_sequence_activated)

	# Connect to click condition checker
	if _click_condition_checker:
		_click_condition_checker.set_sequence_tracker(sequence_tracker)


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


func get_state() -> BoardState:
	return state


func set_state(new_state: BoardState) -> void:
	if state != new_state:
		state = new_state
		state_changed.emit(new_state)

		match new_state:
			BoardState.IDLE:
				_sync_visuals_to_grid()
				_clear_drag_state()
				_input_handler.set_enabled(is_player_controlled)
				ready_for_input.emit()
			BoardState.DRAGGING:
				pass  # Keep input enabled to track ongoing drag
			BoardState.RESOLVING, BoardState.STUNNED:
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


func _on_cascade_complete(result: CascadeHandler.CascadeResult) -> void:
	# Record matches for sequence tracking
	if sequence_tracker:
		for match_result in result.all_matches:
			# Record the tile type for sequence tracking
			var tile_type: int = match_result.tile_type
			sequence_tracker.record_match(tile_type)

	# Ensure minimum tile counts are maintained after cascade
	_ensure_minimum_tiles()

	matches_resolved.emit(result)
	set_state(BoardState.IDLE)


# --- Sequence Signal Handlers ---

func _on_sequence_progressed(current: Array, possible: Array) -> void:
	sequence_progressed.emit(current, possible)


func _on_sequence_completed(pattern: SequencePattern) -> void:
	sequence_completed.emit(pattern)
	# Update Pet tile clickability when sequence is completed
	_update_clickable_highlights()


func _on_sequence_banked(pattern: SequencePattern, stacks: int) -> void:
	sequence_banked.emit(pattern, stacks)


func _on_sequence_broken() -> void:
	sequence_broken.emit()


func _on_sequence_activated(pattern: SequencePattern, stacks: int) -> void:
	sequence_activated.emit(pattern, stacks)


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
	# Clicks are blocked during non-IDLE states
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

	# Check if this is a sequence terminator (Pet tile) with banked sequences
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

				# Visual feedback for sequence activation
				tile.play_activation_animation()
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


## Returns the Alpha Command multiplier for pet abilities with decay.
## Returns a value between 1.0 and 2.0 based on remaining duration.
## At full duration: 2.0x, decays linearly to 1.0x when expired.
func _get_alpha_command_multiplier() -> float:
	var fighter := _get_owner_fighter()
	var combat_mgr := _get_combat_manager()
	if fighter and combat_mgr and combat_mgr.status_effect_manager:
		return combat_mgr.status_effect_manager.get_alpha_command_multiplier(fighter)
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


func _get_owner_fighter() -> Fighter:
	return _owner_fighter


func set_owner_fighter(fighter: Fighter) -> void:
	_owner_fighter = fighter

	# Update click condition checker with related systems
	if _click_condition_checker:
		if sequence_tracker:
			_click_condition_checker.set_sequence_tracker(sequence_tracker)
		if fighter and fighter.mana_system:
			_click_condition_checker.set_mana_system(fighter.mana_system)


func _update_clickable_highlights() -> void:
	# Hide all highlights when board is not in IDLE state
	if state != BoardState.IDLE:
		for tile in grid.get_all_tiles():
			if tile:
				tile.update_clickable_state(false)
		return

	# Update each tile's clickable highlight based on current conditions
	var fighter := _get_owner_fighter()
	for tile in grid.get_all_tiles():
		if not tile or not tile.tile_data:
			continue

		# Only check clickable tiles
		if tile.tile_data.is_clickable:
			var can_click := false
			if _click_condition_checker:
				can_click = _click_condition_checker.can_click(tile, fighter)
			tile.update_clickable_state(can_click)
		else:
			# Ensure non-clickable tiles don't have highlight
			tile.update_clickable_state(false)


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
		# Get all non-specialty tile positions
		var replaceable: Array[Vector2i] = []
		for row in range(Grid.ROWS):
			for col in range(Grid.COLS):
				var tile := grid.get_tile(row, col)
				if tile and tile.tile_data:
					# Only replace tiles without min/max rules
					if tile.tile_data.min_on_board == 0 and tile.tile_data.max_on_board <= 0:
						replaceable.append(Vector2i(row, col))

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


func set_combat_manager(combat_manager: CombatManager) -> void:
	_combat_manager = combat_manager


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
