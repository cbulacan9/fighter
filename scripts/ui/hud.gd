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

# Warden-specific UI components (created dynamically)
var _player_warden_display  # WardenDefenseDisplay
var _enemy_warden_display  # WardenDefenseDisplay

# Assassin-specific UI components (created dynamically)
var _player_assassin_display  # AssassinStatusDisplay
var _enemy_assassin_display  # AssassinStatusDisplay

# Scene references for dynamic instantiation
const COMBO_TREE_DISPLAY_SCENE := preload("res://scenes/ui/combo_tree_display.tscn")
const PET_POPULATION_DISPLAY_SCENE := preload("res://scenes/ui/pet_population_display.tscn")
const WARDEN_DEFENSE_DISPLAY_SCENE := preload("res://scenes/ui/warden_defense_display.tscn")
const ASSASSIN_STATUS_DISPLAY_SCENE := preload("res://scenes/ui/assassin_status_display.tscn")

## Layout constants - single source of truth for positioning
## Layout: Player UI above player board, Enemy UI below enemy board
## Each UI strip: [Portrait] [Panel] [Character-Specific UI]

## Board dimensions
const BOARD_HEIGHT := 384.0     # Height of game boards
const BOARD_X := 104.0          # X position for both boards

## Board positioning using offsets from edges (adjust these to move boards)
const ENEMY_TOP_OFFSET := 45.0      # Enemy board distance from TOP of screen
const PLAYER_BOTTOM_OFFSET := 150.0 # Player board distance from BOTTOM of screen

## UI positioning relative to boards
const UI_X := 10.0                  # Left edge for all UI elements
const UI_BELOW_BOARD := 5.0         # Gap between board bottom and UI
const CHAR_UI_OFFSET_X := 400.0     # Horizontal offset for character-specific UI from portrait

## Portrait settings
const PORTRAIT_SIZE := 96.0
const PORTRAIT_MARGIN := 10.0   # Gap between portrait and bars

## Cached screen height (updated on viewport resize)
static var _screen_height := 1080.0

## Call this to update cached screen height (called automatically in _ready)
static func update_screen_size(viewport: Viewport) -> void:
	if viewport:
		_screen_height = viewport.get_visible_rect().size.y

## Get current screen height
static func get_screen_height() -> float:
	return _screen_height

## Calculated board positions (reactive to screen size)
static func get_enemy_board_y() -> float:
	return ENEMY_TOP_OFFSET

static func get_player_board_y() -> float:
	return _screen_height - PLAYER_BOTTOM_OFFSET - BOARD_HEIGHT

## Player UI Y position (above player board)
static func get_player_ui_y() -> float:
	return get_player_board_y() - PORTRAIT_SIZE - UI_BELOW_BOARD

## Enemy UI Y position (below enemy board)
static func get_enemy_ui_y() -> float:
	return get_enemy_board_y() + BOARD_HEIGHT + UI_BELOW_BOARD

## Damage number positions (centered on boards)
static func get_player_damage_pos() -> Vector2:
	return Vector2(BOARD_X + 256, get_player_board_y() + BOARD_HEIGHT / 2)

static func get_enemy_damage_pos() -> Vector2:
	return Vector2(BOARD_X + 256, get_enemy_board_y() + BOARD_HEIGHT / 2)

## Ability announcement positions (below/above boards)
static func get_player_announcement_pos() -> Vector2:
	return Vector2(BOARD_X + 256, get_player_board_y() + BOARD_HEIGHT + 50)

static func get_enemy_announcement_pos() -> Vector2:
	return Vector2(BOARD_X + 256, get_enemy_board_y() - 50)

var _player_fighter: Fighter
var _enemy_fighter: Fighter
var _mana_system: ManaSystem
var _player_character_data: CharacterData
var _enemy_character_data: CharacterData
var _player_original_portrait: Texture2D
var _enemy_original_portrait: Texture2D
var _player_portrait_glow_tween: Tween
var _enemy_portrait_glow_tween: Tween

@onready var _player_panel: Control = $PlayerPanel
@onready var _enemy_panel: Control = $EnemyPanel

var _enemy_ui_background: ColorRect
var _player_ui_background: ColorRect


