class_name StatusEffectIcons
extends RefCounted

## Utility class that generates placeholder textures for status effect icons.
## Use this when actual icon assets are not available.

static var _cached_icons: Dictionary = {}


static func get_icon_texture(effect_type: StatusTypes.StatusType) -> ImageTexture:
	"""Get a placeholder icon texture for the given effect type."""
	# Return cached texture if available
	if _cached_icons.has(effect_type):
		return _cached_icons[effect_type]

	# Generate new texture
	var texture := _generate_icon_texture(effect_type)
	_cached_icons[effect_type] = texture
	return texture


static func _generate_icon_texture(effect_type: StatusTypes.StatusType) -> ImageTexture:
	"""Generate a 32x32 placeholder icon texture with a colored background and symbol."""
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var color := _get_effect_color(effect_type)
	var symbol := _get_effect_symbol(effect_type)

	# Fill background with effect color
	image.fill(color)

	# Add a darker border (2 pixels)
	var border_color := color.darkened(0.3)
	for x in range(32):
		for y in range(32):
			if x < 2 or x >= 30 or y < 2 or y >= 30:
				image.set_pixel(x, y, border_color)

	# Add simple symbol pattern in center
	_draw_symbol(image, symbol, Color.WHITE)

	# Create texture from image
	var texture := ImageTexture.create_from_image(image)
	return texture


static func _get_effect_color(effect_type: StatusTypes.StatusType) -> Color:
	"""Return the background color for an effect type."""
	match effect_type:
		StatusTypes.StatusType.POISON:
			return Color(0.2, 0.7, 0.2)  # Green
		StatusTypes.StatusType.BLEED:
			return Color(0.8, 0.2, 0.2)  # Red
		StatusTypes.StatusType.ATTACK_UP:
			return Color(1.0, 0.6, 0.1)  # Orange
		StatusTypes.StatusType.DODGE:
			return Color(0.3, 0.5, 1.0)  # Blue
		StatusTypes.StatusType.EVASION:
			return Color(0.5, 0.5, 0.6)  # Gray
		StatusTypes.StatusType.MANA_BLOCK:
			return Color(0.6, 0.2, 0.8)  # Purple
		_:
			return Color(0.4, 0.4, 0.4)  # Default gray


static func _get_effect_symbol(effect_type: StatusTypes.StatusType) -> String:
	"""Return a simple symbol identifier for drawing patterns."""
	match effect_type:
		StatusTypes.StatusType.POISON:
			return "skull"  # Skull/poison drops
		StatusTypes.StatusType.BLEED:
			return "drops"  # Blood drops
		StatusTypes.StatusType.ATTACK_UP:
			return "arrow_up"  # Upward arrow
		StatusTypes.StatusType.DODGE:
			return "dash"  # Dashing lines
		StatusTypes.StatusType.EVASION:
			return "ghost"  # Ghost outline
		StatusTypes.StatusType.MANA_BLOCK:
			return "cross"  # X mark / block
		_:
			return "dot"


static func _draw_symbol(image: Image, symbol: String, color: Color) -> void:
	"""Draw a simple symbol pattern on the image."""
	match symbol:
		"skull":
			_draw_poison_symbol(image, color)
		"drops":
			_draw_bleed_symbol(image, color)
		"arrow_up":
			_draw_attack_up_symbol(image, color)
		"dash":
			_draw_dodge_symbol(image, color)
		"ghost":
			_draw_evasion_symbol(image, color)
		"cross":
			_draw_mana_block_symbol(image, color)
		_:
			_draw_dot_symbol(image, color)


static func _draw_poison_symbol(image: Image, color: Color) -> void:
	"""Draw a poison drop symbol."""
	# Simple drop shape pointing down
	var cx := 16
	var cy := 14

	# Draw drop shape (triangle top + circle bottom)
	for y in range(8, 24):
		for x in range(8, 24):
			var dx: int = x - cx
			var dy: int = y - cy

			# Top triangle part (y < cy)
			if y < cy:
				var width: int = int((y - 8) * 0.8)
				if abs(dx) <= width:
					image.set_pixel(x, y, color)
			# Bottom circle part
			else:
				var radius := 5.0
				if dx * dx + dy * dy <= radius * radius:
					image.set_pixel(x, y, color)


