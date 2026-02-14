# Character Spawn Tiles and Ultimate Abilities Summary

This document provides a comprehensive overview of each character type, their assigned spawn tiles, and ultimate abilities based on the script files.

---

## Character Types Overview

### 1. The Hunter (Combo Specialist)

**Character ID:** `hunter`

#### Assigned Spawn Tiles

**Basic Tiles:**
- **SWORD** (Type 0) - Weight: 24.0
- **SHIELD** (Type 1) - Weight: 24.0
- **FOCUS** (Type 4) - Weight: 16.0
- **MANA** (Type 6) - Weight: 18.0
- **BEAR_PET** (Type 7) - Spawns via sequence completion (Bear combo)
- **HAWK_PET** (Type 8) - Spawns via sequence completion (Hawk combo)
- **SNAKE_PET** (Type 9) - Weight: 18.0 (also spawns via sequence completion)

**Specialty Tiles:**
- None (pets are spawned through sequence system)

**Spawn Weights Distribution:**
```
SWORD (0):      24.0%
SHIELD (1):     24.0%
FOCUS (4):      16.0%
MANA (6):       18.0%
SNAKE_PET (9):  18.0%
```

**Note:** FILLER tiles are not explicitly listed but are part of the system.

#### Ultimate Ability: Alpha Command

**Tile Type:** ALPHA_COMMAND (Type 10)

**Description:** "Your animal companions become empowered. The next 3 pet activations are free and deal double damage with stronger effects."

**Mechanics:**
- Spawns when mana bar is full
- Click to activate
- Grants 3 free pet activations (no mana cost)
- Doubles damage from pet abilities
- Strengthens pet effects
- Cooldown: 60 seconds after use

#### Passive Ability: Animal Companions

Build sequences by matching tiles in order (Physical/Shield/Focus), then click a Pet tile to activate the companion's ability. Each companion has unique offensive and defensive effects. Focus tiles grant stacks that boost your next attack by 20% per stack.

---

### 2. The Assassin (Brawler)

**Character ID:** `assassin`

#### Assigned Spawn Tiles

**Basic Tiles:**
- **SWORD** (Type 0) - Weight: 25.0
- **LIGHTNING** (Type 3) - Weight: 15.0
- **MANA** (Type 4) - Weight: 20.0
- **FILLER** (Type 5) - Weight: 20.0

**Specialty Tiles:**
- **SMOKE_BOMB** (Type 12) - Weight: 10.0
- **SHADOW_STEP** (Type 13) - Weight: 10.0

**Spawn Weights Distribution:**
```
SWORD (0):        25.0%
LIGHTNING (3):    15.0%
MANA (4):         20.0%
FILLER (5):       20.0%
SMOKE_BOMB (12):  10.0%
SHADOW_STEP (13): 10.0%
```

#### Ultimate Ability: Predator's Trance

**Tile Type:** PREDATORS_TRANCE (Type 14)

**Description:** "Enter a deadly trance for 10 seconds. All new tiles become swords. Sword matches during trance trigger auto-chains: 3-match = 1 chain, 4-match = 2 chains, 5-match = 3 chains."

**Mechanics:**
- Spawns when BOTH mana bars are full
- Click to activate
- Duration: 10 seconds
- All new spawned tiles become SWORD type
- Sword matches trigger bonus cascades based on match size
  - 3-match triggers 1 additional cascade
  - 4-match triggers 2 additional cascades
  - 5-match triggers 3 additional cascades
- Drains both mana bars on activation
- Cooldown: 20 seconds after use

#### Passive Ability: Dual Mana System

Smoke Bomb tiles fill the first mana bar (purple), Shadow Step tiles fill the second mana bar (blue). When both bars are full, activate Predator's Trance for devastating auto-chaining sword attacks.

---

### 3. The Mirror Warden (Tank)

**Character ID:** `mirror_warden`

#### Assigned Spawn Tiles

