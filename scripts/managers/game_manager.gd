extends Node

signal state_changed(new_state: GameState)

enum GameState {
	INIT,
	COUNTDOWN,
	BATTLE,
	PAUSED,
	END,
	STATS
}

@export var player_data_path: String = "res://resources/fighters/default_player.tres"
@export var enemy_data_path: String = "res://resources/fighters/default_enemy.tres"

var current_state: GameState = GameState.STATS  # Start at STATS so transition to INIT actually triggers
var match_timer: float = 0.0
var winner_id: int = 0

# Node references (set via _ready or exported)
var player_board: BoardManager
var enemy_board: BoardManager
var combat_manager: CombatManager
var ai_controller: AIController
var game_overlay: GameOverlay
var stats_screen: StatsScreen
var hud: HUD
var damage_spawner: DamageNumberSpawner
var player_stun_overlay: StunOverlay
var enemy_stun_overlay: StunOverlay

var _stats_tracker: StatsTracker
var _player_data: FighterData
var _enemy_data: FighterData


func _ready() -> void:
	_stats_tracker = StatsTracker.new()
	_load_fighter_data()
	call_deferred("_initialize_systems")


func _process(delta: float) -> void:
	_process_state(delta)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if current_state == GameState.BATTLE:
			change_state(GameState.PAUSED)
		elif current_state == GameState.PAUSED:
			change_state(GameState.BATTLE)


func _load_fighter_data() -> void:
	_player_data = load(player_data_path)
	_enemy_data = load(enemy_data_path)


func _initialize_systems() -> void:
	# Find nodes in the scene tree
	_find_node_references()

	# Connect signals
	_connect_signals()

	# Start the game
	change_state(GameState.INIT)


func _find_node_references() -> void:
	var parent := get_parent()
	if not parent:
		return

	# Find CombatManager
	combat_manager = parent.get_node_or_null("CombatManager")

	# Find boards
	var boards := parent.get_node_or_null("Boards")
	if boards:
		player_board = boards.get_node_or_null("PlayerBoard")
		enemy_board = boards.get_node_or_null("EnemyBoard")

	# Find AI
	ai_controller = parent.get_node_or_null("AIController")

	# Find UI nodes
	var ui := parent.get_node_or_null("UI")
	if ui:
		hud = ui.get_node_or_null("HUD")
		game_overlay = ui.get_node_or_null("GameOverlay")
		stats_screen = ui.get_node_or_null("StatsScreen")
		damage_spawner = ui.get_node_or_null("DamageNumbers")
		player_stun_overlay = ui.get_node_or_null("PlayerStunOverlay")
		enemy_stun_overlay = ui.get_node_or_null("EnemyStunOverlay")


func _connect_signals() -> void:
	# GameOverlay signals
	if game_overlay:
		game_overlay.countdown_finished.connect(_on_countdown_finished)
		game_overlay.resume_pressed.connect(_on_resume_pressed)
		game_overlay.quit_pressed.connect(_on_quit_pressed)
		game_overlay.continue_pressed.connect(_on_continue_pressed)

	# StatsScreen signals
	if stats_screen:
		stats_screen.rematch_pressed.connect(_on_rematch_pressed)
		stats_screen.quit_pressed.connect(_on_stats_quit_pressed)

	# CombatManager signals
	if combat_manager:
		combat_manager.match_ended.connect(_on_match_ended)
		combat_manager.damage_dealt.connect(_on_damage_dealt)
		combat_manager.healing_done.connect(_on_healing_done)
		combat_manager.armor_gained.connect(_on_armor_gained)
		combat_manager.stun_applied.connect(_on_stun_applied)
		combat_manager.stun_ended.connect(_on_stun_ended)

	# Board signals
	if player_board:
		player_board.matches_resolved.connect(_on_player_matches_resolved)
	if enemy_board:
		enemy_board.matches_resolved.connect(_on_enemy_matches_resolved)


func change_state(new_state: GameState) -> void:
	if current_state == new_state:
		return

	_exit_state(current_state)
	current_state = new_state
	_enter_state(new_state)
	state_changed.emit(new_state)


func _enter_state(state: GameState) -> void:
	match state:
		GameState.INIT:
			_setup_match()
			change_state(GameState.COUNTDOWN)

		GameState.COUNTDOWN:
			_disable_gameplay()
			if game_overlay:
				game_overlay.show_countdown()

		GameState.BATTLE:
			_enable_gameplay()
			_stats_tracker.start_match()

		GameState.PAUSED:
			_disable_gameplay()
			if game_overlay:
				game_overlay.show_pause()

		GameState.END:
			_disable_gameplay()
			_stats_tracker.end_match()
			if game_overlay:
				game_overlay.show_result(winner_id)

		GameState.STATS:
			if stats_screen:
				stats_screen.show_stats(_stats_tracker.get_stats())


func _exit_state(state: GameState) -> void:
	match state:
		GameState.PAUSED:
			if game_overlay:
				game_overlay.hide_pause()
		GameState.COUNTDOWN:
			pass
		GameState.BATTLE:
			pass
		GameState.END:
			pass
		GameState.STATS:
			pass
		GameState.INIT:
			pass


