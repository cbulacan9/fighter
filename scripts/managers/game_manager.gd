extends Node

signal state_changed(new_state: GameState)

enum GameState {
	MODE_SELECT,
	CHARACTER_SELECT,
	INIT,
	COUNTDOWN,
	BATTLE,
	PAUSED,
	END,
	STATS
}

enum GameMode {
	PLAYER_VS_AI,
	AI_VS_AI
}

enum Difficulty {
	EASY,
	MEDIUM,
	HARD
}

@export var player_data_path: String = "res://resources/fighters/default_player.tres"
@export var enemy_data_path: String = "res://resources/fighters/default_enemy.tres"

var current_state: GameState = GameState.STATS  # Start at STATS so transition to MODE_SELECT actually triggers
var current_mode: GameMode = GameMode.PLAYER_VS_AI
var current_difficulty: Difficulty = Difficulty.MEDIUM
var match_timer: float = 0.0
var winner_id: int = 0

# Character system
var character_registry: CharacterRegistry
var unlock_manager: UnlockManager
var selected_player_character: CharacterData
var selected_enemy_character: CharacterData

# Node references (set via _ready or exported)
var player_board: BoardManager
var enemy_board: BoardManager
var combat_manager: CombatManager
var ai_controller: AIController
var player_ai_controller: AIController  # For AI vs AI mode
var game_overlay: GameOverlay
var stats_screen: StatsScreen
var hud: HUD
var damage_spawner: DamageNumberSpawner
var player_stun_overlay: StunOverlay
var enemy_stun_overlay: StunOverlay
var mode_select_screen: ModeSelectScreen
var character_select_screen: CharacterSelect
var ability_announcement_spawner: AbilityAnnouncementSpawner

# Character selection tracking
var _selecting_player: bool = true

var _stats_tracker: StatsTracker
var _player_data: FighterData
var _enemy_data: FighterData
var _unlock_notification: UnlockNotification


func _ready() -> void:
	_stats_tracker = StatsTracker.new()
	_initialize_character_registry()
	_load_fighter_data()
	call_deferred("_initialize_systems")


## Initializes the character registry and loads all available characters.
func _initialize_character_registry() -> void:
	character_registry = CharacterRegistry.new()
	character_registry.load_all()

	# Initialize unlock manager
	unlock_manager = UnlockManager.new()
	unlock_manager.setup(character_registry)
	unlock_manager.character_unlocked.connect(_on_character_unlocked)


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

	# Start at mode selection
	change_state(GameState.MODE_SELECT)


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

	# Find AI controllers
	ai_controller = parent.get_node_or_null("AIController")
	player_ai_controller = parent.get_node_or_null("PlayerAIController")

	# Find UI nodes
	var ui := parent.get_node_or_null("UI")
	if ui:
		hud = ui.get_node_or_null("HUD")
		game_overlay = ui.get_node_or_null("GameOverlay")
		stats_screen = ui.get_node_or_null("StatsScreen")
		damage_spawner = ui.get_node_or_null("DamageNumbers")
		player_stun_overlay = ui.get_node_or_null("PlayerStunOverlay")
		enemy_stun_overlay = ui.get_node_or_null("EnemyStunOverlay")
		mode_select_screen = ui.get_node_or_null("ModeSelectScreen")
		character_select_screen = ui.get_node_or_null("CharacterSelectScreen")
		ability_announcement_spawner = ui.get_node_or_null("AbilityAnnouncements")

	# Position boards and stun overlays using HUD layout constants
	# (must be after UI nodes are found so stun overlays can be positioned)
	_position_boards()


