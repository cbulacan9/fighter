class_name HUD
extends Control

@onready var player_health_bar: HealthBar = $PlayerPanel/Bars/HealthBar
@onready var player_portrait: TextureRect = $PlayerPanel/Portrait
@onready var enemy_health_bar: HealthBar = $EnemyPanel/Bars/HealthBar
@onready var enemy_portrait: TextureRect = $EnemyPanel/Portrait

var _player_fighter: Fighter
var _enemy_fighter: Fighter


func setup(player_fighter: Fighter, enemy_fighter: Fighter) -> void:
	_player_fighter = player_fighter
	_enemy_fighter = enemy_fighter

	# Setup health bars
	if player_fighter:
		player_health_bar.setup(player_fighter.max_hp)
		player_fighter.hp_changed.connect(_on_player_hp_changed)
		player_fighter.armor_changed.connect(_on_player_armor_changed)

		if player_fighter.fighter_data and player_fighter.fighter_data.portrait:
			player_portrait.texture = player_fighter.fighter_data.portrait

	if enemy_fighter:
		enemy_health_bar.setup(enemy_fighter.max_hp)
		enemy_fighter.hp_changed.connect(_on_enemy_hp_changed)
		enemy_fighter.armor_changed.connect(_on_enemy_armor_changed)

		if enemy_fighter.fighter_data and enemy_fighter.fighter_data.portrait:
			enemy_portrait.texture = enemy_fighter.fighter_data.portrait


func _on_player_hp_changed(current: int, _max_hp: int) -> void:
	player_health_bar.set_hp(current)


func _on_player_armor_changed(current: int) -> void:
	player_health_bar.set_armor(current)


func _on_enemy_hp_changed(current: int, _max_hp: int) -> void:
	enemy_health_bar.set_hp(current)


func _on_enemy_armor_changed(current: int) -> void:
	enemy_health_bar.set_armor(current)
