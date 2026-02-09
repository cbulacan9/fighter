extends Control

const BASE_SIZE: Vector2 = Vector2(720, 1280)

func _ready() -> void:
	update_scale()
	var vp: Viewport = get_viewport()
	if vp:
		vp.size_changed.connect(Callable(self, "_on_viewport_resized"))

	# Connect hover signals for child panels to show tint feedback
	for child in get_children():
		if child is TextureButton:
			var enter_callable: Callable = Callable(self, "_on_panel_mouse_entered").bind(child)
			var exit_callable: Callable = Callable(self, "_on_panel_mouse_exited").bind(child)
			(child as TextureButton).mouse_entered.connect(enter_callable)
			(child as TextureButton).mouse_exited.connect(exit_callable)

func _on_viewport_resized() -> void:
	update_scale()

func update_scale() -> void:
	var parent_node := get_parent()
	var parent_size: Vector2 = Vector2.ZERO

	if parent_node and parent_node is Control:
		parent_size = (parent_node as Control).size
	else:
		parent_size = get_viewport_rect().size

	if parent_size.x <= 0.0 or parent_size.y <= 0.0:
		return

	var scale: float = min(parent_size.x / BASE_SIZE.x, parent_size.y / BASE_SIZE.y)
	var new_size: Vector2 = BASE_SIZE * scale

	size = new_size
	position = (parent_size - new_size) * 0.5


func _on_panel_mouse_entered(btn: TextureButton) -> void:
	if btn:
		btn.modulate = Color(1.0, 0.4, 0.4, 1.0)


func _on_panel_mouse_exited(btn: TextureButton) -> void:
	if btn:
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
