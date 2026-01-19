class_name AbilityData
extends Resource

## Unique identifier for this ability
@export var ability_id: String = ""

## Display name shown in UI
@export var display_name: String = ""

## Description of what this ability does
@export_multiline var description: String = ""

## Icon for ability display in UI
@export var icon: Texture2D

# Activation requirements
## Whether this ability requires full mana bar(s) to activate
@export var requires_full_mana: bool = true

## Whether activating this ability drains all mana
@export var drains_all_mana: bool = true

## Fixed mana cost to activate (used when drains_all_mana is false)
@export var mana_cost: int = 0

## Cooldown in seconds before ability can be used again (0 = no cooldown)
@export var cooldown: float = 0.0

# Effects
## Array of effects triggered when this ability is activated
@export var effects: Array[EffectData] = []

# Duration (for channeled abilities)
## How long the ability lasts if it's a channeled/duration-based ability
@export var duration: float = 0.0


## Returns all effects associated with this ability
func get_effects() -> Array[EffectData]:
	return effects


## Returns true if this ability has any effects configured
func has_effects() -> bool:
	return effects.size() > 0


## Returns true if this ability has a cooldown
func has_cooldown() -> bool:
	return cooldown > 0.0


## Returns true if this is a channeled/duration-based ability
func is_channeled() -> bool:
	return duration > 0.0


## Validates the ability data configuration
func validate() -> bool:
	var valid := true

	if ability_id.is_empty():
		push_warning("AbilityData: ability_id is empty")
		valid = false

	if display_name.is_empty():
		push_warning("AbilityData: display_name is empty")
		valid = false

	if effects.is_empty():
		push_warning("AbilityData: No effects configured for ability '%s'" % ability_id)
		valid = false

	return valid


## Returns a formatted description including effect details
func get_full_description() -> String:
	if description.is_empty() and effects.size() > 0:
		var effect_descriptions: Array[String] = []
		for effect in effects:
			if effect != null:
				effect_descriptions.append(effect.get_effect_description())
		return "\n".join(effect_descriptions)
	return description
