class_name PuzzleTileData
extends Resource

@export var tile_type: TileTypes.Type
@export var display_name: String
@export var sprite: Texture2D
@export var color: Color = Color.WHITE
@export var match_3_value: int = 0
@export var match_4_value: int = 0
@export var match_5_value: int = 0

# Match behavior
@export var is_matchable: bool = true
@export var match_effect: EffectData

# Click behavior
@export var is_clickable: bool = false
@export var click_condition: TileTypes.ClickCondition = TileTypes.ClickCondition.NONE
@export var click_effect: EffectData
@export var click_cooldown: float = 0.0  # For COOLDOWN condition

# Passive effect (triggered on match, separate from main effect)
@export var passive_effect: EffectData

# Visual
@export var clickable_highlight_color: Color = Color(1, 1, 0.5, 0.5)

# Spawn rules
@export var min_on_board: int = 0  # Minimum tiles of this type (Pet = 1)
@export var max_on_board: int = -1  # Maximum tiles (-1 = no limit, Pet = 2)


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


func can_be_matched() -> bool:
	return is_matchable


func can_be_clicked() -> bool:
	return is_clickable and click_condition != TileTypes.ClickCondition.NONE
