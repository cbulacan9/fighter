# Task 016: Damage Numbers

## Objective
Implement floating damage/heal/armor numbers.

## Dependencies
- Task 013 (Combat Manager)

## Reference
- `/docs/SYSTEMS.md` → UI Manager (Damage Number Behavior)

## Deliverables

### 1. Damage Number Scene
Create `/scenes/ui/damage_number.tscn`:

**Node Structure:**
```
DamageNumber (Node2D)
├── Label (Label)
└── AnimationPlayer
```

### 2. Damage Number Script
Create `/scripts/ui/damage_number.gd`:

**Methods:**
| Method | Description |
|--------|-------------|
| `setup(value: int, type: EffectType, pos: Vector2)` | Initialize |
| `play()` | Start animation |

**EffectType Enum:**
- `DAMAGE` - Red
- `HEAL` - Green
- `ARMOR` - Blue
- `STUN` - Yellow

### 3. Visual Style
| Type | Color | Prefix |
|------|-------|--------|
| DAMAGE | #FF4444 | - |
| HEAL | #44FF44 | + |
| ARMOR | #4444FF | +🛡 or +A |
| STUN | #FFFF44 | ⚡ or duration |

**Font:**
- Bold, readable at small size
- Outline for visibility over tiles
- Size: 24-32px

### 4. Animation
Duration: 1.0 second

**Sequence:**
1. Start at spawn position
2. Float upward (~50px)
3. Scale: 1.0 → 1.2 → 1.0
4. Fade: 1.0 → 0.0 (last 0.3s)
5. Queue free on complete

**AnimationPlayer tracks:**
- position:y
- scale
- modulate:a

### 5. Damage Number Manager
Add to UI system or create `/scripts/ui/damage_number_spawner.gd`:

**Methods:**
| Method | Description |
|--------|-------------|
| `spawn(value, type, world_pos)` | Create and play number |

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| `number_scene` | PackedScene | Reference to scene |
| `container` | Node2D | Parent for instances |

### 6. Position Calculation
Numbers spawn at:
- Match position (center of matched tiles)
- Or: Target fighter's position (above health bar)

Slight random X offset (-10 to +10) prevents stacking.

### 7. Combat Manager Integration
Listen to CombatManager signals:
```
_on_damage_dealt(target, result):
    pos = get_fighter_position(target)
    spawn(result.hp_damage, DAMAGE, pos)

_on_healing_done(target, amount):
    pos = get_fighter_position(target)
    spawn(amount, HEAL, pos)

_on_armor_gained(target, amount):
    pos = get_fighter_position(target)
    spawn(amount, ARMOR, pos)

_on_stun_applied(target, duration):
    pos = get_fighter_position(target)
    spawn(duration, STUN, pos)  # Show seconds
```

## Acceptance Criteria
- [ ] Numbers spawn on combat effects
- [ ] Correct colors for each effect type
- [ ] Numbers float upward and fade
- [ ] Multiple numbers can display simultaneously
- [ ] Numbers auto-cleanup after animation
- [ ] Readable over game board
