class_name EffectProcessor
extends RefCounted

## Processes tile effects triggered by click activation or matches.
## Handles damage, healing, shields, status effects, mana operations, and custom effects.

signal effect_processed(effect: EffectData, source: Fighter, target: Fighter, value: int)
signal effect_failed(effect: EffectData, reason: String)

var _combat_manager: CombatManager
var _status_manager: StatusEffectManager
var _mana_system: ManaSystem

# Custom effect IDs
const SMOKE_BOMB_PASSIVE := "smoke_bomb_passive"
const SMOKE_BOMB_ACTIVE := "smoke_bomb_active"
const SHADOW_STEP_PASSIVE := "shadow_step_passive"
const SHADOW_STEP_ACTIVE := "shadow_step_active"
const HAWK_TILE_REPLACE := "hawk_tile_replace"
const SNAKE_CLEANSE_HEAL := "snake_cleanse_heal"


func setup(combat_manager: CombatManager) -> void:
	_combat_manager = combat_manager
	if _combat_manager:
		_status_manager = _combat_manager.status_effect_manager
		_mana_system = _combat_manager.mana_system


## Main method to process an effect from a tile activation or match.
## match_count: The number of tiles in the match (0 for click activations using base_value)
func process_effect(effect: EffectData, source: Fighter, match_count: int = 0) -> void:
	if not effect:
		effect_failed.emit(effect, "null_effect")
		return

	if not source:
		effect_failed.emit(effect, "null_source")
		return

	var value := _calculate_value(effect, match_count)

	# Calculate multiplier for effects that scale (1 if no match_count, otherwise use it)
	var multiplier := maxi(1, match_count)

	match effect.effect_type:
		EffectData.EffectType.DAMAGE:
			_process_damage(effect, source, value)

		EffectData.EffectType.HEAL:
			_process_heal(effect, source, value)

		EffectData.EffectType.SHIELD:
			_process_shield(effect, source, value)

		EffectData.EffectType.STUN:
			_process_stun(effect, source, multiplier)

		EffectData.EffectType.STATUS_APPLY:
			_process_status_apply(effect, source, multiplier)

		EffectData.EffectType.STATUS_REMOVE:
			_process_status_remove(effect, source)

		EffectData.EffectType.MANA_ADD:
			_process_mana_add(effect, source, value)

		EffectData.EffectType.MANA_DRAIN:
			_process_mana_drain(effect, source, value)

		EffectData.EffectType.TILE_TRANSFORM:
			_process_tile_transform(effect, source)

		EffectData.EffectType.TILE_HIDE:
			_process_tile_hide(effect, source, value)

		EffectData.EffectType.CUSTOM:
			_process_custom_effect(effect, source, multiplier)

		_:
			effect_failed.emit(effect, "unknown_effect_type")


# --- Effect Type Handlers ---

func _process_damage(effect: EffectData, source: Fighter, value: int) -> void:
	var targets := _resolve_targets(effect.target, source)

	for target in targets:
		if target:
			_apply_damage(target, source, value)
			effect_processed.emit(effect, source, target, value)


func _process_heal(effect: EffectData, source: Fighter, value: int) -> void:
	var targets := _resolve_targets(effect.target, source)

	for target in targets:
		if target:
			var actual := _apply_heal(target, value)
			effect_processed.emit(effect, source, target, actual)


func _process_shield(effect: EffectData, source: Fighter, value: int) -> void:
	var targets := _resolve_targets(effect.target, source)

	for target in targets:
		if target:
			var actual := _apply_shield(target, value)
			effect_processed.emit(effect, source, target, actual)


func _process_stun(effect: EffectData, source: Fighter, multiplier: int = 1) -> void:
	var targets := _resolve_targets(effect.target, source)
	var duration := effect.duration * multiplier  # Scale duration by multiplier

	for target in targets:
		if target:
			var actual := _apply_stun(target, duration)
			effect_processed.emit(effect, source, target, int(actual))


func _process_status_apply(effect: EffectData, source: Fighter, stacks: int = 1) -> void:
	var targets := _resolve_targets(effect.target, source)
	var status_data := effect.status_effect as StatusEffectData

	if not status_data:
		effect_failed.emit(effect, "missing_status_effect_data")
		return

	for target in targets:
		if target:
			_apply_status(target, source, status_data, stacks)
			effect_processed.emit(effect, source, target, stacks)


func _process_status_remove(effect: EffectData, source: Fighter) -> void:
	var targets := _resolve_targets(effect.target, source)
	var types := effect.status_types_to_remove

	for target in targets:
		if target:
			_remove_status(target, types)
			effect_processed.emit(effect, source, target, types.size())


func _process_mana_add(effect: EffectData, source: Fighter, value: int) -> void:
	var targets := _resolve_targets(effect.target, source)

	for target in targets:
		if target:
			var actual := _add_mana(target, value)
			effect_processed.emit(effect, source, target, actual)


