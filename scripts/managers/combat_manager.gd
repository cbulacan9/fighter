class_name CombatManager
extends Node

signal damage_dealt(target: Fighter, result: Fighter.DamageResult)
signal healing_done(target: Fighter, amount: int)
signal armor_gained(target: Fighter, amount: int)
signal stun_applied(target: Fighter, duration: float)
signal stun_ended(fighter: Fighter)
signal fighter_defeated(fighter: Fighter)
signal match_ended(winner_id: int)

enum MatchResult {
	ONGOING = 0,
	PLAYER_WINS = 1,
	ENEMY_WINS = 2,
	DRAW = 3
}

var player_fighter: Fighter
var enemy_fighter: Fighter

var _tile_data_cache: Dictionary = {}
var _player_was_stunned: bool = false
var _enemy_was_stunned: bool = false


func _ready() -> void:
	_load_tile_data()


func initialize(player_data: FighterData, enemy_data: FighterData) -> void:
	if not player_fighter:
		player_fighter = Fighter.new()
		add_child(player_fighter)

	if not enemy_fighter:
		enemy_fighter = Fighter.new()
		add_child(enemy_fighter)

	player_fighter.initialize(player_data)
	enemy_fighter.initialize(enemy_data)

	player_fighter.defeated.connect(_on_fighter_defeated.bind(player_fighter))
	enemy_fighter.defeated.connect(_on_fighter_defeated.bind(enemy_fighter))

	_player_was_stunned = false
	_enemy_was_stunned = false


func process_cascade_result(source_is_player: bool, result: CascadeHandler.CascadeResult) -> void:
	var source := get_fighter(source_is_player)

	for match_result in result.all_matches:
		apply_match_effect(source, match_result)

	var victory := check_victory()
	if victory != MatchResult.ONGOING:
		match_ended.emit(victory)


func apply_match_effect(source: Fighter, match_result: MatchDetector.MatchResult) -> void:
	var effect_value := _get_effect_value(match_result.tile_type, match_result.count)
	var target: Fighter

	match match_result.tile_type:
		TileTypes.Type.SWORD:
			target = get_opponent(source)
			var result := target.take_damage(effect_value)
			damage_dealt.emit(target, result)

		TileTypes.Type.SHIELD:
			var actual := source.add_armor(effect_value)
			armor_gained.emit(source, actual)

		TileTypes.Type.POTION:
			var actual := source.heal(effect_value)
			healing_done.emit(source, actual)

		TileTypes.Type.LIGHTNING:
			target = get_opponent(source)
			var actual := target.apply_stun(float(effect_value))
			stun_applied.emit(target, actual)

		TileTypes.Type.FILLER:
			pass  # No combat effect


func get_fighter(is_player: bool) -> Fighter:
	return player_fighter if is_player else enemy_fighter


func get_opponent(fighter: Fighter) -> Fighter:
	if fighter == player_fighter:
		return enemy_fighter
	return player_fighter


func tick(delta: float) -> void:
	if player_fighter:
		var was_stunned := player_fighter.is_stunned()
		player_fighter.tick_stun(delta)
		if _player_was_stunned and not player_fighter.is_stunned():
			stun_ended.emit(player_fighter)
		_player_was_stunned = player_fighter.is_stunned()

	if enemy_fighter:
		var was_stunned := enemy_fighter.is_stunned()
		enemy_fighter.tick_stun(delta)
		if _enemy_was_stunned and not enemy_fighter.is_stunned():
			stun_ended.emit(enemy_fighter)
		_enemy_was_stunned = enemy_fighter.is_stunned()


func check_victory() -> int:
	if not player_fighter or not enemy_fighter:
		return MatchResult.ONGOING

	var player_dead := player_fighter.is_defeated
	var enemy_dead := enemy_fighter.is_defeated

	if player_dead and enemy_dead:
		return MatchResult.DRAW
	elif enemy_dead:
		return MatchResult.PLAYER_WINS
	elif player_dead:
		return MatchResult.ENEMY_WINS

	return MatchResult.ONGOING


func reset() -> void:
	if player_fighter:
		player_fighter.reset()
	if enemy_fighter:
		enemy_fighter.reset()

	_player_was_stunned = false
	_enemy_was_stunned = false


func _on_fighter_defeated(fighter: Fighter) -> void:
	fighter_defeated.emit(fighter)


func _load_tile_data() -> void:
	_tile_data_cache[TileTypes.Type.SWORD] = preload("res://resources/tiles/sword.tres")
	_tile_data_cache[TileTypes.Type.SHIELD] = preload("res://resources/tiles/shield.tres")
	_tile_data_cache[TileTypes.Type.POTION] = preload("res://resources/tiles/potion.tres")
	_tile_data_cache[TileTypes.Type.LIGHTNING] = preload("res://resources/tiles/lightning.tres")
	_tile_data_cache[TileTypes.Type.FILLER] = preload("res://resources/tiles/filler.tres")


func _get_effect_value(tile_type: TileTypes.Type, count: int) -> int:
	if _tile_data_cache.has(tile_type):
		var tile_data: PuzzleTileData = _tile_data_cache[tile_type]
		return tile_data.get_value(count)
	return 0
