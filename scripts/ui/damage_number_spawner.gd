class_name DamageNumberSpawner
extends Node2D

@export var number_scene: PackedScene

var _combat_manager: CombatManager
var _player_position: Vector2
var _enemy_position: Vector2


func setup(combat_manager: CombatManager, player_pos: Vector2, enemy_pos: Vector2) -> void:
	_combat_manager = combat_manager
	_player_position = player_pos
	_enemy_position = enemy_pos

	if combat_manager:
		combat_manager.damage_dealt.connect(_on_damage_dealt)
		combat_manager.healing_done.connect(_on_healing_done)
		combat_manager.armor_gained.connect(_on_armor_gained)
		combat_manager.stun_applied.connect(_on_stun_applied)
		combat_manager.damage_dodged.connect(_on_damage_dodged)
		combat_manager.status_damage_dealt.connect(_on_status_damage_dealt)


func spawn(value: float, type: DamageNumber.EffectType, world_pos: Vector2) -> void:
	if not number_scene:
		return

	var number: DamageNumber = number_scene.instantiate()
	add_child(number)
	number.setup(value, type, world_pos)
	number.play()


func _get_fighter_position(fighter: Fighter) -> Vector2:
	if _combat_manager:
		if fighter == _combat_manager.player_fighter:
			return _player_position
		else:
			return _enemy_position
	return Vector2.ZERO


func _on_damage_dealt(target: Fighter, result: Fighter.DamageResult) -> void:
	if result.hp_damage > 0:
		var pos := _get_fighter_position(target)
		spawn(result.hp_damage, DamageNumber.EffectType.DAMAGE, pos)


func _on_healing_done(target: Fighter, amount: int) -> void:
	if amount > 0:
		var pos := _get_fighter_position(target)
		spawn(amount, DamageNumber.EffectType.HEAL, pos)


func _on_armor_gained(target: Fighter, amount: int) -> void:
	if amount > 0:
		var pos := _get_fighter_position(target)
		spawn(amount, DamageNumber.EffectType.ARMOR, pos)


func _on_stun_applied(target: Fighter, duration: float) -> void:
	if duration > 0:
		var pos := _get_fighter_position(target)
		spawn(duration, DamageNumber.EffectType.STUN, pos)


func _on_damage_dodged(_target: Fighter, source: Fighter) -> void:
	# Show MISS on the attacker's side (whose attack missed)
	var pos := _get_fighter_position(source) if source else Vector2.ZERO
	spawn(0, DamageNumber.EffectType.MISS, pos)


func _on_status_damage_dealt(target: Fighter, damage: float, _effect_type: StatusTypes.StatusType) -> void:
	if damage > 0:
		var pos := _get_fighter_position(target)
		spawn(damage, DamageNumber.EffectType.DAMAGE, pos)
