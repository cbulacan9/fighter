class_name CombatManager
extends Node

signal damage_dealt(target: Fighter, result: Fighter.DamageResult)
signal healing_done(target: Fighter, amount: int)
signal armor_gained(target: Fighter, amount: int)
signal stun_applied(target: Fighter, duration: float)
signal stun_ended(fighter: Fighter)
signal fighter_defeated(fighter: Fighter)
signal match_ended(winner_id: int)
signal mana_changed(fighter: Fighter, bar_index: int, current: int, max_value: int)
signal ultimate_ready(fighter: Fighter)
signal ultimate_activated(fighter: Fighter, ability: AbilityData)
signal damage_dodged(target: Fighter, source: Fighter)
signal status_effect_applied(target: Fighter, effect: StatusEffect)
signal status_effect_removed(target: Fighter, effect_type: StatusTypes.StatusType)
signal status_damage_dealt(target: Fighter, damage: float, effect_type: StatusTypes.StatusType)

enum MatchResult {
	ONGOING = 0,
	PLAYER_WINS = 1,
	ENEMY_WINS = 2,
	DRAW = 3
}

var player_fighter: Fighter
var enemy_fighter: Fighter
var mana_system: ManaSystem
var status_effect_manager: StatusEffectManager
var effect_processor: EffectProcessor
var defensive_queue_manager: DefensiveQueueManager

var _tile_data_cache: Dictionary = {}
var _player_was_stunned: bool = false
var _enemy_was_stunned: bool = false
var _character_data: Dictionary = {}  # {Fighter: CharacterData}


func _ready() -> void:
	_load_tile_data()
	_setup_mana_system()
	_setup_status_effects()
	_setup_effect_processor()
	_setup_defensive_queue()


func _setup_mana_system() -> void:
	mana_system = ManaSystem.new()
	mana_system.mana_changed.connect(_on_mana_changed)
	mana_system.all_bars_full.connect(_on_all_bars_full)


func _setup_status_effects() -> void:
	status_effect_manager = StatusEffectManager.new()

	# Connect signals from StatusEffectManager
	status_effect_manager.effect_applied.connect(_on_status_effect_applied)
	status_effect_manager.effect_removed.connect(_on_status_effect_removed)
	status_effect_manager.effect_ticked.connect(_on_status_effect_ticked)


func _setup_effect_processor() -> void:
	effect_processor = EffectProcessor.new()
	effect_processor.setup(self)


func _setup_defensive_queue() -> void:
	defensive_queue_manager = DefensiveQueueManager.new()


func initialize(player_data: FighterData, enemy_data: FighterData) -> void:
	# Clear any existing status effects before reinitializing
	if status_effect_manager:
		if player_fighter:
			status_effect_manager.remove_all(player_fighter)
		if enemy_fighter:
			status_effect_manager.remove_all(enemy_fighter)

	if not player_fighter:
		player_fighter = Fighter.new()
		add_child(player_fighter)

	if not enemy_fighter:
		enemy_fighter = Fighter.new()
		add_child(enemy_fighter)

	player_fighter.initialize(player_data)
	enemy_fighter.initialize(enemy_data)

	# Disconnect old signals before reconnecting to avoid duplicates
	if player_fighter.defeated.is_connected(_on_fighter_defeated):
		player_fighter.defeated.disconnect(_on_fighter_defeated)
	if enemy_fighter.defeated.is_connected(_on_fighter_defeated):
		enemy_fighter.defeated.disconnect(_on_fighter_defeated)

	player_fighter.defeated.connect(_on_fighter_defeated.bind(player_fighter))
	enemy_fighter.defeated.connect(_on_fighter_defeated.bind(enemy_fighter))

	# Reset mana system before setting up new configs
	if mana_system:
		mana_system.reset_all()

	# Setup mana for fighters (if they have mana config)
	_setup_fighter_mana(player_fighter, player_data)
	_setup_fighter_mana(enemy_fighter, enemy_data)

	_player_was_stunned = false
	_enemy_was_stunned = false


func _setup_fighter_mana(fighter: Fighter, data: FighterData) -> void:
	if not fighter or not data:
		return

	# Set mana system reference on fighter
	fighter.mana_system = mana_system

	# Set status effect manager reference on fighter
	fighter.status_manager = status_effect_manager

	# Setup mana bars if fighter has mana config
	if data.mana_config:
		mana_system.setup_fighter(fighter, data.mana_config)


