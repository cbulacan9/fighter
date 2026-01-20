# Puzzle Fighter
*Character Design Reference Document*

---

## The Assassin
*Archetype: Brawler*

A high-mobility damage dealer who obscures the battlefield and evades attacks. Activates a devastating ultimate when health is critical.

### Stats

| Stat | Value | Effect |
|------|-------|--------|
| HP | 105 | Lower than average |
| Max Armor | 50 | Moderate armor cap |
| Strength | 6 | Reduced sword damage |
| Agility | 20 | 20% base dodge chance on all incoming attacks |

### Mana System

Two separate mana bars (50 mana each) for specialty abilities:
- **Bar 0 (Purple):** Smoke Bomb - matching Smoke Bomb tiles fills this bar
- **Bar 1 (Blue):** Shadow Step - matching Shadow Step tiles fills this bar
- **Mana Crystals** fill **both** bars simultaneously, accelerating ability access

Each ability costs 50 mana (full bar) to activate via click.

*Note: Mana does not trigger the ultimate — see Ultimate Ability below.*

### Basic Tiles

| Tile | Effect |
|------|--------|
| Physical Attack | Deals damage to opponent (reduced by low Strength) |
| Stun | Stuns opponent, interrupting their actions |
| Mana Crystal | Fills **both** mana bars simultaneously |
| Empty Box | Filler tile; match to clear board space |

### Specialty Tiles

| Tile | Passive (On Match) | Active (On Click) |
|------|-------------------|-------------------|
| Smoke Bomb | Hides 1/2/3 enemy tiles in smoke for 3 seconds. **Matches containing hidden tiles have no effect.** | Hides random enemy row + column for 3 seconds |
| Shadow Step | Grants dodge chance: 3x = 20%, 4x = 40%, 5x = 75% | **Shadow Veil:** Evade all attacks for 5 seconds |

### Assassin Status Display UI

A dedicated UI panel shows Assassin-specific information:

```
+------------------------------------------+
| [#] SMOKE BOMB    READY       DODGE: 35% |
| [#] SHADOW STEP   --                     |
| [#] TRANCE        2/4                    |
+------------------------------------------+
```

- **Smoke Bomb readiness:** Shows "READY" when mana bar 0 is full
- **Shadow Step readiness:** Shows "READY" when mana bar 1 is full
- **Dodge percentage:** Top right corner, displays total dodge chance (base agility + dodge status stacks)
- **Trance counter:** Shows matches used (X/4) during Predator's Trance, "--" when inactive

### Ultimate Ability

**Predator's Trance**

**Trigger:** Spawns when both mana bars are full (similar to other character ultimates). The Predator's Trance tile appears on the board and must be clicked to activate.

**Effect:** Applies the Predator's Trance status effect. While active, sword matches trigger bonus sword-only cascades:

- 3x sword match: Next cascade spawns only sword tiles (1 bonus cascade)
- 4x sword match: Next 2 cascades spawn only sword tiles (2 bonus cascades)
- 5x sword match: Next 3 cascades spawn only sword tiles (3 bonus cascades)

The bonus cascades counter decrements after each cascade iteration. Once depleted, normal tile spawning resumes.

**4-Match Limit:** Trance ends early after 4 player-initiated sword matches. The UI counter shows progress (0/4 → 1/4 → 2/4 → 3/4 → 4/4). This prevents infinite cascade abuse while still allowing powerful burst damage windows.

**Cooldown:** 20 seconds after activation before another Predator's Trance tile can spawn.

---

## The Hunter
*Archetype: Stun Heavy*

A combo-sequence specialist who commands animal companions. Rewards precise board management with intentional combo building using parallel combo trees.

### Combo System (Multi-Tree)

The Hunter builds combos by matching tiles in specific sequences. Only **player-initiated matches** count — cascade matches are ignored for combo purposes (but still apply normal effects).

**Key Mechanics:**
- Multiple combo trees can be active simultaneously
- Each tree tracks progress toward one sequence (Bear, Hawk, or Snake)
- Trees are pruned individually — if a move doesn't advance a specific tree, only that tree dies
- When a sequence completes, the corresponding Pet tile drops from the top of the board
- Self-buffs stack up to 3 times

**Example:**
1. Player matches Physical + Focus simultaneously → Bear tree starts (Physical), Snake tree starts (Focus)
2. Player matches Shield → Bear tree advances (Physical → Shield), Snake tree dies (needed Physical)
3. Player matches Shield → Bear tree completes (Physical → Shield → Shield) → Bear Pet drops!

### Basic Tiles

| Tile | Effect |
|------|--------|
| Physical Attack | Deals damage to opponent |
| Shield | Adds defensive protection |
| Focus | Builds stacks (1/2/3 for 3/4/5-match) that boost next attack by 7.5% per stack (max 10 stacks, 75% bonus). Consumed on next Physical match. |
| Mana Crystal | Grants bonus mana (3/5/8 for 3/4/5-match) on top of base match mana. Increases tile variety to reduce cascade frequency. |
| Empty Box | Filler tile (low spawn rate); matchable to clear. Also cleared when adjacent to other matches. |

### Specialty Tiles: Pets

Three distinct Pet tile types that spawn when their combo sequence completes.

**Spawn Rules:**
- Pets are NOT in the random tile spawn pool
- Pets drop from a random column at the top when their sequence completes
- Maximum 3 of each Pet type on board (if cap reached, combo completes but no Pet spawns)
- Pets fall with normal gravity and settle into the grid
- Pets are click-only (cannot be matched)

