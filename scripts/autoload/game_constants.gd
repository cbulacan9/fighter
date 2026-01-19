extends Node

# Pet System
const PET_MANA_COST: int = 33  # Mana cost to activate pet tiles (allows 3 activations per full bar)

# Animation Timings
const CLEAR_ANIMATION_TIME: float = 0.2
const FALL_ANIMATION_TIME_PER_ROW: float = 0.07
const SPAWN_ANIMATION_TIME: float = 0.15

# Anti-Cascade System
const ANTI_CASCADE_ENABLED: bool = true
const ANTI_CASCADE_MAX_RETRIES: int = 10  # Attempts before allowing cascade
