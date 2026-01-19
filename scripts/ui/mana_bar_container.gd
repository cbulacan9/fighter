class_name ManaBarContainer
extends VBoxContainer

signal bar_clicked(bar_index: int)
signal ultimate_ready()
signal ultimate_no_longer_ready()
signal alpha_command_activated(fighter: Fighter)
signal alpha_command_expired(fighter: Fighter)

## Scene used to instantiate individual mana bars
@export var mana_bar_scene: PackedScene
## Spacing between bars (uses theme separation if not set)
@export var bar_spacing: float = 4.0
## Show ultimate ready indicator when all bars are full
@export var show_ultimate_indicator: bool = true
## Indicator color when ultimate is ready
@export var ultimate_indicator_color: Color = Color(1.0, 0.9, 0.3, 1.0)
## Color when Alpha Command is active (decaying visual)
@export var alpha_command_color: Color = Color(0.4, 0.8, 1.0, 1.0)

var _fighter: Fighter
var _mana_system: ManaSystem
var _status_manager: StatusEffectManager
var _bars: Array[ManaBarUI] = []
var _ultimate_indicator: Control
var _alpha_command_indicator: Control
var _alpha_command_tween: Tween
var _was_ultimate_ready: bool = false
var _was_alpha_command_active: bool = false


func _ready() -> void:
	# Apply bar spacing
	add_theme_constant_override("separation", int(bar_spacing))


func setup(fighter: Fighter, mana_system: ManaSystem, status_manager: StatusEffectManager = null) -> void:
	_cleanup()

	_fighter = fighter
	_mana_system = mana_system
	_status_manager = status_manager

	if not mana_system or not fighter:
		visible = false
		return

	# Check if this fighter has mana configured
	var bar_count := mana_system.get_bar_count(fighter)
	if bar_count == 0:
		visible = false
		return

	visible = true

	# Create bars for this fighter
	for i in range(bar_count):
		var bar := _create_bar(i)
		if bar:
			_bars.append(bar)

	# Connect to mana system signals
	if not mana_system.mana_changed.is_connected(_on_mana_changed):
		mana_system.mana_changed.connect(_on_mana_changed)
	if not mana_system.mana_blocked.is_connected(_on_mana_blocked):
		mana_system.mana_blocked.connect(_on_mana_blocked)
	if not mana_system.all_bars_full.is_connected(_on_all_bars_full):
		mana_system.all_bars_full.connect(_on_all_bars_full)

	# Connect to status effect signals if status manager is provided
	if _status_manager:
		if not _status_manager.effect_applied.is_connected(_on_status_effect_applied):
			_status_manager.effect_applied.connect(_on_status_effect_applied)
		if not _status_manager.effect_removed.is_connected(_on_status_effect_removed):
			_status_manager.effect_removed.connect(_on_status_effect_removed)

	# Create ultimate indicator if needed
	if show_ultimate_indicator and bar_count > 0:
		_create_ultimate_indicator()

	# Create alpha command indicator
	_create_alpha_command_indicator()

	# Initial state check
	_check_ultimate_ready()


func _cleanup() -> void:
	# Disconnect signals from old mana system
	if _mana_system:
		if _mana_system.mana_changed.is_connected(_on_mana_changed):
			_mana_system.mana_changed.disconnect(_on_mana_changed)
		if _mana_system.mana_blocked.is_connected(_on_mana_blocked):
			_mana_system.mana_blocked.disconnect(_on_mana_blocked)
		if _mana_system.all_bars_full.is_connected(_on_all_bars_full):
			_mana_system.all_bars_full.disconnect(_on_all_bars_full)

	# Remove existing bars
	for bar in _bars:
		if is_instance_valid(bar):
			bar.clicked.disconnect(_on_bar_clicked.bind(_bars.find(bar)))
			bar.queue_free()
	_bars.clear()

	# Remove ultimate indicator
	if _ultimate_indicator and is_instance_valid(_ultimate_indicator):
		_ultimate_indicator.queue_free()
		_ultimate_indicator = null

	# Remove alpha command indicator
	if _alpha_command_indicator and is_instance_valid(_alpha_command_indicator):
		_alpha_command_indicator.queue_free()
		_alpha_command_indicator = null

	# Kill alpha command tween if running
	if _alpha_command_tween:
		_alpha_command_tween.kill()
		_alpha_command_tween = null

	# Disconnect from status manager
	if _status_manager:
		if _status_manager.effect_applied.is_connected(_on_status_effect_applied):
			_status_manager.effect_applied.disconnect(_on_status_effect_applied)
		if _status_manager.effect_removed.is_connected(_on_status_effect_removed):
			_status_manager.effect_removed.disconnect(_on_status_effect_removed)

	_fighter = null
	_mana_system = null
	_status_manager = null
	_was_ultimate_ready = false
	_was_alpha_command_active = false