func _process_state(delta: float) -> void:
	match current_state:
		GameState.BATTLE:
			match_timer += delta

			# Tick combat for stun timers
			if combat_manager:
				combat_manager.tick(delta)

			# Update board stun states
			_update_board_stun_states()


func _setup_match() -> void:
	match_timer = 0.0
	winner_id = 0
	_stats_tracker.reset()

	# Initialize combat
	if combat_manager:
		combat_manager.initialize(_player_data, _enemy_data)

	# Initialize boards
	if player_board:
		player_board.initialize(_player_data, true)
	if enemy_board:
		enemy_board.initialize(_enemy_data, false)

	# Setup AI
	if ai_controller and enemy_board:
		ai_controller.setup(enemy_board, enemy_board._match_detector)

	# Setup HUD
	if hud and combat_manager:
		hud.setup(combat_manager.player_fighter, combat_manager.enemy_fighter)

	# Setup damage number spawner
	if damage_spawner and combat_manager:
		var player_pos := Vector2(360, 750)  # Center of player board area
		var enemy_pos := Vector2(360, 300)   # Center of enemy board area
		damage_spawner.setup(combat_manager, player_pos, enemy_pos)


func _enable_gameplay() -> void:
	if player_board:
		player_board.set_state(BoardManager.BoardState.IDLE)
	if enemy_board:
		enemy_board.set_state(BoardManager.BoardState.IDLE)
	if ai_controller:
		ai_controller.set_enabled(true)


func _disable_gameplay() -> void:
	if player_board and player_board.state == BoardManager.BoardState.IDLE:
		player_board.lock_input()
	if enemy_board and enemy_board.state == BoardManager.BoardState.IDLE:
		enemy_board.lock_input()
	if ai_controller:
		ai_controller.set_enabled(false)


func _update_board_stun_states() -> void:
	if combat_manager and player_board:
		var player_stunned := combat_manager.player_fighter.is_stunned()
		if player_stunned and player_board.state != BoardManager.BoardState.STUNNED:
			player_board.apply_stun(combat_manager.player_fighter.stun_remaining)
		elif not player_stunned and player_board.state == BoardManager.BoardState.STUNNED:
			player_board.set_state(BoardManager.BoardState.IDLE)

	if combat_manager and enemy_board:
		var enemy_stunned := combat_manager.enemy_fighter.is_stunned()
		if enemy_stunned and enemy_board.state != BoardManager.BoardState.STUNNED:
			enemy_board.apply_stun(combat_manager.enemy_fighter.stun_remaining)
		elif not enemy_stunned and enemy_board.state == BoardManager.BoardState.STUNNED:
			enemy_board.set_state(BoardManager.BoardState.IDLE)


func reset_match() -> void:
	match_timer = 0.0
	winner_id = 0

	if combat_manager:
		combat_manager.reset()
	if player_board:
		player_board.generate_initial_board()
	if enemy_board:
		enemy_board.generate_initial_board()

	_stats_tracker.reset()

	change_state(GameState.COUNTDOWN)


# --- Signal Handlers ---

func _on_countdown_finished() -> void:
	if current_state == GameState.COUNTDOWN:
		change_state(GameState.BATTLE)


func _on_resume_pressed() -> void:
	if current_state == GameState.PAUSED:
		change_state(GameState.BATTLE)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_continue_pressed() -> void:
	if current_state == GameState.END:
		change_state(GameState.STATS)


func _on_rematch_pressed() -> void:
	reset_match()


func _on_stats_quit_pressed() -> void:
	get_tree().quit()


func _on_match_ended(result: int) -> void:
	winner_id = result
	change_state(GameState.END)


func _on_player_matches_resolved(result: CascadeHandler.CascadeResult) -> void:
	if combat_manager:
		combat_manager.process_cascade_result(true, result)
	_stats_tracker.record_cascade_result(result)


func _on_enemy_matches_resolved(result: CascadeHandler.CascadeResult) -> void:
	if combat_manager:
		combat_manager.process_cascade_result(false, result)


func _on_damage_dealt(target: Fighter, result: Fighter.DamageResult) -> void:
	if combat_manager and target == combat_manager.enemy_fighter:
		_stats_tracker.record_damage(result.hp_damage)
	if result.armor_absorbed > 0:
		_stats_tracker.record_armor_used(result.armor_absorbed)


func _on_healing_done(_target: Fighter, amount: int) -> void:
	_stats_tracker.record_heal(amount)


func _on_armor_gained(_target: Fighter, _amount: int) -> void:
	pass  # Stats tracker doesn't track armor gained


func _on_stun_applied(target: Fighter, duration: float) -> void:
	if combat_manager and target == combat_manager.enemy_fighter:
		_stats_tracker.record_stun(duration)

	# Show stun overlay
	if target == combat_manager.player_fighter and player_stun_overlay:
		player_stun_overlay.show_stun(duration)
	elif target == combat_manager.enemy_fighter and enemy_stun_overlay:
		enemy_stun_overlay.show_stun(duration)


func _on_stun_ended(fighter: Fighter) -> void:
	if fighter == combat_manager.player_fighter and player_stun_overlay:
		player_stun_overlay.hide_stun()
	elif fighter == combat_manager.enemy_fighter and enemy_stun_overlay:
		enemy_stun_overlay.hide_stun()
