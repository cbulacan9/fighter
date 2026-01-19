class_name HUD
extends Control

signal player_ultimate_ready()
signal enemy_ultimate_ready()
signal player_mana_bar_clicked(bar_index: int)
signal enemy_mana_bar_clicked(bar_index: int)

@onready var player_health_bar: HealthBar = $PlayerPanel/Bars/HealthBar
@onready var player_portrait: TextureRect = $PlayerPanel/Portrait
@onready var player_name_label: Label = $PlayerPanel/Bars/NameLabel
@onready var player_mana_container: ManaBarContainer = $PlayerPanel/Bars/ManaContainer
@onready var player_sequence_indicator: SequenceIndicator = $SequenceIndicator
@onready var player_status_display: StatusEffectDisplay = $PlayerPanel/Bars/StatusEffectDisplay
@onready var enemy_health_bar: HealthBar = $EnemyPanel/Bars/HealthBar
@onready var enemy_portrait: TextureRect = $EnemyPanel/Portrait
@onready var enemy_name_label: Label = $EnemyPanel/Bars/NameLabel
@onready var enemy_mana_container: ManaBarContainer = $EnemyPanel/Bars/ManaContainer
@onready var enemy_sequence_indicator: SequenceIndicator = $EnemySequenceIndicator
@onready var enemy_status_display: StatusEffectDisplay = $EnemyPanel/Bars/StatusEffectDisplay

# Hunter-specific UI components (created dynamically)
var _player_combo_tree_display: ComboTreeDisplay
var _player_pet_population_display: PetPopulationDisplay
var _enemy_combo_tree_display: ComboTreeDisplay
var _enemy_pet_population_display: PetPopulationDisplay
var _combo_log_debugger: ComboLogDebugger
var _combat_log_debugger: CombatLogDebugger

# Scene references for dynamic instantiation
const COMBO_TREE_DISPLAY_SCENE := preload("res://scenes/ui/combo_tree_display.tscn")
const PET_POPULATION_DISPLAY_SCENE := preload("res://scenes/ui/pet_population_display.tscn")

## Layout constants - single source of truth for positioning
## Change X_OFFSET values to shift all UI elements (panel, portrait, combo tree) together
const PLAYER_X_OFFSET := 20.0  # Shift all player UI elements horizontally
const ENEMY_X_OFFSET := 20.0   # Shift all enemy UI elements horizontally

## Base positions (before offset is applied)
const PANEL_BASE_X := 10.0      # Base X for health/mana panel
const COMBO_TREE_BASE_X := 405.0  # Base X for combo tree (right of board)
const PLAYER_UI_Y := 645.0      # Y position for player UI elements
const ENEMY_UI_Y := 5.0         # Y position for enemy UI elements
const PLAYER_BOARD_OFFSET := 125.0  # How far below PLAYER_UI_Y the board starts
const ENEMY_BOARD_OFFSET := 120.0   # How far below ENEMY_UI_Y the board starts

## UI Background positions (adjust these to fine-tune black boxes behind UI)
const ENEMY_BG_Y := 0.0         # Top of enemy UI background
const ENEMY_BG_HEIGHT := 125.0  # Height of enemy UI background
const PLAYER_BG_Y := 605.0      # Top of player UI background
const PLAYER_BG_HEIGHT := 165.0 # Height of player UI background

## Calculated positions for external use (e.g., GameManager positioning boards)
static func get_player_board_y() -> float:
	return PLAYER_UI_Y + PLAYER_BOARD_OFFSET

static func get_enemy_board_y() -> float:
	return ENEMY_UI_Y + ENEMY_BOARD_OFFSET

var _player_fighter: Fighter
var _enemy_fighter: Fighter
var _mana_system: ManaSystem

@onready var _player_panel: Control = $PlayerPanel
@onready var _enemy_panel: Control = $EnemyPanel

var _enemy_ui_background: ColorRect
var _player_ui_background: ColorRect


