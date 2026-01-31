class_name CharacterData
extends Resource

## Unique identifier for this character
@export var character_id: String = ""

## Display name shown in UI
@export var display_name: String = ""

## Character archetype (e.g., "Brawler", "Tank", "Assassin", "Balanced")
@export var archetype: String = ""

## Character description for character select and loading screens
@export_multiline var description: String = ""

# Visual
## Full-size portrait for character select and combat screens
@export var portrait: Texture2D

## Small portrait for HUD and lists
@export var portrait_small: Texture2D

## Portrait shown during ultimate ability activation
@export var ultimate_portrait: Texture2D

## Large character card image for character selection screen
@export var character_card_texture: Texture2D

# Tiles
## Basic tiles available to all characters or shared between archetypes
@export var basic_tiles: Array[PuzzleTileData] = []

## Specialty tiles unique to this character
@export var specialty_tiles: Array[PuzzleTileData] = []

## Spawn weights for tile types {TileType.Type: float}
## Higher weight = more likely to spawn
@export var spawn_weights: Dictionary = {}

# Systems
## Mana configuration for ultimate abilities (null for characters without mana)
@export var mana_config: ManaConfig

## Combo sequences available to this character
@export var sequences: Array[SequencePattern] = []

# Abilities
## Ultimate ability triggered when mana is full
@export var ultimate_ability: AbilityData

## Description of passive ability (for UI display)
@export_multiline var passive_description: String = ""

# Stats
## Starting HP
@export var base_hp: int = 100

## Starting armor value
@export var base_armor: int = 0

## Maximum armor cap (0 = use base_hp as cap)
@export var max_armor: int = 0

## Strength stat - scales sword damage (10 = baseline, 15 = +50% damage)
@export var base_strength: int = 10

## Agility stat - provides base dodge chance (15 = 15% dodge)
@export var base_agility: int = 0

# Unlock
## Whether this character is available from the start
@export var is_starter: bool = false

## Beat this character's ID to unlock this character (empty = already unlocked or starter)
@export var unlock_opponent_id: String = ""


## Returns all tiles (basic + specialty) combined
func get_all_tiles() -> Array[PuzzleTileData]:
	var all_tiles: Array[PuzzleTileData] = []
	all_tiles.append_array(basic_tiles)
	all_tiles.append_array(specialty_tiles)
	return all_tiles


## Returns the spawn weight for a given tile type, defaulting to 1.0
func get_spawn_weight(tile_type: TileTypes.Type) -> float:
	if spawn_weights.has(tile_type):
		return spawn_weights[tile_type]
	return 1.0


## Returns true if this character has a mana system configured
func has_mana_system() -> bool:
	return mana_config != null and mana_config.bar_count > 0


## Returns true if this character has combo sequences
func has_sequences() -> bool:
	return sequences.size() > 0


## Returns true if this character has an ultimate ability
func has_ultimate() -> bool:
	return ultimate_ability != null


## Validates the character data configuration
func validate() -> bool:
	var valid := true

	if character_id.is_empty():
		push_warning("CharacterData: character_id is empty")
		valid = false

	if display_name.is_empty():
		push_warning("CharacterData: display_name is empty")
		valid = false

	if basic_tiles.is_empty() and specialty_tiles.is_empty():
		push_warning("CharacterData: No tiles configured for character '%s'" % character_id)
		valid = false

	if mana_config != null and not mana_config.validate():
		push_warning("CharacterData: Invalid mana_config for character '%s'" % character_id)
		valid = false

	# Validate all tiles
	for tile in basic_tiles:
		if tile and not tile.validate():
			push_warning("CharacterData '%s': Invalid basic tile '%s'" % [character_id, tile.display_name])
			valid = false

	for tile in specialty_tiles:
		if tile and not tile.validate():
			push_warning("CharacterData '%s': Invalid specialty tile '%s'" % [character_id, tile.display_name])
			valid = false

	return valid
