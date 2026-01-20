class_name DefensiveQueueManager
extends RefCounted

## Manages the Warden's Defensive Queue System - queuing reactive defenses
## that trigger based on timing windows around enemy attacks.

signal defense_queued(fighter: Fighter, defense_type: StatusTypes.StatusType)
signal defense_triggered(fighter: Fighter, defense_type: StatusTypes.StatusType)
signal defense_expired(fighter: Fighter, defense_type: StatusTypes.StatusType)
signal defensive_posture_changed(fighter: Fighter, is_defensive: bool)
signal absorb_damage_stored(fighter: Fighter, amount: int, total: int)
signal absorb_damage_released(fighter: Fighter, amount: int, multiplier: float)

# Timing windows for each defense type (in seconds)
const REFLECTION_WINDOW := 2.0
const CANCEL_WINDOW := 2.0
const ABSORB_WINDOW := 5.0

# Enhancement: 3 consecutive matches = enhanced version
const ENHANCED_STACK_COUNT := 3
const ENHANCED_DURATION_MULTIPLIER := 1.5

# Internal tracking
var _queued_defenses: Dictionary = {}  # {Fighter: {StatusType: {time_remaining: float, stacks: int, enhanced: bool}}}
var _consecutive_matches: Dictionary = {}  # {Fighter: {StatusType: int}}
var _last_match_type: Dictionary = {}  # {Fighter: StatusType}
var _absorbed_damage: Dictionary = {}  # {Fighter: int}
var _cancel_window_active: Dictionary = {}  # {Fighter: {active: bool, time: float, damage: int, statuses: Array}}

# Cached arrays to avoid allocations in tick()
var _tick_fighters_to_cleanup: Array = []
var _tick_expired_types: Array = []


func _init() -> void:
	_queued_defenses = {}
	_consecutive_matches = {}
	_last_match_type = {}
	_absorbed_damage = {}
	_cancel_window_active = {}


## Queue a defense for the given fighter
func queue_defense(fighter: Fighter, defense_type: StatusTypes.StatusType, match_count: int = 3) -> void:
	if not fighter:
		return

	# Initialize fighter's data if needed
	if not _queued_defenses.has(fighter):
		_queued_defenses[fighter] = {}
		_consecutive_matches[fighter] = {}
		_last_match_type[fighter] = -1

	# Track consecutive matches for enhancement
	_update_consecutive_matches(fighter, defense_type)

	var is_enhanced := _is_enhanced(fighter, defense_type)
	var duration := _get_duration_for_type(defense_type)
	if is_enhanced:
		duration *= ENHANCED_DURATION_MULTIPLIER

	# Determine stacks from match count
	var stacks := match_count - 2  # 3-match=1, 4-match=2, 5-match=3

	# Queue or refresh the defense
	var was_defensive := is_in_defensive_posture(fighter)

	_queued_defenses[fighter][defense_type] = {
		"time_remaining": duration,
		"stacks": stacks,
		"enhanced": is_enhanced
	}

	defense_queued.emit(fighter, defense_type)

	# Emit posture change if needed
	if not was_defensive:
		defensive_posture_changed.emit(fighter, true)


## Check if fighter has a specific queued defense
func has_queued_defense(fighter: Fighter, defense_type: StatusTypes.StatusType) -> bool:
	if not _queued_defenses.has(fighter):
		return false
	return _queued_defenses[fighter].has(defense_type)


## Consume a queued defense (when it triggers)
func consume_defense(fighter: Fighter, defense_type: StatusTypes.StatusType) -> bool:
	if not has_queued_defense(fighter, defense_type):
		return false

	var was_defensive := is_in_defensive_posture(fighter)
	_queued_defenses[fighter].erase(defense_type)
	defense_triggered.emit(fighter, defense_type)

	# Check if still defensive
	if was_defensive and not is_in_defensive_posture(fighter):
		defensive_posture_changed.emit(fighter, false)

	return true


