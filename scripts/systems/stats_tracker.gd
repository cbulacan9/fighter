class_name StatsTracker
extends RefCounted


class MatchStats:
	var damage_dealt: int = 0
	var largest_match: int = 0
	var tiles_broken: int = 0
	var healing_done: int = 0
	var damage_blocked: int = 0
	var match_duration: float = 0.0
	var stun_inflicted: float = 0.0
	var longest_chain: int = 0


var _stats: MatchStats
var _match_start_time: float = 0.0


func _init() -> void:
	_stats = MatchStats.new()


func reset() -> void:
	_stats = MatchStats.new()
	_match_start_time = 0.0


func start_match() -> void:
	reset()
	_match_start_time = Time.get_ticks_msec() / 1000.0


func end_match() -> void:
	var current_time := Time.get_ticks_msec() / 1000.0
	_stats.match_duration = current_time - _match_start_time


func record_damage(amount: int) -> void:
	_stats.damage_dealt += amount


func record_armor_used(amount: int) -> void:
	_stats.damage_blocked += amount


func record_match(tile_count: int, chain_depth: int) -> void:
	_stats.tiles_broken += tile_count
	_stats.largest_match = maxi(_stats.largest_match, tile_count)
	_stats.longest_chain = maxi(_stats.longest_chain, chain_depth)


func record_heal(amount: int) -> void:
	_stats.healing_done += amount


func record_stun(duration: float) -> void:
	_stats.stun_inflicted += duration


func record_cascade_result(result: CascadeHandler.CascadeResult) -> void:
	_stats.tiles_broken += result.total_tiles_cleared
	_stats.longest_chain = maxi(_stats.longest_chain, result.chain_count)

	for match_result in result.all_matches:
		_stats.largest_match = maxi(_stats.largest_match, match_result.positions.size())


func get_stats() -> MatchStats:
	return _stats
