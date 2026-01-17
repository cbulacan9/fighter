class_name StatusEffectManager
extends RefCounted

signal effect_applied(target: Fighter, effect: StatusEffect)
signal effect_removed(target: Fighter, effect_type: StatusTypes.StatusType)
signal effect_ticked(target: Fighter, effect: StatusEffect, damage: float)
signal effect_stacked(target: Fighter, effect: StatusEffect, new_stacks: int)

# Active effects per fighter: {Fighter: {StatusType: StatusEffect}}
# For INDEPENDENT stack behavior: {Fighter: {StatusType: Array[StatusEffect]}}
var _active_effects: Dictionary = {}

# Track independent effects separately for proper handling
var _independent_effects: Dictionary = {}


func apply(target: Fighter, effect_data: StatusEffectData, source: Fighter = null, stacks: int = 1) -> void:
	if target == null or effect_data == null:
		return

	if stacks <= 0:
		return

	_ensure_target_exists(target)

	var effect_type := effect_data.effect_type

	# Handle INDEPENDENT stack behavior separately
	if effect_data.stack_behavior == StatusTypes.StackBehavior.INDEPENDENT:
		_apply_independent(target, effect_data, source, stacks)
		return

	var effects: Dictionary = _active_effects[target]

	if effects.has(effect_type):
		var existing := effects[effect_type] as StatusEffect
		_apply_stacking(target, existing, effect_data, source, stacks)
	else:
		var new_effect := StatusEffect.new(effect_data, source)
		new_effect.stacks = mini(stacks, effect_data.max_stacks)
		effects[effect_type] = new_effect
		effect_applied.emit(target, new_effect)


func _apply_stacking(target: Fighter, existing: StatusEffect, effect_data: StatusEffectData, source: Fighter, stacks: int) -> void:
	match effect_data.stack_behavior:
		StatusTypes.StackBehavior.ADDITIVE:
			var old_stacks := existing.stacks
			existing.add_stacks(stacks)
			if existing.stacks > old_stacks:
				effect_stacked.emit(target, existing, existing.stacks)

		StatusTypes.StackBehavior.REFRESH:
			existing.refresh_duration()

		StatusTypes.StackBehavior.REPLACE:
			var effects: Dictionary = _active_effects[target]
			var new_effect := StatusEffect.new(effect_data, source)
			new_effect.stacks = mini(stacks, effect_data.max_stacks)
			effects[effect_data.effect_type] = new_effect
			effect_applied.emit(target, new_effect)


func _apply_independent(target: Fighter, effect_data: StatusEffectData, source: Fighter, stacks: int) -> void:
	var effect_type := effect_data.effect_type

	if not _independent_effects.has(target):
		_independent_effects[target] = {}

	if not _independent_effects[target].has(effect_type):
		_independent_effects[target][effect_type] = []

	var effects_array: Array = _independent_effects[target][effect_type]

	# Create individual effect instances for each stack
	for i in range(stacks):
		if effects_array.size() >= effect_data.max_stacks:
			break
		var new_effect := StatusEffect.new(effect_data, source)
		new_effect.stacks = 1
		effects_array.append(new_effect)
		effect_applied.emit(target, new_effect)


func remove(target: Fighter, effect_type: StatusTypes.StatusType) -> void:
	_remove_internal(target, effect_type)

	# Also remove any independent effects of this type
	if _independent_effects.has(target) and _independent_effects[target].has(effect_type):
		_independent_effects[target].erase(effect_type)


func remove_all(target: Fighter) -> void:
	if _active_effects.has(target):
		for effect_type in _active_effects[target].keys():
			effect_removed.emit(target, effect_type)
		_active_effects[target].clear()
		_active_effects.erase(target)

	if _independent_effects.has(target):
		for effect_type in _independent_effects[target].keys():
			effect_removed.emit(target, effect_type)
		_independent_effects[target].clear()
		_independent_effects.erase(target)