func _create_ui_backgrounds() -> void:
	# Create background for player UI area (above player board)
	var player_ui_y := get_player_ui_y()
	_player_ui_background = ColorRect.new()
	_player_ui_background.color = Color(0, 0, 0, 1)
	_player_ui_background.position = Vector2(0, player_ui_y)
	_player_ui_background.size = Vector2(720, PORTRAIT_SIZE + 10)  # Slightly taller than portrait
	add_child(_player_ui_background)
	move_child(_player_ui_background, 0)  # Move to back

	# Create background for enemy UI area (below enemy board)
	var enemy_ui_y := get_enemy_ui_y()
	_enemy_ui_background = ColorRect.new()
	_enemy_ui_background.color = Color(0, 0, 0, 1)
	_enemy_ui_background.position = Vector2(0, enemy_ui_y)
	_enemy_ui_background.size = Vector2(720, PORTRAIT_SIZE + 10)  # Slightly taller than portrait
	add_child(_enemy_ui_background)
	move_child(_enemy_ui_background, 0)  # Move to back


func _ready() -> void:
	# Initialize screen size from viewport
	update_screen_size(get_viewport())

	# Connect to viewport size changes for responsive layout
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	# Add black backgrounds behind UI areas to hide falling tiles
	_create_ui_backgrounds()

	# Setup portraits (reparenting only happens once)
	_setup_player_portrait()
	_setup_enemy_portrait()

	# Position all UI elements
	_update_layout()


func _on_viewport_size_changed() -> void:
	"""Handle viewport resize - update positions for new screen size."""
	update_screen_size(get_viewport())
	_update_layout()
	_update_ui_background()


func _update_ui_background() -> void:
	"""Update UI background size/position after viewport change."""
	if _player_ui_background:
		var player_ui_y := get_player_ui_y()
		_player_ui_background.position = Vector2(0, player_ui_y)
		_player_ui_background.size = Vector2(720, PORTRAIT_SIZE + 10)

	if _enemy_ui_background:
		var enemy_ui_y := get_enemy_ui_y()
		_enemy_ui_background.position = Vector2(0, enemy_ui_y)
		_enemy_ui_background.size = Vector2(720, PORTRAIT_SIZE + 10)


func _update_layout() -> void:
	"""Position all UI elements based on current screen size."""
	var player_ui_y := get_player_ui_y()
	var enemy_ui_y := get_enemy_ui_y()
	var char_ui_x := UI_X + CHAR_UI_OFFSET_X

	# Position PlayerPanel above player board: [Portrait][Panel][CharUI]
	if _player_panel:
		var panel_width := _player_panel.offset_right - _player_panel.offset_left
		var panel_height := _player_panel.offset_bottom - _player_panel.offset_top
		_player_panel.offset_left = UI_X + PORTRAIT_SIZE + PORTRAIT_MARGIN
		_player_panel.offset_top = player_ui_y
		_player_panel.offset_right = _player_panel.offset_left + panel_width
		_player_panel.offset_bottom = _player_panel.offset_top + panel_height

	# Position EnemyPanel below enemy board: [Portrait][Panel][CharUI]
	if _enemy_panel:
		var panel_width := _enemy_panel.offset_right - _enemy_panel.offset_left
		var panel_height := _enemy_panel.offset_bottom - _enemy_panel.offset_top
		_enemy_panel.offset_left = UI_X + PORTRAIT_SIZE + PORTRAIT_MARGIN
		_enemy_panel.offset_top = enemy_ui_y
		_enemy_panel.offset_right = _enemy_panel.offset_left + panel_width
		_enemy_panel.offset_bottom = _enemy_panel.offset_top + panel_height

	# Position SequenceIndicators (for non-Hunter characters) - right of panel
	if player_sequence_indicator:
		var indicator_width := player_sequence_indicator.offset_right - player_sequence_indicator.offset_left
		var indicator_height := player_sequence_indicator.offset_bottom - player_sequence_indicator.offset_top
		player_sequence_indicator.offset_left = char_ui_x
		player_sequence_indicator.offset_top = player_ui_y
		player_sequence_indicator.offset_right = player_sequence_indicator.offset_left + indicator_width
		player_sequence_indicator.offset_bottom = player_sequence_indicator.offset_top + indicator_height

	if enemy_sequence_indicator:
		var indicator_width := enemy_sequence_indicator.offset_right - enemy_sequence_indicator.offset_left
		var indicator_height := enemy_sequence_indicator.offset_bottom - enemy_sequence_indicator.offset_top
		enemy_sequence_indicator.offset_left = char_ui_x
		enemy_sequence_indicator.offset_top = enemy_ui_y
		enemy_sequence_indicator.offset_right = enemy_sequence_indicator.offset_left + indicator_width
		enemy_sequence_indicator.offset_bottom = enemy_sequence_indicator.offset_top + indicator_height

	# Update portrait positions (both at left edge, facing right toward their panels)
	if player_portrait:
		player_portrait.position = Vector2(UI_X, player_ui_y)
	if enemy_portrait:
		enemy_portrait.position = Vector2(UI_X, enemy_ui_y)

	# Update dynamic UI positions (Hunter combo tree, Warden display) - right of panel
	if _player_combo_tree_display:
		_player_combo_tree_display.position = Vector2(char_ui_x, player_ui_y)
	if _enemy_combo_tree_display:
		_enemy_combo_tree_display.position = Vector2(char_ui_x, enemy_ui_y)
	if _player_warden_display:
		_player_warden_display.position = Vector2(char_ui_x, player_ui_y)
	if _enemy_warden_display:
		_enemy_warden_display.position = Vector2(char_ui_x, enemy_ui_y)
	if _player_assassin_display:
		_player_assassin_display.position = Vector2(char_ui_x, player_ui_y)
	if _enemy_assassin_display:
		_enemy_assassin_display.position = Vector2(char_ui_x, enemy_ui_y)