func process_cascade_result(source_is_player: bool, result: CascadeHandler.CascadeResult) -> void:
	# NOTE: Combat effects are now applied immediately via process_immediate_matches
	# This function is kept for backwards compatibility but no longer processes combat
	pass


## Process matches immediately when detected (before animations complete)
## This provides responsive gameplay - damage/healing happens right away
func process_immediate_matches(source_is_player: bool, matches: Array) -> void:
	var source := get_fighter(source_is_player)

	# Notify status manager that this fighter made matches (triggers ON_MATCH effects like Bleed)
	if status_effect_manager and not matches.is_empty():
		status_effect_manager._on_target_matched(source)

	for match_result in matches:
		apply_match_effect(source, match_result)

	# Process mana gain from matches
	_process_mana_from_immediate_matches(source, matches)

	var victory := check_victory()
	if victory != MatchResult.ONGOING:
		match_ended.emit(victory)


## Process mana from immediate matches array
func _process_mana_from_immediate_matches(fighter: Fighter, matches: Array) -> void:
	if not mana_system:
		return

	# Check if fighter is mana blocked
	if fighter.is_mana_blocked():
		return

	# Check if fighter has mana configured
	if not mana_system.has_fighter(fighter):
		return

	for match_result in matches:
		var match_count: int = match_result.positions.size()
		mana_system.add_mana_from_match(fighter, match_count)


func _process_mana_from_matches(fighter: Fighter, result: CascadeHandler.CascadeResult) -> void:
	if not mana_system:
		return

	# Check if fighter is mana blocked
	if fighter.is_mana_blocked():
		return

	# Check if fighter has mana configured
	if not mana_system.has_fighter(fighter):
		return

	for match_result in result.all_matches:
		var match_count := match_result.positions.size()
		# TODO: Check if tile type generates mana for this character
		# For now, all matches generate mana
		mana_system.add_mana_from_match(fighter, match_count)


