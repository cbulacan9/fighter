class_name HUD
extends Control

signal player_ultimate_ready()
signal enemy_ultimate_ready()
signal player_mana_bar_clicked(bar_index: int)
signal enemy_mana_bar_clicked(bar_index: int)

@onready var player_health_bar: HealthBar = $PlayerPanel/Bars/HealthBar
@onready var player_portrait: TextureRect = $PlayerPanel/Portrait
@onready var player_mana_container: ManaBarContainer = $PlayerPanel/Bars/ManaContainer
@onready var player_sequence_indicator: SequenceIndicator = $SequenceIndicator
@onready var player_status_display: StatusEffectDisplay = $PlayerPanel/Bars/StatusEffectDisplay
@onready var enemy_health_bar: HealthBar = $EnemyPanel/Bars/HealthBar
@onready var enemy_portrait: TextureRect = $EnemyPanel/Portrait
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

# Note: PlayerPanel is now at bottom (y=600), EnemyPanel at top (y=5)

var _player_fighter: Fighter
var _enemy_fighter: Fighter
var _mana_system: ManaSystem


func setup(player_fighter: Fighter, enemy_fighter: Fighter) -> void:
	_player_fighter = player_fighter
	_enemy_fighter = enemy_fighter

	# Get mana system reference
	_mana_system = _get_mana_system()

	# Setup health bars
	if player_fighter:
		player_health_bar.setup(player_fighter.max_hp)
		player_fighter.hp_changed.connect(_on_player_hp_changed)
		player_fighter.armor_changed.connect(_on_player_armor_changed)

		if player_fighter.fighter_data and player_fighter.fighter_data.portrait:
			player_portrait.texture = player_fighter.fighter_data.portrait

	if enemy_fighter:
		enemy_health_bar.setup(enemy_fighter.max_hp)
		enemy_fighter.hp_changed.connect(_on_enemy_hp_changed)
		enemy_fighter.armor_changed.connect(_on_enemy_armor_changed)

		if enemy_fighter.fighter_data and enemy_fighter.fighter_data.portrait:
			enemy_portrait.texture = enemy_fighter.fighter_data.portrait

	# Setup mana bars
	_setup_mana_bars()

	# Setup sequence indicator (for characters that use sequences)
	_setup_sequence_indicator()

	# Setup status effect displays
	_setup_status_displays()

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
	var combo_tree_pos := Vector2(290, 390) if is_player else Vector2(290, 5)

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


func _process(_delta: float) -> void:
	# Update blocked state periodically (in case status effects change)
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