func cleanse(target: Fighter, types: Array[StatusTypes.StatusType] = []) -> void:
	if not _active_effects.has(target) and not _independent_effects.has(target):
		return

	if types.is_empty():
		# Cleanse all effects
		if _active_effects.has(target):
			for effect_type in _active_effects[target].keys():
				effect_removed.emit(target, effect_type)
			_active_effects[target].clear()

		if _independent_effects.has(target):
			for effect_type in _independent_effects[target].keys():
				effect_removed.emit(target, effect_type)
			_independent_effects[target].clear()
	else:
		# Cleanse specific types
		for effect_type in types:
			if _active_effects.has(target) and _active_effects[target].has(effect_type):
				_remove_internal(target, effect_type)

			if _independent_effects.has(target) and _independent_effects[target].has(effect_type):
				_independent_effects[target].erase(effect_type)
				effect_removed.emit(target, effect_type)


func tick(delta: float) -> void:
	_tick_standard_effects(delta)
	_tick_independent_effects(delta)


func _tick_standard_effects(delta: float) -> void:
	var targets_to_cleanup: Array[Fighter] = []

	for target: Fighter in _active_effects.keys():
		if not is_instance_valid(target):
			targets_to_cleanup.append(target)
			continue

		var effects: Dictionary = _active_effects[target]
		var to_remove: Array[StatusTypes.StatusType] = []

		for effect_type: StatusTypes.StatusType in effects.keys():
			var effect := effects[effect_type] as StatusEffect

			# Update duration
			effect.update_duration(delta)

			if effect.is_expired():
				to_remove.append(effect_type)
				continue

			# Process ticks for ON_TIME effects
			if effect.tick(delta):
				_process_tick(target, effect)

		# Remove expired effects
		for effect_type in to_remove:
			_remove_internal(target, effect_type)

	# Cleanup invalid targets
	for target in targets_to_cleanup:
		_active_effects.erase(target)


func _tick_independent_effects(delta: float) -> void:
	var targets_to_cleanup: Array[Fighter] = []

	for target: Fighter in _independent_effects.keys():
		if not is_instance_valid(target):
			targets_to_cleanup.append(target)
			continue

		var effects_by_type: Dictionary = _independent_effects[target]
		var types_to_remove: Array[StatusTypes.StatusType] = []

		for effect_type: StatusTypes.StatusType in effects_by_type.keys():
			var effects_array: Array = effects_by_type[effect_type]
			var to_remove_indices: Array[int] = []

			for i in range(effects_array.size()):
				var effect := effects_array[i] as StatusEffect

				effect.update_duration(delta)

				if effect.is_expired():
					to_remove_indices.append(i)
					continue

				if effect.tick(delta):
					_process_tick(target, effect)

			# Remove expired effects (reverse order to maintain indices)
			for i in range(to_remove_indices.size() - 1, -1, -1):
				effects_array.remove_at(to_remove_indices[i])

			if effects_array.is_empty():
				types_to_remove.append(effect_type)
				effect_removed.emit(target, effect_type)

		for effect_type in types_to_remove:
			effects_by_type.erase(effect_type)

	for target in targets_to_cleanup:
		_independent_effects.erase(target)


func get_effect(target: Fighter, effect_type: StatusTypes.StatusType) -> StatusEffect:
	if _active_effects.has(target) and _active_effects[target].has(effect_type):
		return _active_effects[target][effect_type] as StatusEffect

	# For independent effects, return the first one if any exist
	if _independent_effects.has(target) and _independent_effects[target].has(effect_type):
		var effects_array: Array = _independent_effects[target][effect_type]
		if not effects_array.is_empty():
			return effects_array[0] as StatusEffect

	return null


func has_effect(target: Fighter, effect_type: StatusTypes.StatusType) -> bool:
	if _active_effects.has(target) and _active_effects[target].has(effect_type):
		return true

	if _independent_effects.has(target) and _independent_effects[target].has(effect_type):
		var effects_array: Array = _independent_effects[target][effect_type]
		return not effects_array.is_empty()

	return false