func apply_match_effect(source: Fighter, match_result: MatchDetector.MatchResult) -> void:
	# Skip effects for matches containing smoke-obscured tiles
	if match_result.contains_hidden_tile:
		return

	var effect_value := _get_effect_value(match_result.tile_type, match_result.count)
	var target: Fighter

	match match_result.tile_type:
		TileTypes.Type.SWORD:
			target = get_opponent(source)
			# Scale sword damage by strength (10 = baseline, 15 = +50% damage)
			var strength_scaled := int(float(effect_value) * (float(source.strength) / 10.0))
			_apply_damage(target, source, strength_scaled)

		TileTypes.Type.SHIELD:
			var actual := source.add_armor(effect_value)
			armor_gained.emit(source, actual)

		TileTypes.Type.POTION:
			var actual := source.heal(effect_value)
			healing_done.emit(source, actual)
			source.reset_health_ultimate_trigger()  # Allow re-trigger if healed above threshold

		TileTypes.Type.LIGHTNING:
			target = get_opponent(source)
			var actual := target.apply_stun(float(effect_value))
			stun_applied.emit(target, actual)

		TileTypes.Type.FILLER:
			pass  # No combat effect

		TileTypes.Type.MANA:
			var mana_value: int = _tile_data_cache[TileTypes.Type.MANA].get_value(match_result.count)
			if mana_system and not source.is_mana_blocked():
				# Fill all mana bars for characters with multiple bars (like Assassin)
				if mana_system.get_bar_count(source) > 1:
					mana_system.add_mana_all_bars(source, mana_value)
				else:
					mana_system.add_mana(source, mana_value)

		TileTypes.Type.FOCUS:
			# Stacks based on match count: 3=1, 4=2, 5=3
			var stacks := match_result.count - 2
			if status_effect_manager:
				var focus_effect := preload("res://resources/status_effects/focus.tres")
				status_effect_manager.apply(source, focus_effect, source, stacks)

		TileTypes.Type.SMOKE_BOMB:
			# Fill mana bar 0
			if mana_system and not source.is_mana_blocked():
				mana_system.add_mana_from_match(source, match_result.count, 0)
			# Trigger passive effect: hide tiles on enemy board
			var smoke_tile_data := _tile_data_cache.get(TileTypes.Type.SMOKE_BOMB) as PuzzleTileData
			if smoke_tile_data and smoke_tile_data.passive_effect and effect_processor:
				effect_processor.process_effect(smoke_tile_data.passive_effect, source, match_result.count)

		TileTypes.Type.SHADOW_STEP:
			# Fill mana bar 1
			if mana_system and not source.is_mana_blocked():
				mana_system.add_mana_from_match(source, match_result.count, 1)
			# Trigger passive effect: grant dodge chance to self
			var shadow_tile_data := _tile_data_cache.get(TileTypes.Type.SHADOW_STEP) as PuzzleTileData
			if shadow_tile_data and shadow_tile_data.passive_effect and effect_processor:
				effect_processor.process_effect(shadow_tile_data.passive_effect, source, match_result.count)

		TileTypes.Type.MAGIC_ATTACK:
			target = get_opponent(source)
			var base_damage := effect_value
			# Check for stored absorb damage to release
			if defensive_queue_manager:
				var release_damage := defensive_queue_manager.release_stored_damage(source, match_result.count)
				base_damage += release_damage
			# Scale magic damage by strength
			var strength_scaled := int(float(base_damage) * (float(source.strength) / 10.0))
			_apply_damage(target, source, strength_scaled)
			# Generate mana
			if mana_system and not source.is_mana_blocked():
				mana_system.add_mana_from_match(source, match_result.count)

		TileTypes.Type.REFLECTION:
			# Queue reflection defense
			if defensive_queue_manager:
				defensive_queue_manager.queue_defense(source, StatusTypes.StatusType.REFLECTION_QUEUED, match_result.count)
			# Generate mana
			if mana_system and not source.is_mana_blocked():
				mana_system.add_mana_from_match(source, match_result.count)

		TileTypes.Type.CANCEL:
			# Queue cancel defense
			if defensive_queue_manager:
				defensive_queue_manager.queue_defense(source, StatusTypes.StatusType.CANCEL_QUEUED, match_result.count)
			# Generate mana
			if mana_system and not source.is_mana_blocked():
				mana_system.add_mana_from_match(source, match_result.count)

		TileTypes.Type.ABSORB:
			# Queue absorb defense
			if defensive_queue_manager:
				defensive_queue_manager.queue_defense(source, StatusTypes.StatusType.ABSORB_QUEUED, match_result.count)
			# Generate mana
			if mana_system and not source.is_mana_blocked():
				mana_system.add_mana_from_match(source, match_result.count)


func _apply_damage(target: Fighter, source: Fighter, base_damage: int) -> void:
	var final_damage := base_damage
	var focus_stacks_used := 0

	# Check Invincibility (complete damage immunity)
	if status_effect_manager and status_effect_manager.has_effect(target, StatusTypes.StatusType.INVINCIBILITY):
		damage_dodged.emit(target, source)  # Visual feedback
		return

	# Check Reflection (reflects damage back to attacker)
	if defensive_queue_manager and defensive_queue_manager.check_and_consume_reflection(target):
		# Reflect damage back to the source
		if source and source != target:
			var reflect_result := source.take_damage(base_damage)
			damage_dealt.emit(source, reflect_result)
		return

	if status_effect_manager:
		# Apply attacker's damage modifiers (ATTACK_UP)
		if source != null and status_effect_manager.has_effect(source, StatusTypes.StatusType.ATTACK_UP):
			var attack_bonus := status_effect_manager.get_modifier(source, StatusTypes.StatusType.ATTACK_UP)
			if attack_bonus > 0:
				final_damage = int(float(final_damage) * (1.0 + attack_bonus))

		# Apply Focus bonus (7.5% per stack, consumes all stacks)
		if source != null and status_effect_manager.has_effect(source, StatusTypes.StatusType.FOCUS):
			var focus_stacks := status_effect_manager.get_stacks(source, StatusTypes.StatusType.FOCUS)
			if focus_stacks > 0:
				var focus_bonus := 0.075 * float(focus_stacks)
				final_damage = int(float(final_damage) * (1.0 + focus_bonus))
				focus_stacks_used = focus_stacks
				status_effect_manager.remove(source, StatusTypes.StatusType.FOCUS)

		# Check target's EVASION (auto-miss, consumes one stack)
		if status_effect_manager.has_effect(target, StatusTypes.StatusType.EVASION):
			status_effect_manager.consume_evasion_stack(target)
			damage_dodged.emit(target, source)
			return

		# Combined dodge check: base agility + DODGE status effect
		var total_dodge_chance := float(target.agility) / 100.0
		if status_effect_manager.has_effect(target, StatusTypes.StatusType.DODGE):
			total_dodge_chance += status_effect_manager.get_modifier(target, StatusTypes.StatusType.DODGE)

		if total_dodge_chance > 0 and randf() < total_dodge_chance:
			damage_dodged.emit(target, source)
			return

	# Check Absorb (stores damage instead of taking it)
	if defensive_queue_manager:
		var absorbed := defensive_queue_manager.process_absorb(target, final_damage)
		final_damage -= absorbed
		if final_damage <= 0:
			return  # All damage absorbed

	# Apply damage normally
	var result := target.take_damage(final_damage)
	result.focus_stacks_consumed = focus_stacks_used
	damage_dealt.emit(target, result)

	# Check for health-based ultimate trigger (Assassin)
	target.check_health_ultimate()

	# Record damage for Cancel window
	if defensive_queue_manager:
		defensive_queue_manager.record_damage_taken(target, result.hp_damage, [])
		# Check if cancel should trigger immediately (if already queued)
		var cancel_result := defensive_queue_manager.check_and_trigger_cancel(target)
		if not cancel_result.is_empty():
			# Heal back the damage
			var healed := target.heal(cancel_result.healed)
			if healed > 0:
				healing_done.emit(target, healed)
				target.reset_health_ultimate_trigger()  # Allow re-trigger if healed above threshold