static func _draw_bleed_symbol(image: Image, color: Color) -> void:
	"""Draw blood drop symbols."""
	# Three small drops
	var drops := [Vector2i(10, 14), Vector2i(16, 10), Vector2i(22, 14)]

	for drop in drops:
		for y in range(-4, 6):
			for x in range(-3, 4):
				var px: int = drop.x + x
				var py: int = drop.y + y

				if px >= 2 and px < 30 and py >= 2 and py < 30:
					# Simple drop shape
					if y < 0:
						@warning_ignore("integer_division")
						if abs(x) <= (4 + y) / 2:
							image.set_pixel(px, py, color)
					else:
						var radius := 2.5
						if x * x + y * y <= radius * radius:
							image.set_pixel(px, py, color)


static func _draw_attack_up_symbol(image: Image, color: Color) -> void:
	"""Draw an upward arrow."""
	var cx := 16

	# Arrow shaft
	for y in range(10, 24):
		for x in range(-2, 3):
			var px: int = cx + x
			if px >= 2 and px < 30:
				image.set_pixel(px, y, color)

	# Arrow head
	for row in range(6):
		var width: int = 6 - row
		for x in range(-width, width + 1):
			var px: int = cx + x
			var py: int = 10 - row
			if px >= 2 and px < 30 and py >= 2:
				image.set_pixel(px, py, color)


static func _draw_dodge_symbol(image: Image, color: Color) -> void:
	"""Draw diagonal motion lines."""
	# Three diagonal lines suggesting movement
	for i in range(3):
		var start_x: int = 8 + i * 6
		var start_y: int = 10 + i * 4

		for j in range(10):
			var px: int = start_x + j
			var py: int = start_y + int(j * 0.5)
			if px >= 2 and px < 30 and py >= 2 and py < 30:
				image.set_pixel(px, py, color)
				if py + 1 < 30:
					image.set_pixel(px, py + 1, color)


static func _draw_evasion_symbol(image: Image, color: Color) -> void:
	"""Draw a ghost/fade outline."""
	var cx := 16
	var cy := 14

	# Draw a faded circle outline
	for angle in range(0, 360, 10):
		var rad: float = deg_to_rad(float(angle))
		var radius: float = 8.0 + sin(rad * 3) * 2  # Wavy radius

		var px: int = int(cx + cos(rad) * radius)
		var py: int = int(cy + sin(rad) * radius)

		if px >= 2 and px < 30 and py >= 2 and py < 30:
			image.set_pixel(px, py, color)
			# Add some thickness
			if px + 1 < 30:
				image.set_pixel(px + 1, py, color)
			if py + 1 < 30:
				image.set_pixel(px, py + 1, color)


static func _draw_mana_block_symbol(image: Image, color: Color) -> void:
	"""Draw an X mark for block."""
	# Draw X shape
	for i in range(16):
		var offset: int = i + 4
		# Top-left to bottom-right
		if offset >= 2 and offset < 30 and i + 8 >= 2 and i + 8 < 30:
			image.set_pixel(offset + 4, i + 8, color)
			image.set_pixel(offset + 5, i + 8, color)

		# Top-right to bottom-left
		var px: int = 27 - offset
		if px >= 2 and px < 30 and i + 8 >= 2 and i + 8 < 30:
			image.set_pixel(px, i + 8, color)
			image.set_pixel(px + 1, i + 8, color)


static func _draw_dot_symbol(image: Image, color: Color) -> void:
	"""Draw a simple dot in the center."""
	var cx := 16
	var cy := 14
	var radius := 4

	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			if x * x + y * y <= radius * radius:
				var px: int = cx + x
				var py: int = cy + y
				if px >= 2 and px < 30 and py >= 2 and py < 30:
					image.set_pixel(px, py, color)


static func clear_cache() -> void:
	"""Clear the cached icon textures."""
	_cached_icons.clear()