## Position boards based on HUD layout constants
## This ensures board positions stay in sync with UI positioning
func _position_boards() -> void:
	const BOARD_X := 30.0  # X position for both boards (closer to left edge)
	const BOARD_WIDTH := 640.0  # 8 cols × 80px
	const BOARD_HEIGHT := 480.0  # 6 rows × 80px

	# Enemy board Y is calculated from HUD.ENEMY_UI_Y + offset
	var enemy_board_y := HUD.get_enemy_board_y()
	if enemy_board:
		enemy_board.position = Vector2(BOARD_X, enemy_board_y)
		enemy_board.update_input_position()  # Update input handler with new position

		# Also update enemy stun overlay to match board position
		if enemy_stun_overlay:
			enemy_stun_overlay.offset_left = BOARD_X
			enemy_stun_overlay.offset_top = enemy_board_y
			enemy_stun_overlay.offset_right = BOARD_X + BOARD_WIDTH
			enemy_stun_overlay.offset_bottom = enemy_board_y + BOARD_HEIGHT

	# Player board Y is calculated from HUD.PLAYER_UI_Y + offset
	var player_board_y := HUD.get_player_board_y()
	if player_board:
		player_board.position = Vector2(BOARD_X, player_board_y)
		player_board.update_input_position()  # Update input handler with new position

		# Also update player stun overlay to match board position
		if player_stun_overlay:
			player_stun_overlay.offset_left = BOARD_X
			player_stun_overlay.offset_top = player_board_y
			player_stun_overlay.offset_right = BOARD_X + BOARD_WIDTH
			player_stun_overlay.offset_bottom = player_board_y + BOARD_HEIGHT


func _connect_signals() -> void:
	# ModeSelectScreen signals
	if mode_select_screen:
		mode_select_screen.mode_selected.connect(_on_mode_selected)

	# CharacterSelectScreen signals
	if character_select_screen:
		character_select_screen.character_selected.connect(_on_character_selected)
		character_select_screen.back_pressed.connect(_on_character_select_back)

	# GameOverlay signals
	if game_overlay:
		game_overlay.countdown_finished.connect(_on_countdown_finished)
		game_overlay.resume_pressed.connect(_on_resume_pressed)
		game_overlay.quit_pressed.connect(_on_quit_pressed)
		game_overlay.continue_pressed.connect(_on_continue_pressed)

	# StatsScreen signals
	if stats_screen:
		stats_screen.new_game_pressed.connect(_on_new_game_pressed)
		stats_screen.rematch_pressed.connect(_on_rematch_pressed)

	# CombatManager signals
	if combat_manager:
		combat_manager.match_ended.connect(_on_match_ended)
		combat_manager.damage_dealt.connect(_on_damage_dealt)
		combat_manager.healing_done.connect(_on_healing_done)
		combat_manager.armor_gained.connect(_on_armor_gained)
		combat_manager.stun_applied.connect(_on_stun_applied)
		combat_manager.stun_ended.connect(_on_stun_ended)
		combat_manager.damage_dodged.connect(_on_damage_dodged)
		combat_manager.status_effect_applied.connect(_on_status_effect_applied)
		combat_manager.status_effect_removed.connect(_on_status_effect_removed)
		combat_manager.status_damage_dealt.connect(_on_status_damage_dealt)

	# Board signals
	if player_board:
		player_board.immediate_matches.connect(_on_player_immediate_matches)
		player_board.matches_resolved.connect(_on_player_matches_resolved)
		player_board.pet_ability_activated.connect(_on_pet_ability_activated)
	if enemy_board:
		enemy_board.immediate_matches.connect(_on_enemy_immediate_matches)
		enemy_board.matches_resolved.connect(_on_enemy_matches_resolved)
		enemy_board.pet_ability_activated.connect(_on_pet_ability_activated)


func change_state(new_state: GameState) -> void:
	if current_state == new_state:
		return

	_exit_state(current_state)
	current_state = new_state
	_enter_state(new_state)
	state_changed.emit(new_state)


func _enter_state(state: GameState) -> void:
	match state:
		GameState.MODE_SELECT:
			_disable_gameplay()
			if mode_select_screen:
				mode_select_screen.show_screen()

		GameState.CHARACTER_SELECT:
			_disable_gameplay()
			_show_character_select()

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
				var combat_log_entries: Array[Dictionary] = []
				if hud:
					var combat_log := hud.get_combat_log_debugger()
					if combat_log:
						combat_log_entries = combat_log.get_log_entries()
				stats_screen.show_stats(_stats_tracker.get_stats(), combat_log_entries)


func _exit_state(state: GameState) -> void:
	match state:
		GameState.MODE_SELECT:
			if mode_select_screen:
				mode_select_screen.hide_screen()
		GameState.CHARACTER_SELECT:
			if character_select_screen:
				character_select_screen.hide_screen()
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

			# Tick combat for stun timers and status effects
			if combat_manager:
				combat_manager.tick(delta)