func _setup_player_portrait() -> void:
	"""Setup player portrait - reparent and configure (position set by _update_layout)."""
	if not player_portrait:
		return

	# Reparent portrait to HUD root (out of panel)
	var original_parent := player_portrait.get_parent()
	if original_parent and original_parent != self:
		original_parent.remove_child(player_portrait)
		add_child(player_portrait)

	# Configure portrait settings
	player_portrait.flip_h = false  # Face right (toward enemy)
	player_portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	player_portrait.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)


func _setup_enemy_portrait() -> void:
	"""Setup enemy portrait - reparent and configure (position set by _update_layout)."""
	if not enemy_portrait:
		return

	# Reparent portrait to HUD root (out of panel)
	var original_parent := enemy_portrait.get_parent()
	if original_parent and original_parent != self:
		original_parent.remove_child(enemy_portrait)
		add_child(enemy_portrait)

	# Configure portrait settings
	enemy_portrait.flip_h = false  # Face right (toward UI panel)
	enemy_portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	enemy_portrait.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)


func setup(player_fighter: Fighter, enemy_fighter: Fighter, player_char_data: CharacterData = null, enemy_char_data: CharacterData = null) -> void:
	_player_fighter = player_fighter
	_enemy_fighter = enemy_fighter
	_player_character_data = player_char_data
	_enemy_character_data = enemy_char_data

	# Get mana system reference
	_mana_system = _get_mana_system()

	# Setup health bars, name labels, and portraits
	if player_fighter:
		player_health_bar.setup(player_fighter.max_hp)
		if not player_fighter.hp_changed.is_connected(_on_player_hp_changed):
			player_fighter.hp_changed.connect(_on_player_hp_changed)
		if not player_fighter.armor_changed.is_connected(_on_player_armor_changed):
			player_fighter.armor_changed.connect(_on_player_armor_changed)

		# Set player name label
		if player_fighter.fighter_data and player_name_label:
			player_name_label.text = player_fighter.fighter_data.fighter_name

		# Set player portrait
		if player_fighter.fighter_data and player_fighter.fighter_data.portrait and player_portrait:
			player_portrait.texture = player_fighter.fighter_data.portrait
			_player_original_portrait = player_fighter.fighter_data.portrait

		# Connect alpha command signals for portrait swap
		if not player_fighter.alpha_command_activated.is_connected(_on_player_alpha_command_activated):
			player_fighter.alpha_command_activated.connect(_on_player_alpha_command_activated)
		if not player_fighter.alpha_command_deactivated.is_connected(_on_player_alpha_command_deactivated):
			player_fighter.alpha_command_deactivated.connect(_on_player_alpha_command_deactivated)

	if enemy_fighter:
		enemy_health_bar.setup(enemy_fighter.max_hp)
		if not enemy_fighter.hp_changed.is_connected(_on_enemy_hp_changed):
			enemy_fighter.hp_changed.connect(_on_enemy_hp_changed)
		if not enemy_fighter.armor_changed.is_connected(_on_enemy_armor_changed):
			enemy_fighter.armor_changed.connect(_on_enemy_armor_changed)

		# Set enemy name label
		if enemy_fighter.fighter_data and enemy_name_label:
			enemy_name_label.text = enemy_fighter.fighter_data.fighter_name

		# Set enemy portrait
		if enemy_fighter.fighter_data and enemy_fighter.fighter_data.portrait and enemy_portrait:
			enemy_portrait.texture = enemy_fighter.fighter_data.portrait
			_enemy_original_portrait = enemy_fighter.fighter_data.portrait

		# Connect alpha command signals for portrait swap
		if not enemy_fighter.alpha_command_activated.is_connected(_on_enemy_alpha_command_activated):
			enemy_fighter.alpha_command_activated.connect(_on_enemy_alpha_command_activated)
		if not enemy_fighter.alpha_command_deactivated.is_connected(_on_enemy_alpha_command_deactivated):
			enemy_fighter.alpha_command_deactivated.connect(_on_enemy_alpha_command_deactivated)

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

	# Position combo tree to the right of panel [Portrait][Panel][CharUI]
	var char_ui_x := UI_X + CHAR_UI_OFFSET_X
	var combo_tree_pos: Vector2
	if is_player:
		combo_tree_pos = Vector2(char_ui_x, get_player_ui_y())
	else:
		combo_tree_pos = Vector2(char_ui_x, get_enemy_ui_y())

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