func _create_ui_backgrounds() -> void:
	# Create background for enemy UI area (top of screen)
	_enemy_ui_background = ColorRect.new()
	_enemy_ui_background.color = Color(0, 0, 0, 1)
	_enemy_ui_background.position = Vector2(0, ENEMY_BG_Y)
	_enemy_ui_background.size = Vector2(720, ENEMY_BG_HEIGHT)
	add_child(_enemy_ui_background)
	move_child(_enemy_ui_background, 0)  # Move to back

	# Create background for player UI area
	_player_ui_background = ColorRect.new()
	_player_ui_background.color = Color(0, 0, 0, 1)
	_player_ui_background.position = Vector2(0, PLAYER_BG_Y)
	_player_ui_background.size = Vector2(720, PLAYER_BG_HEIGHT)
	add_child(_player_ui_background)
	move_child(_player_ui_background, 1)  # Move to back (after enemy bg)


func _ready() -> void:
	# Add black backgrounds behind UI areas to hide falling tiles
	_create_ui_backgrounds()

	# Position PlayerPanel using layout constants with offset
	# Panels use anchor layout (layout_mode = 1), so we set offsets not position
	if _player_panel:
		var panel_width := _player_panel.offset_right - _player_panel.offset_left
		var panel_height := _player_panel.offset_bottom - _player_panel.offset_top
		_player_panel.offset_left = PANEL_BASE_X + PLAYER_X_OFFSET
		_player_panel.offset_top = PLAYER_UI_Y
		_player_panel.offset_right = _player_panel.offset_left + panel_width
		_player_panel.offset_bottom = _player_panel.offset_top + panel_height

	# Position EnemyPanel using layout constants with offset
	if _enemy_panel:
		var panel_width := _enemy_panel.offset_right - _enemy_panel.offset_left
		var panel_height := _enemy_panel.offset_bottom - _enemy_panel.offset_top
		_enemy_panel.offset_left = PANEL_BASE_X + ENEMY_X_OFFSET
		_enemy_panel.offset_top = ENEMY_UI_Y
		_enemy_panel.offset_right = _enemy_panel.offset_left + panel_width
		_enemy_panel.offset_bottom = _enemy_panel.offset_top + panel_height

	# Position SequenceIndicators (for non-Hunter characters) with offsets
	if player_sequence_indicator:
		var indicator_width := player_sequence_indicator.offset_right - player_sequence_indicator.offset_left
		player_sequence_indicator.offset_left = COMBO_TREE_BASE_X + PLAYER_X_OFFSET
		player_sequence_indicator.offset_right = player_sequence_indicator.offset_left + indicator_width
	if enemy_sequence_indicator:
		var indicator_width := enemy_sequence_indicator.offset_right - enemy_sequence_indicator.offset_left
		enemy_sequence_indicator.offset_left = COMBO_TREE_BASE_X + ENEMY_X_OFFSET
		enemy_sequence_indicator.offset_right = enemy_sequence_indicator.offset_left + indicator_width

	# Setup portraits - move outside panel, position to the left, make larger
	_setup_portrait(player_portrait, PLAYER_X_OFFSET, PLAYER_UI_Y)
	_setup_portrait(enemy_portrait, ENEMY_X_OFFSET, ENEMY_UI_Y)


func _setup_portrait(portrait: TextureRect, x_offset: float, y_pos: float) -> void:
	if not portrait:
		return

	const PORTRAIT_SIZE := 96.0
	const PORTRAIT_MARGIN := 10.0  # Gap between portrait and panel

	# Reparent portrait to HUD root (out of panel)
	var original_parent := portrait.get_parent()
	if original_parent and original_parent != self:
		original_parent.remove_child(portrait)
		add_child(portrait)

	# Position portrait to the left of where the panel will be
	portrait.flip_h = false
	portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.position = Vector2(x_offset, y_pos)

	# Shift panel to the right to make room for portrait
	if original_parent and original_parent is Control:
		var panel := original_parent as Control
		var shift := PORTRAIT_SIZE + PORTRAIT_MARGIN
		panel.offset_left += shift
		panel.offset_right += shift