**Basic Tiles:**
- **MAGIC_ATTACK** (Type 15) - Weight: 20.0
- **MANA** (Type 6) - Weight: 20.0
- **FILLER** (Type 5) - Included (weight not specified in spawn_weights but listed in basic_tiles)

**Specialty Tiles:**
- **REFLECTION** (Type 16) - Weight: 24.0
- **CANCEL** (Type 17) - Weight: 11.0
- **ABSORB** (Type 18) - Weight: 14.0

**Spawn Weights Distribution:**
```
MAGIC_ATTACK (15): 20.0%
MANA (6):          20.0%
FILLER (5):        ~11% (implied)
REFLECTION (16):   24.0%
CANCEL (17):       11.0%
ABSORB (18):       14.0%
```

#### Ultimate Ability: Invincibility

**Tile Type:** INVINCIBILITY_TILE (Type 19)

**Description:** "The Mirror Warden becomes completely immune to all damage for 8 seconds. During this time, all incoming attacks are negated."

**Mechanics:**
- Spawns when mana bar is full
- Click to activate
- Duration: 8 seconds
- Complete immunity to all damage
- All incoming attacks are negated
- Drains mana bar on activation
- Cooldown: 60 seconds after use

#### Passive Ability: Defensive Queue System

Match defensive tiles to queue Reflection, Cancel, or Absorb. Time your defenses to reflect damage, heal back injuries, or store damage for a powerful counterattack.

- **REFLECTION:** Queue a 2-second window that reflects enemy attacks
- **CANCEL:** Heal back damage taken and remove applied status effects
- **ABSORB:** Store incoming damage, then release it with your next Magic Attack at up to 2x multiplier

---

## Tile Type Reference (from scripts/data/tile_types.gd)

```gdscript
enum Type {
	NONE = -1,
	SWORD = 0,
	SHIELD = 1,
	POTION = 2,
	LIGHTNING = 3,
	FILLER = 5,
	PET = 6,
	MANA = 6,
	BEAR_PET = 7,      # Hunter combo pet
	HAWK_PET = 8,      # Hunter combo pet
	SNAKE_PET = 9,     # Hunter combo pet
	FOCUS = 10,       # Hunter
	ALPHA_COMMAND = 11,   # Hunter ultimate
	SMOKE_BOMB = 12,      # Assassin
	SHADOW_STEP = 13,     # Assassin
	PREDATORS_TRANCE = 14,  # Assassin ultimate
	MAGIC_ATTACK = 15,     # Warden
	REFLECTION = 16,       # Warden
	CANCEL = 17,          # Warden
	ABSORB = 18,          # Warden
	INVINCIBILITY_TILE = 19,  # Warden ultimate
}
```

---

## Character Stats Summary

| Character | Base HP | Max Armor | Base Strength | Base Agility | Archetype |
|-----------|---------|-----------|---------------|---------------|-----------|
| Hunter    | 125     | 45        | 8             | -             | Combo Specialist |
| Assassin  | 105     | 50        | 12            | 25            | Brawler |
| Warden    | 140     | 55        | 9             | -             | Tank |

---

## Notes for Game State Documents

When creating or validating game state documents, ensure the following:

1. **Tile spawns** follow the weight distributions specified in each character's `spawn_weights`
2. **Ultimate tiles** (ALPHA_COMMAND, PREDATORS_TRANCE, INVINCIBILITY_TILE) only spawn when mana conditions are met
3. **Pet tiles** for Hunter (BEAR_PET, HAWK_PET, SNAKE_PET) spawn through sequence completion, not random spawn
4. **Specialty tiles** may have minimum/maximum board counts (check TileSpawner spawn rules)
5. **Mana systems** vary by character:
   - Hunter: Single bar
   - Assassin: Dual bars (purple and blue)
   - Warden: Single bar

---

*Generated from analysis of character resource files: hunter.tres, assassin.tres, mirror_warden.tres*