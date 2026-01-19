class_name CascadeHandler
extends Node

signal tiles_cleared(count: int)
signal tiles_fell(moves: Array[TileMove])
signal tiles_spawned(tiles: Array[Tile])
signal cascade_complete(result: CascadeResult)
signal matches_processed(matches: Array[MatchDetector.MatchResult])  # Fires immediately when matches are cleared

var grid: Grid
var tile_spawner: TileSpawner
var match_detector: MatchDetector
var tiles_container: Node2D


class TileMove:
	var tile: Tile
	var from_row: int
	var to_row: int
	var col: int

	func _init(t: Tile, from: int, to: int, c: int) -> void:
		tile = t
		from_row = from
		to_row = to
		col = c


class CascadeResult:
	var all_matches: Array[MatchDetector.MatchResult] = []
	var total_tiles_cleared: int = 0
	var chain_count: int = 0


func setup(g: Grid, spawner: TileSpawner, detector: MatchDetector, container: Node2D) -> void:
	grid = g
	tile_spawner = spawner
	match_detector = detector
	tiles_container = container


func process_matches(initial_matches: Array[MatchDetector.MatchResult]) -> CascadeResult:
	var result := CascadeResult.new()
	await _run_cascade_loop(result, initial_matches, false)
	cascade_complete.emit(result)
	return result


## Runs the main cascade loop, processing matches and their resulting cascades.
## tag_first_as_cascade: If true, even the first round of matches will be tagged as CASCADE.
func _run_cascade_loop(result: CascadeResult, initial_matches: Array[MatchDetector.MatchResult], tag_first_as_cascade: bool) -> void:
	var current_matches := initial_matches
	var is_first_round := true

	while current_matches.size() > 0:
		result.chain_count += 1

		# Tag cascade matches with CASCADE origin
		if not is_first_round or tag_first_as_cascade:
			for match_result in current_matches:
				match_result.origin = TileTypes.MatchOrigin.CASCADE

		result.all_matches.append_array(current_matches)

		# Emit immediately so UI can update before animations
		matches_processed.emit(current_matches)

		# Collect all positions to clear
		var positions := _collect_positions(current_matches)
		result.total_tiles_cleared += positions.size()

		# Remove matched tiles
		await _remove_tiles(positions)

		# Apply gravity
		var moves := _calculate_gravity()
		if moves.size() > 0:
			await _animate_falls(moves)

		# Fill empty spaces
		var new_tiles := _fill_empty_spaces()
		if new_tiles.size() > 0:
			await _animate_spawns(new_tiles)

		# Check for new matches - these are CASCADE matches
		current_matches = match_detector.find_matches(grid)
		is_first_round = false


func remove_tiles(positions: Array[Vector2i]) -> void:
	await _remove_tiles(positions)


## Processes a single tile removal (e.g., from clicking a PET tile)
## Applies gravity, refills the column, and checks for cascading matches
## All matches from this are tagged as CASCADE since they result from gravity
func process_single_removal(_row: int, _col: int) -> CascadeResult:
	var result := CascadeResult.new()

	# The tile has already been removed from the grid by the caller
	# Apply gravity to the column
	var moves := _calculate_gravity()
	if moves.size() > 0:
		await _animate_falls(moves)

	# Fill empty spaces (new tile spawns from top)
	var new_tiles := _fill_empty_spaces()
	if new_tiles.size() > 0:
		await _animate_spawns(new_tiles)

	# Check for new matches caused by the refill and run cascade loop
	# All matches are tagged as CASCADE since they result from gravity/removal
	var new_matches := match_detector.find_matches(grid)
	if new_matches.size() > 0:
		await _run_cascade_loop(result, new_matches, true)

	cascade_complete.emit(result)
	return result


func apply_gravity() -> Array[TileMove]:
	return _calculate_gravity()


func fill_empty_spaces() -> Array[Tile]:
	return _fill_empty_spaces()


func _collect_positions(matches: Array[MatchDetector.MatchResult]) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var seen: Dictionary = {}

	for match_result in matches:
		for pos in match_result.positions:
			if not seen.has(pos):
				seen[pos] = true
				positions.append(pos)

	# Also collect adjacent FILLER tiles (they get cleared by nearby matches)
	var adjacent_fillers := _find_adjacent_fillers(positions, seen)
	positions.append_array(adjacent_fillers)

	return positions


