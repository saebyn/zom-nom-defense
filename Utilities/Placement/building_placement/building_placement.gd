extends Node3D
class_name Utility_BuildingPlacement

enum BuildingPlacementStatus {
  NONE,
  NO_PLACEABLE_BUILDING,
  OUTSIDE_BORDER,
  BUILDING_COLLISION,
  NO_TERRAIN_SUPPORT,
  INSUFFICIENT_CLEARANCE,
  INSUFFICIENT_FUNDS,
}

signal rebake_navigation_mesh
signal placement_mode_entered ## Emitted when entering building placement mode
signal placement_mode_exited ## Emitted when exiting building placement mode
signal building_placed ## Emitted when a building is successfully placed
signal building_placement_status_changed(status: BuildingPlacementStatus)

@export_group("Placement Settings")
@export var placement_clearance: float = 3.0 ## Minimum distance from other buildings
@export var world_min_x: float = -200.0 # Minimum X boundary
@export var world_max_x: float = 200.0 # Maximum X boundary
@export var world_min_z: float = -200.0 # Minimum Z boundary
@export var world_max_z: float = 200.0 # Maximum Z boundary
@export var valid_placement_material: StandardMaterial3D
@export var invalid_placement_material: StandardMaterial3D

@export_group("Sound Effects")
@export var audio_player: AudioStreamPlayer

@export_group("Raycast Settings")
@export var raycast_length: float = 1000.0 ## Length of the raycast for building placement
@export var raycast_start: Vector3 = Vector3(0, 10, 0) ## Start position offset for the raycast
@export var raycast_down: Vector3 = Vector3(0, -20, 0) ## Direction and length to cast downwards

@export_group("Node References")
@export var navigation_region: NavigationRegion3D
@export var camera: Camera3D

@onready var raycast: RayCast3D = $GroundDetectionRayCast3D
@onready var building_detection_raycast: RayCast3D = $BuildingDetectionRayCast3D2

var busy: bool:
  get:
    return _preview != null

var _place_building_type: Resource_BuildingType = null
var _preview: Node3D = null
var _internal_placement_status: BuildingPlacementStatus = BuildingPlacementStatus.NONE
var _last_placement_status: BuildingPlacementStatus:
  set(value):
    if _internal_placement_status != value:
      _internal_placement_status = value
      building_placement_status_changed.emit(value)
  get:
    return _internal_placement_status


func _process(_delta: float) -> void:
  if _preview:
    if Input.is_action_just_pressed("place_cancel"):
      # Handle building placement cancellation
      _cancel_building_placement()
    elif Input.is_action_just_pressed("place_building"):
      # Handle building placement confirmation
      _place_building()
    elif Input.is_action_just_pressed("place_rotate_left"):
      # Rotate the building left
      _preview.rotate_y(-PI / 2) # Rotate left by 90 degrees
    elif Input.is_action_just_pressed("place_rotate_right"):
      # Rotate the building right
      _preview.rotate_y(PI / 2) # Rotate right by 90 degrees


func _physics_process(_delta: float) -> void:
  if _preview and raycast.is_colliding():
    var collision_point = raycast.get_collision_point()
    
    # Position preview at collision point
    # This assumes that all buildings' models are centered such that their base is at y=0
    _preview.global_position = collision_point
    
    # Update visual feedback based on placement validity
    _update_visual_feedback(collision_point)

func _input(event: InputEvent) -> void:
  if event is InputEventMouseMotion and busy:
    _project_placed_building(event.position)


func _validate_placement(target_position: Vector3) -> BuildingPlacementStatus:
  if not _preview:
    MyLogger.debug("Placement", "Invalid placement - No placeable building selected")
    return BuildingPlacementStatus.NO_PLACEABLE_BUILDING

  if not _is_within_border(target_position):
    MyLogger.debug("Placement", " Invalid placement - Outside world boundaries")
    return BuildingPlacementStatus.OUTSIDE_BORDER
  
  if _has_building_collision(target_position):
    MyLogger.debug("Placement", "Invalid placement - Collision with existing building")
    return BuildingPlacementStatus.BUILDING_COLLISION
  
  if not _has_terrain_support(target_position):
    MyLogger.debug("Placement", "Invalid placement - Invalid terrain support")
    return BuildingPlacementStatus.NO_TERRAIN_SUPPORT
  
  if not _has_sufficient_clearance(target_position):
    MyLogger.debug("Placement", "Invalid placement - Insufficient clearance")
    return BuildingPlacementStatus.INSUFFICIENT_CLEARANCE

  if CurrencyManager.get_scrap() < _place_building_type.cost:
    MyLogger.debug("Placement", "Invalid placement - Insufficient funds")
    return BuildingPlacementStatus.INSUFFICIENT_FUNDS
  
  return BuildingPlacementStatus.NONE


func _is_within_border(target_position: Vector3) -> bool:
  return target_position.x >= world_min_x and target_position.x <= world_max_x and target_position.z >= world_min_z and target_position.z <= world_max_z

