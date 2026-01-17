class_name MatchDetector
extends Node

const MAX_MATCH_COUNT: int = 5


class MatchResult:
	var tile_type: TileTypes.Type
	var positions: Array[Vector2i]
	var count: int:
		get:
			return mini(positions.size(), MAX_MATCH_COUNT)

	func _init(type: TileTypes.Type, pos: Array[Vector2i]) -> void:
		tile_type = type
		positions = pos


func find_matches(grid: Grid) -> Array[MatchResult]:
	var horizontal := _find_horizontal_matches(grid)
	var vertical := _find_vertical_matches(grid)
	return _merge_matches(horizontal, vertical)


func has_any_match(grid: Grid) -> bool:
	# Quick check - stop at first match found
	for row in range(Grid.ROWS):
		if _has_horizontal_match_in_row(grid, row):
			return true

	for col in range(Grid.COLS):
		if _has_vertical_match_in_col(grid, col):
			return true

	return false


func preview_match(grid: Grid, axis: InputHandler.DragAxis, index: int, cells_offset: int) -> bool:
	if cells_offset == 0:
		return false

	# Temporarily shift grid
	if axis == InputHandler.DragAxis.HORIZONTAL:
		grid.shift_row(index, cells_offset)
	else:
		grid.shift_column(index, cells_offset)

	var has_match := has_any_match(grid)

	# Revert shift
	if axis == InputHandler.DragAxis.HORIZONTAL:
		grid.shift_row(index, -cells_offset)
	else:
		grid.shift_column(index, -cells_offset)

	return has_match


func _find_horizontal_matches(grid: Grid) -> Array[MatchResult]:
	var matches: Array[MatchResult] = []

	for row in range(Grid.ROWS):
		var current_type: TileTypes.Type = TileTypes.Type.NONE
		var current_run: Array[Vector2i] = []

		for col in range(Grid.COLS):
			var tile := grid.get_tile(row, col)
			if not tile:
				_record_match_if_valid(matches, current_type, current_run)
				current_type = TileTypes.Type.NONE
				current_run = []
				continue

			# Skip non-matchable tiles (they break match runs)
			if not _is_tile_matchable(tile):
				_record_match_if_valid(matches, current_type, current_run)
				current_type = TileTypes.Type.NONE
				current_run = []
				continue

			var tile_type := tile.get_type()
			if tile_type == current_type:
				current_run.append(Vector2i(row, col))
			else:
				_record_match_if_valid(matches, current_type, current_run)
				current_type = tile_type
				current_run = [Vector2i(row, col)]

		_record_match_if_valid(matches, current_type, current_run)

	return matches


func _find_vertical_matches(grid: Grid) -> Array[MatchResult]:
	var matches: Array[MatchResult] = []

	for col in range(Grid.COLS):
		var current_type: TileTypes.Type = TileTypes.Type.NONE
		var current_run: Array[Vector2i] = []

		for row in range(Grid.ROWS):
			var tile := grid.get_tile(row, col)
			if not tile:
				_record_match_if_valid(matches, current_type, current_run)
				current_type = TileTypes.Type.NONE
				current_run = []
				continue

			# Skip non-matchable tiles (they break match runs)
			if not _is_tile_matchable(tile):
				_record_match_if_valid(matches, current_type, current_run)
				current_type = TileTypes.Type.NONE
				current_run = []
				continue

			var tile_type := tile.get_type()
			if tile_type == current_type:
				current_run.append(Vector2i(row, col))
			else:
				_record_match_if_valid(matches, current_type, current_run)
				current_type = tile_type
				current_run = [Vector2i(row, col)]

		_record_match_if_valid(matches, current_type, current_run)

	return matches


func _record_match_if_valid(matches: Array[MatchResult], tile_type: TileTypes.Type, run: Array[Vector2i]) -> void:
	if tile_type != TileTypes.Type.NONE and run.size() >= 3:
		var typed_run: Array[Vector2i] = []
		typed_run.assign(run)
		matches.append(MatchResult.new(tile_type, typed_run))


