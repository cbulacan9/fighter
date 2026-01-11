# Task 001: Project Setup

## Objective
Initialize Godot project with correct folder structure and project settings.

## Dependencies
None

## Reference
- `/docs/ARCHITECTURE.md` → File Structure section

## Deliverables

### 1. Create Folder Structure
```
project/
├── scenes/
│   ├── board/
│   └── ui/
├── scripts/
│   ├── managers/
│   ├── systems/
│   ├── controllers/
│   ├── entities/
│   └── data/
├── resources/
│   ├── tiles/
│   └── fighters/
└── assets/
    ├── sprites/
    └── ui/
```

### 2. Project Settings
- Project name: "Puzzle Fighter"
- Window size: 720x1280 (portrait mobile)
- Stretch mode: `canvas_items`
- Stretch aspect: `keep_width`
- Renderer: Compatibility (for mobile support)

### 3. Create Autoload Placeholder
- Create empty `game_manager.gd` in `/scripts/managers/`
- Register as autoload named `GameManager`

### 4. Create Main Scene
- Create `main.tscn` as the main scene
- Set as project's main scene
- Add root Node named "Main"

## Acceptance Criteria
- [ ] All folders exist
- [ ] Project runs without errors
- [ ] Main scene loads on play
- [ ] GameManager autoload accessible