func _has_building_collision(target_position: Vector3) -> bool:
  if not _preview:
    return false
  
  # Set up raycast to check for existing buildings
  building_detection_raycast.enabled = true
  building_detection_raycast.global_position = target_position + raycast_start # Start from above
  building_detection_raycast.target_position = raycast_down # Cast downward
  
  # Force raycast update
  building_detection_raycast.force_raycast_update()
  
  var has_collision = building_detection_raycast.is_colliding()
  if has_collision:
    var collider = building_detection_raycast.get_collider()
    if collider:
      building_detection_raycast.enabled = false
      return true
  
  building_detection_raycast.enabled = false
  return false

func _has_terrain_support(_position: Vector3) -> bool:
  # Use the main raycast to check if we're hitting valid ground
  if not raycast.is_colliding():
    return false
  
  var collider = raycast.get_collider()
  if not collider:
    return false
  
  # Check if we're hitting the ground/terrain (collision layer 16/17)
  var collision_layer = 0
  if collider.has_method("get_collision_layer"):
    collision_layer = collider.get_collision_layer()
  
  # Should be hitting ground (layer 17 = 16 + 1)
  return (collision_layer & 16) != 0

func _has_sufficient_clearance(target_position: Vector3) -> bool:
  # Check for clearance around the building position
  var space_state = get_world_3d().direct_space_state
  var query = PhysicsShapeQueryParameters3D.new()
  
  # Create a sphere to check clearance
  var sphere = SphereShape3D.new()
  sphere.radius = placement_clearance
  query.shape = sphere
  query.transform.origin = target_position
  query.collision_mask = 2 # Check for buildings

  return space_state.intersect_shape(query).size() == 0

func _on_building_spawn_requested(building_type: Resource_BuildingType) -> void:
  MyLogger.info("Placement", "Spawn building button pressed for: %s" % building_type.name)

  if busy:
    MyLogger.info("Placement", "Already placing a building, cancelling previous placement")
    _cancel_building_placement()

  _place_building_type = building_type
  _preview = building_type.preview.instantiate()
  MyLogger.info("Placement", "Created preview for building: %s" % building_type.name)
  raycast.enabled = true
  add_child(_preview)
  placement_mode_entered.emit()

func _place_building() -> void:
  if not _preview:
    return
  
  # Check if placement is valid
  if _validate_placement(_preview.global_position) != BuildingPlacementStatus.NONE:
    return

  # Deduct cost
  if not CurrencyManager.spend_scrap(_place_building_type.cost):
    # This should not happen due to prior validation, but just in case
    MyLogger.error("Placement", "Cannot place building: Insufficient funds")
    return
  
  var building := _place_building_type.scene.instantiate()
  assert(building is Entity_PlaceableBuilding, "Instantiated building is not an Entity_PlaceableBuilding")
  assert(get_parent() != null, "BuildingPlacement node has no parent to add the building to")
  get_parent().add_child(building)
  building.global_position = _preview.global_position
  building.global_rotation = _preview.global_rotation
  building.building_type = _place_building_type
  building.place(navigation_region)

  rebake_navigation_mesh.emit()
  building_placed.emit()
  
  # Track building placement in stats system
  if StatsManager and _place_building_type:
    StatsManager.track_building_placed(_place_building_type.id)
  
  _clear_building_placement()

  AudioManager.play_sound(audio_player, Resource_SoundEffect.SoundEffect.BUILDING_COMPLETE)

func _cancel_building_placement() -> void:
  _clear_building_placement()
  AudioManager.play_sound(audio_player, Resource_SoundEffect.SoundEffect.UI_CANCEL)

func _clear_building_placement() -> void:
  if _preview:
    _preview.queue_free()
    _preview = null
  _place_building_type = null
  raycast.enabled = false
  placement_mode_exited.emit()
  _last_placement_status = BuildingPlacementStatus.NONE

func _update_visual_feedback(target_position: Vector3) -> void:
  if not _preview:
    return

  # Only update if we have valid materials
  if not valid_placement_material or not invalid_placement_material:
    return

  _last_placement_status = _validate_placement(target_position)
  var is_valid = _last_placement_status == BuildingPlacementStatus.NONE
  var material = valid_placement_material if is_valid else invalid_placement_material
  
  _set_preview_material(material)

func _project_placed_building(mouse_position: Vector2) -> void:
  var ray_origin = camera.project_ray_origin(mouse_position)
  var ray_direction = camera.project_ray_normal(mouse_position)
  raycast.target_position = ray_direction * raycast_length
  raycast.position = ray_origin

## Sets a material override for all meshes in the placement preview node.
## 
## @param material The Material to apply as an override to all preview mesh surfaces.
func _set_preview_material(material: Material) -> void:
  if _preview == null:
    MyLogger.warn("Placement", "Cannot set preview material - no preview node available")
    return

  for node in _preview.find_children("*", "MeshInstance3D"):
    if node is MeshInstance3D and node.mesh != null:
      var surface_count = node.mesh.get_surface_count()
      for i in range(surface_count):
        node.set_surface_override_material(i, material)
