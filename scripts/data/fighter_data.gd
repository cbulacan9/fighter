class_name FighterData
extends Resource

@export var fighter_name: String
@export var max_hp: int = 100
@export var portrait: Texture2D
@export var tile_weights: Dictionary = {
	TileTypes.Type.SWORD: 1.0,
	TileTypes.Type.SHIELD: 1.0,
	TileTypes.Type.POTION: 1.0,
	TileTypes.Type.LIGHTNING: 1.0,
	TileTypes.Type.FILLER: 1.0
}