## Finds FILLER tiles adjacent to the given positions
## These tiles are cleared when matches are made next to them
func _find_adjacent_fillers(match_positions: Array[Vector2i], seen: Dictionary) -> Array[Vector2i]:
	var fillers: Array[Vector2i] = []

	for pos in match_positions:
		# Check all 4 directions: up, down, left, right
		var adjacents: Array[Vector2i] = [
			Vector2i(pos.x - 1, pos.y),
			Vector2i(pos.x + 1, pos.y),
			Vector2i(pos.x, pos.y - 1),
			Vector2i(pos.x, pos.y + 1)
		]

		for adjacent in adjacents:
			# Skip if out of bounds
			if adjacent.x < 0 or adjacent.x >= Grid.ROWS or adjacent.y < 0 or adjacent.y >= Grid.COLS:
				continue
			# Skip if already seen
			if seen.has(adjacent):
				continue

			var tile := grid.get_tile(adjacent.x, adjacent.y)
			if tile and tile.tile_data:
				# Check if it's a FILLER tile
				if tile.tile_data.tile_type == TileTypes.Type.FILLER:
					seen[adjacent] = true
					fillers.append(adjacent)

	return fillers


func _remove_tiles(positions: Array[Vector2i]) -> void:
	var tiles_to_clear: Array[Tile] = []

	for pos in positions:
		var tile := grid.get_tile(pos.x, pos.y)
		if tile:
			tiles_to_clear.append(tile)
			grid.clear_tile(pos.x, pos.y)

	tiles_cleared.emit(tiles_to_clear.size())

	# Play clear animations
	for tile in tiles_to_clear:
		tile.play_match_animation()

	# Wait for animation
	if tiles_to_clear.size() > 0:
		await _wait(GameConstants.CLEAR_ANIMATION_TIME)

		# Remove from scene
		for tile in tiles_to_clear:
			tile.queue_free()


func _calculate_gravity() -> Array[TileMove]:
	var moves: Array[TileMove] = []

	for col in range(Grid.COLS):
		moves.append_array(_calculate_column_gravity(col))

	return moves


func _calculate_column_gravity(col: int) -> Array[TileMove]:
	var moves: Array[TileMove] = []

	# Start from bottom, find empty spaces
	var write_row := Grid.ROWS - 1

	for read_row in range(Grid.ROWS - 1, -1, -1):
		var tile := grid.get_tile(read_row, col)
		if tile:
			if read_row != write_row:
				# Move tile down
				moves.append(TileMove.new(tile, read_row, write_row, col))
				grid.clear_tile(read_row, col)
				grid.set_tile(write_row, col, tile)
			write_row -= 1

	return moves


func _animate_falls(moves: Array[TileMove]) -> void:
	if moves.is_empty():
		return

	tiles_fell.emit(moves)

	var max_distance := 0
	var tween := _create_tween()

	for move in moves:
		var distance := move.to_row - move.from_row
		max_distance = maxi(max_distance, distance)

		var target_pos := grid.grid_to_world(move.to_row, move.col)
		var duration := distance * GameConstants.FALL_ANIMATION_TIME_PER_ROW
		tween.parallel().tween_property(move.tile, "position", target_pos, duration) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	await tween.finished


func _fill_empty_spaces() -> Array[Tile]:
	var new_tiles: Array[Tile] = []

	for col in range(Grid.COLS):
		var empty_rows := grid.get_column_empties(col)
		if empty_rows.is_empty():
			continue

		# Sort to get topmost empties first
		empty_rows.sort()

		for i in range(empty_rows.size()):
			var row: int = empty_rows[i]
			var tile := tile_spawner.spawn_tile()

			# Start above the grid
			var start_row := -(empty_rows.size() - i)
			tile.position = grid.grid_to_world(start_row, col)
			tile.grid_position = Vector2i(row, col)

			tiles_container.add_child(tile)
			grid.set_tile(row, col, tile)
			new_tiles.append(tile)

	return new_tiles


func _animate_spawns(tiles: Array[Tile]) -> void:
	if tiles.is_empty():
		return

	tiles_spawned.emit(tiles)

	var tween := _create_tween()

	for tile in tiles:
		var target_pos := grid.grid_to_world(tile.grid_position.x, tile.grid_position.y)
		var start_pos := tile.position
		var distance := int((target_pos.y - start_pos.y) / Grid.CELL_SIZE.y)
		var duration := maxi(distance, 1) * GameConstants.FALL_ANIMATION_TIME_PER_ROW

		tile.play_spawn_animation()
		tween.parallel().tween_property(tile, "position", target_pos, duration) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	await tween.finished


func _create_tween() -> Tween:
	var tween := create_tween()
	tween.set_parallel(false)
	return tween


func _wait(duration: float) -> void:
	await get_tree().create_timer(duration).timeout
