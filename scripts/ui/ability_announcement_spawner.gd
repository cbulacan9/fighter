class_name AbilityAnnouncementSpawner
extends Node2D

## Spawns ability announcements when PET abilities are activated

@export var announcement_scene: PackedScene

var _player_position: Vector2 = Vector2(360, 600)
var _enemy_position: Vector2 = Vector2(360, 200)


func setup(player_pos: Vector2, enemy_pos: Vector2) -> void:
	_player_position = player_pos
	_enemy_position = enemy_pos


func spawn_player_announcement(ability_name: String, effect_desc: String, color: Color = Color.YELLOW) -> void:
	_spawn_at(_player_position, ability_name, effect_desc, color)


func spawn_enemy_announcement(ability_name: String, effect_desc: String, color: Color = Color.RED) -> void:
	_spawn_at(_enemy_position, ability_name, effect_desc, color)


func _spawn_at(pos: Vector2, ability_name: String, effect_desc: String, color: Color) -> void:
	if not announcement_scene:
		push_warning("AbilityAnnouncementSpawner: No announcement scene set")
		return

	var announcement: AbilityAnnouncement = announcement_scene.instantiate()
	announcement.position = pos - Vector2(150, 40)  # Center the 300x80 announcement
	add_child(announcement)
	announcement.show_announcement(ability_name, effect_desc, color)


## Creates offensive effect description (damage/debuffs applied to enemy)
static func get_offensive_effect_description(pattern: SequencePattern) -> String:
	if not pattern.on_complete_effect:
		return ""

	var effect := pattern.on_complete_effect
	match effect.effect_type:
		EffectData.EffectType.STATUS_APPLY:
			if effect.status_effect:
				var status_data := effect.status_effect as StatusEffectData
				if status_data:
					return _get_status_name(status_data.effect_type)
			return "Status"
		EffectData.EffectType.DAMAGE:
			return "Damage"
		EffectData.EffectType.STUN:
			return "Stun %.1fs" % effect.duration
		EffectData.EffectType.CUSTOM:
			return _format_custom_effect(effect.custom_effect_id)
		_:
			return "Effect"


## Creates self-buff effect description (buffs applied to self)
static func get_self_buff_description(pattern: SequencePattern) -> String:
	if not pattern.self_buff_effect:
		return ""

	var buff := pattern.self_buff_effect
	match buff.effect_type:
		EffectData.EffectType.STATUS_APPLY:
			if buff.status_effect:
				var status_data := buff.status_effect as StatusEffectData
				if status_data:
					return _get_status_name(status_data.effect_type)
			return "Buff"
		EffectData.EffectType.STATUS_REMOVE:
			return "Cleanse"
		EffectData.EffectType.HEAL:
			return "Heal"
		EffectData.EffectType.SHIELD:
			return "Shield"
		EffectData.EffectType.CUSTOM:
			return _format_custom_effect(buff.custom_effect_id)
		_:
			return "Buff"


static func _get_status_name(status_type: int) -> String:
	match status_type:
		StatusTypes.StatusType.BLEED:
			return "Bleed"
		StatusTypes.StatusType.POISON:
			return "Poison"
		StatusTypes.StatusType.ATTACK_UP:
			return "Attack Up"
		StatusTypes.StatusType.EVASION:
			return "Evasion"
		StatusTypes.StatusType.DODGE:
			return "Dodge"
		StatusTypes.StatusType.MANA_BLOCK:
			return "Mana Block"
		StatusTypes.StatusType.ALPHA_COMMAND:
			return "Alpha Command"
		_:
			return "Status"


static func _format_custom_effect(effect_id: String) -> String:
	match effect_id:
		"hawk_tile_replace":
			return "Tile Transform"
		"snake_cleanse_heal":
			return "Heal"
		_:
			return effect_id.capitalize()
