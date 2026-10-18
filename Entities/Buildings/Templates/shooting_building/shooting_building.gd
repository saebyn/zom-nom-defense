class_name Entity_ShootingBuilding
extends Entity_RangedBuilding

@export var enemy_group: String = "enemies"
@export var detection_interval: float = 0.5

## The currently tracked target enemy, updated by detection timer
var current_target: Node3D = null
## Whether the building is ready to attack (e.g., turret is aimed at target)
var ready_to_attack: bool = true
## Whether the current target is within attack range (updated by detection logic)
var can_attack_current_target: bool = false
var attack: Component_Attack

@onready var detection_timer: Timer = $DetectionTimer

func _ready():
  # Call parent _ready first
  super._ready()
  
  # Find Attack component via metadata
  if has_meta("attack_component"):
    attack = get_meta("attack_component")
  
  # Set damage source for building attacks
  if attack:
    attack.damage_source = "building"

  # Set up detection timer
  _setup_detection_timer()


func can_hit_target(target: Node3D, max_distance: float = INF) -> bool:
  if not target or not is_instance_valid(target):
    return false
  var distance := global_position.distance_to(target.global_position)

  if distance > max_distance:
    return false

  return distance <= effect_range

func place(navigation_region: NavigationRegion3D) -> void:
  super.place(navigation_region)
  _setup_detection_timer()


func _setup_detection_timer() -> void:
  if not detection_timer:
    return
  detection_timer.wait_time = detection_interval
  if not detection_timer.timeout.is_connected(_detect_and_attack_enemies):
    detection_timer.timeout.connect(_detect_and_attack_enemies)
  if detection_timer.is_stopped():
    detection_timer.start()


func _detect_and_attack_enemies():
  var result = _find_nearest_enemy_in_range()
  current_target = result[0]
  can_attack_current_target = result[1]
  if current_target and can_attack_current_target and ready_to_attack:
    MyLogger.debug("ShootingBuilding", "Attacking enemy at distance: %f" % global_position.distance_to(current_target.global_position))
    attack.perform_attack(current_target)

func _find_nearest_enemy_in_range() -> Array:
  var enemies := get_tree().get_nodes_in_group(enemy_group)
  var nearest_enemy: Node3D = null
  var nearest_distance: float = INF
  var can_attack := false
  
  for enemy in enemies:
    if can_hit_target(enemy, nearest_distance):
      nearest_distance = global_position.distance_to(enemy.global_position)
      nearest_enemy = enemy
      can_attack = true
  
  return [nearest_enemy, can_attack]

func _on_died(damage_source: String = "unknown") -> void:
  MyLogger.info("ShootingBuilding", "Shooting building destroyed by: %s" % damage_source)
  # Stop detection timer before destruction
  if detection_timer:
    detection_timer.stop()
  queue_free()


func _handle_buffs(buff_type: Entity_BuffBuilding.BuffType, amounts: Array[float]) -> void:
  match buff_type:
    Entity_BuffBuilding.BuffType.ATTACK_SPEED:
      if attack:
        attack.attack_speed = _stack_buffs(buff_type, attack.attack_speed, amounts)
    Entity_BuffBuilding.BuffType.DAMAGE:
      if attack:
        attack.damage_amount = _stack_buffs(buff_type, attack.damage_amount, amounts)
    _:
      super._handle_buffs(buff_type, amounts)

## Override to add shooting-specific stats
func get_tooltip_info() -> Dictionary:
  var info = super.get_tooltip_info()
  
  if attack:
    # Attack speed
    var base_speed = _original_values.get(Entity_BuffBuilding.BuffType.ATTACK_SPEED, attack.attack_speed)
    info.base_stats["attack_speed"] = base_speed
    info.current_stats["attack_speed"] = attack.attack_speed
    
    # Damage
    var base_damage = _original_values.get(Entity_BuffBuilding.BuffType.DAMAGE, attack.damage_amount)
    info.base_stats["damage"] = base_damage
    info.current_stats["damage"] = attack.damage_amount
  
  return info
