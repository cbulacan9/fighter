# Puzzle Fighter — Game Design Document

**Version:** 1.0 (MVP)  
**Platform:** Mobile & Desktop  
**Genre:** Real-Time Puzzle Combat  

---

## 1. Game Overview

Puzzle Fighter is a real-time match-3 combat game where two opponents manipulate a shared-style grid to match tiles and trigger combat effects. Players drag rows and columns to align 3+ matching tiles, dealing damage, healing, blocking, or stunning their opponent. The first player to reduce their opponent's HP to 0 wins.

---

## 2. Board Specifications

| Property | Value |
|----------|-------|
| Grid size | 6 rows × 8 columns |
| Tile movement | Rows shift horizontally, columns shift vertically |
| Wrapping | Yes — tiles pushed off one edge appear on the opposite edge |
| Tile refill | New tiles fall from the top |
| Starting board | Randomly generated with no pre-existing matches |

---

## 3. Controls

**Input:** Touch (mobile) / Mouse (desktop)

| Action | Input |
|--------|-------|
| Move row | Tap and drag any tile horizontally |
| Move column | Tap and drag any tile vertically |
| Movement feel | Real-time smooth dragging (tiles follow input) |

**Snap-Back Rule:**  
On release, if the new position contains a valid match (3+ aligned), tiles lock in place and the match triggers. If no valid match exists, the row/column reverts to its original position.

---

## 4. Tile Types & Effects

Five tile types in the MVP. Spawn weighting is **configurable per character** for balance tuning.

| Tile | Effect | 3-Match | 4-Match | 5-Match |
|------|--------|---------|---------|---------|
| Sword | Damage opponent | 10 | 25 | 50 |
| Shield | Add armor (absorbs damage before HP, caps at max HP) | 10 | 25 | 50 |
| Health Potion | Heal self | 10 | 25 | 50 |
| Lightning | Stun opponent (grey out board, lock input) | 1 sec | 2 sec | 3 sec |
| Filler | Clears with no effect | — | — | — |

**Combo Cap:** 6+ tile matches are capped at 5-match rewards.

---

## 5. Match & Cascade Rules

- **Valid match:** 3+ identical tiles aligned horizontally or vertically
- **Cascades:** When tiles fall from the top and create new matches, those matches trigger automatically (chain reactions)
- **Cascade effects:** All tile effects apply normally during cascades

---

## 6. Combat System

### Health
- Starting HP: **100** (configurable per character later)
- Win condition: Reduce opponent to **0 HP**
- Simultaneous 0 HP: **Draw**

### Armor (Shields)
- Shield matches add armor points to a protective buffer
- Armor absorbs incoming damage before HP is affected
- Armor cannot exceed maximum HP
- Armor persists until depleted by damage

### Stun (Lightning)
- Stunned player's board is **greyed out** and input is **locked**
- Stun stacking: **Diminishing returns** if applied while already stunned

---

## 7. Combo Meter (Future Implementation)

- Small bar displayed under the health bar
- Fills as tiles are broken
- Decays slowly when no tiles are broken
- When full, triggers character-specific **Special Ability**

*Note: Special abilities are out of scope for MVP but documented for future reference.*

---

## 8. UI Layout

```
┌─────────────────────────────────────────────┐
│  [Player HP Bar]         [Enemy HP Bar]     │
│  [Combo Meter]           [Combo Meter]      │
│  [Player Portrait]       [Enemy Portrait]   │
├─────────────────────────────────────────────┤
│                                             │
│              6 × 8 GAME BOARD               │
│                                             │
│            (tiles wrap around)              │
│                                             │
└─────────────────────────────────────────────┘
```

### Visual Feedback
- **Damage numbers:** Float up when damage is dealt
- **Stun state:** Opponent's board greyed out
- **Match break:** Tiles clear (additional effects to be added later)

---

## 9. Game Flow

### Round Start
1. Both boards generate randomly (no pre-existing matches)
2. Countdown timer appears
3. Match begins

### During Match
- Real-time gameplay (no turns)
- Both players manipulate their boards simultaneously
- ~1-2 minute target match duration

### Round End
1. One player reaches 0 HP (or draw if simultaneous)
2. **Victory/Defeat splash** displays
3. **Stats Summary screen** shows:
   - Total damage dealt
   - Largest combo
   - Total tiles broken
   - Healing done
   - Damage blocked
   - Match duration
   - Stun time inflicted

### Pause
- Available in PvE only
- Not available in PvP (future)

---

## 10. AI Behavior (PvE)

- AI plays the same tile-matching game as the player
- AI difficulty levels affect reaction speed and decision quality
- Boss characters may have unique tile weightings and abilities (future)

---

## 11. MVP Scope

### Included
- 6×8 wrapping grid with drag controls
- 5 tile types with scaling effects
- Snap-back on invalid moves
- Cascade chain reactions
- Health, armor, stun mechanics
- One playable character vs one AI boss
- Health bars and damage number feedback
- Countdown start → Battle → Victory/Defeat → Stats Summary
- Pause in PvE
- Configurable tile spawn weighting

### Excluded (Future)
- Special abilities and combo meter activation
- Multiple characters with unique abilities
- PvP multiplayer
- Campaign/progression system
- Audio/sound effects
- Enhanced visual effects

---

## 12. Future Character Concepts

For reference in future development:

| Character | Ability | Effect |
|-----------|---------|--------|
| Tank | Titan's Wrath | Invulnerable 5-8 sec (extends with matches), enhanced sword spawn |
| Assassin | Predator's Trance | New tiles auto-combo as swords based on match size |
| Battle Monk | Vital Resonance | Clears board, spawns heals/shields left + swords in criss-cross pattern |

---

## 13. Technical Notes

- **Engine:** Godot
- **Art style:** Pixel art
- **Target platforms:** Mobile (touch), Desktop (mouse)

---

*Document End*