func get_stacks(target: Fighter, effect_type: StatusTypes.StatusType) -> int:
	if _active_effects.has(target) and _active_effects[target].has(effect_type):
		var effect := _active_effects[target][effect_type] as StatusEffect
		return effect.stacks

	# For independent effects, count all individual effects
	if _independent_effects.has(target) and _independent_effects[target].has(effect_type):
		var effects_array: Array = _independent_effects[target][effect_type]
		return effects_array.size()

	return 0


func get_modifier(target: Fighter, effect_type: StatusTypes.StatusType) -> float:
	var effect := get_effect(target, effect_type)
	if effect == null:
		return 0.0
	return effect.get_value()


func get_all_effects(target: Fighter) -> Array[StatusEffect]:
	var result: Array[StatusEffect] = []

	if _active_effects.has(target):
		for effect_type in _active_effects[target].keys():
			result.append(_active_effects[target][effect_type] as StatusEffect)

	if _independent_effects.has(target):
		for effect_type in _independent_effects[target].keys():
			var effects_array: Array = _independent_effects[target][effect_type]
			for effect in effects_array:
				result.append(effect as StatusEffect)

	return result


func apply_damage_modifiers(target: Fighter, base_damage: float, attacker: Fighter = null) -> float:
	var modified := base_damage

	# Apply attacker's ATTACK_UP buff if present
	if attacker != null and has_effect(attacker, StatusTypes.StatusType.ATTACK_UP):
		var attack_modifier := get_modifier(attacker, StatusTypes.StatusType.ATTACK_UP)
		modified *= (1.0 + attack_modifier)

	# Check for EVASION on target (auto-miss, consumed on use)
	if has_effect(target, StatusTypes.StatusType.EVASION):
		_consume_evasion_stack(target)
		return 0.0

	# Check for DODGE on target (chance to avoid)
	if has_effect(target, StatusTypes.StatusType.DODGE):
		var dodge_chance := get_modifier(target, StatusTypes.StatusType.DODGE)
		if randf() < dodge_chance:
			return 0.0

	return modified


func _consume_evasion_stack(target: Fighter) -> void:
	consume_evasion_stack(target)


## Consume one stack of evasion from the target.
## Returns true if an evasion stack was consumed, false if no evasion was present.
func consume_evasion_stack(target: Fighter) -> bool:
	if _active_effects.has(target) and _active_effects[target].has(StatusTypes.StatusType.EVASION):
		var effect := _active_effects[target][StatusTypes.StatusType.EVASION] as StatusEffect
		effect.stacks -= 1
		if effect.stacks <= 0:
			_remove_internal(target, StatusTypes.StatusType.EVASION)
		return true

	# Check independent effects
	if _independent_effects.has(target) and _independent_effects[target].has(StatusTypes.StatusType.EVASION):
		var effects_array: Array = _independent_effects[target][StatusTypes.StatusType.EVASION]
		if not effects_array.is_empty():
			effects_array.pop_front()
			if effects_array.is_empty():
				_independent_effects[target].erase(StatusTypes.StatusType.EVASION)
				effect_removed.emit(target, StatusTypes.StatusType.EVASION)
			return true

	return false


func _process_tick(target: Fighter, effect: StatusEffect) -> void:
	if not is_instance_valid(target):
		return

	match effect.data.effect_type:
		StatusTypes.StatusType.POISON:
			var damage := effect.get_value()
			target.take_damage(int(damage))
			effect_ticked.emit(target, effect, damage)

		StatusTypes.StatusType.BLEED:
			# Bleed triggers on match via _on_target_matched, not on time
			pass

		_:
			# Other effect types may have their own tick behavior
			pass


func _remove_internal(target: Fighter, effect_type: StatusTypes.StatusType) -> void:
	if _active_effects.has(target) and _active_effects[target].has(effect_type):
		_active_effects[target].erase(effect_type)
		effect_removed.emit(target, effect_type)


