class_name ManaConfig
extends Resource

## Number of mana bars (1 for most characters, 2 for Assassin)
@export var bar_count: int = 1

## Maximum mana per bar
@export var max_mana: Array[int] = [100]

## Mana gained per match size {match_count: mana_amount}
@export var mana_per_match: Dictionary = {
	3: 10,
	4: 20,
	5: 35
}

## Which tile types generate mana (for characters with Mana tiles)
## Empty array means no tiles generate mana directly
@export var mana_tile_types: Array[int] = []  # TileType enum values

## Mana decay rate per second (0 = no decay)
@export var decay_rate: float = 0.0

## Whether all bars must be full for ultimate
@export var require_all_bars_full: bool = true


func get_max_mana(bar_index: int) -> int:
	if bar_index < max_mana.size():
		return max_mana[bar_index]
	return 100  # Default


func get_mana_for_match(match_count: int) -> int:
	# Cap at 5-match value
	var capped_count := mini(match_count, 5)
	if mana_per_match.has(capped_count):
		return mana_per_match[capped_count]
	return 0


func validate() -> bool:
	# Ensure max_mana array matches bar_count
	if max_mana.size() != bar_count:
		push_warning("ManaConfig: max_mana array size doesn't match bar_count")
		return false
	return true
