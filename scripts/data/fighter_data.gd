class_name FighterData
extends Resource

@export var fighter_name: String
@export var max_hp: int = 100
@export var max_armor: int = 0  ## Maximum armor cap (0 = use max_hp)
@export var strength: int = 10  ## Scales sword damage (10 = baseline)
@export var agility: int = 0  ## Base dodge chance (15 = 15%)
@export var portrait: Texture2D
@export var tile_weights: Dictionary = {
	TileTypes.Type.SWORD: 1.0,
	TileTypes.Type.SHIELD: 1.0,
	TileTypes.Type.POTION: 1.0,
	TileTypes.Type.LIGHTNING: 1.0,
	TileTypes.Type.FILLER: 1.0
}

## Mana configuration for this fighter (null for fighters without mana)
@export var mana_config: ManaConfig

## Combo sequences for this fighter (empty for fighters without sequences)
@export var sequences: Array[SequencePattern] = []
