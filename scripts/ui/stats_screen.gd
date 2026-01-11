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


func _ready() -> void:
	visible = false
	_connect_buttons()


func _connect_buttons() -> void:
	if rematch_button:
		rematch_button.pressed.connect(_on_rematch_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)


func show_stats(stats: StatsTracker.MatchStats) -> void:
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

	visible = true


func hide_stats() -> void:
	visible = false


func _format_duration(seconds: float) -> String:
	var minutes := int(seconds) / 60
	var secs := int(seconds) % 60
	return "%d:%02d" % [minutes, secs]


func _on_rematch_pressed() -> void:
	hide_stats()
	rematch_pressed.emit()


func _on_quit_pressed() -> void:
	quit_pressed.emit()
