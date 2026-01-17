class_name ManaSystem
extends RefCounted

signal mana_changed(fighter: Fighter, bar_index: int, current: int, max_value: int)
signal mana_full(fighter: Fighter, bar_index: int)
signal all_bars_full(fighter: Fighter)
signal mana_drained(fighter: Fighter, bar_index: int, amount: int)
signal mana_blocked(fighter: Fighter, bar_index: int, duration: float)

# Mana bars per fighter: {Fighter: Array[ManaBar]}
var _mana_bars: Dictionary = {}
# Config per fighter: {Fighter: ManaConfig}
var _configs: Dictionary = {}


func setup_fighter(fighter: Fighter, config: ManaConfig) -> void:
	if config == null or config.bar_count == 0:
		return

	_configs[fighter] = config
	_mana_bars[fighter] = []

	for i in range(config.bar_count):
		var bar := ManaBar.new(config.get_max_mana(i))
		bar.mana_changed.connect(_on_bar_mana_changed.bind(fighter, i))
		bar.mana_full.connect(_on_bar_full.bind(fighter, i))
		_mana_bars[fighter].append(bar)


func remove_fighter(fighter: Fighter) -> void:
	_mana_bars.erase(fighter)
	_configs.erase(fighter)


func add_mana(fighter: Fighter, amount: int, bar_index: int = 0) -> int:
	if not _mana_bars.has(fighter):
		return 0

	var bars: Array = _mana_bars[fighter]
	if bar_index < 0 or bar_index >= bars.size():
		return 0

	return bars[bar_index].add(amount)


func add_mana_from_match(fighter: Fighter, match_count: int, bar_index: int = 0) -> int:
	if not _configs.has(fighter):
		return 0

	var config: ManaConfig = _configs[fighter]
	var amount := config.get_mana_for_match(match_count)
	return add_mana(fighter, amount, bar_index)


func add_mana_all_bars(fighter: Fighter, amount: int) -> void:
	if not _mana_bars.has(fighter):
		return

	for bar in _mana_bars[fighter]:
		bar.add(amount)


func drain(fighter: Fighter, amount: int, bar_index: int = 0) -> int:
	if not _mana_bars.has(fighter):
		return 0

	var bars: Array = _mana_bars[fighter]
	if bar_index < 0 or bar_index >= bars.size():
		return 0

	var drained := bars[bar_index].drain(amount)
	if drained > 0:
		mana_drained.emit(fighter, bar_index, drained)
	return drained


func drain_all(fighter: Fighter) -> int:
	if not _mana_bars.has(fighter):
		return 0

	var total_drained := 0
	var bars: Array = _mana_bars[fighter]
	for i in range(bars.size()):
		var drained: int = bars[i].drain_all()
		if drained > 0:
			mana_drained.emit(fighter, i, drained)
		total_drained += drained

	return total_drained


func block_mana(fighter: Fighter, duration: float, bar_index: int = -1) -> void:
	if not _mana_bars.has(fighter):
		return

	var bars: Array = _mana_bars[fighter]
	if bar_index >= 0 and bar_index < bars.size():
		# Block specific bar
		bars[bar_index].block(duration)
		mana_blocked.emit(fighter, bar_index, duration)
	else:
		# Block all bars
		for i in range(bars.size()):
			bars[i].block(duration)
			mana_blocked.emit(fighter, i, duration)


func is_full(fighter: Fighter, bar_index: int = 0) -> bool:
	if not _mana_bars.has(fighter):
		return false

	var bars: Array = _mana_bars[fighter]
	if bar_index < 0 or bar_index >= bars.size():
		return false

	return bars[bar_index].is_full()


func are_all_bars_full(fighter: Fighter) -> bool:
	if not _mana_bars.has(fighter):
		return false

	var bars: Array = _mana_bars[fighter]
	if bars.is_empty():
		return false

	for bar in bars:
		if not bar.is_full():
			return false
	return true


func can_use_ultimate(fighter: Fighter) -> bool:
	if not _configs.has(fighter):
		return false

	var config: ManaConfig = _configs[fighter]
	if config.require_all_bars_full:
		return are_all_bars_full(fighter)
	else:
		return is_full(fighter, 0)


func get_mana(fighter: Fighter, bar_index: int = 0) -> int:
	if not _mana_bars.has(fighter):
		return 0

	var bars: Array = _mana_bars[fighter]
	if bar_index < 0 or bar_index >= bars.size():
		return 0

	return bars[bar_index].current


func get_max_mana(fighter: Fighter, bar_index: int = 0) -> int:
	if not _mana_bars.has(fighter):
		return 0

	var bars: Array = _mana_bars[fighter]
	if bar_index < 0 or bar_index >= bars.size():
		return 0

	return bars[bar_index].max_value


func get_percentage(fighter: Fighter, bar_index: int = 0) -> float:
	if not _mana_bars.has(fighter):
		return 0.0

	var bars: Array = _mana_bars[fighter]
	if bar_index < 0 or bar_index >= bars.size():
		return 0.0

	return bars[bar_index].get_percentage()


func get_bar_count(fighter: Fighter) -> int:
	if not _mana_bars.has(fighter):
		return 0
	return _mana_bars[fighter].size()


func tick(delta: float) -> void:
	for fighter in _mana_bars.keys():
		var bars: Array = _mana_bars[fighter]
		var config: ManaConfig = _configs.get(fighter)

		for bar in bars:
			bar.tick(delta)

			# Apply decay if configured
			if config and config.decay_rate > 0:
				var decay := int(config.decay_rate * delta)
				if decay > 0:
					bar.drain(decay)


func reset_fighter(fighter: Fighter) -> void:
	if not _mana_bars.has(fighter):
		return

	for bar in _mana_bars[fighter]:
		bar.reset()


func reset_all() -> void:
	for fighter in _mana_bars.keys():
		reset_fighter(fighter)


func is_bar_blocked(fighter: Fighter, bar_index: int = 0) -> bool:
	if not _mana_bars.has(fighter):
		return false

	var bars: Array = _mana_bars[fighter]
	if bar_index < 0 or bar_index >= bars.size():
		return false

	return bars[bar_index].is_blocked


func has_fighter(fighter: Fighter) -> bool:
	return _mana_bars.has(fighter)


# Signal handlers
func _on_bar_mana_changed(current: int, max_value: int, fighter: Fighter, bar_index: int) -> void:
	mana_changed.emit(fighter, bar_index, current, max_value)


func _on_bar_full(fighter: Fighter, bar_index: int) -> void:
	mana_full.emit(fighter, bar_index)
	if are_all_bars_full(fighter):
		all_bars_full.emit(fighter)