func _process_mana_drain(effect: EffectData, source: Fighter, value: int) -> void:
	var targets := _resolve_targets(effect.target, source)

	for target in targets:
		if target:
			var actual := _drain_mana(target, value)
			effect_processed.emit(effect, source, target, actual)


func _process_tile_transform(_effect: EffectData, _source: Fighter) -> void:
	# Placeholder for tile transformation effects
	# Will be implemented when tile transformation mechanics are defined
	pass


func _process_tile_hide(effect: EffectData, source: Fighter, value: int) -> void:
	# Placeholder for tile hide effects (smoke bomb)
	# The actual hiding is handled by the custom effect handlers
	# This is for generic tile hide effects if needed
	effect_processed.emit(effect, source, null, value)


func _process_custom_effect(effect: EffectData, source: Fighter, multiplier: int = 1) -> void:
	match effect.custom_effect_id:
		SMOKE_BOMB_PASSIVE:
			_smoke_bomb_passive(source)
			effect_processed.emit(effect, source, null, 1)

		SMOKE_BOMB_ACTIVE:
			_smoke_bomb_active(source)
			effect_processed.emit(effect, source, null, 1)

		SHADOW_STEP_PASSIVE:
			_shadow_step_passive(source, effect)
			effect_processed.emit(effect, source, source, 1)

		SHADOW_STEP_ACTIVE:
			var target := _get_enemy_of(source)
			_shadow_step_active(target, effect)
			effect_processed.emit(effect, source, target, 1)

		HAWK_TILE_REPLACE:
			var scaled_value := effect.base_value * multiplier  # Scale by multiplier
			var count := _hawk_tile_replace(source, scaled_value)
			effect_processed.emit(effect, source, null, count)

		SNAKE_CLEANSE_HEAL:
			_snake_cleanse_heal(source, effect, multiplier)  # Pass multiplier for heal scaling
			effect_processed.emit(effect, source, source, effect.base_value * multiplier)

		_:
			effect_failed.emit(effect, "unknown_custom_effect: " + effect.custom_effect_id)


# --- Core Effect Application Methods ---

func _apply_damage(target: Fighter, source: Fighter, value: int) -> void:
	if not _combat_manager:
		return

	# Use combat manager's damage application which handles modifiers
	var final_damage := value

	if _status_manager:
		# Apply attacker's damage modifiers (ATTACK_UP)
		if source != null and _status_manager.has_effect(source, StatusTypes.StatusType.ATTACK_UP):
			var attack_bonus := _status_manager.get_modifier(source, StatusTypes.StatusType.ATTACK_UP)
			if attack_bonus > 0:
				final_damage = int(float(final_damage) * (1.0 + attack_bonus))

		# Check target's EVASION (auto-miss, consumes one stack)
		if _status_manager.has_effect(target, StatusTypes.StatusType.EVASION):
			_status_manager.consume_evasion_stack(target)
			_combat_manager.damage_dodged.emit(target, source)
			return

		# Check target's DODGE (chance to avoid)
		if _status_manager.has_effect(target, StatusTypes.StatusType.DODGE):
			var dodge_chance := _status_manager.get_modifier(target, StatusTypes.StatusType.DODGE)
			if randf() < dodge_chance:
				_combat_manager.damage_dodged.emit(target, source)
				return

	var result := target.take_damage(final_damage)
	_combat_manager.damage_dealt.emit(target, result)


func _apply_heal(target: Fighter, value: int) -> int:
	var actual := target.heal(value)
	if _combat_manager and actual > 0:
		_combat_manager.healing_done.emit(target, actual)
	return actual


func _apply_shield(target: Fighter, value: int) -> int:
	var actual := target.add_armor(value)
	if _combat_manager and actual > 0:
		_combat_manager.armor_gained.emit(target, actual)
	return actual


func _apply_stun(target: Fighter, duration: float) -> float:
	var actual := target.apply_stun(duration)
	if _combat_manager:
		_combat_manager.stun_applied.emit(target, actual)
	return actual


func _apply_status(target: Fighter, source: Fighter, status_data: StatusEffectData, stacks: int = 1) -> void:
	if _status_manager and status_data:
		_status_manager.apply(target, status_data, source, stacks)


func _remove_status(target: Fighter, types: Array[String]) -> void:
	if not _status_manager:
		return

	if types.is_empty():
		# Remove all status effects
		_status_manager.remove_all(target)
	else:
		# Remove specific types by name
		for type_name in types:
			# Convert string to StatusType enum
			var effect_type := _string_to_status_type(type_name)
			if effect_type >= 0:
				_status_manager.remove(target, effect_type as StatusTypes.StatusType)


func _add_mana(target: Fighter, value: int) -> int:
	if not _mana_system:
		return 0

	# Check if target is mana blocked
	if target.is_mana_blocked():
		return 0

	return _mana_system.add_mana(target, value)


func _drain_mana(target: Fighter, value: int) -> int:
	if not _mana_system:
		return 0

	return _mana_system.drain(target, value)