func setup(player_fighter: Fighter, enemy_fighter: Fighter) -> void:
	_player_fighter = player_fighter
	_enemy_fighter = enemy_fighter

	# Get mana system reference
	_mana_system = _get_mana_system()

	# Setup health bars, name labels, and portraits
	if player_fighter:
		player_health_bar.setup(player_fighter.max_hp)
		player_fighter.hp_changed.connect(_on_player_hp_changed)
		player_fighter.armor_changed.connect(_on_player_armor_changed)

		# Set player name label
		if player_fighter.fighter_data and player_name_label:
			player_name_label.text = player_fighter.fighter_data.fighter_name

		# Set player portrait
		if player_fighter.fighter_data and player_fighter.fighter_data.portrait and player_portrait:
			player_portrait.texture = player_fighter.fighter_data.portrait

	if enemy_fighter:
		enemy_health_bar.setup(enemy_fighter.max_hp)
		enemy_fighter.hp_changed.connect(_on_enemy_hp_changed)
		enemy_fighter.armor_changed.connect(_on_enemy_armor_changed)

		# Set enemy name label
		if enemy_fighter.fighter_data and enemy_name_label:
			enemy_name_label.text = enemy_fighter.fighter_data.fighter_name

		# Set enemy portrait
		if enemy_fighter.fighter_data and enemy_fighter.fighter_data.portrait and enemy_portrait:
			enemy_portrait.texture = enemy_fighter.fighter_data.portrait

	# Setup mana bars
	_setup_mana_bars()

	# Setup sequence indicator (for characters that use sequences)
	_setup_sequence_indicator()

	# Setup status effect displays
	_setup_status_displays()

	# Setup mana block signal connections (replaces per-frame polling)
	_setup_mana_block_signals()
	# Initial update for mana blocked states
	_update_mana_blocked_states()

	# Setup combat log debugger
	_setup_combat_log_debugger()


func _setup_mana_bars() -> void:
	# Setup player mana container
	if player_mana_container and _player_fighter and _mana_system:
		player_mana_container.setup(_player_fighter, _mana_system)

		# Connect signals if not already connected
		if not player_mana_container.ultimate_ready.is_connected(_on_player_ultimate_ready):
			player_mana_container.ultimate_ready.connect(_on_player_ultimate_ready)
		if not player_mana_container.bar_clicked.is_connected(_on_player_mana_bar_clicked):
			player_mana_container.bar_clicked.connect(_on_player_mana_bar_clicked)
	elif player_mana_container:
		player_mana_container.visible = false

	# Setup enemy mana container
	if enemy_mana_container and _enemy_fighter and _mana_system:
		enemy_mana_container.setup(_enemy_fighter, _mana_system)

		# Connect signals if not already connected
		if not enemy_mana_container.ultimate_ready.is_connected(_on_enemy_ultimate_ready):
			enemy_mana_container.ultimate_ready.connect(_on_enemy_ultimate_ready)
		if not enemy_mana_container.bar_clicked.is_connected(_on_enemy_mana_bar_clicked):
			enemy_mana_container.bar_clicked.connect(_on_enemy_mana_bar_clicked)
	elif enemy_mana_container:
		enemy_mana_container.visible = false


func _setup_sequence_indicator() -> void:
	# Setup sequence indicator for player if they use sequences
	var player_board := _get_player_board()
	_setup_sequence_ui_for_board(player_board, true)

	# Setup sequence indicator for enemy if they use sequences
	var enemy_board := _get_enemy_board()
	_setup_sequence_ui_for_board(enemy_board, false)


## Sets up the appropriate sequence UI for a board based on whether it uses Hunter-style pets
func _setup_sequence_ui_for_board(board: BoardManager, is_player: bool) -> void:
	var sequence_indicator: SequenceIndicator = player_sequence_indicator if is_player else enemy_sequence_indicator
	var use_hunter_ui := _board_uses_hunter_pets(board)

	if use_hunter_ui:
		# Hide the standard SequenceIndicator
		if sequence_indicator:
			sequence_indicator.visible = false

		# Create and setup Hunter UI components
		_create_hunter_ui(board, is_player)
	else:
		# Clean up any existing Hunter UI
		_cleanup_hunter_ui(is_player)

		# Use standard SequenceIndicator
		if sequence_indicator:
			if board and board.sequence_tracker:
				sequence_indicator.setup(board.sequence_tracker)
				sequence_indicator.visible = true
			else:
				sequence_indicator.visible = false