**Pet Types:**
| Pet | Spawns When |
|-----|-------------|
| 🐻 Bear Pet | Bear sequence completed |
| 🦅 Hawk Pet | Hawk sequence completed |
| 🐍 Snake Pet | Snake sequence completed |

### Pet Abilities

Click a Pet tile to activate its ability. **Costs 33 mana per activation** (allows 3 activations per full mana bar). Pet tiles can be activated during cascades.

| Ability | Sequence | Offensive Effect | Self Buff (3x stack) |
|---------|----------|------------------|----------------------|
| **Bear** | Physical → Shield → Shield | 1 bleed stack (damages on enemy's next match) | Attack strength increase |
| **Hawk** | Shield → Focus | Replaces 5 enemy tiles with empty boxes | Evasion (next attack auto-misses) |
| **Snake** | Focus → Physical → Shield | 3-second enemy board stun | Cleanses poison and heals 5 HP |

*Note: All sequences have unique starting tiles, so a single match can only start one tree (unless multiple tile types are matched simultaneously).*

### Hunter UI

*Replaces the match history bar (last 10 tiles) with combo-specific displays.*

**Combo Tree Display:** Shows all three sequences (Bear, Hawk, Snake) with tiles that brighten as combos progress and dim when completed or broken. Each sequence is a row showing the required tile order.

**Pet Population Display:** Shows current Pet counts: `🐻 0/3  🦅 0/3  🐍 0/3`. Flashes "MAX POP" when attempting to spawn a Pet at cap.

### Ultimate Ability

**Alpha Command**

Requires full mana bar. When mana is full, an Alpha Command tile spawns on the board. Click it to activate.

**Activation Effects:**
- Drains all mana
- Restores full armor (capped at max HP: 150)
- Grants 3 free pet activations (no mana cost)
- 2x multiplier to pet ability offensive effects while free activations remain
- 60-second cooldown before another Alpha Command tile can spawn

---

## The Mirror Warden
*Archetype: Tank*

A defensive specialist who queues reactive abilities to counter enemy attacks. Rewards anticipation and timing with powerful defensive payoffs.

### Defensive Queue System

Matching defensive tiles queues that effect with a countdown timer:

- Queued abilities expire if not triggered within their window
- Matching the same defensive type 3x in a row stacks into a stronger version and resets the timer
- A visible UI indicator shows opponents when the Warden is in defensive posture

*This allows opponents to "poke" with smaller attacks before committing larger ones.*

### Basic Tiles

| Tile | Effect |
|------|--------|
| Magic Attack | Deals magic damage to opponent |
| Shield | Adds defensive protection |
| Health | Restores Warden's health |

### Specialty Tiles

| Tile | Timing Window | Effect |
|------|---------------|--------|
| Reflection | Pre-attack (within 2 sec before hit) | Reflects enemy attack back at them |
| Cancel | Post-attack (within 2 sec after hit) | Cancels the enemy's attack effect |
| Absorb | On receiving attack | Stores damage; releases on next attack combo (scales with 4x/5x matches) |

### Ultimate Ability

**Invincibility**

Requires full mana bar. Grants complete damage immunity for 8 seconds.

---

## The Apothecary
*Archetype: Status Effect*

A variety-focused caster who rewards diverse matching patterns with damage multipliers. Specializes in poison damage and board manipulation.

### Variety Chain System

Each unique tile type matched in sequence adds 0.5x to a multiplier:

- Multiplier applies to the first repeated tile type in the chain
- Chain resets after multiplier is applied
- Minimum 3 unique combos required for any bonus
- All 6 tile types (4 basic + 2 specialty) count as unique

*Example: Attack → Health → Mana → Empty Box → Attack = 2x multiplier on that Attack (4 unique × 0.5x)*

### Basic Tiles

| Tile | Effect |
|------|--------|
| Magic Attack | Deals magic damage to opponent |
| Health | Restores Apothecary's health |
| Mana | Fills mana bar |
| Empty Box | Filler tile; match to clear board space |

### Specialty Tiles

Both specialty tiles are drop tiles that appear and can be clicked to activate.

| Tile | Effect (On Click) |
|------|-------------------|
| Poison | Applies poison to enemy; deals damage over time. Stacks additively, fades over time. |
| Potion | Replaces all Empty Box tiles on Apothecary's board with Health tiles |

### Ultimate Ability

**Transmute**

Requires full mana bar.

- Poisons 10 random tiles on the enemy's board
- When enemy matches poisoned tiles, they take poison damage
- Damage is unavoidable unless cleansed (currently only Hunter's Snake can cleanse)

---

## Matchup Dynamics

Initial observations on character interactions. Subject to playtesting.

| Matchup | Dynamic |
|---------|---------|
| **Hunter vs Apothecary** | Hunter must land Snake to cleanse Transmute; Apothecary wants to poison before Hunter completes sequence |
| **Assassin vs Mirror Warden** | Smoke obscures Warden's board, making defensive timing harder; Warden's visible defense stance lets Assassin bait with small attacks |
| **Mirror Warden vs Hunter** | Warden can Reflect/Cancel pet abilities if timed well; Hunter might bait with Hawk before committing to Snake |
| **Apothecary vs Assassin** | Poison punishes Assassin's reliance on extended combos during Predator's Trance; Assassin's Smoke Bomb negates poisoned tile matches |

---

*— End of Document —*
