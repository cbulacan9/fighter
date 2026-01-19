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
	BEAR_PET,   # Hunter combo pet - click to deal damage
	HAWK_PET,   # Hunter combo pet - click for defense
	SNAKE_PET,  # Hunter combo pet - click for healing
	FOCUS,      # Hunter - builds stacks consumed on next attack
}

enum ClickCondition {
	NONE,              # Not clickable
	ALWAYS,            # Can always click
	SEQUENCE_COMPLETE, # Requires completed sequence (Hunter's Pet)
	MANA_FULL,         # Requires full mana bar(s)
	COOLDOWN,          # Time-based cooldown
	CUSTOM,            # Custom condition check
}

enum MatchOrigin {
	PLAYER_INITIATED,  # Direct result of player's move
	CASCADE            # Result of gravity fill
}
