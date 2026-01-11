class_name Grid
extends Node2D

const ROWS: int = 6
const COLS: int = 8
const CELL_SIZE: Vector2 = Vector2(64, 64)

var _tiles: Array[Array] = []


func initialize() -> void:
	_tiles.clear()
	for row in range(ROWS):
		var row_array: Array[Tile] = []
		row_array.resize(COLS)
		_tiles.append(row_array)


func get_tile(row: int, col: int) -> Tile:
	var wrapped := wrap_position(row, col)
	return _tiles[wrapped.x][wrapped.y]


func set_tile(row: int, col: int, tile: Tile) -> void:
	var wrapped := wrap_position(row, col)
	_tiles[wrapped.x][wrapped.y] = tile
	if tile:
		tile.grid_position = wrapped


func clear_tile(row: int, col: int) -> Tile:
	var wrapped := wrap_position(row, col)
	var tile: Tile = _tiles[wrapped.x][wrapped.y]
	_tiles[wrapped.x][wrapped.y] = null
	return tile


func is_empty(row: int, col: int) -> bool:
	var wrapped := wrap_position(row, col)
	return _tiles[wrapped.x][wrapped.y] == null


func wrap_row(row: int) -> int:
	return ((row % ROWS) + ROWS) % ROWS


func wrap_col(col: int) -> int:
	return ((col % COLS) + COLS) % COLS


func wrap_position(row: int, col: int) -> Vector2i:
	return Vector2i(wrap_row(row), wrap_col(col))


func grid_to_world(row: int, col: int) -> Vector2:
	return Vector2(col * CELL_SIZE.x + CELL_SIZE.x / 2, row * CELL_SIZE.y + CELL_SIZE.y / 2)


func world_to_grid(world_pos: Vector2) -> Vector2i:
	var col := int(world_pos.x / CELL_SIZE.x)
	var row := int(world_pos.y / CELL_SIZE.y)
	return wrap_position(row, col)


func get_row(row_index: int) -> Array[Tile]:
	var wrapped_row := wrap_row(row_index)
	var result: Array[Tile] = []
	for col in range(COLS):
		result.append(_tiles[wrapped_row][col])
	return result


func get_column(col_index: int) -> Array[Tile]:
	var wrapped_col := wrap_col(col_index)
	var result: Array[Tile] = []
	for row in range(ROWS):
		result.append(_tiles[row][wrapped_col])
	return result


func shift_row(row_index: int, offset: int) -> void:
	var wrapped_row := wrap_row(row_index)
	var old_row := get_row(wrapped_row)
	for col in range(COLS):
		var new_col := wrap_col(col + offset)
		_tiles[wrapped_row][new_col] = old_row[col]
		if old_row[col]:
			old_row[col].grid_position = Vector2i(wrapped_row, new_col)


func shift_column(col_index: int, offset: int) -> void:
	var wrapped_col := wrap_col(col_index)
	var old_col := get_column(wrapped_col)
	for row in range(ROWS):
		var new_row := wrap_row(row + offset)
		_tiles[new_row][wrapped_col] = old_col[row]
		if old_col[row]:
			old_col[row].grid_position = Vector2i(new_row, wrapped_col)


func get_all_tiles() -> Array[Tile]:
	var result: Array[Tile] = []
	for row in range(ROWS):
		for col in range(COLS):
			if _tiles[row][col]:
				result.append(_tiles[row][col])
	return result


func get_empty_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in range(ROWS):
		for col in range(COLS):
			if _tiles[row][col] == null:
				result.append(Vector2i(row, col))
	return result


func get_column_empties(col: int) -> Array[int]:
	var wrapped_col := wrap_col(col)
	var result: Array[int] = []
	for row in range(ROWS):
		if _tiles[row][wrapped_col] == null:
			result.append(row)
	return result
