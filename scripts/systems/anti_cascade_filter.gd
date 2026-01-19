class_name AntiCascadeFilter
extends RefCounted

## Checks if placing a tile of tile_type at (row, col) would create a 3+ match.
## Does NOT modify the grid - purely read-only analysis.
func would_create_match(grid: Grid, row: int, col: int, tile_type: TileTypes.Type) -> bool:
	# Check horizontal: count matching tiles left + right
	var h_count := 1  # Start with 1 for the tile we're placing

	# Count left
	var c := col - 1
	while c >= 0:
		var tile := grid.get_tile(row, c)
		if not _is_matching_tile(tile, tile_type):
			break
		h_count += 1
		c -= 1

	# Count right
	c = col + 1
	while c < Grid.COLS:
		var tile := grid.get_tile(row, c)
		if not _is_matching_tile(tile, tile_type):
			break
		h_count += 1
		c += 1

	if h_count >= 3:
		return true

	# Check vertical: count matching tiles up + down
	var v_count := 1  # Start with 1 for the tile we're placing

	# Count up (lower row numbers)
	var r := row - 1
	while r >= 0:
		var tile := grid.get_tile(r, col)
		if not _is_matching_tile(tile, tile_type):
			break
		v_count += 1
		r -= 1

	# Count down (higher row numbers)
	r = row + 1
	while r < Grid.ROWS:
		var tile := grid.get_tile(r, col)
		if not _is_matching_tile(tile, tile_type):
			break
		v_count += 1
		r += 1

	if v_count >= 3:
		return true

	return false


## Checks if a tile matches the target type and is matchable
func _is_matching_tile(tile: Tile, target_type: TileTypes.Type) -> bool:
	if not tile:
		return false
	if tile.get_type() != target_type:
		return false
	# Respect is_matchable flag
	if tile.tile_data and not tile.tile_data.is_matchable:
		return false
	return true
