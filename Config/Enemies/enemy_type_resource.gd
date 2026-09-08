class_name Resource_EnemyType
extends Resource

@export_category("Basic Properties")
@export var name: String = "New Enemy Type" ## Human readable name of the enemy type
@export var enemy_type: String = "" ## Unique identifier for the enemy type for stats tracking
@export var description: String = "Description of the enemy type." ## Description of the enemy
@export var scene: PackedScene ## Scene representing the enemy type.

@export_category("Gameplay Properties")
@export var scale_multiplier: float = 1.0 ## Scale multiplier for the enemy
@export var hitpoints: int = 100 ## Health of the enemy
@export var speed: float = 2.0 ## Movement speed of the enemy
@export var damage_amount: float = 10.0 ## Damage dealt by the enemy
@export var attack_speed: float = 1.0 ## Cooldown between enemy attacks
@export var scrap_reward: int = 10 ## Scrap awarded when enemy dies
@export var target_desired_distance: float = 4.0 ## Desired distance to target when approaching (navigation stopping distance)
@export var target_attack_range: float = 4.0 ## Range at which the enemy will attack the primary target
@export var building_attack_range: float = 6.0 ## Range at which the enemy will start attacking buildings instead of the survivor (if they are closer than the survivor)
@export var attack_effect: Resource_AttackEffect = null ## Attack effect resource for additional properties

@export_category("Visual Properties")
@export var skin_material: Material ## Material used for the enemy's skin