## Check if defense is enhanced (3x consecutive matches)
func is_enhanced(fighter: Fighter, defense_type: StatusTypes.StatusType) -> bool:
	if not has_queued_defense(fighter, defense_type):
		return false
	return _queued_defenses[fighter][defense_type].get("enhanced", false)


## Get stacks for a queued defense
func get_defense_stacks(fighter: Fighter, defense_type: StatusTypes.StatusType) -> int:
	if not has_queued_defense(fighter, defense_type):
		return 0
	return _queued_defenses[fighter][defense_type].get("stacks", 1)


## Tick down all active defense windows
func tick(delta: float) -> void:
	# Early exit if no queued defenses - skip all dictionary iterations
	if _queued_defenses.is_empty():
		_tick_cancel_windows(delta)
		return

	# Clear cached arrays instead of allocating new ones
	_tick_fighters_to_cleanup.clear()

	for fighter in _queued_defenses.keys():
		if not is_instance_valid(fighter):
			_tick_fighters_to_cleanup.append(fighter)
			continue

		var was_defensive := is_in_defensive_posture(fighter)
		_tick_expired_types.clear()

		for defense_type in _queued_defenses[fighter].keys():
			_queued_defenses[fighter][defense_type].time_remaining -= delta
			if _queued_defenses[fighter][defense_type].time_remaining <= 0:
				_tick_expired_types.append(defense_type)

		# Remove expired defenses
		for defense_type in _tick_expired_types:
			_queued_defenses[fighter].erase(defense_type)
			defense_expired.emit(fighter, defense_type)

		# Check posture change
		if was_defensive and not is_in_defensive_posture(fighter):
			defensive_posture_changed.emit(fighter, false)

	# Clean up invalid fighters
	for fighter in _tick_fighters_to_cleanup:
		_queued_defenses.erase(fighter)
		_consecutive_matches.erase(fighter)
		_last_match_type.erase(fighter)
		_absorbed_damage.erase(fighter)
		_cancel_window_active.erase(fighter)

	# Tick cancel windows
	_tick_cancel_windows(delta)


## Check if fighter is in a defensive posture (has any queued defense)
func is_in_defensive_posture(fighter: Fighter) -> bool:
	if not _queued_defenses.has(fighter):
		return false
	return not _queued_defenses[fighter].is_empty()


# --- Reflection ---

## Check and consume reflection before damage is applied
## Returns true if reflection should trigger (damage should be reflected)
func check_and_consume_reflection(target: Fighter) -> bool:
	if has_queued_defense(target, StatusTypes.StatusType.REFLECTION_QUEUED):
		consume_defense(target, StatusTypes.StatusType.REFLECTION_QUEUED)
		return true
	return false


# --- Cancel ---

## Record damage taken for potential cancel
func record_damage_taken(fighter: Fighter, damage: int, applied_statuses: Array) -> void:
	if not fighter:
		return

	if not _cancel_window_active.has(fighter):
		_cancel_window_active[fighter] = {}

	_cancel_window_active[fighter] = {
		"active": true,
		"time": CANCEL_WINDOW,
		"damage": damage,
		"statuses": applied_statuses.duplicate()
	}


## Check if cancel window is active
func has_cancel_window(fighter: Fighter) -> bool:
	if not _cancel_window_active.has(fighter):
		return false
	return _cancel_window_active[fighter].get("active", false)


## Trigger cancel if queued and window is active
## Returns {healed: int, statuses_removed: Array} or empty dict if not triggered
func check_and_trigger_cancel(fighter: Fighter) -> Dictionary:
	if not has_cancel_window(fighter):
		return {}

	if not has_queued_defense(fighter, StatusTypes.StatusType.CANCEL_QUEUED):
		return {}

	var window_data: Dictionary = _cancel_window_active[fighter]
	var healed: int = window_data.get("damage", 0)
	var statuses: Array = window_data.get("statuses", [])

	# Enhanced cancel heals 50% more
	if is_enhanced(fighter, StatusTypes.StatusType.CANCEL_QUEUED):
		healed = int(float(healed) * 1.5)

	consume_defense(fighter, StatusTypes.StatusType.CANCEL_QUEUED)

	# Clear the cancel window
	_cancel_window_active[fighter] = {"active": false}

	return {
		"healed": healed,
		"statuses_removed": statuses
	}