## Checks if a board uses Hunter-style pet sequences (patterns with pet_type set)
func _board_uses_hunter_pets(board: BoardManager) -> bool:
	if not board or not board.sequence_tracker:
		return false

	var patterns := board.sequence_tracker.get_valid_patterns()
	for pattern in patterns:
		if pattern.pet_type >= 0:
			return true

	return false


## Creates the Hunter-specific UI components for a board
func _create_hunter_ui(board: BoardManager, is_player: bool) -> void:
	if not board:
		return

	# Determine positions based on player/enemy
	# Player UI is in the gap between boards, Enemy UI is at top
	var combo_tree_pos: Vector2
	if is_player:
		combo_tree_pos = Vector2(COMBO_TREE_BASE_X + PLAYER_X_OFFSET, PLAYER_UI_Y)
	else:
		combo_tree_pos = Vector2(COMBO_TREE_BASE_X + ENEMY_X_OFFSET, ENEMY_UI_Y)

	# Create ComboTreeDisplay (now includes pet population counts)
	var combo_tree: ComboTreeDisplay = COMBO_TREE_DISPLAY_SCENE.instantiate()
	combo_tree.position = combo_tree_pos
	add_child(combo_tree)

	if board.sequence_tracker:
		combo_tree.setup(board.sequence_tracker)

	# Connect pet spawner to combo tree display for population counts
	if board.pet_spawner:
		combo_tree.setup_pet_spawner(board.pet_spawner)

	# Store references
	if is_player:
		_player_combo_tree_display = combo_tree
		_player_pet_population_display = null  # No longer using separate display

		# Create combo log debugger (only for player, toggle with F3)
		if not _combo_log_debugger and board.sequence_tracker:
			_combo_log_debugger = ComboLogDebugger.new()
			_combo_log_debugger.position = Vector2(10, 100)
			add_child(_combo_log_debugger)
			_combo_log_debugger.setup(board.sequence_tracker)
	else:
		_enemy_combo_tree_display = combo_tree
		_enemy_pet_population_display = null  # No longer using separate display


## Cleans up Hunter-specific UI components
func _cleanup_hunter_ui(is_player: bool) -> void:
	if is_player:
		if _player_combo_tree_display:
			_player_combo_tree_display.clear()
			_player_combo_tree_display.queue_free()
			_player_combo_tree_display = null
		_player_pet_population_display = null  # No longer using separate display
		# Cleanup combo log debugger
		if _combo_log_debugger:
			_combo_log_debugger.clear()
			_combo_log_debugger.queue_free()
			_combo_log_debugger = null
		# Cleanup combat log debugger
		if _combat_log_debugger:
			_combat_log_debugger.clear()
			_combat_log_debugger.queue_free()
			_combat_log_debugger = null
	else:
		if _enemy_combo_tree_display:
			_enemy_combo_tree_display.clear()
			_enemy_combo_tree_display.queue_free()
			_enemy_combo_tree_display = null
		_enemy_pet_population_display = null  # No longer using separate display


func _setup_status_displays() -> void:
	# Get status manager reference
	var status_manager := _get_status_manager()

	# Setup player status display
	if player_status_display and _player_fighter:
		player_status_display.setup(_player_fighter, status_manager)
		player_status_display.visible = true
	elif player_status_display:
		player_status_display.visible = false

	# Setup enemy status display
	if enemy_status_display and _enemy_fighter:
		enemy_status_display.setup(_enemy_fighter, status_manager)
		enemy_status_display.visible = true
	elif enemy_status_display:
		enemy_status_display.visible = false


func _get_status_manager() -> StatusEffectManager:
	# Try to get status manager from CombatManager
	var combat_manager := get_node_or_null("/root/Main/CombatManager")
	if combat_manager and "status_manager" in combat_manager:
		return combat_manager.status_manager

	# Try alternate paths
	var game_manager := get_node_or_null("/root/Main/GameManager")
	if game_manager:
		var cm := game_manager.get_node_or_null("CombatManager")
		if cm and "status_manager" in cm:
			return cm.status_manager

	# Try from fighter directly
	if _player_fighter and _player_fighter.status_manager:
		return _player_fighter.status_manager
	if _enemy_fighter and _enemy_fighter.status_manager:
		return _enemy_fighter.status_manager

	return null


