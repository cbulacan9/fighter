class_name EffectData
extends Resource

## Effect types that can be triggered by abilities and sequences
enum EffectType {
	NONE,
	DAMAGE,
	HEAL,
	SHIELD,
	STATUS_APPLY,
	STATUS_REMOVE,
	STUN,
	MANA_ADD,
	MANA_DRAIN,
	TILE_TRANSFORM,
	TILE_HIDE,
	BOARD_MANIPULATION,
	CUSTOM,
}

## Target types for effects
enum TargetType {
	NONE,
	SELF,
	ENEMY,
	BOTH,
	BOARD_SELF,
	BOARD_ENEMY,
	BOARD_BOTH,
}

## Unique identifier for this effect
@export var effect_id: String = ""

## Display name for UI
@export var display_name: String = ""

## The type of effect
@export var effect_type: EffectType = EffectType.NONE

## Who/what this effect targets
@export var target: TargetType = TargetType.NONE

## Base value for the effect (damage amount, heal amount, tile count, etc.)
@export var base_value: int = 0

## Values for different match sizes (match-3, match-4, match-5)
@export var values_by_match_size: Dictionary = {3: 10, 4: 25, 5: 50}

## Duration in seconds (for timed effects like stun)
@export var duration: float = 0.0

## Status effect reference (for STATUS_APPLY/STATUS_REMOVE types)
@export var status_effect: Resource  # StatusEffectData - placeholder reference

## Custom effect identifier (for CUSTOM type effects)
@export var custom_effect_id: String = ""

## Status types to remove (for STATUS_REMOVE type)
@export var status_types_to_remove: Array[String] = []

## Description for UI/debugging
@export_multiline var description: String = ""


func get_effect_description() -> String:
	if description != "":
		return description

	match effect_type:
		EffectType.DAMAGE:
			return "Deals %d damage to %s" % [base_value, _target_string()]
		EffectType.HEAL:
			return "Heals %d to %s" % [base_value, _target_string()]
		EffectType.STUN:
			return "Stuns %s for %.1f seconds" % [_target_string(), duration]
		EffectType.STATUS_APPLY:
			return "Applies status to %s" % [_target_string()]
		EffectType.STATUS_REMOVE:
			return "Removes status from %s" % [_target_string()]
		EffectType.BOARD_MANIPULATION:
			return "Modifies %d tiles on %s board" % [base_value, _target_string()]
		EffectType.CUSTOM:
			return "Custom effect: %s" % [custom_effect_id]
		_:
			return "No effect"


func _target_string() -> String:
	match target:
		TargetType.SELF:
			return "self"
		TargetType.ENEMY:
			return "enemy"
		TargetType.BOTH:
			return "both"
		TargetType.BOARD_SELF:
			return "own board"
		TargetType.BOARD_ENEMY:
			return "enemy board"
		TargetType.BOARD_BOTH:
			return "both boards"
		_:
			return "none"


## Get the effect value for a specific match size
func get_value_for_match(match_count: int) -> int:
	var capped := mini(match_count, 5)
	if values_by_match_size.has(capped):
		return values_by_match_size[capped]
	return base_value
