class_name MockFighter
extends Node
## Mock Fighter for testing mana and status effects in isolation.
## Mimics the Fighter class interface but without game dependencies.
## Note: Extends Node instead of Fighter to avoid scene dependencies,
## but provides the same interface for dictionary-based lookups in systems.

signal hp_changed(current: int, max_hp: int)
signal armor_changed(current: int)
signal stun_changed(remaining: float)
signal status_effect_applied(effect: StatusEffect)
signal status_effect_removed(effect_type: StatusTypes.StatusType)

# Properties matching Fighter interface
var max_hp: int = 100
var current_hp: int = 100
var armor: int = 0
var stun_remaining: float = 0.0
var is_defeated: bool = false
var status_manager: StatusEffectManager
var mana_system: ManaSystem
var _mana_blocked: bool = false

# Constants matching Fighter
const MIN_STUN_DURATION: float = 0.25
const STUN_DIMINISHING_FACTOR: float = 0.5

# Test tracking
var damage_taken_log: Array[int] = []
var heal_log: Array[int] = []
var armor_log: Array[int] = []
var stun_log: Array[float] = []
var mock_name: String = "MockFighter"


func _init(name_override: String = "MockFighter") -> void:
	mock_name = name_override
	reset()


func take_damage(amount: int) -> void:
	damage_taken_log.append(amount)
	var old_hp := current_hp
	current_hp = maxi(0, current_hp - amount)
	if current_hp != old_hp:
		hp_changed.emit(current_hp, max_hp)


func heal(amount: int) -> int:
	var actual := mini(amount, max_hp - current_hp)
	if actual > 0:
		heal_log.append(actual)
		current_hp += actual
		hp_changed.emit(current_hp, max_hp)
	return actual


func add_armor(amount: int) -> int:
	var actual := mini(amount, max_hp - armor)
	if actual > 0:
		armor += actual
		armor_log.append(actual)
		armor_changed.emit(armor)
	return actual


func apply_stun(duration: float) -> float:
	if stun_remaining > 0:
		# Diminishing returns
		duration *= STUN_DIMINISHING_FACTOR

	duration = maxf(MIN_STUN_DURATION, duration)
	stun_remaining += duration
	stun_log.append(duration)
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
	damage_taken_log.clear()
	heal_log.clear()
	armor_log.clear()
	stun_log.clear()


func initialize_for_test(hp: int = 100) -> void:
	max_hp = hp
	current_hp = hp
	armor = 0
	stun_remaining = 0.0
	is_defeated = false
	_mana_blocked = false


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


func is_mana_blocked() -> bool:
	if _mana_blocked:
		return true
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


func get_total_damage_taken() -> int:
	var total := 0
	for dmg in damage_taken_log:
		total += dmg
	return total


func get_damage_count() -> int:
	return damage_taken_log.size()


func get_mock_name() -> String:
	return mock_name
