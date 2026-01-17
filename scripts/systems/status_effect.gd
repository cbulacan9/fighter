class_name StatusEffect
extends RefCounted

var data: StatusEffectData
var remaining_duration: float
var stacks: int = 1
var source: Fighter  # Who applied it
var tick_timer: float = 0.0


func _init(effect_data: StatusEffectData, source_fighter: Fighter = null) -> void:
	data = effect_data
	remaining_duration = effect_data.duration
	source = source_fighter
	tick_timer = 0.0


func get_value() -> float:
	return data.base_value + (data.value_per_stack * (stacks - 1))


func is_expired() -> bool:
	return data.duration > 0 and remaining_duration <= 0


func add_stacks(amount: int) -> void:
	stacks = mini(stacks + amount, data.max_stacks)


func refresh_duration() -> void:
	remaining_duration = data.duration


func tick(delta: float) -> bool:
	# Returns true if a tick should be processed (for ON_TIME effects)
	if data.tick_behavior != StatusTypes.TickBehavior.ON_TIME:
		return false

	tick_timer += delta
	if tick_timer >= data.tick_interval:
		tick_timer -= data.tick_interval
		return true
	return false


func update_duration(delta: float) -> void:
	if data.duration > 0:
		remaining_duration = maxf(0.0, remaining_duration - delta)


func get_remaining_ticks() -> int:
	if data.tick_interval <= 0:
		return 0
	return ceili(remaining_duration / data.tick_interval)
