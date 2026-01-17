# Task 046: Character Loading & Selection

## Objective
Implement character loading in GameManager and create character selection screen.

## Dependencies
- Task 045 (Character Data Resource)
- Task 020 (Game Manager)

## Reference
- `/docs/PROPOSAL_CHARACTER_SYSTEMS.md` → Character Framework

## Deliverables

### 1. Create CharacterRegistry
Create `/scripts/managers/character_registry.gd`:

```gdscript
class_name CharacterRegistry extends RefCounted

const CHARACTERS_PATH = "res://resources/characters/"

var _characters: Dictionary = {}  # {character_id: CharacterData}

func load_all() -> void:
    var dir = DirAccess.open(CHARACTERS_PATH)
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".tres"):
                var path = CHARACTERS_PATH + file_name
                var data = load(path) as CharacterData
                if data:
                    _characters[data.character_id] = data
            file_name = dir.get_next()

func get_character(id: String) -> CharacterData:
    return _characters.get(id)

func get_all_characters() -> Array[CharacterData]:
    var result: Array[CharacterData] = []
    for data in _characters.values():
        result.append(data)
    return result

func get_starter() -> CharacterData:
    for data in _characters.values():
        if data.is_starter:
            return data
    return null

func get_unlockable_characters() -> Array[CharacterData]:
    var result: Array[CharacterData] = []
    for data in _characters.values():
        if not data.is_starter:
            result.append(data)
    return result
```

### 2. Extend GameManager for Character Loading
Modify `/scripts/managers/game_manager.gd`:

```gdscript
# Add to GameManager

var character_registry: CharacterRegistry
var selected_player_character: CharacterData
var selected_enemy_character: CharacterData

func _ready() -> void:
    character_registry = CharacterRegistry.new()
    character_registry.load_all()
    # ... rest of existing code ...

func select_player_character(character_id: String) -> void:
    selected_player_character = character_registry.get_character(character_id)

func select_enemy_character(character_id: String) -> void:
    selected_enemy_character = character_registry.get_character(character_id)

func _setup_match() -> void:
    # Use selected characters or defaults
    var player_char = selected_player_character
    if not player_char:
        player_char = character_registry.get_starter()

    var enemy_char = selected_enemy_character
    if not enemy_char:
        enemy_char = character_registry.get_starter()

    # Initialize with character data
    _initialize_with_characters(player_char, enemy_char)

func _initialize_with_characters(player_char: CharacterData, enemy_char: CharacterData) -> void:
    # Create fighter data from character data
    var player_fighter_data = _create_fighter_data(player_char)
    var enemy_fighter_data = _create_fighter_data(enemy_char)

    # Initialize combat
    if combat_manager:
        combat_manager.initialize(player_fighter_data, enemy_fighter_data)

    # Initialize boards with character tiles
    if player_board:
        player_board.initialize_with_character(player_char, true)
    if enemy_board:
        enemy_board.initialize_with_character(enemy_char, false)

    # Setup sequence trackers if needed
    if player_char.has_sequences() and player_board:
        player_board._setup_sequence_tracker(player_char.sequences)

    # ... rest of setup ...

func _create_fighter_data(char_data: CharacterData) -> FighterData:
    var fighter_data = FighterData.new()
    fighter_data.max_hp = char_data.base_hp
    fighter_data.mana_config = char_data.mana_config
    fighter_data.portrait = char_data.portrait
    # Copy spawn weights
    fighter_data.tile_weights = char_data.spawn_weights.duplicate()
    return fighter_data
```

### 3. Create Character Select Screen
Create `/scenes/ui/character_select.tscn` and `/scripts/ui/character_select.gd`:

```gdscript
class_name CharacterSelect extends Control

signal character_selected(character_id: String)
signal back_pressed()

@export var character_card_scene: PackedScene

@onready var cards_container: GridContainer = $CardsContainer
@onready var description_label: Label = $DescriptionPanel/Description
@onready var select_button: Button = $SelectButton
@onready var back_button: Button = $BackButton

var _characters: Array[CharacterData] = []
var _unlocked_ids: Array[String] = []
var _selected_character: CharacterData = null

func setup(characters: Array[CharacterData], unlocked: Array[String]) -> void:
    _characters = characters
    _unlocked_ids = unlocked
    _populate_cards()

func _populate_cards() -> void:
    for child in cards_container.get_children():
        child.queue_free()

    for char_data in _characters:
        var card = _create_character_card(char_data)
        cards_container.add_child(card)

func _create_character_card(char_data: CharacterData) -> Control:
    var card = character_card_scene.instantiate()
    card.setup(char_data, _is_unlocked(char_data))
    card.pressed.connect(_on_card_pressed.bind(char_data))
    return card

func _is_unlocked(char_data: CharacterData) -> bool:
    if char_data.is_starter:
        return true
    return _unlocked_ids.has(char_data.character_id)

func _on_card_pressed(char_data: CharacterData) -> void:
    if not _is_unlocked(char_data):
        return

    _selected_character = char_data
    description_label.text = char_data.description
    select_button.disabled = false

func _on_select_pressed() -> void:
    if _selected_character:
        character_selected.emit(_selected_character.character_id)

func _on_back_pressed() -> void:
    back_pressed.emit()
```

### 4. Extend BoardManager for Character Initialization
Modify BoardManager:

```gdscript
func initialize_with_character(char_data: CharacterData, is_player: bool) -> void:
    _character_data = char_data
    _is_player_board = is_player

    # Setup tile spawner with character weights
    if _tile_spawner:
        _tile_spawner.set_weights(char_data.spawn_weights)
        _tile_spawner.set_available_tiles(char_data.get_all_tiles())

    # Generate initial board
    generate_initial_board()
```

## Acceptance Criteria
- [ ] CharacterRegistry loads all character resources
- [ ] GameManager uses selected characters
- [ ] Character select screen displays all characters
- [ ] Locked characters shown but not selectable
- [ ] BoardManager initializes with character-specific tiles
- [ ] Spawn weights respected
