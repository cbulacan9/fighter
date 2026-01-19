class_name StatusTypes
extends RefCounted

enum StatusType {
	POISON,         # DoT, ticks damage over time
	BLEED,          # Damage on enemy's next match
	DODGE,          # Chance to avoid next attack
	ATTACK_UP,      # Damage multiplier buff
	EVASION,        # Next attack auto-misses
	MANA_BLOCK,     # Prevent mana generation
	ALPHA_COMMAND,  # Hunter ultimate - 2x multiplier on animal companion abilities
	FOCUS,          # Hunter - 20% attack bonus per stack, consumed on attack
}

enum StackBehavior {
	ADDITIVE,     # Stacks increase magnitude
	REFRESH,      # New application refreshes duration
	INDEPENDENT,  # Each stack tracks separately
	REPLACE,      # New application replaces old
}

enum TickBehavior {
	ON_TIME,      # Ticks every X seconds
	ON_MATCH,     # Triggers when target matches
	ON_HIT,       # Triggers when target is hit
	ON_ACTION,    # Triggers on any target action
}
