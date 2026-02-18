# Feature: Adrenaline Tile for The Detective

**Created:** 2026-02-17
**Status:** Implemented

## Problem Statement
The Detective (basic character) needs a unique tile that gives the character identity — a noir detective who resorts to drugs to compensate for his shortcomings.

## Design

### Adrenaline Tile
- **Replaces:** Potion tile on The Detective
- **On match:** Instant burst overheal + Strength buff + HP drain over time
- **Stacking:** Re-match removes old effects and applies fresh ones with new match tier values
- **Duration:** 5 seconds

### Match Values

| Match | Burst Heal | Strength Buff | Duration | HP Drain/sec | Total Drain |
|-------|-----------|---------------|----------|-------------|-------------|
| 3-match | 15 HP | +40% damage | 5s | 3/s | 15 HP |
| 4-match | 30 HP | +60% damage | 5s | 6/s | 30 HP |
| 5-match | 60 HP | +80% damage | 5s | 12/s | 60 HP |

### Behavior
- Replaces Potion tile entirely in The Detective's tile set
- On match: Overheal (can exceed max HP) -> apply strength buff -> start HP drain over time
- Re-match: Old effects are explicitly removed, new ones applied fresh with correct tier values
- Strength buff values are set per-instance via `value_override` on the StatusEffect
- HP drain **bypasses armor** (uses `drain_hp()` instead of `take_damage()`) — it's self-inflicted, not an attack
- Net HP after full duration: ~0 (break even if strength not utilized)
- Value is in sword matches landed while buffed

### Implementation Details
- **Tile type:** `TileTypes.Type.ADRENALINE = 20`
- **Status types:** `ADRENALINE_BOOST` (14) and `ADRENALINE_DRAIN` (15)
- **Resources:** Single `adrenaline_boost.tres` and `adrenaline_drain.tres` — values set per-instance at runtime
- **StatusEffect.value_override:** New field that overrides `data.base_value` when >= 0, allowing per-instance values from shared resources
- **Fighter.overheal():** Heals beyond max HP so full-health adrenaline isn't punished
- **Fighter.drain_hp():** Drains HP directly bypassing armor

### UI
- **Adrenaline Boost icon:** Bright orange with upward arrow symbol (+)
- **Adrenaline Drain icon:** Dark red with drops symbol (-)

### Character Identity
Noir detective, self-destructive edge. Strong but burning the candle at both ends. Risk/reward playstyle.

## Success Criteria
- [x] Adrenaline tile appears on The Detective's board (replaces Potion)
- [x] Matching grants burst overheal, strength buff, and HP drain
- [x] Overheal can exceed max HP
- [x] HP drain bypasses armor
- [x] Buff duration is 5 seconds, refreshes on re-match
- [x] AI can evaluate and match Adrenaline tiles
- [x] Status effect icons are visually distinct (orange boost, red drain)
- [x] All other characters unaffected

## Non-Goals
- No new visual assets (use placeholder colors/textures)
- No new sound effects
- No changes to other characters