func _get_combat_manager() -> CombatManager:
	# Try direct path
	var combat_manager := get_node_or_null("/root/Main/CombatManager")
	if combat_manager:
		return combat_manager as CombatManager

	# Try alternate paths
	var game_manager := get_node_or_null("/root/Main/GameManager")
	if game_manager:
		var cm := game_manager.get_node_or_null("CombatManager")
		if cm:
			return cm as CombatManager

	# Try from parent
	var parent := get_parent()
	if parent:
		var main := parent.get_parent()
		if main:
			var cm := main.get_node_or_null("CombatManager")
			if cm:
				return cm as CombatManager

	return null


func _setup_combat_log_debugger() -> void:
	# Don't create if already exists
	if _combat_log_debugger:
		return

	var combat_manager := _get_combat_manager()
	if not combat_manager:
		return

	_combat_log_debugger = CombatLogDebugger.new()
	_combat_log_debugger.position = Vector2(320, 100)  # Position to the right of combo log debugger
	add_child(_combat_log_debugger)
	_combat_log_debugger.setup(combat_manager)


func _get_player_board() -> BoardManager:
	# Try to find the player's board manager
	var board := get_node_or_null("/root/Main/Boards/PlayerBoard")
	if board:
		return board as BoardManager

	# Try alternate paths
	var game_manager := get_node_or_null("/root/Main/GameManager")
	if game_manager:
		var boards := game_manager.get_node_or_null("Boards")
		if boards:
			var player_board := boards.get_node_or_null("PlayerBoard")
			if player_board:
				return player_board as BoardManager

	# Try from parent scene
	var main := get_node_or_null("/root/Main")
	if main:
		for child in main.get_children():
			if child is BoardManager and child.is_player_controlled:
				return child

	return null


func _get_enemy_board() -> BoardManager:
	# Try to find the enemy's board manager
	var board := get_node_or_null("/root/Main/Boards/EnemyBoard")
	if board:
		return board as BoardManager

	# Try alternate paths
	var game_manager := get_node_or_null("/root/Main/GameManager")
	if game_manager:
		var boards := game_manager.get_node_or_null("Boards")
		if boards:
			var enemy_board := boards.get_node_or_null("EnemyBoard")
			if enemy_board:
				return enemy_board as BoardManager

	# Try from parent scene
	var main := get_node_or_null("/root/Main")
	if main:
		for child in main.get_children():
			if child is BoardManager and not child.is_player_controlled:
				return child

	return null


var _status_manager_for_mana: StatusEffectManager


func _get_mana_system() -> ManaSystem:
	# Try to get mana system from CombatManager
	var combat_manager := get_node_or_null("/root/Main/CombatManager")
	if combat_manager and combat_manager.has_method("get") and "mana_system" in combat_manager:
		return combat_manager.mana_system

	# Fallback: try to access directly
	if combat_manager and "mana_system" in combat_manager:
		return combat_manager.mana_system

	# Try alternate paths
	var game_manager := get_node_or_null("/root/Main/GameManager")
	if game_manager:
		var cm := game_manager.get_node_or_null("CombatManager")
		if cm and "mana_system" in cm:
			return cm.mana_system

	# Try from fighter directly
	if _player_fighter and _player_fighter.mana_system:
		return _player_fighter.mana_system
	if _enemy_fighter and _enemy_fighter.mana_system:
		return _enemy_fighter.mana_system

	return null


func _setup_mana_block_signals() -> void:
	"""Connect to status manager signals for mana block changes (replaces per-frame polling)."""
	_status_manager_for_mana = _get_status_manager()
	if _status_manager_for_mana:
		if not _status_manager_for_mana.effect_applied.is_connected(_on_status_effect_for_mana):
			_status_manager_for_mana.effect_applied.connect(_on_status_effect_for_mana)
		if not _status_manager_for_mana.effect_removed.is_connected(_on_status_removed_for_mana):
			_status_manager_for_mana.effect_removed.connect(_on_status_removed_for_mana)


