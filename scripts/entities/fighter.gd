class_name Fighter
extends Node

signal hp_changed(current: int, max_hp: int)
signal armor_changed(current: int)
signal stun_changed(remaining: float)
signal defeated
@warning_ignore("unused_signal")  # Emitted by ManaSystem
signal mana_changed(bar_index: int, current: int, max_value: int)
@warning_ignore("unused_signal")  # Emitted by ManaSystem
signal ultimate_ready()
@warning_ignore("unused_signal")  # Emitted by StatusEffectManager
signal status_effect_applied(effect: StatusEffect)
@warning_ignore("unused_signal")  # Emitted by StatusEffectManager
signal status_effect_removed(effect_type: StatusTypes.StatusType)
signal alpha_command_activated()
signal alpha_command_deactivated()

@export var fighter_data: FighterData

var current_hp: int = 0
var max_hp: int = 100
var max_armor: int = 0  ## 0 = use max_hp as cap
var strength: int = 10  ## Scales sword damage (10 = baseline, 15 = +50%)
var agility: int = 0  ## Base dodge chance (15 = 15%)
var armor: int = 0
var stun_remaining: float = 0.0
var is_defeated: bool = false
var mana_system: ManaSystem  # Set by CombatManager
var status_manager: StatusEffectManager  # Set by CombatManager
var _mana_blocked: bool = false  # Direct mana block flag (for simple blocking without status effects)
var _ultimate_cooldown_end_time: float = 0.0  # Time.get_ticks_msec() when ultimate cooldown ends
var alpha_command_free_activations: int = 0  # Free pet activations remaining from Alpha Command
var character_id: String = ""  # Character identifier (set by CombatManager)
var _health_ultimate_triggered: bool = false  # Tracks if health-based ultimate was triggered

const MIN_STUN_DURATION: float = 0.25
const HEALTH_ULTIMATE_THRESHOLD: float = 0.5  # 50% HP threshold for health-based ultimates
const STUN_DIMINISHING_FACTOR: float = 0.5


class DamageResult:
	var total_damage: int = 0
	var armor_absorbed: int = 0
	var hp_damage: int = 0
	var is_defeated: bool = false
	var focus_stacks_consumed: int = 0


func initialize(data: FighterData) -> void:
	fighter_data = data
	max_hp = data.max_hp if data else 100
	max_armor = data.max_armor if data else 0
	strength = data.strength if data else 10
	agility = data.agility if data else 0
	current_hp = max_hp
	armor = 0
	stun_remaining = 0.0
	is_defeated = false

	hp_changed.emit(current_hp, max_hp)
	armor_changed.emit(armor)
	stun_changed.emit(stun_remaining)


func take_damage(amount: int) -> DamageResult:
	var result := DamageResult.new()
	result.total_damage = amount

	# Armor absorbs first
	if armor > 0:
		var absorbed := mini(armor, amount)
		armor -= absorbed
		amount -= absorbed
		result.armor_absorbed = absorbed
		armor_changed.emit(armor)

	# Remaining damages HP
	var old_hp := current_hp
	current_hp = maxi(0, current_hp - amount)
	result.hp_damage = old_hp - current_hp

	if current_hp != old_hp:
		hp_changed.emit(current_hp, max_hp)

	if current_hp == 0 and not is_defeated:
		is_defeated = true
		result.is_defeated = true
		defeated.emit()

	return result


func heal(amount: int) -> int:
	var actual := mini(amount, max_hp - current_hp)
	if actual > 0:
		current_hp += actual
		hp_changed.emit(current_hp, max_hp)
	return actual


func add_armor(amount: int) -> int:
	var armor_cap := max_armor if max_armor > 0 else max_hp
	var actual := mini(amount, armor_cap - armor)
	if actual > 0:
		armor += actual
		armor_changed.emit(armor)
	return actual


func apply_stun(duration: float) -> float:
	if stun_remaining > 0:
		# Diminishing returns
		duration *= STUN_DIMINISHING_FACTOR

	duration = maxf(MIN_STUN_DURATION, duration)
	stun_remaining += duration
	stun_changed.emit(stun_remaining)
	return duration


func tick_stun(delta: float) -> void:
	if stun_remaining > 0:
		stun_remaining = maxf(0.0, stun_remaining - delta)
		stun_changed.emit(stun_remaining)


func is_stunned() -> bool:
	return stun_remaining > 0


func reset() -> void:
	current_hp = max_hp
	armor = 0
	stun_remaining = 0.0
	is_defeated = false
	_mana_blocked = false
	_ultimate_cooldown_end_time = 0.0
	_health_ultimate_triggered = false

	# Reset Alpha Command state
	if alpha_command_free_activations > 0:
		alpha_command_free_activations = 0
		alpha_command_deactivated.emit()

	hp_changed.emit(current_hp, max_hp)
	armor_changed.emit(armor)
	stun_changed.emit(stun_remaining)