func _create_bar(bar_index: int) -> ManaBarUI:
	if not mana_bar_scene:
		push_error("ManaBarContainer: mana_bar_scene not set")
		return null

	var bar: ManaBarUI = mana_bar_scene.instantiate()
	if not bar:
		push_error("ManaBarContainer: Failed to instantiate mana bar scene")
		return null

	add_child(bar)

	# Setup the bar with max mana value
	var max_mana := _mana_system.get_max_mana(_fighter, bar_index)
	bar.setup(max_mana)

	# Set initial value
	var current := _mana_system.get_mana(_fighter, bar_index)
	bar.set_value(current, max_mana)

	# Check if blocked
	if _mana_system.is_bar_blocked(_fighter, bar_index):
		bar.set_blocked(true)

	# Connect click signal
	bar.clicked.connect(_on_bar_clicked.bind(bar_index))

	return bar


func _create_ultimate_indicator() -> void:
	if _ultimate_indicator:
		return

	# Create a simple indicator panel below the bars
	_ultimate_indicator = PanelContainer.new()
	_ultimate_indicator.name = "UltimateIndicator"
	_ultimate_indicator.visible = false
	_ultimate_indicator.custom_minimum_size = Vector2(0, 16)

	var style := StyleBoxFlat.new()
	style.bg_color = ultimate_indicator_color
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	_ultimate_indicator.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.name = "Label"
	label.text = "ULTIMATE READY"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.BLACK)
	_ultimate_indicator.add_child(label)

	add_child(_ultimate_indicator)


func _create_alpha_command_indicator() -> void:
	if _alpha_command_indicator:
		return

	# Create an indicator panel for Alpha Command active state
	_alpha_command_indicator = PanelContainer.new()
	_alpha_command_indicator.name = "AlphaCommandIndicator"
	_alpha_command_indicator.visible = false
	_alpha_command_indicator.custom_minimum_size = Vector2(0, 20)

	var style := StyleBoxFlat.new()
	style.bg_color = alpha_command_color
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	_alpha_command_indicator.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.name = "Label"
	label.text = "ALPHA COMMAND"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.BLACK)
	_alpha_command_indicator.add_child(label)

	add_child(_alpha_command_indicator)


func _on_status_effect_applied(target: Fighter, effect: StatusEffect) -> void:
	if target != _fighter:
		return

	# Check if Alpha Command was applied
	if effect.data.effect_type == StatusTypes.StatusType.ALPHA_COMMAND:
		_was_alpha_command_active = true
		_show_alpha_command_active()
		alpha_command_activated.emit(_fighter)


func _on_status_effect_removed(target: Fighter, effect_type: StatusTypes.StatusType) -> void:
	if target != _fighter:
		return

	# Check if Alpha Command was removed
	if effect_type == StatusTypes.StatusType.ALPHA_COMMAND:
		_was_alpha_command_active = false
		_hide_alpha_command_active()
		alpha_command_expired.emit(_fighter)


func _show_alpha_command_active() -> void:
	if not _alpha_command_indicator:
		return

	_alpha_command_indicator.visible = true

	# Hide ultimate ready indicator when alpha command is active
	if _ultimate_indicator:
		_ultimate_indicator.visible = false

	_animate_alpha_command_indicator()


func _hide_alpha_command_active() -> void:
	if _alpha_command_indicator:
		_alpha_command_indicator.visible = false

	# Kill the animation tween
	if _alpha_command_tween:
		_alpha_command_tween.kill()
		_alpha_command_tween = null

	# Check if ultimate should be shown again
	_check_ultimate_ready()


func _animate_alpha_command_indicator() -> void:
	if not _alpha_command_indicator or not is_instance_valid(_alpha_command_indicator):
		return

	# Kill any existing tween
	if _alpha_command_tween:
		_alpha_command_tween.kill()

	# Pulsing animation for the indicator
	_alpha_command_tween = create_tween()
	_alpha_command_tween.set_loops()
	_alpha_command_tween.set_ease(Tween.EASE_IN_OUT)
	_alpha_command_tween.set_trans(Tween.TRANS_SINE)

	var panel_style: StyleBoxFlat = _alpha_command_indicator.get_theme_stylebox("panel")
	if panel_style:
		var bright := alpha_command_color
		var dim := Color(bright.r * 0.6, bright.g * 0.6, bright.b * 0.6, bright.a)
		_alpha_command_tween.tween_property(panel_style, "bg_color", dim, 0.3)
		_alpha_command_tween.tween_property(panel_style, "bg_color", bright, 0.3)


