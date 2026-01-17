class_name StatusEffectData
extends Resource

@export var effect_id: String
@export var display_name: String
@export var effect_type: StatusTypes.StatusType
@export var icon: Texture2D

# Duration
@export var duration: float = 0.0  # 0 = permanent until removed
@export var tick_interval: float = 1.0  # For DoT effects

# Stacking
@export var max_stacks: int = 99
@export var stack_behavior: StatusTypes.StackBehavior = StatusTypes.StackBehavior.ADDITIVE

# Tick behavior
@export var tick_behavior: StatusTypes.TickBehavior = StatusTypes.TickBehavior.ON_TIME

# Effect values (interpretation depends on effect_type)
@export var base_value: float = 0.0  # Damage per tick, buff %, etc.
@export var value_per_stack: float = 0.0  # Additional value per stack