func _on_target_matched(target: Fighter) -> void:
	# Called when target makes a match - triggers ON_MATCH effects
	if not is_instance_valid(target):
		return

	_process_match_effect(target, StatusTypes.StatusType.BLEED)


func _process_match_effect(target: Fighter, effect_type: StatusTypes.StatusType) -> void:
	# Check standard effects
	if _active_effects.has(target) and _active_effects[target].has(effect_type):
		var effect := _active_effects[target][effect_type] as StatusEffect

		if effect.data.tick_behavior == StatusTypes.TickBehavior.ON_MATCH:
			var damage := effect.get_value()
			target.take_damage(int(damage))
			effect_ticked.emit(target, effect, damage)

			effect.stacks -= 1
			if effect.stacks <= 0:
				_remove_internal(target, effect_type)
		return

	# Check independent effects
	if _independent_effects.has(target) and _independent_effects[target].has(effect_type):
		var effects_array: Array = _independent_effects[target][effect_type]
		if not effects_array.is_empty():
			var effect := effects_array[0] as StatusEffect

			if effect.data.tick_behavior == StatusTypes.TickBehavior.ON_MATCH:
				var damage := effect.get_value()
				target.take_damage(int(damage))
				effect_ticked.emit(target, effect, damage)

				effects_array.pop_front()
				if effects_array.is_empty():
					_independent_effects[target].erase(effect_type)
					effect_removed.emit(target, effect_type)


func _ensure_target_exists(target: Fighter) -> void:
	if not _active_effects.has(target):
		_active_effects[target] = {}


func get_effects_by_tick_behavior(target: Fighter, tick_behavior: StatusTypes.TickBehavior) -> Array[StatusEffect]:
	var result: Array[StatusEffect] = []

	if _active_effects.has(target):
		for effect_type in _active_effects[target].keys():
			var effect := _active_effects[target][effect_type] as StatusEffect
			if effect.data.tick_behavior == tick_behavior:
				result.append(effect)

	if _independent_effects.has(target):
		for effect_type in _independent_effects[target].keys():
			var effects_array: Array = _independent_effects[target][effect_type]
			for effect in effects_array:
				var status_effect := effect as StatusEffect
				if status_effect.data.tick_behavior == tick_behavior:
					result.append(status_effect)

	return result


func is_mana_blocked(target: Fighter) -> bool:
	return has_effect(target, StatusTypes.StatusType.MANA_BLOCK)


func get_total_dot_damage(target: Fighter) -> float:
	var total := 0.0

	for effect in get_all_effects(target):
		if effect.data.tick_behavior == StatusTypes.TickBehavior.ON_TIME:
			match effect.data.effect_type:
				StatusTypes.StatusType.POISON, StatusTypes.StatusType.BLEED:
					total += effect.get_value()

	return total


func clear_all() -> void:
	for target: Fighter in _active_effects.keys():
		for effect_type in _active_effects[target].keys():
			effect_removed.emit(target, effect_type)

	for target: Fighter in _independent_effects.keys():
		for effect_type in _independent_effects[target].keys():
			effect_removed.emit(target, effect_type)

	_active_effects.clear()
	_independent_effects.clear()


## Returns the Alpha Command multiplier for pet abilities with linear decay.
## At full duration: returns base_value (2.0)
## At 0 duration: returns 1.0 (no bonus)
## Linear interpolation in between
func get_alpha_command_multiplier(fighter: Fighter) -> float:
	var effect := get_effect(fighter, StatusTypes.StatusType.ALPHA_COMMAND)
	if not effect:
		return 1.0

	var total_duration := effect.data.duration
	var remaining := effect.remaining_duration

	if total_duration <= 0:
		# Permanent effect - no decay
		return effect.data.base_value

	# Linear decay from base_value (2.0) to 1.0
	var progress := remaining / total_duration
	var multiplier := 1.0 + (effect.data.base_value - 1.0) * progress
	return multiplier
