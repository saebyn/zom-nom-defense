extends Node3D
class_name Component_Targeting

enum TargetPreference {
  RANDOM_SURVIVOR,
  NEAREST_THREAT,
  NEAREST_SURVIVOR,
  LOWEST_HEALTH_SURVIVOR,
  NEAREST_BUILDING,
  RECENT_ATTACKER,
  LOWEST_HEALTH_THREAT,
  # Future home for fallback blocker targeting when the preferred target is unreachable.
  BLOCKING_BUILDING,
}

@export var target_preferences: Array[TargetPreference] = [TargetPreference.RANDOM_SURVIVOR]
@export var survivor_group: String = "survivors"
@export var building_group: String = "buildings"
@export var attack: Component_Attack
@export var navigation_agent: NavigationAgent3D
@export var retarget_interval: float = 0.5
@export var reachable_distance_tolerance: float = 1.0

var current_target: Node3D = null
var fallback_building_target: Node3D = null # Used when direct path to target is blocked
var retarget_timer: Timer

var building_attack_range: float:
  get:
    return get_parent().building_attack_range if get_parent() else 0.0

var target_attack_range: float:
  get:
    return get_parent().target_attack_range if get_parent() else 0.0

func _ready() -> void:
  retarget_timer = Timer.new()
  retarget_timer.name = "RetargetTimer"
  retarget_timer.wait_time = retarget_interval
  retarget_timer.timeout.connect(_refresh_target)
  add_child(retarget_timer)

  # Make sure to not await during _ready.
  _actor_setup.call_deferred()

func _actor_setup():
  # Wait for the first physics frame so the NavigationServer can sync.
  await get_tree().physics_frame

  # Now that the navigation map is no longer empty, set the movement target.
  _refresh_target()

  # Check if we need fallback pathfinding
  _check_and_set_fallback_target()

  retarget_timer.start()

func _process(_delta: float) -> void:
  _attack_target()

func _physics_process(_delta: float):
  if navigation_agent.is_navigation_finished():
    # Check if we reached the fallback building or if we need to recheck path
    if fallback_building_target and is_instance_valid(fallback_building_target):
      # We've reached the fallback building, stay here and attack it
      MyLogger.trace("Component_Targeting", "Reached fallback building target.")
    else:
      # Check if we can now reach the main target
      if current_target and is_instance_valid(current_target):
        navigation_agent.set_target_position(current_target.global_position)
        _check_and_set_fallback_target()


func _refresh_target() -> void:
  if _try_refresh_target(true):
    return

  if _try_refresh_target(false):
    return

  _clear_current_target()


func _try_refresh_target(require_reachable: bool) -> bool:
  for target_preference in target_preferences:
    if _current_target_matches_preference(target_preference):
      if not require_reachable or _is_target_reachable(current_target):
        _set_current_target(current_target)
        return true

    var next_target := _find_best_target_for_preference(target_preference, require_reachable)
    if next_target:
      _set_current_target(next_target)
      return true

  return false


func _find_best_target_for_preference(target_preference: TargetPreference, require_reachable: bool) -> Node3D:
  var candidates := _get_candidates_for_preference(target_preference)

  if require_reachable:
    candidates = _filter_reachable(candidates)

  if candidates.is_empty():
    return null

  _rank_candidates_for_preference(candidates, target_preference)
  return candidates[0]


func _get_candidates_for_preference(target_preference: TargetPreference) -> Array[Node3D]:
  match target_preference:
    TargetPreference.RANDOM_SURVIVOR:
      return _get_survivors()
    TargetPreference.NEAREST_THREAT:
      return _get_threats()

  return []


func _filter_reachable(candidates: Array[Node3D]) -> Array[Node3D]:
  var reachable_candidates: Array[Node3D] = []

  for candidate in candidates:
    if _is_target_reachable(candidate):
      reachable_candidates.append(candidate)

  return reachable_candidates


func _rank_candidates_for_preference(candidates: Array[Node3D], target_preference: TargetPreference) -> void:
  match target_preference:
    TargetPreference.RANDOM_SURVIVOR:
      candidates.shuffle()
    TargetPreference.NEAREST_THREAT:
      candidates.sort_custom(_sort_by_distance_to_self)


func _get_survivors() -> Array[Node3D]:
  var targets: Array[Node3D] = []

  for node in get_tree().get_nodes_in_group(survivor_group):
    var target_node := node as Node3D
    if target_node != null and is_instance_valid(target_node):
      targets.append(target_node)

  return targets


func _get_threats() -> Array[Node3D]:
  var targets: Array[Node3D] = []

  for node in get_tree().get_nodes_in_group(building_group):
    var target_node := node as Node3D
    if target_node != null and _target_matches_preference(target_node, TargetPreference.NEAREST_THREAT):
      targets.append(target_node)

  return targets


func _current_target_matches_preference(target_preference: TargetPreference) -> bool:
  return current_target \
    and is_instance_valid(current_target) \
    and _target_matches_preference(current_target, target_preference)


func _target_matches_preference(target: Node3D, target_preference: TargetPreference) -> bool:
  if not target or not is_instance_valid(target):
    return false

  match target_preference:
    TargetPreference.RANDOM_SURVIVOR:
      return target.is_in_group(survivor_group)
    TargetPreference.NEAREST_THREAT:
      var actor := get_parent() as Node3D
      return target.is_in_group(building_group) \
        and actor != null \
        and target.has_method("can_hit_target") \
        and target.can_hit_target(actor)

  return false