func _setup_match() -> void:
	match_timer = 0.0
	winner_id = 0
	_stats_tracker.reset()

	# Prepare fighter data from selected characters or use defaults
	_prepare_fighter_data()

	# Initialize combat
	if combat_manager:
		combat_manager.initialize(_player_data, _enemy_data)
		# Set character data for ultimate abilities
		if selected_player_character:
			combat_manager.set_character_data(combat_manager.player_fighter, selected_player_character)
		if selected_enemy_character:
			combat_manager.set_character_data(combat_manager.enemy_fighter, selected_enemy_character)

	# Link boards to their owner fighters and combat manager
	if player_board and combat_manager:
		player_board.set_owner_fighter(combat_manager.player_fighter)
		player_board.set_combat_manager(combat_manager)
	if enemy_board and combat_manager:
		enemy_board.set_owner_fighter(combat_manager.enemy_fighter)
		enemy_board.set_combat_manager(combat_manager)

	# Initialize boards with character data if available
	if player_board:
		if selected_player_character:
			player_board.initialize_with_character(selected_player_character, true)
		else:
			player_board.initialize(_player_data, true)

	if enemy_board:
		if selected_enemy_character:
			enemy_board.initialize_with_character(selected_enemy_character, false)
		else:
			enemy_board.initialize(_enemy_data, false)

	# Setup enemy AI
	if ai_controller and enemy_board:
		ai_controller.setup(enemy_board, enemy_board._match_detector)

	# Setup player AI for AI vs AI mode
	if current_mode == GameMode.AI_VS_AI and player_ai_controller and player_board:
		player_ai_controller.setup(player_board, player_board._match_detector)
		# Disable player input since AI controls the board
		player_board.is_player_controlled = false

	# Setup HUD
	if hud and combat_manager:
		hud.setup(combat_manager.player_fighter, combat_manager.enemy_fighter, selected_player_character, selected_enemy_character)

	# Setup damage number spawner
	if damage_spawner and combat_manager:
		var player_pos := Vector2(360, 750)  # Center of player board area
		var enemy_pos := Vector2(360, 300)   # Center of enemy board area
		damage_spawner.setup(combat_manager, player_pos, enemy_pos)

	# Setup ability announcement spawner
	if ability_announcement_spawner:
		var player_announce_pos := Vector2(360, 850)  # Below player board
		var enemy_announce_pos := Vector2(360, 250)   # Center of enemy board area
		ability_announcement_spawner.setup(player_announce_pos, enemy_announce_pos)

	# Setup defensive queue displays and damage number integration
	if combat_manager and combat_manager.defensive_queue_manager:
		# Setup HUD defensive displays
		if hud:
			hud.setup_defensive_queue(combat_manager.player_fighter, combat_manager.enemy_fighter,
				combat_manager.defensive_queue_manager)

		# Setup damage number spawner for defensive events
		if damage_spawner:
			damage_spawner.setup_defensive_queue(combat_manager.defensive_queue_manager)


## Prepares fighter data from selected characters or loads default files.
func _prepare_fighter_data() -> void:
	if selected_player_character:
		_player_data = _create_fighter_data(selected_player_character)
	elif not _player_data:
		_load_fighter_data()

	if selected_enemy_character:
		_enemy_data = _create_fighter_data(selected_enemy_character)
	elif not _enemy_data:
		_load_fighter_data()


func _enable_gameplay() -> void:
	if player_board:
		player_board.set_state(BoardManager.BoardState.IDLE)
	if enemy_board:
		enemy_board.set_state(BoardManager.BoardState.IDLE)

	# Enable enemy AI
	if ai_controller:
		ai_controller.set_enabled(true)

	# Enable player AI in AI vs AI mode
	if current_mode == GameMode.AI_VS_AI and player_ai_controller:
		player_ai_controller.set_enabled(true)


func _disable_gameplay() -> void:
	if player_board:
		if player_board.state == BoardManager.BoardState.IDLE:
			player_board.lock_input()
		player_board.disable_all_input()
	if enemy_board:
		if enemy_board.state == BoardManager.BoardState.IDLE:
			enemy_board.lock_input()
		enemy_board.disable_all_input()

	# Disable enemy AI
	if ai_controller:
		ai_controller.set_enabled(false)

	# Disable player AI
	if player_ai_controller:
		player_ai_controller.set_enabled(false)