# --- Warden Defense Display ---

func setup_defensive_queue(player_fighter: Fighter, enemy_fighter: Fighter,
		defensive_queue: DefensiveQueueManager) -> void:
	"""Setup Warden defense displays only for Mirror Warden characters."""
	# Clean up any existing displays
	_cleanup_warden_ui()

	if not defensive_queue:
		return

	# Create player Warden display only if player is Mirror Warden
	if player_fighter and _is_mirror_warden(_player_character_data):
		_create_warden_ui(player_fighter, defensive_queue, true)

	# Create enemy Warden display only if enemy is Mirror Warden
	if enemy_fighter and _is_mirror_warden(_enemy_character_data):
		_create_warden_ui(enemy_fighter, defensive_queue, false)


func _is_mirror_warden(char_data: CharacterData) -> bool:
	"""Check if the character is a Mirror Warden."""
	if not char_data:
		return false
	return char_data.character_id == "mirror_warden"


func _create_warden_ui(fighter: Fighter, defensive_queue: DefensiveQueueManager, is_player: bool) -> void:
	"""Create Warden defense display positioned to the right of panel [Portrait][Panel][CharUI]."""
	if not fighter or not defensive_queue:
		return

	# Position to the right of panel (same as Hunter ComboTreeDisplay)
	var char_ui_x := UI_X + CHAR_UI_OFFSET_X
	var display_pos: Vector2
	if is_player:
		display_pos = Vector2(char_ui_x, get_player_ui_y())
	else:
		display_pos = Vector2(char_ui_x, get_enemy_ui_y())

	# Create WardenDefenseDisplay
	var display = WARDEN_DEFENSE_DISPLAY_SCENE.instantiate()
	display.position = display_pos
	add_child(display)
	display.setup(fighter, defensive_queue)

	# Store reference
	if is_player:
		_player_warden_display = display
	else:
		_enemy_warden_display = display


func _cleanup_warden_ui() -> void:
	"""Clean up Warden defense displays."""
	if _player_warden_display:
		_player_warden_display.clear()
		_player_warden_display.queue_free()
		_player_warden_display = null

	if _enemy_warden_display:
		_enemy_warden_display.clear()
		_enemy_warden_display.queue_free()
		_enemy_warden_display = null


func get_player_warden_display():
	"""Returns the player's WardenDefenseDisplay if active."""
	return _player_warden_display


func get_enemy_warden_display():
	"""Returns the enemy's WardenDefenseDisplay if active."""
	return _enemy_warden_display


## Returns true if the player is using Warden-style UI
func is_player_using_warden_ui() -> bool:
	return _player_warden_display != null


## Returns true if the enemy is using Warden-style UI
func is_enemy_using_warden_ui() -> bool:
	return _enemy_warden_display != null


# --- Assassin Status Display ---

func setup_assassin_ui(player_fighter: Fighter, enemy_fighter: Fighter,
		mana_system: ManaSystem, status_manager: StatusEffectManager,
		player_tile_spawner: TileSpawner = null, enemy_tile_spawner: TileSpawner = null) -> void:
	"""Setup Assassin status displays only for Assassin characters."""
	# Clean up any existing displays
	_cleanup_assassin_ui()

	if not mana_system:
		return

	# Create player Assassin display only if player is Assassin
	if player_fighter and _is_assassin(_player_character_data):
		_create_assassin_ui(player_fighter, mana_system, status_manager, true, player_tile_spawner)

	# Create enemy Assassin display only if enemy is Assassin
	if enemy_fighter and _is_assassin(_enemy_character_data):
		_create_assassin_ui(enemy_fighter, mana_system, status_manager, false, enemy_tile_spawner)


