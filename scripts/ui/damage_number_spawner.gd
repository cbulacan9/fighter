class_name DamageNumberSpawner
extends Node2D

@export var number_scene: PackedScene

const POOL_SIZE := 15  # Covers worst-case cascade damage burst
const MAX_POOL_SIZE := 30  # Hard cap to prevent unbounded growth

var _combat_manager: CombatManager
var _player_position: Vector2
var _enemy_position: Vector2
var _pool: Array[DamageNumber] = []
var _pool_index: int = 0  # For round-robin reuse when pool is exhausted


func _ready() -> void:
	# Pre-instantiate damage numbers for the pool
	_initialize_pool()


func _initialize_pool() -> void:
	if not number_scene:
		return

	for i in range(POOL_SIZE):
		var number: DamageNumber = number_scene.instantiate()
		number.visible = false
		add_child(number)
		_pool.append(number)


func _get_from_pool() -> DamageNumber:
	# Try to get an inactive number from the pool
	for number in _pool:
		if not number.visible:
			return number

	# Pool exhausted - create new one only if under max cap
	if _pool.size() < MAX_POOL_SIZE and number_scene:
		var number: DamageNumber = number_scene.instantiate()
		number.visible = false
		add_child(number)
		_pool.append(number)
		return number

	# At max capacity - reuse oldest entry (round-robin)
	if not _pool.is_empty():
		var number := _pool[_pool_index]
		_pool_index = (_pool_index + 1) % _pool.size()
		# Force reset the number even if still animating
		if number._tween:
			number._tween.kill()
		number.visible = false
		number.modulate.a = 1.0
		number.scale = Vector2.ONE
		return number

	return null


func _return_to_pool(number: DamageNumber) -> void:
	number.visible = false
	# Reset position to prevent visual artifacts
	number.position = Vector2.ZERO
	number.modulate.a = 1.0
	number.scale = Vector2.ONE


func setup(combat_manager: CombatManager, player_pos: Vector2, enemy_pos: Vector2) -> void:
	# Disconnect from old combat manager if any
	_disconnect_signals()

	_combat_manager = combat_manager
	_player_position = player_pos
	_enemy_position = enemy_pos

	if combat_manager:
		if not combat_manager.damage_dealt.is_connected(_on_damage_dealt):
			combat_manager.damage_dealt.connect(_on_damage_dealt)
		if not combat_manager.healing_done.is_connected(_on_healing_done):
			combat_manager.healing_done.connect(_on_healing_done)
		if not combat_manager.armor_gained.is_connected(_on_armor_gained):
			combat_manager.armor_gained.connect(_on_armor_gained)
		if not combat_manager.stun_applied.is_connected(_on_stun_applied):
			combat_manager.stun_applied.connect(_on_stun_applied)
		if not combat_manager.damage_dodged.is_connected(_on_damage_dodged):
			combat_manager.damage_dodged.connect(_on_damage_dodged)
		if not combat_manager.status_damage_dealt.is_connected(_on_status_damage_dealt):
			combat_manager.status_damage_dealt.connect(_on_status_damage_dealt)


func _disconnect_signals() -> void:
	if _combat_manager:
		if _combat_manager.damage_dealt.is_connected(_on_damage_dealt):
			_combat_manager.damage_dealt.disconnect(_on_damage_dealt)
		if _combat_manager.healing_done.is_connected(_on_healing_done):
			_combat_manager.healing_done.disconnect(_on_healing_done)
		if _combat_manager.armor_gained.is_connected(_on_armor_gained):
			_combat_manager.armor_gained.disconnect(_on_armor_gained)
		if _combat_manager.stun_applied.is_connected(_on_stun_applied):
			_combat_manager.stun_applied.disconnect(_on_stun_applied)
		if _combat_manager.damage_dodged.is_connected(_on_damage_dodged):
			_combat_manager.damage_dodged.disconnect(_on_damage_dodged)
		if _combat_manager.status_damage_dealt.is_connected(_on_status_damage_dealt):
			_combat_manager.status_damage_dealt.disconnect(_on_status_damage_dealt)


func spawn(value: float, type: DamageNumber.EffectType, world_pos: Vector2) -> void:
	var number := _get_from_pool()
	if not number:
		return

	number.visible = true
	number.setup(value, type, world_pos)
	number.play(_return_to_pool)


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
