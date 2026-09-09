extends CharacterBody3D

const CMP_EPSILON = 0.001

@export var movement_speed: float = 2.0
@export var rotation_speed: float = PI / 3.0 # Radians per second, adjust for faster/slower turning. This is independent of movement speed to ensure the enemy can always turn towards the target effectively.
@export var path_desired_distance: float = 0.5
@export var target_desired_distance: float = 4.0
@export var target_attack_range: float = 2.0
@export var building_attack_range: float = 6.0
@export var scrap_reward: int = 10 ## Scrap awarded when enemy dies (can be 0)
@export var enemy_type: String = "base_enemy" ## Type identifier for stats tracking

@export_group("Animations")
@export var idle_animation: String = "zombie_library/zombie_idle"
@export var run_animation: String = "zombie_library/zombie_running"

var attack: Component_Attack
var health: Component_Health
var damage_numbers: Component_DamageNumbers

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var mesh_instance: MeshInstance3D = $characterMedium

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

func _ready():
  # Find components via metadata
  if has_meta("attack_component"):
    attack = get_meta("attack_component")
  if has_meta("health_component"):
    health = get_meta("health_component")
  if has_meta("damage_numbers_component"):
    damage_numbers = get_meta("damage_numbers_component")
  
  # These values need to be adjusted for the actor's speed
  # and the navigation layout.
  navigation_agent.path_desired_distance = path_desired_distance
  navigation_agent.target_desired_distance = target_desired_distance

  # Sync NavigationAgent3D debug display with the project setting
  navigation_agent.debug_enabled = ProjectSettings.get_setting("zom_nom_defense/debug/show_navigation_paths", false)

  # Connect the death signal from Health component
  if health:
    health.died.connect(_on_died)
    health.damaged.connect(_on_health_damaged)

# Resource_EnemyType
func load_resource(resource: Resource_EnemyType) -> void:
  ready.connect(func() -> void:
    MyLogger.debug("Enemy", "Loading enemy resource: %s" % resource.name)
    # Override properties from resource
    movement_speed = resource.speed
    target_desired_distance = resource.target_desired_distance
    target_attack_range = resource.target_attack_range
    building_attack_range = resource.building_attack_range
    scrap_reward = resource.scrap_reward
    enemy_type = resource.enemy_type

    # Update skin material if specified
    if resource.skin_material and mesh_instance:
      mesh_instance.set_surface_override_material(0, resource.skin_material)

    # Update navigation agent desired distance
    navigation_agent.target_desired_distance = target_desired_distance

    # Update scale
    scale = Vector3.ONE * resource.scale_multiplier

    # Update health
    if health:
      health.hitpoints = resource.hitpoints
      health.max_hitpoints = resource.hitpoints
      health._update_display()

    # Update attack component
    if attack:
      attack.damage_amount = resource.damage_amount
      attack.attack_speed = resource.attack_speed
      attack.damage_source = resource.enemy_type

      if resource.attack_effect:
        attack.attack_effect = resource.attack_effect

  , Object.CONNECT_ONE_SHOT)


func _process(_delta: float) -> void:
  # play animation based on movement speed
  if velocity.length() > 0.1:
    animation_player.play(run_animation)
  else:
    animation_player.play(idle_animation)


func _physics_process(delta: float):
  # Do not query when the map has never synchronized and is empty.
  if NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) == 0:
    MyLogger.debug("Enemy.Navigation", "Navigation map is empty, cannot navigate.")
    return

  _update_navigation(delta)

  move_and_slide()

func _update_navigation(delta: float):
  if navigation_agent.is_navigation_finished():
    velocity = Vector3.ZERO
  else:
    var next_path_position := navigation_agent.get_next_path_position()

    var local_current_look_position := Vector3.MODEL_FRONT

    # Move directly without avoidance
    var direction := global_position.direction_to(next_path_position)
    velocity = direction * movement_speed

    var global_target_look_position := Vector3(next_path_position)
    global_target_look_position.y = global_position.y # Keep the look direction horizontal
    var local_target_look_position := to_local(global_target_look_position)

    # If the target look vector is effectively zero, we are already aligned for this frame.
    if local_target_look_position.length_squared() <= CMP_EPSILON * CMP_EPSILON:
      return

    local_target_look_position = local_target_look_position.normalized()

    var radians_to_target := local_current_look_position.angle_to(local_target_look_position)

    # Avoid division by zero and unnecessary interpolation when already facing the target.
    if radians_to_target <= CMP_EPSILON:
      return
    var elapsed_rotation := rotation_speed * delta
    var rotation_fraction := clampf(elapsed_rotation / radians_to_target, 0, 1)

    var interpolated_look_position := to_global(local_current_look_position.slerp(local_target_look_position, rotation_fraction))

    look_at(interpolated_look_position, Vector3.UP, true)

    
func _on_died(damage_source: String = "unknown"):
  MyLogger.info("Enemy", "Enemy (%s) died from %s, removing from scene" % [enemy_type, damage_source])
  
  # Track the defeat in stats system
  if StatsManager:
    var defeated_by_hand = (damage_source == "player")
    StatsManager.track_enemy_defeated(enemy_type, defeated_by_hand)
  
  # Award scrap if the enemy gives any
  if scrap_reward > 0:
    CurrencyManager.earn_scrap(scrap_reward)
    # Show floating scrap gain feedback via damage numbers component
    if damage_numbers:
        damage_numbers.show_scrap(scrap_reward)
  
  queue_free()


func _on_health_damaged(amount: int, hitpoints: int, damage_source: String = "unknown") -> void:
  MyLogger.debug("Enemy.Combat", "Enemy (%s) took %d damage from %s. Remaining HP: %d" % [enemy_type, amount, damage_source, hitpoints])