func get_hp_percent() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)


func get_armor_percent() -> float:
	var armor_cap := max_armor if max_armor > 0 else max_hp
	if armor_cap <= 0:
		return 0.0
	return float(armor) / float(armor_cap)


# Mana-related methods

func is_mana_blocked() -> bool:
	# Check direct mana block flag
	if _mana_blocked:
		return true
	# Check status effect-based mana block
	if has_status(StatusTypes.StatusType.MANA_BLOCK):
		return true
	# Check if any mana bar is blocked
	if mana_system and mana_system.has_fighter(self):
		for i in range(mana_system.get_bar_count(self)):
			if mana_system.is_bar_blocked(self, i):
				return true
	return false


func set_mana_blocked(blocked: bool) -> void:
	_mana_blocked = blocked


func get_mana(bar_index: int = 0) -> int:
	if mana_system:
		return mana_system.get_mana(self, bar_index)
	return 0


func get_max_mana(bar_index: int = 0) -> int:
	if mana_system:
		return mana_system.get_max_mana(self, bar_index)
	return 0


func get_mana_percentage(bar_index: int = 0) -> float:
	if mana_system:
		return mana_system.get_percentage(self, bar_index)
	return 0.0


func get_mana_bar_count() -> int:
	if mana_system:
		return mana_system.get_bar_count(self)
	return 0


func can_use_ultimate() -> bool:
	if mana_system:
		return mana_system.can_use_ultimate(self)
	return false


func is_mana_full(bar_index: int = 0) -> bool:
	if mana_system:
		return mana_system.is_full(self, bar_index)
	return false


func are_all_mana_bars_full() -> bool:
	if mana_system:
		return mana_system.are_all_bars_full(self)
	return false


# Ultimate cooldown methods

func is_ultimate_on_cooldown() -> bool:
	return Time.get_ticks_msec() < _ultimate_cooldown_end_time


func start_ultimate_cooldown(duration_seconds: float) -> void:
	_ultimate_cooldown_end_time = Time.get_ticks_msec() + (duration_seconds * 1000.0)


func get_ultimate_cooldown_remaining() -> float:
	var remaining_ms := _ultimate_cooldown_end_time - Time.get_ticks_msec()
	return maxf(0.0, remaining_ms / 1000.0)


# Health-based ultimate methods (for Assassin)

func uses_health_ultimate() -> bool:
	## Returns true if this character uses health-based ultimate instead of mana
	## Note: Assassin now uses mana-based ultimate (Predator's Trance spawns when both bars full)
	return false


func check_health_ultimate() -> bool:
	## Checks if health dropped below threshold and triggers ultimate if conditions met.
	## Returns true if ultimate was triggered.
	if not uses_health_ultimate():
		return false

	if _health_ultimate_triggered:
		return false

	if is_ultimate_on_cooldown():
		return false

	if get_hp_percent() < HEALTH_ULTIMATE_THRESHOLD:
		_health_ultimate_triggered = true
		ultimate_ready.emit()
		return true

	return false


func reset_health_ultimate_trigger() -> void:
	## Resets the health ultimate trigger when health goes back above threshold
	if _health_ultimate_triggered and get_hp_percent() >= HEALTH_ULTIMATE_THRESHOLD:
		_health_ultimate_triggered = false


# Alpha Command free activation methods

func has_free_pet_activation() -> bool:
	return alpha_command_free_activations > 0


func use_free_pet_activation() -> bool:
	if alpha_command_free_activations > 0:
		alpha_command_free_activations -= 1
		# Emit deactivation signal when all free activations are used
		if alpha_command_free_activations == 0:
			alpha_command_deactivated.emit()
		return true
	return false


func is_alpha_command_active() -> bool:
	return alpha_command_free_activations > 0


## Returns true if the fighter can activate a pet tile.
## Either has free activations from Alpha Command or enough mana.
func can_activate_pet() -> bool:
	if has_free_pet_activation():
		return true
	if not mana_system:
		return false
	return mana_system.get_mana(self, 0) >= GameConstants.PET_MANA_COST


# Status effect-related methods

func has_status(effect_type: StatusTypes.StatusType) -> bool:
	if status_manager:
		return status_manager.has_effect(self, effect_type)
	return false


func get_status_stacks(effect_type: StatusTypes.StatusType) -> int:
	if status_manager:
		return status_manager.get_stacks(self, effect_type)
	return 0


func get_status_modifier(effect_type: StatusTypes.StatusType) -> float:
	if status_manager:
		return status_manager.get_modifier(self, effect_type)
	return 0.0


func get_all_status_effects() -> Array[StatusEffect]:
	if status_manager:
		return status_manager.get_all_effects(self)
	return []
