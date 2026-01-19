class_name StatsScreen
extends CanvasLayer

signal rematch_pressed
signal quit_pressed

@onready var panel: Control = $Panel
@onready var damage_value: Label = $Panel/StatsContainer/DamageDealt/Value
@onready var largest_match_value: Label = $Panel/StatsContainer/LargestMatch/Value
@onready var tiles_broken_value: Label = $Panel/StatsContainer/TilesBroken/Value
@onready var healing_value: Label = $Panel/StatsContainer/HealingDone/Value
@onready var blocked_value: Label = $Panel/StatsContainer/DamageBlocked/Value
@onready var duration_value: Label = $Panel/StatsContainer/MatchDuration/Value
@onready var stun_value: Label = $Panel/StatsContainer/StunInflicted/Value
@onready var chain_value: Label = $Panel/StatsContainer/LongestChain/Value
@onready var rematch_button: Button = $Panel/ButtonContainer/RematchButton
@onready var quit_button: Button = $Panel/ButtonContainer/QuitButton

# Combat log UI (created programmatically)
var _combat_log_panel: PanelContainer
var _combat_log_container: VBoxContainer
var _combat_log_scroll: ScrollContainer


func _ready() -> void:
	visible = false
	_connect_buttons()
	_create_combat_log_panel()


func _connect_buttons() -> void:
	if rematch_button:
		rematch_button.pressed.connect(_on_rematch_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)


func _create_combat_log_panel() -> void:
	if not panel:
		return

	# Create panel container below the stats (bottom center)
	_combat_log_panel = PanelContainer.new()
	_combat_log_panel.name = "CombatLogPanel"
	_combat_log_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_combat_log_panel.offset_left = -300
	_combat_log_panel.offset_top = -350
	_combat_log_panel.offset_right = 300
	_combat_log_panel.offset_bottom = -150
	panel.add_child(_combat_log_panel)

	# Style the panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	_combat_log_panel.add_theme_stylebox_override("panel", style)

	# Margin container
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_combat_log_panel.add_child(margin)

	# VBox for header + scroll
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Header label
	var header := Label.new()
	header.text = "Combat Log"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	vbox.add_child(header)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Scroll container
	_combat_log_scroll = ScrollContainer.new()
	_combat_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_combat_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_combat_log_scroll)

	# Log entries container
	_combat_log_container = VBoxContainer.new()
	_combat_log_container.add_theme_constant_override("separation", 2)
	_combat_log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_combat_log_scroll.add_child(_combat_log_container)


func show_stats(stats: StatsTracker.MatchStats, combat_log_entries: Array[Dictionary] = []) -> void:
	if damage_value:
		damage_value.text = str(stats.damage_dealt)
	if largest_match_value:
		largest_match_value.text = str(stats.largest_match)
	if tiles_broken_value:
		tiles_broken_value.text = str(stats.tiles_broken)
	if healing_value:
		healing_value.text = str(stats.healing_done)
	if blocked_value:
		blocked_value.text = str(stats.damage_blocked)
	if duration_value:
		duration_value.text = _format_duration(stats.match_duration)
	if stun_value:
		stun_value.text = "%.1fs" % stats.stun_inflicted
	if chain_value:
		chain_value.text = str(stats.longest_chain)

	# Populate combat log
	_populate_combat_log(combat_log_entries)

	visible = true


func hide_stats() -> void:
	visible = false


func _populate_combat_log(entries: Array[Dictionary]) -> void:
	if not _combat_log_container:
		return

	# Clear existing entries
	for child in _combat_log_container.get_children():
		child.queue_free()

	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No combat events recorded"
		empty_label.add_theme_font_size_override("font_size", 11)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_combat_log_container.add_child(empty_label)
		return

	# Add log entries
	for entry in entries:
		var label := Label.new()
		label.text = entry.get("text", "")
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", entry.get("color", Color.WHITE))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_combat_log_container.add_child(label)

	# Scroll to bottom (show most recent events) after a frame
	if _combat_log_scroll:
		await get_tree().process_frame
		_combat_log_scroll.scroll_vertical = int(_combat_log_scroll.get_v_scroll_bar().max_value)


func _format_duration(seconds: float) -> String:
	@warning_ignore("integer_division")
	var minutes: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	return "%d:%02d" % [minutes, secs]


func _on_rematch_pressed() -> void:
	hide_stats()
	rematch_pressed.emit()


func _on_quit_pressed() -> void:
	quit_pressed.emit()