func _is_assassin(char_data: CharacterData) -> bool:
	"""Check if the character is an Assassin."""
	if not char_data:
		return false
	return char_data.character_id == "assassin"


func _create_assassin_ui(fighter: Fighter, mana_system: ManaSystem,
		status_manager: StatusEffectManager, is_player: bool, tile_spawner: TileSpawner = null) -> void:
	"""Create Assassin status display positioned to the right of panel [Portrait][Panel][CharUI]."""
	if not fighter or not mana_system:
		return

	# Position to the right of panel (same as Hunter ComboTreeDisplay and Warden)
	var char_ui_x := UI_X + CHAR_UI_OFFSET_X
	var display_pos: Vector2
	if is_player:
		display_pos = Vector2(char_ui_x, get_player_ui_y())
	else:
		display_pos = Vector2(char_ui_x, get_enemy_ui_y())

	# Create AssassinStatusDisplay
	var display = ASSASSIN_STATUS_DISPLAY_SCENE.instantiate()
	display.position = display_pos
	add_child(display)
	display.setup(fighter, mana_system, status_manager, tile_spawner)

	# Store reference
	if is_player:
		_player_assassin_display = display
	else:
		_enemy_assassin_display = display


func _cleanup_assassin_ui() -> void:
	"""Clean up Assassin status displays."""
	if _player_assassin_display:
		_player_assassin_display.clear()
		_player_assassin_display.queue_free()
		_player_assassin_display = null

	if _enemy_assassin_display:
		_enemy_assassin_display.clear()
		_enemy_assassin_display.queue_free()
		_enemy_assassin_display = null


func get_player_assassin_display():
	"""Returns the player's AssassinStatusDisplay if active."""
	return _player_assassin_display


func get_enemy_assassin_display():
	"""Returns the enemy's AssassinStatusDisplay if active."""
	return _enemy_assassin_display


## Returns true if the player is using Assassin-style UI
func is_player_using_assassin_ui() -> bool:
	return _player_assassin_display != null


## Returns true if the enemy is using Assassin-style UI
func is_enemy_using_assassin_ui() -> bool:
	return _enemy_assassin_display != null


# --- Alpha Command Portrait Swap ---

func _on_player_alpha_command_activated() -> void:
	if _player_character_data and _player_character_data.ultimate_portrait and player_portrait:
		player_portrait.texture = _player_character_data.ultimate_portrait
	_start_portrait_glow(player_portrait, true)


func _on_player_alpha_command_deactivated() -> void:
	if _player_original_portrait and player_portrait:
		player_portrait.texture = _player_original_portrait
	_stop_portrait_glow(player_portrait, true)


func _on_enemy_alpha_command_activated() -> void:
	if _enemy_character_data and _enemy_character_data.ultimate_portrait and enemy_portrait:
		enemy_portrait.texture = _enemy_character_data.ultimate_portrait
	_start_portrait_glow(enemy_portrait, false)


func _on_enemy_alpha_command_deactivated() -> void:
	if _enemy_original_portrait and enemy_portrait:
		enemy_portrait.texture = _enemy_original_portrait
	_stop_portrait_glow(enemy_portrait, false)


func _start_portrait_glow(portrait: TextureRect, is_player: bool) -> void:
	if not portrait:
		return

	# Kill any existing tween
	if is_player and _player_portrait_glow_tween:
		_player_portrait_glow_tween.kill()
	elif not is_player and _enemy_portrait_glow_tween:
		_enemy_portrait_glow_tween.kill()

	# Create pulsing red glow effect
	var glow_color := Color(1.5, 0.7, 0.7, 1.0)  # Bright red tint
	var normal_color := Color(1.0, 1.0, 1.0, 1.0)  # Normal

	var tween := create_tween()
	tween.set_loops()

	# Pulse: normal -> red -> normal
	tween.tween_property(portrait, "modulate", glow_color, 0.4).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(portrait, "modulate", normal_color, 0.4).set_ease(Tween.EASE_IN_OUT)

	if is_player:
		_player_portrait_glow_tween = tween
	else:
		_enemy_portrait_glow_tween = tween


func _stop_portrait_glow(portrait: TextureRect, is_player: bool) -> void:
	if not portrait:
		return

	# Kill the tween
	if is_player and _player_portrait_glow_tween:
		_player_portrait_glow_tween.kill()
		_player_portrait_glow_tween = null
	elif not is_player and _enemy_portrait_glow_tween:
		_enemy_portrait_glow_tween.kill()
		_enemy_portrait_glow_tween = null

	# Reset to normal color
	portrait.modulate = Color(1.0, 1.0, 1.0, 1.0)
