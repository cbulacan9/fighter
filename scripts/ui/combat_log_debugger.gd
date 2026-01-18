class_name CombatLogDebugger
extends Control

## Debug panel that logs combat events (damage, healing, armor) in real-time.
## Toggle visibility with F4 key.
##
## Shows:
## - Damage dealt (with armor absorption breakdown)
## - Healing done
## - Armor/shield gained
## - Status effect damage (DoT)
## - Dodge events

const MAX_LOG_LINES := 100
const LOG_FADE_TIME := 15.0

var _combat_manager: CombatManager
var _log_entries: Array[Dictionary] = []

# UI elements (created programmatically)
var _panel: PanelContainer
var _vbox: VBoxContainer
var _title_label: Label
var _log_container: VBoxContainer
var _scroll_container: ScrollContainer
var _clear_button: Button

# Colors for different event types
const COLOR_DAMAGE := Color(1.0, 0.4, 0.4)       # Red for damage
const COLOR_DAMAGE_BLOCKED := Color(0.7, 0.5, 0.3)  # Orange for armor absorbed
const COLOR_HEAL := Color(0.4, 1.0, 0.4)         # Green for healing
const COLOR_ARMOR := Color(0.4, 0.7, 1.0)        # Blue for armor/shield
const COLOR_DOT := Color(0.8, 0.4, 0.8)          # Purple for DoT damage
const COLOR_DODGE := Color(1.0, 1.0, 0.5)        # Yellow for dodge
const COLOR_DEFEAT := Color(1.0, 0.2, 0.2)       # Bright red for defeat
const COLOR_INFO := Color(0.6, 0.6, 0.6)         # Gray for info


func _ready() -> void:
	_create_ui()
	visible = false  # Hidden by default