## Updates the Alpha Command indicator to show decay progress
func update_alpha_command_decay(multiplier: float) -> void:
	if not _alpha_command_indicator or not is_instance_valid(_alpha_command_indicator):
		return

	if multiplier <= 1.0:
		# Effect has expired
		_hide_alpha_command_active()
		return

	# Update the label to show current multiplier
	var label: Label = _alpha_command_indicator.get_node_or_null("Label")
	if label:
		var percent := int((multiplier - 1.0) * 100.0)
		label.text = "ALPHA COMMAND %d%%" % percent


## Returns the current Alpha Command multiplier for UI display
func get_alpha_command_multiplier() -> float:
	if not _status_manager or not _fighter:
		return 1.0
	return _status_manager.get_alpha_command_multiplier(_fighter)


## Returns true if Alpha Command is currently active
func is_alpha_command_active() -> bool:
	return _was_alpha_command_active


func _on_mana_changed(fighter: Fighter, bar_index: int, current: int, max_value: int) -> void:
	if fighter != _fighter:
		return

	if bar_index >= 0 and bar_index < _bars.size():
		_bars[bar_index].set_value(current, max_value)

	# Check if ultimate ready state changed
	_check_ultimate_ready()


func _on_mana_blocked(fighter: Fighter, bar_index: int, _duration: float) -> void:
	if fighter != _fighter:
		return

	if bar_index >= 0 and bar_index < _bars.size():
		_bars[bar_index].set_blocked(true)


func _on_all_bars_full(fighter: Fighter) -> void:
	if fighter != _fighter:
		return

	# Only show ultimate ready if not on cooldown
	if not _fighter.is_ultimate_on_cooldown():
		_show_ultimate_ready_effect()


func _on_bar_clicked(bar_index: int) -> void:
	bar_clicked.emit(bar_index)


func _check_ultimate_ready() -> void:
	if not _mana_system or not _fighter:
		return

	var mana_full := _mana_system.are_all_bars_full(_fighter)
	var on_cooldown := _fighter.is_ultimate_on_cooldown()
	var is_ready := mana_full and not on_cooldown

	if is_ready and not _was_ultimate_ready:
		_was_ultimate_ready = true
		ultimate_ready.emit()
		# Only show visual if Alpha Command is not active
		if not _was_alpha_command_active:
			_show_ultimate_ready_effect()
	elif not is_ready and _was_ultimate_ready:
		_was_ultimate_ready = false
		ultimate_no_longer_ready.emit()
		_hide_ultimate_ready_effect()


func _show_ultimate_ready_effect() -> void:
	# Don't show ultimate ready if Alpha Command is active
	if _was_alpha_command_active:
		return
	# Show all bar glows
	for bar in _bars:
		if is_instance_valid(bar) and bar.glow:
			bar.glow.visible = true

	# Show ultimate indicator
	if _ultimate_indicator and show_ultimate_indicator:
		_ultimate_indicator.visible = true
		_animate_ultimate_indicator()


func _hide_ultimate_ready_effect() -> void:
	# Hide ultimate indicator
	if _ultimate_indicator:
		_ultimate_indicator.visible = false


func _animate_ultimate_indicator() -> void:
	if not _ultimate_indicator or not is_instance_valid(_ultimate_indicator):
		return

	# Simple pulse animation for the indicator
	var tween := create_tween()
	tween.set_loops()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)

	var panel_style: StyleBoxFlat = _ultimate_indicator.get_theme_stylebox("panel")
	if panel_style:
		var bright := ultimate_indicator_color
		var dim := Color(bright.r * 0.7, bright.g * 0.7, bright.b * 0.7, bright.a)
		tween.tween_property(panel_style, "bg_color", dim, 0.4)
		tween.tween_property(panel_style, "bg_color", bright, 0.4)


func update_blocked_state() -> void:
	if not _fighter or not _mana_system:
		return

	# Update each bar's blocked state
	for i in range(_bars.size()):
		if i < _bars.size() and is_instance_valid(_bars[i]):
			var is_blocked := _mana_system.is_bar_blocked(_fighter, i)
			_bars[i].set_blocked(is_blocked)


func get_bar(index: int) -> ManaBarUI:
	if index >= 0 and index < _bars.size():
		return _bars[index]
	return null


func get_bar_count() -> int:
	return _bars.size()


func is_ultimate_ready() -> bool:
	return _was_ultimate_ready


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup()