func _tick_cancel_windows(delta: float) -> void:
	for fighter in _cancel_window_active.keys():
		if not is_instance_valid(fighter):
			continue

		if _cancel_window_active[fighter].get("active", false):
			_cancel_window_active[fighter].time -= delta
			if _cancel_window_active[fighter].time <= 0:
				_cancel_window_active[fighter] = {"active": false}


# --- Absorb ---

## Process absorb when damage is incoming
## Returns amount absorbed (reduces incoming damage by this much)
func process_absorb(fighter: Fighter, incoming_damage: int) -> int:
	if not has_queued_defense(fighter, StatusTypes.StatusType.ABSORB_QUEUED):
		return 0

	# Initialize absorbed damage storage
	if not _absorbed_damage.has(fighter):
		_absorbed_damage[fighter] = 0

	# Absorb all damage
	var absorb_amount := incoming_damage

	# Enhanced absorb can absorb multiple hits (don't consume)
	var is_enh := is_enhanced(fighter, StatusTypes.StatusType.ABSORB_QUEUED)
	if not is_enh:
		consume_defense(fighter, StatusTypes.StatusType.ABSORB_QUEUED)

	_absorbed_damage[fighter] += absorb_amount
	absorb_damage_stored.emit(fighter, absorb_amount, _absorbed_damage[fighter])

	return absorb_amount


## Get stored absorbed damage
func get_stored_damage(fighter: Fighter) -> int:
	return int(_absorbed_damage.get(fighter, 0))


## Release stored damage on Magic Attack match
## Returns total damage to deal (stored * multiplier)
func release_stored_damage(fighter: Fighter, match_count: int) -> int:
	var stored: int = int(_absorbed_damage.get(fighter, 0))
	if stored <= 0:
		return 0

	var multiplier := 1.0
	if match_count >= 5:
		multiplier = 2.0
	elif match_count >= 4:
		multiplier = 1.5

	var release_amount := int(float(stored) * multiplier)
	_absorbed_damage[fighter] = 0

	absorb_damage_released.emit(fighter, release_amount, multiplier)
	return release_amount


# --- Internal Helpers ---

func _get_duration_for_type(defense_type: StatusTypes.StatusType) -> float:
	match defense_type:
		StatusTypes.StatusType.REFLECTION_QUEUED:
			return REFLECTION_WINDOW
		StatusTypes.StatusType.CANCEL_QUEUED:
			return CANCEL_WINDOW
		StatusTypes.StatusType.ABSORB_QUEUED:
			return ABSORB_WINDOW
		_:
			return 2.0


func _update_consecutive_matches(fighter: Fighter, defense_type: StatusTypes.StatusType) -> void:
	if not _consecutive_matches.has(fighter):
		_consecutive_matches[fighter] = {}

	var last: int = int(_last_match_type.get(fighter, -1))

	if last == defense_type:
		# Same type, increment
		_consecutive_matches[fighter][defense_type] = int(_consecutive_matches[fighter].get(defense_type, 0)) + 1
	else:
		# Different type, reset all and start fresh
		_consecutive_matches[fighter] = {defense_type: 1}
		_last_match_type[fighter] = defense_type


func _is_enhanced(fighter: Fighter, defense_type: StatusTypes.StatusType) -> bool:
	if not _consecutive_matches.has(fighter):
		return false
	return int(_consecutive_matches[fighter].get(defense_type, 0)) >= ENHANCED_STACK_COUNT


## Clear all data for a fighter (on match end)
func clear_fighter(fighter: Fighter) -> void:
	_queued_defenses.erase(fighter)
	_consecutive_matches.erase(fighter)
	_last_match_type.erase(fighter)
	_absorbed_damage.erase(fighter)
	_cancel_window_active.erase(fighter)
