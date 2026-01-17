class_name PlaceholderTextures
extends RefCounted

## Utility class for generating placeholder textures at runtime.
## Used when character portraits or other textures are missing.

## Cache of generated textures to avoid regenerating the same placeholder
static var _texture_cache: Dictionary = {}


## Generates a placeholder portrait texture with a letter initial
static func generate_portrait(character_id: String, size: int = 128) -> ImageTexture:
	var cache_key := "%s_%d" % [character_id, size]
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key]

	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)

	# Fill with a gradient background based on character_id hash
	var hash_value := character_id.hash()
	var base_hue := (hash_value % 360) / 360.0
	var base_color := Color.from_hsv(base_hue, 0.5, 0.7, 1.0)
	var dark_color := Color.from_hsv(base_hue, 0.6, 0.4, 1.0)

	for y in range(size):
		for x in range(size):
			var gradient_factor := float(y) / float(size)
			var color := base_color.lerp(dark_color, gradient_factor)
			image.set_pixel(x, y, color)

	# Draw a border
	var border_color := Color(0.2, 0.2, 0.2, 1.0)
	for i in range(size):
		image.set_pixel(i, 0, border_color)
		image.set_pixel(i, size - 1, border_color)
		image.set_pixel(0, i, border_color)
		image.set_pixel(size - 1, i, border_color)

	# Draw a simple circle in the center representing the character
	@warning_ignore("integer_division")
	var center := size / 2
	@warning_ignore("integer_division")
	var radius := size / 3
	var circle_color := Color(1.0, 1.0, 1.0, 0.3)

	for y in range(size):
		for x in range(size):
			var dist := sqrt(pow(x - center, 2) + pow(y - center, 2))
			if dist <= radius:
				var existing := image.get_pixel(x, y)
				image.set_pixel(x, y, existing.blend(circle_color))

	var texture := ImageTexture.create_from_image(image)
	_texture_cache[cache_key] = texture
	return texture


## Generates a small placeholder portrait (typically 64x64)
static func generate_portrait_small(character_id: String) -> ImageTexture:
	return generate_portrait(character_id, 64)


## Clears the texture cache (useful for memory management)
static func clear_cache() -> void:
	_texture_cache.clear()


## Gets or generates a portrait for a character
## Returns the existing portrait if available, otherwise generates a placeholder
static func get_or_generate_portrait(char_data: CharacterData, small: bool = false) -> Texture2D:
	if small:
		if char_data.portrait_small:
			return char_data.portrait_small
		elif char_data.portrait:
			return char_data.portrait
		else:
			return generate_portrait_small(char_data.character_id)
	else:
		if char_data.portrait:
			return char_data.portrait
		elif char_data.portrait_small:
			return char_data.portrait_small
		else:
			return generate_portrait(char_data.character_id)
