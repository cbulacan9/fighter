class_name PuzzleTileData
extends Resource

@export var tile_type: TileTypes.Type
@export var display_name: String
@export var sprite: Texture2D
@export var color: Color = Color.WHITE
@export var match_3_value: int = 0
@export var match_4_value: int = 0
@export var match_5_value: int = 0


func get_value(match_count: int) -> int:
	match clampi(match_count, 3, 5):
		3:
			return match_3_value
		4:
			return match_4_value
		5:
			return match_5_value
		_:
			return 0