func get_fighter(is_player: bool) -> Fighter:
	return player_fighter if is_player else enemy_fighter


func get_opponent(fighter: Fighter) -> Fighter:
	if fighter == player_fighter:
		return enemy_fighter
	return player_fighter


func tick(delta: float) -> void:
	if player_fighter:
		player_fighter.tick_stun(delta)
		if _player_was_stunned and not player_fighter.is_stunned():
			stun_ended.emit(player_fighter)
		_player_was_stunned = player_fighter.is_stunned()

	if enemy_fighter:
		enemy_fighter.tick_stun(delta)
		if _enemy_was_stunned and not enemy_fighter.is_stunned():
			stun_ended.emit(enemy_fighter)
		_enemy_was_stunned = enemy_fighter.is_stunned()

	# Tick mana system (handles block timers and decay)
	if mana_system:
		mana_system.tick(delta)

	# Tick status effects
	if status_effect_manager:
		status_effect_manager.tick(delta)

	# Tick defensive queue windows
	if defensive_queue_manager:
		defensive_queue_manager.tick(delta)


func check_victory() -> int:
	if not player_fighter or not enemy_fighter:
		return MatchResult.ONGOING

	var player_dead := player_fighter.is_defeated
	var enemy_dead := enemy_fighter.is_defeated

	if player_dead and enemy_dead:
		return MatchResult.DRAW
	elif enemy_dead:
		return MatchResult.PLAYER_WINS
	elif player_dead:
		return MatchResult.ENEMY_WINS

	return MatchResult.ONGOING


func reset() -> void:
	# Clear all status effects before resetting fighters
	if status_effect_manager:
		if player_fighter:
			status_effect_manager.remove_all(player_fighter)
		if enemy_fighter:
			status_effect_manager.remove_all(enemy_fighter)

	if player_fighter:
		player_fighter.reset()
	if enemy_fighter:
		enemy_fighter.reset()

	# Reset mana system
	if mana_system:
		mana_system.reset_all()

	_player_was_stunned = false
	_enemy_was_stunned = false


func _on_fighter_defeated(fighter: Fighter) -> void:
	fighter_defeated.emit(fighter)


