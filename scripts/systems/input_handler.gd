class_name InputHandler
extends Node

signal drag_started(axis: DragAxis, index: int, start_pos: Vector2)
signal drag_moved(offset_pixels: float)
signal drag_ended(final_offset: float)

enum DragAxis {
	NONE,
	HORIZONTAL,
	VERTICAL
}

@export var drag_threshold: float = 10.0
@export var cell_size: float = 64.0

var is_dragging: bool = false
var drag_axis: DragAxis = DragAxis.NONE
var drag_start_world: Vector2
var drag_start_grid: Vector2i
var drag_index: int = -1
var current_offset: float = 0.0

var _enabled: bool = true
var _grid: Grid
var _board_rect: Rect2


func setup(grid: Grid, board_position: Vector2) -> void:
	_grid = grid
	_board_rect = Rect2(
		board_position,
		Vector2(Grid.COLS * cell_size, Grid.ROWS * cell_size)
	)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		reset()


func reset() -> void:
	is_dragging = false
	drag_axis = DragAxis.NONE
	drag_start_world = Vector2.ZERO
	drag_start_grid = Vector2i.ZERO
	drag_index = -1
	current_offset = 0.0


func _input(event: InputEvent) -> void:
	if not _enabled or not _grid:
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		_on_press(event.position)
	else:
		_on_release()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if is_dragging:
		_on_drag(event.position)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_on_press(event.position)
	else:
		_on_release()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if is_dragging:
		_on_drag(event.position)


func _on_press(pos: Vector2) -> void:
	var local_pos := _screen_to_board(pos)
	var check_point := local_pos + _board_rect.position
	var in_bounds := _board_rect.has_point(check_point)

	if not in_bounds:
		return

	var grid_pos := _grid.world_to_grid(local_pos)
	if not _is_valid_grid_pos(grid_pos):
		return

	is_dragging = true
	drag_axis = DragAxis.NONE
	drag_start_world = local_pos
	drag_start_grid = grid_pos
	current_offset = 0.0


func _on_drag(pos: Vector2) -> void:
	if not is_dragging:
		return

	var local_pos := _screen_to_board(pos)
	var delta := local_pos - drag_start_world

	if drag_axis == DragAxis.NONE:
		if delta.length() > drag_threshold:
			if abs(delta.x) > abs(delta.y):
				drag_axis = DragAxis.HORIZONTAL
				drag_index = drag_start_grid.x
			else:
				drag_axis = DragAxis.VERTICAL
				drag_index = drag_start_grid.y
			drag_started.emit(drag_axis, drag_index, drag_start_world)

	if drag_axis != DragAxis.NONE:
		if drag_axis == DragAxis.HORIZONTAL:
			current_offset = delta.x
		else:
			current_offset = delta.y
		drag_moved.emit(current_offset)


func _on_release() -> void:
	if not is_dragging:
		return

	if drag_axis != DragAxis.NONE:
		drag_ended.emit(current_offset)

	reset()


func _screen_to_board(screen_pos: Vector2) -> Vector2:
	# TODO: Account for board's global position when integrated
	return screen_pos - _board_rect.position


func _is_valid_grid_pos(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < Grid.ROWS and pos.y >= 0 and pos.y < Grid.COLS
