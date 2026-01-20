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
	ALPHA_COMMAND,  # Hunter ultimate - spawns when mana full, click to activate
	SMOKE_BOMB = 12,  # Assassin - hides enemy tiles
	SHADOW_STEP = 13,  # Assassin - grants dodge chance
	PREDATORS_TRANCE = 14,  # Assassin ultimate - spawns when both mana bars full, click to activate
	MAGIC_ATTACK = 15,  # Warden - deals magic damage
	REFLECTION = 16,  # Warden - queues reflection defense
	CANCEL = 17,  # Warden - queues cancel defense
	ABSORB = 18,  # Warden - queues absorb defense
	INVINCIBILITY_TILE = 19,  # Warden ultimate - spawns when mana full, click to activate
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