func _load_tile_data() -> void:
	_tile_data_cache[TileTypes.Type.SWORD] = preload("res://resources/tiles/sword.tres")
	_tile_data_cache[TileTypes.Type.SHIELD] = preload("res://resources/tiles/shield.tres")
	_tile_data_cache[TileTypes.Type.POTION] = preload("res://resources/tiles/potion.tres")
	_tile_data_cache[TileTypes.Type.LIGHTNING] = preload("res://resources/tiles/lightning.tres")
	_tile_data_cache[TileTypes.Type.FILLER] = preload("res://resources/tiles/filler.tres")
	_tile_data_cache[TileTypes.Type.FOCUS] = preload("res://resources/tiles/focus.tres")
	_tile_data_cache[TileTypes.Type.MANA] = preload("res://resources/tiles/mana.tres")
	_tile_data_cache[TileTypes.Type.SMOKE_BOMB] = preload("res://resources/tiles/smoke_bomb.tres")
	_tile_data_cache[TileTypes.Type.SHADOW_STEP] = preload("res://resources/tiles/shadow_step.tres")
	_tile_data_cache[TileTypes.Type.PREDATORS_TRANCE] = preload("res://resources/tiles/predators_trance.tres")
	_tile_data_cache[TileTypes.Type.MAGIC_ATTACK] = preload("res://resources/tiles/magic_attack.tres")
	_tile_data_cache[TileTypes.Type.REFLECTION] = preload("res://resources/tiles/reflection.tres")
	_tile_data_cache[TileTypes.Type.CANCEL] = preload("res://resources/tiles/cancel.tres")
	_tile_data_cache[TileTypes.Type.ABSORB] = preload("res://resources/tiles/absorb.tres")
	_tile_data_cache[TileTypes.Type.INVINCIBILITY_TILE] = preload("res://resources/tiles/invincibility_tile.tres")


func _get_effect_value(tile_type: TileTypes.Type, count: int) -> int:
	if _tile_data_cache.has(tile_type):
		var tile_data: PuzzleTileData = _tile_data_cache[tile_type]
		return tile_data.get_value(count)
	return 0


func _on_mana_changed(fighter: Fighter, bar_index: int, current: int, max_value: int) -> void:
	mana_changed.emit(fighter, bar_index, current, max_value)
	# Also emit on the fighter for direct listeners
	fighter.mana_changed.emit(bar_index, current, max_value)


func _on_all_bars_full(fighter: Fighter) -> void:
	# Skip mana-based ultimate for characters with health-based ultimates (Assassin)
	if fighter.uses_health_ultimate():
		return

	ultimate_ready.emit(fighter)
	fighter.ultimate_ready.emit()


# --- Ultimate Ability API ---

## Sets the character data for a fighter (required for ultimate abilities)
func set_character_data(fighter: Fighter, char_data: CharacterData) -> void:
	if fighter and char_data:
		_character_data[fighter] = char_data
		fighter.character_id = char_data.character_id


## Gets the character data for a fighter
func _get_character_data(fighter: Fighter) -> CharacterData:
	if _character_data.has(fighter):
		return _character_data[fighter]
	return null


## Activates the ultimate ability for a fighter.
## Returns true if the ultimate was successfully activated.
func activate_ultimate(fighter: Fighter) -> bool:
	var char_data := _get_character_data(fighter)
	if not char_data or not char_data.ultimate_ability:
		return false

	var ability := char_data.ultimate_ability

	# Check mana requirement
	if ability.requires_full_mana:
		if not mana_system or not mana_system.can_use_ultimate(fighter):
			return false
	elif ability.mana_cost > 0:
		# Check if fighter has enough mana for the fixed cost
		if not mana_system or mana_system.get_mana(fighter, 0) < ability.mana_cost:
			return false

	# Drain mana
	if ability.drains_all_mana and mana_system:
		mana_system.drain_all(fighter)
	elif ability.mana_cost > 0 and mana_system:
		mana_system.drain(fighter, ability.mana_cost, 0)

	# Restore full armor
	var armor_cap: int = fighter.max_armor if fighter.max_armor > 0 else fighter.max_hp
	var armor_restored := fighter.add_armor(armor_cap - fighter.armor)
	if armor_restored > 0:
		armor_gained.emit(fighter, armor_restored)

	# Process ability effects (status buffs, etc.)
	if effect_processor and ability.has_effects():
		for effect in ability.get_effects():
			if effect:
				effect_processor.process_effect(effect, fighter, 0)

	# Character-specific ultimate behavior
	match ability.ability_id:
		"alpha_command":
			# Hunter: Grant 3 free pet activations
			fighter.alpha_command_free_activations = 3
			fighter.alpha_command_activated.emit()
		"predators_trance":
			# Assassin: The status effect handles sword-only spawns
			# Any additional trance-specific behavior goes here
			pass
		"invincibility":
			# Mirror Warden: Apply invincibility status effect for 8 seconds
			# The effect is already applied via ability.effects, but we can add visual feedback
			pass

	# Visual feedback
	_show_ultimate_activation(fighter, ability)
	ultimate_activated.emit(fighter, ability)

	return true


