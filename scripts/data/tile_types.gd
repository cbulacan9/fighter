class_name TileTypes
extends RefCounted

enum Type {
	NONE = -1,
	SWORD,
	SHIELD,
	POTION,
	LIGHTNING,
	FILLER,
	PET,
	MANA,  # Generates mana on match
}

enum ClickCondition {
	NONE,              # Not clickable
	ALWAYS,            # Can always click
	SEQUENCE_COMPLETE, # Requires completed sequence (Hunter's Pet)
	MANA_FULL,         # Requires full mana bar(s)
	COOLDOWN,          # Time-based cooldown
	CUSTOM,            # Custom condition check
}