func _is_target_reachable(target: Node3D) -> bool:
  if not target or not is_instance_valid(target):
    return false

  var map := navigation_agent.get_navigation_map()
  if NavigationServer3D.map_get_iteration_id(map) == 0:
    return false

  var path := NavigationServer3D.map_get_path(map, global_position, target.global_position, true)
  if path.is_empty():
    return false

  var final_path_position: Vector3 = path[path.size() - 1]
  return final_path_position.distance_to(target.global_position) <= navigation_agent.target_desired_distance + reachable_distance_tolerance


func _set_current_target(target: Node3D) -> void:
  var changed := current_target != target
  current_target = target
  fallback_building_target = null
  navigation_agent.set_target_position(current_target.global_position)

  if changed:
    MyLogger.info("Component_Targeting", "Chose new target: %s" % current_target.name)


func _clear_current_target() -> void:
  if current_target:
    MyLogger.trace("Component_Targeting", "No targets available.")

  current_target = null
  fallback_building_target = null
  attack.cancel()
  # No targets available, stop the agent.
  navigation_agent.set_target_position(global_position)


func _get_attack_range_for_target(target: Node3D) -> float:
  if target and is_instance_valid(target) and target.is_in_group(building_group):
    return building_attack_range

  return target_attack_range


func _sort_by_distance_to_self(a: Node3D, b: Node3D) -> bool:
  var dist_a := global_position.distance_to(a.global_position)
  var dist_b := global_position.distance_to(b.global_position)
  if dist_a < dist_b:
    return true
  else:
    return false

func _find_nearest_building_in_range() -> Node3D:
  var buildings := get_tree().get_nodes_in_group(building_group)
  var nearest_building: Node3D = null
  var nearest_distance: float = building_attack_range + 1.0 # Start beyond max range
  
  for building in buildings:
    if not building or not is_instance_valid(building):
      continue
      
    var distance := global_position.distance_to(building.global_position)
    if distance <= building_attack_range and distance < nearest_distance:
      nearest_distance = distance
      nearest_building = building
  
  return nearest_building


func _find_building_closest_to_target() -> Node3D:
  """Find the building that is closest to the current target.
  This is used as a fallback when the zombie cannot path directly to the target."""
  if not current_target:
    return null
  
  var buildings := get_tree().get_nodes_in_group(building_group)
  if buildings.is_empty():
    return null
  
  var closest_building: Node3D = null
  var closest_distance: float = INF
  
  for building in buildings:
    if not building or not is_instance_valid(building):
      continue
    
    var distance_to_target: float = building.global_position.distance_to(current_target.global_position)
    if distance_to_target < closest_distance:
      closest_distance = distance_to_target
      closest_building = building
  
  return closest_building


func _check_and_set_fallback_target() -> void:
  """Check if the enemy can reach the target. If not, find a building to attack."""
  if not current_target or not is_instance_valid(current_target):
    return
  
  # Wait for navigation to calculate path
  await get_tree().physics_frame
  
  # Check if the path is valid/reachable
  if navigation_agent.is_target_reachable():
    # Path is fine, clear any fallback
    fallback_building_target = null
    MyLogger.trace("Component_Targeting", "Path to target is reachable")
  else:
    # Path is blocked, find building to attack
    MyLogger.info("Component_Targeting", "Cannot reach target, searching for blocking building")
    var blocking_building = _find_building_closest_to_target()
    
    if blocking_building:
      fallback_building_target = blocking_building
      navigation_agent.set_target_position(blocking_building.global_position)
      MyLogger.info("Component_Targeting", "Found blocking building, switching to fallback target")
    else:
      MyLogger.warn("Component_Targeting", "No path to target and no buildings found to attack!")


func _attack_target():
  MyLogger.debug("Component_Targeting", "Attempting to attack target. Current target: %s, Fallback building: %s" % [current_target, fallback_building_target])

  if not current_target or not is_instance_valid(current_target):
    MyLogger.trace("Component_Targeting", "No current target to attack.")
    _refresh_target()
    if not current_target or not is_instance_valid(current_target):
      return
  
  # If we have a fallback building target, prioritize it
  if fallback_building_target and is_instance_valid(fallback_building_target):
    MyLogger.debug("Component_Targeting", "Fallback building target is valid, checking distance to attack.")
    var distance_to_fallback: float = global_position.distance_to(fallback_building_target.global_position)
    
    # Attack the fallback building if in range
    if distance_to_fallback <= building_attack_range:
      MyLogger.debug("Component_Targeting", "Attacking fallback building at distance: %f" % distance_to_fallback)
      attack.perform_attack(fallback_building_target)
      return
  else:
    MyLogger.debug("Component_Targeting", "No valid fallback building target currently set.")
    var destination := current_target.global_position
    if navigation_agent.target_position != destination:
      navigation_agent.set_target_position(destination)
    _check_and_set_fallback_target()

  # Attack primary target if in range (higher priority)
  var distance_to_target: float = global_position.distance_to(current_target.global_position)
  var current_target_attack_range := _get_attack_range_for_target(current_target)
  MyLogger.debug("Component_Targeting", "Distance to primary target: %f. Minimum attack range: %f" % [distance_to_target, current_target_attack_range])
  if distance_to_target <= current_target_attack_range:
      attack.perform_attack(current_target)
      return

  # If no targets in range, check for nearby buildings to attack
  var nearby_building = _find_nearest_building_in_range()
  if nearby_building:
    MyLogger.trace("Component_Targeting", "Attacking nearby building at distance: %f" % global_position.distance_to(nearby_building.global_position))
    attack.perform_attack(nearby_building)
    return