func reset_match() -> void:
	match_timer = 0.0
	winner_id = 0

	if combat_manager:
		combat_manager.reset()
		# Clear defensive queue data for both fighters
		if combat_manager.defensive_queue_manager:
			combat_manager.defensive_queue_manager.clear_fighter(combat_manager.player_fighter)
			combat_manager.defensive_queue_manager.clear_fighter(combat_manager.enemy_fighter)

	# Reset boards fully (clears state, sequence tracker, and regenerates)
	if player_board:
		player_board.reset()
	if enemy_board:
		enemy_board.reset()

	# Reconnect board signals after reset (reset() disconnects them)
	if player_board and combat_manager:
		player_board.set_owner_fighter(combat_manager.player_fighter)
	if enemy_board and combat_manager:
		enemy_board.set_owner_fighter(combat_manager.enemy_fighter)

	# Clear stun overlays
	if player_stun_overlay:
		player_stun_overlay.hide_stun()
	if enemy_stun_overlay:
		enemy_stun_overlay.hide_stun()

	# Reset HUD sequence indicators
	if hud:
		if hud.player_sequence_indicator:
			hud.player_sequence_indicator.reset()
		if hud.enemy_sequence_indicator:
			hud.enemy_sequence_indicator.reset()
		# Reset Hunter combo tree displays
		var player_combo_tree := hud.get_player_combo_tree_display()
		if player_combo_tree:
			player_combo_tree.reset()
		var enemy_combo_tree := hud.get_enemy_combo_tree_display()
		if enemy_combo_tree:
			enemy_combo_tree.reset()
		# Reset Hunter pet population displays
		var player_pet_pop := hud.get_player_pet_population_display()
		if player_pet_pop:
			player_pet_pop.reset()
		var enemy_pet_pop := hud.get_enemy_pet_population_display()
		if enemy_pet_pop:
			enemy_pet_pop.reset()
		# Reset combo log debugger
		var combo_log := hud.get_combo_log_debugger()
		if combo_log:
			combo_log.reset()
		# Reset combat log debugger
		var combat_log := hud.get_combat_log_debugger()
		if combat_log:
			combat_log.reset()
		# Reset Warden defense displays
		var player_warden := hud.get_player_warden_display()
		if player_warden:
			player_warden.reset()
		var enemy_warden := hud.get_enemy_warden_display()
		if enemy_warden:
			enemy_warden.reset()

	_stats_tracker.reset()

	change_state(GameState.COUNTDOWN)


# --- Signal Handlers ---

func _on_mode_selected(mode: int, difficulty: int) -> void:
	# Convert the ints to our enums
	current_mode = mode as GameMode
	current_difficulty = difficulty as Difficulty

	# Reset selection state and clear previous selections
	_selecting_player = true
	selected_player_character = null
	selected_enemy_character = null

	change_state(GameState.CHARACTER_SELECT)


## Shows character select screen with appropriate title for current selection phase.
func _show_character_select() -> void:
	if not character_select_screen:
		return

	# Setup the screen with available characters
	var characters := get_all_characters()
	var unlocked := get_unlocked_character_ids()
	character_select_screen.setup(characters, unlocked)

	# Set title based on which player we're selecting for
	if _selecting_player:
		character_select_screen.set_title("SELECT PLAYER 1")
	else:
		character_select_screen.set_title("SELECT PLAYER 2")

	character_select_screen.show_screen()


## Called when a character is selected on the character select screen.
func _on_character_selected(character_id: String) -> void:
	if _selecting_player:
		# First selection - store as player character
		select_player_character(character_id)
		_selecting_player = false
		# Show again for P2 selection
		_show_character_select()
	else:
		# Second selection - store as enemy character and start match
		select_enemy_character(character_id)
		change_state(GameState.INIT)


## Called when back is pressed on character select screen.
func _on_character_select_back() -> void:
	if _selecting_player:
		# On P1 selection, back goes to mode select
		change_state(GameState.MODE_SELECT)
	else:
		# On P2 selection, back goes to P1 selection
		_selecting_player = true
		selected_player_character = null
		_show_character_select()


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


