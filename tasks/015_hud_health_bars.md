# Task 015: HUD (Health Bars)

## Objective
Implement health bar display with armor overlay.

## Dependencies
- Task 012 (Fighter State)

## Reference
- `/docs/SYSTEMS.md` → UI Manager
- Design Doc → Section 8 UI Layout

## Deliverables

### 1. HUD Scene
Create `/scenes/ui/hud.tscn`:

**Node Structure:**
```
HUD (Control)
├── PlayerPanel (HBoxContainer)
│   ├── Portrait (TextureRect)
│   └── Bars (VBoxContainer)
│       ├── HealthBar (custom)
│       └── ComboMeter (ProgressBar) [visual only]
└── EnemyPanel (HBoxContainer)
    ├── Bars (VBoxContainer)
    │   ├── HealthBar (custom)
    │   └── ComboMeter (ProgressBar)
    └── Portrait (TextureRect)
```

### 2. Health Bar Scene
Create `/scenes/ui/health_bar.tscn`:

**Node Structure:**
```
HealthBar (Control)
├── Background (ColorRect)
├── ArmorFill (ColorRect)
├── HealthFill (ColorRect)
└── Label (Label) [optional: "50/100"]
```

### 3. Health Bar Script
Create `/scripts/ui/health_bar.gd`:

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| `max_value` | int | Maximum HP |
| `current_hp` | int | Current HP |
| `current_armor` | int | Current armor |

**Methods:**
| Method | Description |
|--------|-------------|
| `setup(max_hp: int)` | Initialize bar |
| `set_hp(value: int)` | Update HP display |
| `set_armor(value: int)` | Update armor display |
| `animate_change()` | Smooth transition |

### 4. Visual Design
- Background: Dark grey
- Health fill: Green (or red when low)
- Armor fill: Blue, overlaid on health
- Dimensions: Flexible width, 20-30px height

**Fill calculation:**
```
health_width = (current_hp / max_value) * total_width
armor_width = (current_armor / max_value) * total_width
```

Armor displays on top of/alongside health portion.

### 5. Animation
When values change:
- Tween to new width over 0.2s
- Optional: Flash on damage
- Optional: Pulse when low (< 25%)

### 6. HUD Manager Script
Create `/scripts/ui/hud.gd`:

**Methods:**
| Method | Description |
|--------|-------------|
| `setup(player_fighter, enemy_fighter)` | Connect signals |
| `_on_hp_changed(fighter, current, max)` | Update correct bar |
| `_on_armor_changed(fighter, current)` | Update armor display |

### 7. Signal Connections
HUD listens to Fighter signals:
- `hp_changed` → Update health fill
- `armor_changed` → Update armor fill

### 8. Portrait Display
- TextureRect sized for portrait image
- Load from FighterData.portrait
- Placeholder: Colored rectangle

## Acceptance Criteria
- [ ] Health bars display for both fighters
- [ ] HP changes reflected visually
- [ ] Armor displayed distinctly from HP
- [ ] Portraits display correctly
- [ ] Animations smooth value changes
- [ ] Layout responsive to screen size
