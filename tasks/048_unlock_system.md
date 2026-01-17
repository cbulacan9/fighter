# Task 048: Unlock System

## Objective
Implement save/load for unlocked characters and victory tracking.

## Dependencies
- Task 046 (Character Loading & Selection)

## Reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → Unlock System

## Deliverables

### 1. Create SaveData Resource
Create `/scripts/data/save_data.gd`:

```gdscript
class_name SaveData extends Resource

const SAVE_PATH = "user://save_data.tres"

@export var unlocked_characters: Array[String] = []
@export var defeated_opponents: Array[String] = []
@export var total_wins: int = 0
@export var total_losses: int = 0

static func load_or_create() -> SaveData:
    if ResourceLoader.exists(SAVE_PATH):
        var data = load(SAVE_PATH) as SaveData
        if data:
            return data
    return SaveData.new()

func save() -> void:
    ResourceSaver.save(self, SAVE_PATH)

func unlock_character(character_id: String) -> void:
    if not unlocked_characters.has(character_id):
        unlocked_characters.append(character_id)
        save()

func record_defeat(opponent_id: String) -> void:
    if not defeated_opponents.has(opponent_id):
        defeated_opponents.append(opponent_id)
    total_wins += 1
    save()

func record_loss() -> void:
    total_losses += 1
    save()

func is_unlocked(character_id: String) -> bool:
    return unlocked_characters.has(character_id)

func has_defeated(opponent_id: String) -> bool:
    return defeated_opponents.has(opponent_id)
```

### 2. Create UnlockManager
Create `/scripts/managers/unlock_manager.gd`:

```gdscript
class_name UnlockManager extends RefCounted

signal character_unlocked(character_id: String)

var _save_data: SaveData
var _character_registry: CharacterRegistry

func setup(registry: CharacterRegistry) -> void:
    _character_registry = registry
    _save_data = SaveData.load_or_create()
    _process_unlocks()

func _process_unlocks() -> void:
    # Check if any defeated opponents should unlock characters
    for char_data in _character_registry.get_all_characters():
        if char_data.is_starter:
            continue

        # If we've defeated the unlock opponent, unlock this character
        if char_data.unlock_opponent_id != "":
            if _save_data.has_defeated(char_data.unlock_opponent_id):
                if not _save_data.is_unlocked(char_data.character_id):
                    _unlock(char_data.character_id)

func on_match_won(opponent_id: String) -> void:
    _save_data.record_defeat(opponent_id)

    # Check if this unlocks any characters
    for char_data in _character_registry.get_all_characters():
        if char_data.unlock_opponent_id == opponent_id:
            if not _save_data.is_unlocked(char_data.character_id):
                _unlock(char_data.character_id)

func on_match_lost() -> void:
    _save_data.record_loss()

func _unlock(character_id: String) -> void:
    _save_data.unlock_character(character_id)
    character_unlocked.emit(character_id)

func is_unlocked(character_id: String) -> bool:
    var char_data = _character_registry.get_character(character_id)
    if char_data and char_data.is_starter:
        return true
    return _save_data.is_unlocked(character_id)

func get_unlocked_ids() -> Array[String]:
    var result: Array[String] = []

    for char_data in _character_registry.get_all_characters():
        if is_unlocked(char_data.character_id):
            result.append(char_data.character_id)

    return result

func get_stats() -> Dictionary:
    return {
        "wins": _save_data.total_wins,
        "losses": _save_data.total_losses,
        "unlocked_count": get_unlocked_ids().size()
    }
```

### 3. Integrate with GameManager
Modify GameManager:

```gdscript
var unlock_manager: UnlockManager

func _ready() -> void:
    # ... existing code ...
    unlock_manager = UnlockManager.new()
    unlock_manager.setup(character_registry)
    unlock_manager.character_unlocked.connect(_on_character_unlocked)

func _on_match_ended(result: int) -> void:
    winner_id = result
    change_state(GameState.END)

    # Track unlock progress
    if result == 1:  # Player wins
        unlock_manager.on_match_won(selected_enemy_character.character_id)
    else:
        unlock_manager.on_match_lost()

func _on_character_unlocked(character_id: String) -> void:
    # Show unlock notification
    var char_data = character_registry.get_character(character_id)
    if char_data:
        _show_unlock_notification(char_data)

func _show_unlock_notification(char_data: CharacterData) -> void:
    # Display unlock popup
    # Could be in StatsScreen or separate overlay
    print("Character Unlocked: %s" % char_data.display_name)
```

### 4. Create Unlock Notification UI
Create `/scripts/ui/unlock_notification.gd`:

```gdscript
class_name UnlockNotification extends Control

@onready var portrait: TextureRect = $Portrait
@onready var name_label: Label = $NameLabel
@onready var message_label: Label = $MessageLabel

func show_unlock(char_data: CharacterData) -> void:
    portrait.texture = char_data.portrait
    name_label.text = char_data.display_name
    message_label.text = "Character Unlocked!"

    visible = true
    modulate.a = 0

    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 1.0, 0.3)
    tween.tween_interval(2.0)
    tween.tween_property(self, "modulate:a", 0.0, 0.3)
    tween.tween_callback(func(): visible = false)
```

### 5. Update Character Select with Unlock State
Modify character select to use UnlockManager:

```gdscript
func _ready() -> void:
    var game_manager = get_node("/root/Main/GameManager")
    if game_manager:
        var unlocked = game_manager.unlock_manager.get_unlocked_ids()
        setup(game_manager.character_registry.get_all_characters(), unlocked)
```

## Acceptance Criteria
- [ ] SaveData saves/loads from user directory
- [ ] UnlockManager tracks defeated opponents
- [ ] Defeating opponent unlocks corresponding character
- [ ] Unlock notification displays on first unlock
- [ ] Character select shows locked/unlocked state
- [ ] Stats (wins/losses) tracked
- [ ] Save persists between sessions