func _on_status_effect_for_mana(target: Fighter, effect: StatusEffect) -> void:
	"""Called when any status effect is applied - check if it's mana block."""
	if effect.data.effect_type == StatusTypes.StatusType.MANA_BLOCK:
		if target == _player_fighter or target == _enemy_fighter:
			_update_mana_blocked_states()


func _on_status_removed_for_mana(target: Fighter, effect_type: StatusTypes.StatusType) -> void:
	"""Called when any status effect is removed - check if it's mana block."""
	if effect_type == StatusTypes.StatusType.MANA_BLOCK:
		if target == _player_fighter or target == _enemy_fighter:
			_update_mana_blocked_states()


func _update_mana_blocked_states() -> void:
	if player_mana_container and _player_fighter:
		player_mana_container.update_blocked_state()
	if enemy_mana_container and _enemy_fighter:
		enemy_mana_container.update_blocked_state()


func _on_player_hp_changed(current: int, _max_hp: int) -> void:
	player_health_bar.set_hp(current)


func _on_player_armor_changed(current: int) -> void:
	player_health_bar.set_armor(current)


func _on_enemy_hp_changed(current: int, _max_hp: int) -> void:
	enemy_health_bar.set_hp(current)


func _on_enemy_armor_changed(current: int) -> void:
	enemy_health_bar.set_armor(current)


func _on_player_ultimate_ready() -> void:
	player_ultimate_ready.emit()


func _on_enemy_ultimate_ready() -> void:
	enemy_ultimate_ready.emit()


func _on_player_mana_bar_clicked(bar_index: int) -> void:
	player_mana_bar_clicked.emit(bar_index)


func _on_enemy_mana_bar_clicked(bar_index: int) -> void:
	enemy_mana_bar_clicked.emit(bar_index)


func is_player_ultimate_ready() -> bool:
	if player_mana_container:
		return player_mana_container.is_ultimate_ready()
	return false


func is_enemy_ultimate_ready() -> bool:
	if enemy_mana_container:
		return enemy_mana_container.is_ultimate_ready()
	return false


func get_player_mana_container() -> ManaBarContainer:
	return player_mana_container


func get_enemy_mana_container() -> ManaBarContainer:
	return enemy_mana_container


func get_player_sequence_indicator() -> SequenceIndicator:
	return player_sequence_indicator


func get_enemy_sequence_indicator() -> SequenceIndicator:
	return enemy_sequence_indicator


## Sets up the sequence indicator with a specific board manager
## Useful when board manager is created after HUD setup
func setup_sequence_indicator_for_board(board: BoardManager) -> void:
	_setup_sequence_ui_for_board(board, true)


## Sets up the enemy sequence indicator with a specific board manager
func setup_enemy_sequence_indicator_for_board(board: BoardManager) -> void:
	_setup_sequence_ui_for_board(board, false)


## Returns the player's ComboTreeDisplay if Hunter UI is active
func get_player_combo_tree_display() -> ComboTreeDisplay:
	return _player_combo_tree_display


## Returns the player's PetPopulationDisplay if Hunter UI is active
func get_player_pet_population_display() -> PetPopulationDisplay:
	return _player_pet_population_display


## Returns the enemy's ComboTreeDisplay if Hunter UI is active
func get_enemy_combo_tree_display() -> ComboTreeDisplay:
	return _enemy_combo_tree_display


## Returns the enemy's PetPopulationDisplay if Hunter UI is active
func get_enemy_pet_population_display() -> PetPopulationDisplay:
	return _enemy_pet_population_display


## Returns true if the player is using Hunter-style UI
func is_player_using_hunter_ui() -> bool:
	return _player_combo_tree_display != null


## Returns true if the enemy is using Hunter-style UI
func is_enemy_using_hunter_ui() -> bool:
	return _enemy_combo_tree_display != null


## Returns the combo log debugger if active
func get_combo_log_debugger() -> ComboLogDebugger:
	return _combo_log_debugger


## Returns the combat log debugger if active
func get_combat_log_debugger() -> CombatLogDebugger:
	return _combat_log_debugger


func get_player_status_display() -> StatusEffectDisplay:
	return player_status_display


func get_enemy_status_display() -> StatusEffectDisplay:
	return enemy_status_display