func _create_ui() -> void:
	# Panel
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(320, 300)
	add_child(_panel)

	# Semi-transparent background style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.05, 0.05, 0.9)
	style.border_color = Color(0.4, 0.2, 0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", style)

	# Margin container
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	# VBox
	_vbox = VBoxContainer.new()
	_vbox.name = "VBox"
	_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(_vbox)

	# Title
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "COMBAT LOG (F4 to toggle)"
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	_vbox.add_child(_title_label)

	# Separator
	var sep := HSeparator.new()
	_vbox.add_child(sep)

	# Scroll container for log
	_scroll_container = ScrollContainer.new()
	_scroll_container.custom_minimum_size = Vector2(0, 220)
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_vbox.add_child(_scroll_container)

	# Log container
	_log_container = VBoxContainer.new()
	_log_container.name = "LogContainer"
	_log_container.add_theme_constant_override("separation", 2)
	_log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(_log_container)

	# Clear button
	_clear_button = Button.new()
	_clear_button.name = "ClearButton"
	_clear_button.text = "Clear Log"
	_clear_button.pressed.connect(_on_clear_pressed)
	_vbox.add_child(_clear_button)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F4:
		visible = not visible
		get_viewport().set_input_as_handled()


## Sets up the debugger with a combat manager
func setup(combat_manager: CombatManager) -> void:
	if _combat_manager:
		_disconnect_signals()

	_combat_manager = combat_manager

	if _combat_manager:
		_connect_signals()
		_log("Combat log connected", COLOR_INFO)


func _connect_signals() -> void:
	if not _combat_manager:
		return

	if not _combat_manager.damage_dealt.is_connected(_on_damage_dealt):
		_combat_manager.damage_dealt.connect(_on_damage_dealt)
	if not _combat_manager.healing_done.is_connected(_on_healing_done):
		_combat_manager.healing_done.connect(_on_healing_done)
	if not _combat_manager.armor_gained.is_connected(_on_armor_gained):
		_combat_manager.armor_gained.connect(_on_armor_gained)
	if not _combat_manager.damage_dodged.is_connected(_on_damage_dodged):
		_combat_manager.damage_dodged.connect(_on_damage_dodged)
	if not _combat_manager.status_damage_dealt.is_connected(_on_status_damage_dealt):
		_combat_manager.status_damage_dealt.connect(_on_status_damage_dealt)
	if not _combat_manager.fighter_defeated.is_connected(_on_fighter_defeated):
		_combat_manager.fighter_defeated.connect(_on_fighter_defeated)


func _disconnect_signals() -> void:
	if not _combat_manager:
		return

	if _combat_manager.damage_dealt.is_connected(_on_damage_dealt):
		_combat_manager.damage_dealt.disconnect(_on_damage_dealt)
	if _combat_manager.healing_done.is_connected(_on_healing_done):
		_combat_manager.healing_done.disconnect(_on_healing_done)
	if _combat_manager.armor_gained.is_connected(_on_armor_gained):
		_combat_manager.armor_gained.disconnect(_on_armor_gained)
	if _combat_manager.damage_dodged.is_connected(_on_damage_dodged):
		_combat_manager.damage_dodged.disconnect(_on_damage_dodged)
	if _combat_manager.status_damage_dealt.is_connected(_on_status_damage_dealt):
		_combat_manager.status_damage_dealt.disconnect(_on_status_damage_dealt)
	if _combat_manager.fighter_defeated.is_connected(_on_fighter_defeated):
		_combat_manager.fighter_defeated.disconnect(_on_fighter_defeated)


# --- Signal Handlers ---

func _on_damage_dealt(target: Fighter, result: Fighter.DamageResult) -> void:
	var target_name := _get_fighter_name(target)

	if result.armor_absorbed > 0 and result.hp_damage > 0:
		_log("⚔ %s took %d dmg (%d blocked, %d to HP)" % [
			target_name, result.total_damage, result.armor_absorbed, result.hp_damage
		], COLOR_DAMAGE)
	elif result.armor_absorbed > 0:
		_log("🛡 %s blocked %d dmg (all absorbed by armor)" % [
			target_name, result.armor_absorbed
		], COLOR_DAMAGE_BLOCKED)
	else:
		_log("⚔ %s took %d dmg to HP" % [target_name, result.hp_damage], COLOR_DAMAGE)


func _on_healing_done(target: Fighter, amount: int) -> void:
	var target_name := _get_fighter_name(target)
	_log("💚 %s healed for %d" % [target_name, amount], COLOR_HEAL)


func _on_armor_gained(target: Fighter, amount: int) -> void:
	var target_name := _get_fighter_name(target)
	_log("🛡 %s gained %d armor" % [target_name, amount], COLOR_ARMOR)


func _on_damage_dodged(target: Fighter, _source: Fighter) -> void:
	var target_name := _get_fighter_name(target)
	_log("💨 %s DODGED an attack!" % target_name, COLOR_DODGE)


func _on_status_damage_dealt(target: Fighter, damage: float, effect_type: int) -> void:
	var target_name := _get_fighter_name(target)
	var effect_name := _get_effect_name(effect_type)
	_log("☠ %s took %.0f %s damage" % [target_name, damage, effect_name], COLOR_DOT)


func _on_fighter_defeated(fighter: Fighter) -> void:
	var fighter_name := _get_fighter_name(fighter)
	_log("💀 %s DEFEATED!" % fighter_name, COLOR_DEFEAT)


# --- Helper Methods ---

func _log(text: String, color: Color = Color.WHITE) -> void:
	var timestamp := "%.1f" % (Time.get_ticks_msec() / 1000.0)
	var entry := {
		"text": "[%s] %s" % [timestamp, text],
		"time": Time.get_ticks_msec(),
		"color": color
	}
	_log_entries.append(entry)

	# Trim old entries
	while _log_entries.size() > MAX_LOG_LINES:
		_log_entries.pop_front()

	_update_display()

	# Auto-scroll to bottom
	if _scroll_container:
		await get_tree().process_frame
		_scroll_container.scroll_vertical = int(_scroll_container.get_v_scroll_bar().max_value)


func _update_display() -> void:
	if not _log_container:
		return

	# Clear existing labels
	for child in _log_container.get_children():
		child.queue_free()

	# Add new labels
	for entry in _log_entries:
		var label := Label.new()
		label.text = entry.text
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", entry.color)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_log_container.add_child(label)


func _on_clear_pressed() -> void:
	_log_entries.clear()
	_update_display()


func _get_fighter_name(fighter: Fighter) -> String:
	if not fighter:
		return "Unknown"

	# Determine P1 (top/enemy) or P2 (bottom/player)
	var prefix := ""
	if _combat_manager:
		if fighter == _combat_manager.enemy_fighter:
			prefix = "P1 - "
		elif fighter == _combat_manager.player_fighter:
			prefix = "P2 - "

	if fighter.fighter_data:
		return prefix + fighter.fighter_data.fighter_name
	return prefix + "Fighter"


func _get_effect_name(effect_type: int) -> String:
	match effect_type:
		StatusTypes.StatusType.BLEED:
			return "Bleed"
		StatusTypes.StatusType.POISON:
			return "Poison"
		_:
			return "DoT"


## Cleanup
func clear() -> void:
	_disconnect_signals()
	_combat_manager = null
	_log_entries.clear()


func reset() -> void:
	_log_entries.clear()
	_update_display()
	_log("--- Combat Reset ---", COLOR_INFO)


## Returns all log entries for display in stats screen
func get_log_entries() -> Array[Dictionary]:
	return _log_entries