func _merge_matches(horizontal: Array[MatchResult], vertical: Array[MatchResult]) -> Array[MatchResult]:
	var all_matches: Array[MatchResult] = []
	all_matches.append_array(horizontal)
	all_matches.append_array(vertical)

	if all_matches.is_empty():
		return []

	# Group matches by tile type
	var by_type: Dictionary = {}
	for match_result in all_matches:
		if not by_type.has(match_result.tile_type):
			by_type[match_result.tile_type] = []
		by_type[match_result.tile_type].append(match_result)

	# Merge overlapping matches of same type
	var merged: Array[MatchResult] = []
	for tile_type in by_type:
		var type_matches: Array = by_type[tile_type]
		var merged_type := _merge_overlapping_matches(tile_type, type_matches)
		merged.append_array(merged_type)

	return merged


func _merge_overlapping_matches(tile_type: TileTypes.Type, matches: Array) -> Array[MatchResult]:
	if matches.size() <= 1:
		var single_result: Array[MatchResult] = []
		for m in matches:
			single_result.append(m)
		return single_result

	# Use union-find to group connected matches
	var all_positions: Array[Vector2i] = []
	var position_to_match: Dictionary = {}

	for i in range(matches.size()):
		var match_result: MatchResult = matches[i]
		for pos in match_result.positions:
			if not all_positions.has(pos):
				all_positions.append(pos)
			if not position_to_match.has(pos):
				position_to_match[pos] = []
			position_to_match[pos].append(i)

	# Find connected components
	var visited: Dictionary = {}
	var components: Array[Array] = []

	for pos in all_positions:
		if visited.has(pos):
			continue

		var component: Array[Vector2i] = []
		var stack: Array[Vector2i] = [pos]

		while not stack.is_empty():
			var current: Vector2i = stack.pop_back()
			if visited.has(current):
				continue

			visited[current] = true
			component.append(current)

			# Find all positions connected through shared matches
			if position_to_match.has(current):
				for match_idx in position_to_match[current]:
					var match_result: MatchResult = matches[match_idx]
					for connected_pos in match_result.positions:
						if not visited.has(connected_pos):
							stack.append(connected_pos)

		components.append(component)

	# Create merged match results
	var result: Array[MatchResult] = []
	for component in components:
		var typed_component: Array[Vector2i] = []
		typed_component.assign(component)
		result.append(MatchResult.new(tile_type, typed_component))

	return result


func _has_horizontal_match_in_row(grid: Grid, row: int) -> bool:
	var current_type: TileTypes.Type = TileTypes.Type.NONE
	var run_length := 0

	for col in range(Grid.COLS):
		var tile := grid.get_tile(row, col)
		if not tile:
			current_type = TileTypes.Type.NONE
			run_length = 0
			continue

		# Skip non-matchable tiles (they break match runs)
		if not _is_tile_matchable(tile):
			current_type = TileTypes.Type.NONE
			run_length = 0
			continue

		var tile_type := tile.get_type()
		if tile_type == current_type:
			run_length += 1
			if run_length >= 3:
				return true
		else:
			current_type = tile_type
			run_length = 1

	return false


func _has_vertical_match_in_col(grid: Grid, col: int) -> bool:
	var current_type: TileTypes.Type = TileTypes.Type.NONE
	var run_length := 0

	for row in range(Grid.ROWS):
		var tile := grid.get_tile(row, col)
		if not tile:
			current_type = TileTypes.Type.NONE
			run_length = 0
			continue

		# Skip non-matchable tiles (they break match runs)
		if not _is_tile_matchable(tile):
			current_type = TileTypes.Type.NONE
			run_length = 0
			continue

		var tile_type := tile.get_type()
		if tile_type == current_type:
			run_length += 1
			if run_length >= 3:
				return true
		else:
			current_type = tile_type
			run_length = 1

	return false


## Checks if a tile is matchable based on its tile_data
func _is_tile_matchable(tile: Tile) -> bool:
	if not tile:
		return false
	if not tile.tile_data:
		return true  # Default to matchable if no data
	return tile.tile_data.is_matchable
