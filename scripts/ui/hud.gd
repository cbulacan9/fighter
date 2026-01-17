class_name HUD
extends Control

signal player_ultimate_ready()
signal enemy_ultimate_ready()
signal player_mana_bar_clicked(bar_index: int)
signal enemy_mana_bar_clicked(bar_index: int)

@onready var player_health_bar: HealthBar = $PlayerPanel/Bars/HealthBar
@onready var player_portrait: TextureRect = $PlayerPanel/Portrait
@onready var player_mana_container: ManaBarContainer = $PlayerPanel/Bars/ManaContainer
@onready var player_sequence_indicator: SequenceIndicator = $PlayerPanel/SequenceIndicator
@onready var player_status_display: StatusEffectDisplay = $PlayerPanel/Bars/StatusEffectDisplay
@onready var enemy_health_bar: HealthBar = $EnemyPanel/Bars/HealthBar
@onready var enemy_portrait: TextureRect = $EnemyPanel/Portrait
@onready var enemy_mana_container: ManaBarContainer = $EnemyPanel/Bars/ManaContainer
@onready var enemy_status_display: StatusEffectDisplay = $EnemyPanel/Bars/StatusEffectDisplay

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
	if player_sequence_indicator:
		var player_board := _get_player_board()
		if player_board and player_board.sequence_tracker:
			player_sequence_indicator.setup(player_board.sequence_tracker)
			player_sequence_indicator.visible = true
		else:
			player_sequence_indicator.visible = false


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


## Sets up the sequence indicator with a specific board manager
## Useful when board manager is created after HUD setup
func setup_sequence_indicator_for_board(board: BoardManager) -> void:
	if not player_sequence_indicator:
		return

	if board and board.sequence_tracker:
		player_sequence_indicator.setup(board.sequence_tracker)
		player_sequence_indicator.visible = true
	else:
		player_sequence_indicator.visible = false


func get_player_status_display() -> StatusEffectDisplay:
	return player_status_display


func get_enemy_status_display() -> StatusEffectDisplay:
	return enemy_status_display