## Shows visual feedback when ultimate is activated
func _show_ultimate_activation(_fighter: Fighter, _ability: AbilityData) -> void:
	# Emit signal for UI to display
	# Could add screen flash, sound, etc.
	pass


# --- Status Effect API ---

func apply_status_effect(target: Fighter, effect_data: StatusEffectData, source: Fighter = null, stacks: int = 1) -> void:
	if status_effect_manager:
		status_effect_manager.apply(target, effect_data, source, stacks)


func remove_status_effect(target: Fighter, effect_type: StatusTypes.StatusType) -> void:
	if status_effect_manager:
		status_effect_manager.remove(target, effect_type)


func cleanse_status(target: Fighter, types: Array[StatusTypes.StatusType] = []) -> void:
	if status_effect_manager:
		status_effect_manager.cleanse(target, types)


func has_status_effect(target: Fighter, effect_type: StatusTypes.StatusType) -> bool:
	if status_effect_manager:
		return status_effect_manager.has_effect(target, effect_type)
	return false


func get_status_modifier(target: Fighter, effect_type: StatusTypes.StatusType) -> float:
	if status_effect_manager:
		return status_effect_manager.get_modifier(target, effect_type)
	return 0.0


# --- Status Effect Signal Handlers ---

func _on_status_effect_applied(target: Fighter, effect: StatusEffect) -> void:
	status_effect_applied.emit(target, effect)
	if is_instance_valid(target):
		target.status_effect_applied.emit(effect)


func _on_status_effect_removed(target: Fighter, effect_type: StatusTypes.StatusType) -> void:
	status_effect_removed.emit(target, effect_type)
	if is_instance_valid(target):
		target.status_effect_removed.emit(effect_type)


func _on_status_effect_ticked(target: Fighter, effect: StatusEffect, damage: float) -> void:
	status_damage_dealt.emit(target, damage, effect.data.effect_type)


# --- Tile Effect Processing ---

## Process a tile activation from clicking
func process_tile_activation(tile: Tile, source: Fighter) -> void:
	if not tile or not source:
		return

	var tile_data := tile.tile_data as PuzzleTileData
	if not tile_data:
		return

	# Drain mana for tiles with MANA_FULL condition
	if tile_data.click_condition == TileTypes.ClickCondition.MANA_FULL and mana_system:
		if tile_data.mana_bar_index >= 0:
			# Drain specific mana bar (Smoke Bomb/Shadow Step)
			mana_system.drain(source, mana_system.get_mana(source, tile_data.mana_bar_index), tile_data.mana_bar_index)
		else:
			# Drain all mana bars (ultimate)
			mana_system.drain_all(source)

	var effect := tile_data.click_effect
	if effect and effect_processor:
		effect_processor.process_effect(effect, source, 0)


## Process a match effect from a tile type
func process_match_effect(tile_data: PuzzleTileData, source: Fighter, match_count: int) -> void:
	if not tile_data or not source:
		return

	# Process main match effect if present
	if tile_data.match_effect and effect_processor:
		effect_processor.process_effect(tile_data.match_effect, source, match_count)

	# Process passive effect if present
	if tile_data.passive_effect and effect_processor:
		effect_processor.process_effect(tile_data.passive_effect, source, match_count)


## Applies a sequence effect from Pet activation with stacks and multiplier
## is_self_buff: if true, this is a self-buff effect (the effect's target property is used regardless)
func apply_sequence_effect(effect: EffectData, source: Fighter, stacks: int, multiplier: float, _is_self_buff: bool = false) -> void:
	if not effect or not source or not effect_processor:
		return

	# Calculate effective value with stacks and multiplier
	# The effect processor will handle target resolution based on effect's target property
	# Stacks act as the count multiplier, and Alpha Command further multiplies the result
	var effective_count := int(float(maxi(1, stacks)) * multiplier)

	# Process the effect with the calculated count
	# The effect's target property (SELF, ENEMY, etc.) determines the actual target
	effect_processor.process_effect(effect, source, effective_count)