func _on_new_game_pressed() -> void:
	change_state(GameState.MODE_SELECT)


func _on_match_ended(result: int) -> void:
	winner_id = result

	# Record match result for unlock system
	if unlock_manager:
		if result == 1:  # Player won
			var opponent_id := ""
			if selected_enemy_character:
				opponent_id = selected_enemy_character.character_id
			if opponent_id != "":
				unlock_manager.on_match_won(opponent_id)
		elif result == 2:  # Player lost
			unlock_manager.on_match_lost()

	change_state(GameState.END)


## Called immediately when matches are detected (before animations)
## This applies combat effects right away for responsive gameplay
func _on_player_immediate_matches(matches: Array) -> void:
	if combat_manager:
		combat_manager.process_immediate_matches(true, matches)


## Called immediately when matches are detected (before animations)
func _on_enemy_immediate_matches(matches: Array) -> void:
	if combat_manager:
		combat_manager.process_immediate_matches(false, matches)


func _on_player_matches_resolved(result: CascadeHandler.CascadeResult) -> void:
	# Combat effects are now applied immediately via _on_player_immediate_matches
	# This handler is kept for stats tracking and other post-cascade processing
	_stats_tracker.record_cascade_result(result)


func _on_enemy_matches_resolved(_result: CascadeHandler.CascadeResult) -> void:
	# Combat effects are now applied immediately via _on_enemy_immediate_matches
	pass


func _on_damage_dealt(target: Fighter, result: Fighter.DamageResult) -> void:
	if combat_manager and target == combat_manager.enemy_fighter:
		# Track total damage dealt (before armor absorption) for accurate stats
		_stats_tracker.record_damage(result.total_damage)
	if result.armor_absorbed > 0:
		_stats_tracker.record_armor_used(result.armor_absorbed)


func _on_healing_done(_target: Fighter, amount: int) -> void:
	_stats_tracker.record_heal(amount)


func _on_armor_gained(_target: Fighter, _amount: int) -> void:
	pass  # Stats tracker doesn't track armor gained


func _on_stun_applied(target: Fighter, duration: float) -> void:
	if combat_manager and target == combat_manager.enemy_fighter:
		_stats_tracker.record_stun(duration)

	# Apply stun to the appropriate board
	if target == combat_manager.player_fighter:
		if player_board and player_board.state != BoardManager.BoardState.STUNNED:
			player_board.apply_stun(duration)
		if player_stun_overlay:
			player_stun_overlay.show_stun(duration)
	elif target == combat_manager.enemy_fighter:
		if enemy_board and enemy_board.state != BoardManager.BoardState.STUNNED:
			enemy_board.apply_stun(duration)
		if enemy_stun_overlay:
			enemy_stun_overlay.show_stun(duration)


func _on_stun_ended(fighter: Fighter) -> void:
	# Remove stun from the appropriate board
	if fighter == combat_manager.player_fighter:
		if player_board and player_board.state == BoardManager.BoardState.STUNNED:
			player_board.set_state(BoardManager.BoardState.IDLE)
		if player_stun_overlay:
			player_stun_overlay.hide_stun()
	elif fighter == combat_manager.enemy_fighter:
		if enemy_board and enemy_board.state == BoardManager.BoardState.STUNNED:
			enemy_board.set_state(BoardManager.BoardState.IDLE)
		if enemy_stun_overlay:
			enemy_stun_overlay.hide_stun()


func _on_damage_dodged(_target: Fighter, _source: Fighter) -> void:
	# Forward to UI for dodge feedback (implemented in Task 031)
	pass


func _on_status_effect_applied(_target: Fighter, _effect: StatusEffect) -> void:
	# Forward to UI for status effect display (implemented in Task 031)
	pass


func _on_status_effect_removed(_target: Fighter, _effect_type: StatusTypes.StatusType) -> void:
	# Forward to UI for status effect removal (implemented in Task 031)
	pass


func _on_status_damage_dealt(target: Fighter, damage: float, _effect_type: StatusTypes.StatusType) -> void:
	# Record status effect damage to stats
	if combat_manager and target == combat_manager.enemy_fighter:
		_stats_tracker.record_damage(int(damage))


