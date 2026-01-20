class_name ClickConditionChecker
extends RefCounted

var _sequence_tracker: SequenceTracker
var _mana_system: ManaSystem
var _cooldown_timers: Dictionary = {}  # {Tile: float}


func set_sequence_tracker(tracker: SequenceTracker) -> void:
	_sequence_tracker = tracker


func set_mana_system(mana_system: ManaSystem) -> void:
	_mana_system = mana_system


func can_click(tile: Tile, fighter: Fighter) -> bool:
	if not tile or not tile.tile_data:
		return false

	var data := tile.tile_data as PuzzleTileData
	if not data.is_clickable:
		return false

	match data.click_condition:
		TileTypes.ClickCondition.NONE:
			return false

		TileTypes.ClickCondition.ALWAYS:
			# Hunter pet tiles require mana even with ALWAYS condition
			if TileTypeHelper.is_hunter_pet_type(data.tile_type):
				return fighter.can_activate_pet() if fighter else false
			return true

		TileTypes.ClickCondition.SEQUENCE_COMPLETE:
			if _sequence_tracker:
				return _sequence_tracker.has_completable_sequence()
			return false

		TileTypes.ClickCondition.MANA_FULL:
			if _mana_system and fighter:
				# Check specific bar if mana_bar_index is set, otherwise check all bars
				if data.mana_bar_index >= 0:
					return _mana_system.is_full(fighter, data.mana_bar_index)
				return _mana_system.are_all_bars_full(fighter)
			return false

		TileTypes.ClickCondition.COOLDOWN:
			return not _is_on_cooldown(tile)

		TileTypes.ClickCondition.CUSTOM:
			return _check_custom_condition(tile, fighter)

	return false


func start_cooldown(tile: Tile) -> void:
	if tile and tile.tile_data:
		var data := tile.tile_data as PuzzleTileData
		if data.click_cooldown > 0:
			_cooldown_timers[tile] = data.click_cooldown


func tick(delta: float) -> void:
	var to_remove: Array = []
	for tile in _cooldown_timers.keys():
		_cooldown_timers[tile] -= delta
		if _cooldown_timers[tile] <= 0:
			to_remove.append(tile)

	for tile in to_remove:
		_cooldown_timers.erase(tile)


func _is_on_cooldown(tile: Tile) -> bool:
	return _cooldown_timers.has(tile) and _cooldown_timers[tile] > 0


func _check_custom_condition(tile: Tile, _fighter: Fighter) -> bool:
	# Override in subclass or implement custom logic
	# For now, check if there's a custom_effect_id on the click_effect
	if tile and tile.tile_data:
		var data := tile.tile_data as PuzzleTileData
		if data.click_effect and data.click_effect.custom_effect_id != "":
			# Custom conditions can be added here as needed
			pass
	return true


func get_cooldown_remaining(tile: Tile) -> float:
	if _cooldown_timers.has(tile):
		return maxf(0.0, _cooldown_timers[tile])
	return 0.0


func clear_cooldown(tile: Tile) -> void:
	_cooldown_timers.erase(tile)


func clear_all_cooldowns() -> void:
	_cooldown_timers.clear()
