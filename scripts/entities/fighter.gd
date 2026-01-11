class_name Fighter
extends Node

signal hp_changed(current: int, max_hp: int)
signal armor_changed(current: int)
signal stun_changed(remaining: float)
signal defeated

@export var fighter_data: FighterData

var current_hp: int = 0
var max_hp: int = 100
var armor: int = 0
var stun_remaining: float = 0.0
var is_defeated: bool = false

const MIN_STUN_DURATION: float = 0.25
const STUN_DIMINISHING_FACTOR: float = 0.5


class DamageResult:
	var total_damage: int = 0
	var armor_absorbed: int = 0
	var hp_damage: int = 0
	var is_defeated: bool = false


func initialize(data: FighterData) -> void:
	fighter_data = data
	max_hp = data.max_hp if data else 100
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
	var actual := mini(amount, max_hp - armor)
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

	hp_changed.emit(current_hp, max_hp)
	armor_changed.emit(armor)
	stun_changed.emit(stun_remaining)


func get_hp_percent() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)


func get_armor_percent() -> float:
	if max_hp <= 0:
		return 0.0
	return float(armor) / float(max_hp)