func _on_pet_ability_activated(pattern: SequencePattern, stacks: int, is_player: bool) -> void:
	if not ability_announcement_spawner or not pattern:
		return

	var ability_name: String = "PET Ability"
	if pattern.display_name and pattern.display_name != "":
		ability_name = pattern.display_name

	var stack_suffix := " x%d" % stacks if stacks > 1 else ""

	# Offensive effect shows on the ENEMY of whoever activated it
	var offensive_desc := AbilityAnnouncementSpawner.get_offensive_effect_description(pattern)
	if offensive_desc != "":
		offensive_desc += stack_suffix
		# Player activates -> show on enemy board (red), Enemy activates -> show on player board (red)
		if is_player:
			ability_announcement_spawner.spawn_enemy_announcement(ability_name, offensive_desc, Color.RED)
		else:
			ability_announcement_spawner.spawn_player_announcement(ability_name, offensive_desc, Color.RED)

	# Self-buff shows on the SELF of whoever activated it
	var buff_desc := AbilityAnnouncementSpawner.get_self_buff_description(pattern)
	if buff_desc != "":
		buff_desc += stack_suffix
		# Player activates -> show on player board (green), Enemy activates -> show on enemy board (green)
		if is_player:
			ability_announcement_spawner.spawn_player_announcement(ability_name, buff_desc, Color.GREEN)
		else:
			ability_announcement_spawner.spawn_enemy_announcement(ability_name, buff_desc, Color.GREEN)


# --- Character Selection ---

## Selects a character for the player by ID.
func select_player_character(character_id: String) -> void:
	if character_registry and character_registry.has_character(character_id):
		selected_player_character = character_registry.get_character(character_id)
	else:
		push_warning("GameManager: Player character not found: %s" % character_id)


## Selects a character for the enemy by ID.
func select_enemy_character(character_id: String) -> void:
	if character_registry and character_registry.has_character(character_id):
		selected_enemy_character = character_registry.get_character(character_id)
	else:
		push_warning("GameManager: Enemy character not found: %s" % character_id)


## Initializes a match with specific character data for both sides.
func initialize_with_characters(player_char: CharacterData, enemy_char: CharacterData) -> void:
	selected_player_character = player_char
	selected_enemy_character = enemy_char

	# Regenerate fighter data from characters
	if player_char:
		_player_data = _create_fighter_data(player_char)
	if enemy_char:
		_enemy_data = _create_fighter_data(enemy_char)


## Creates FighterData from CharacterData.
func _create_fighter_data(char_data: CharacterData) -> FighterData:
	var fighter := FighterData.new()
	fighter.fighter_name = char_data.display_name
	fighter.max_hp = char_data.base_hp
	fighter.max_armor = char_data.max_armor
	fighter.strength = char_data.base_strength
	fighter.portrait = PlaceholderTextures.get_or_generate_portrait(char_data, false)

	# Convert spawn weights from CharacterData format to FighterData format
	fighter.tile_weights = char_data.spawn_weights.duplicate()

	# Copy mana configuration
	fighter.mana_config = char_data.mana_config

	# Copy sequences
	fighter.sequences = char_data.sequences.duplicate()

	return fighter


## Returns all available characters from the registry.
func get_all_characters() -> Array[CharacterData]:
	if character_registry:
		return character_registry.get_all_characters()
	return []


## Returns a starter character from the registry.
func get_starter_character() -> CharacterData:
	if character_registry:
		return character_registry.get_starter()
	return null


## Returns unlocked character IDs for character selection.
func get_unlocked_character_ids() -> Array[String]:
	if unlock_manager:
		return unlock_manager.get_unlocked_ids()
	return []


# --- Unlock System ---

## Called when a character is unlocked.
func _on_character_unlocked(character_id: String) -> void:
	var char_data := character_registry.get_character(character_id)
	if char_data:
		_show_unlock_notification(char_data)


## Shows the unlock notification UI for a character.
func _show_unlock_notification(char_data: CharacterData) -> void:
	# Create notification if it doesn't exist
	if not _unlock_notification:
		var notification_scene := load("res://scenes/ui/unlock_notification.tscn")
		if notification_scene:
			_unlock_notification = notification_scene.instantiate()
			get_tree().root.add_child(_unlock_notification)
		else:
			push_warning("GameManager: Could not load unlock_notification.tscn")
			return

	_unlock_notification.show_unlock(char_data)