# --- Custom Effect Handlers ---

## Smoke Bomb Passive: Hide 1 random enemy tile for 3 seconds
func _smoke_bomb_passive(source: Fighter) -> void:
	var enemy_board := _get_enemy_board(source)
	if enemy_board:
		enemy_board.hide_random_tiles(1, 3.0)


## Smoke Bomb Active: Hide a random row AND column on enemy board for 3 seconds
func _smoke_bomb_active(source: Fighter) -> void:
	var enemy_board := _get_enemy_board(source)
	if enemy_board:
		enemy_board.hide_random_row_and_column(3.0)


## Shadow Step Passive: Grant dodge chance to source
func _shadow_step_passive(source: Fighter, effect: EffectData) -> void:
	if not _status_manager:
		return

	# Apply DODGE status effect if the effect has status_effect data
	var status_data := effect.status_effect as StatusEffectData
	if status_data:
		_status_manager.apply(source, status_data, source, 1)
	else:
		# Create a temporary dodge effect if no status data provided
		# Use base_value as dodge percentage (e.g., 20 = 20% dodge)
		pass  # Status data should be configured in the effect resource


## Shadow Step Active: Block enemy mana generation for 5 seconds
func _shadow_step_active(target: Fighter, _effect: EffectData) -> void:
	if not _mana_system or not target:
		return

	# Block all mana bars for 5 seconds
	_mana_system.block_mana(target, 5.0)


## Hawk Tile Replace: Replace random matchable tiles on enemy board with filler tiles
## Returns the number of tiles actually replaced
func _hawk_tile_replace(source: Fighter, value: int) -> int:
	var enemy_board := _get_enemy_board(source)
	if not enemy_board:
		return 0

	var positions := enemy_board.get_random_matchable_positions(value)
	var replaced_count := 0

	for pos in positions:
		if enemy_board.replace_tile_at(pos, TileTypes.Type.FILLER):
			replaced_count += 1

	# After replacing tiles, check for any new matches on the enemy board
	# This handles cases where tile removal creates new match opportunities
	if replaced_count > 0:
		enemy_board.check_and_resolve_matches()

	return replaced_count


func _snake_cleanse_heal(source: Fighter, effect: EffectData, multiplier: int = 1) -> void:
	# Cleanse poison from self
	if _status_manager:
		_status_manager.remove(source, StatusTypes.StatusType.POISON)

	# Apply heal scaled by multiplier
	if effect.base_value > 0:
		var heal_amount := effect.base_value * multiplier
		_apply_heal(source, heal_amount)


# --- Helper Methods ---

## Resolves the target(s) based on the target type
func _resolve_targets(target_type: EffectData.TargetType, source: Fighter) -> Array[Fighter]:
	var targets: Array[Fighter] = []

	match target_type:
		EffectData.TargetType.SELF:
			targets.append(source)

		EffectData.TargetType.ENEMY:
			var enemy := _get_enemy_of(source)
			if enemy:
				targets.append(enemy)

		EffectData.TargetType.BOTH:
			targets.append(source)
			var enemy := _get_enemy_of(source)
			if enemy:
				targets.append(enemy)

		EffectData.TargetType.BOARD_SELF, EffectData.TargetType.BOARD_ENEMY, EffectData.TargetType.BOARD_BOTH:
			# Board targets don't return fighters, they're handled separately
			pass

		_:
			pass

	return targets


## Returns the opponent of the given fighter
func _get_enemy_of(fighter: Fighter) -> Fighter:
	if not _combat_manager:
		return null
	return _combat_manager.get_opponent(fighter)


## Calculates the effect value based on match count
func _calculate_value(effect: EffectData, match_count: int) -> int:
	if match_count > 0:
		return effect.get_value_for_match(match_count)
	return effect.base_value


## Gets the enemy's board manager (for tile hiding effects)
func _get_enemy_board(source: Fighter) -> BoardManager:
	if not _combat_manager:
		return null

	var enemy := _get_enemy_of(source)
	if not enemy:
		return null

	# Look for board manager in the scene tree
	# The board managers should be set up with owner references
	var tree := _combat_manager.get_tree()
	if not tree:
		return null

	var boards := tree.get_nodes_in_group("board_managers")
	for board in boards:
		var board_manager := board as BoardManager
		if board_manager and board_manager._get_owner_fighter() == enemy:
			return board_manager

	return null


## Converts a status type string to the enum value
func _string_to_status_type(type_name: String) -> int:
	match type_name.to_upper():
		"POISON":
			return StatusTypes.StatusType.POISON
		"BLEED":
			return StatusTypes.StatusType.BLEED
		"DODGE":
			return StatusTypes.StatusType.DODGE
		"ATTACK_UP":
			return StatusTypes.StatusType.ATTACK_UP
		"EVASION":
			return StatusTypes.StatusType.EVASION
		"MANA_BLOCK":
			return StatusTypes.StatusType.MANA_BLOCK
		_:
			return -1
