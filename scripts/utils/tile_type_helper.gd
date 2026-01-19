class_name TileTypeHelper
extends RefCounted

## Checks if the tile type is a Hunter pet (BEAR_PET, HAWK_PET, SNAKE_PET).
static func is_hunter_pet_type(tile_type: TileTypes.Type) -> bool:
	return tile_type in [TileTypes.Type.BEAR_PET, TileTypes.Type.HAWK_PET, TileTypes.Type.SNAKE_PET]


## Returns true if this tile type should not be replaced by pet spawning or other effects.
## Includes pet tiles and Alpha Command tile.
static func is_special_tile(tile_type: TileTypes.Type) -> bool:
	return is_hunter_pet_type(tile_type) or tile_type == TileTypes.Type.ALPHA_COMMAND
