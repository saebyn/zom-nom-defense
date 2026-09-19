extends Node3D

@onready var camera_controller: Main_CameraController = $CameraRig
@onready var camera: Camera3D = $CameraRig/YawPivot/PitchPivot/Camera3D
@onready var ui: MainUI = $UI
@onready var building_placement: Utility_BuildingPlacement = $BuildingPlacement
@onready var navigation_controller: Main_NavigationController = $NavigationController
@onready var hover_controller: Main_HoverController = $HoverController
@onready var player_input_controller: Main_PlayerInputController = $PlayerInputController

var current_scenario: Stage_Scenario = null

func _ready() -> void:
  # Connect to building placement signals for showing all shooting building ranges
  building_placement.placement_mode_entered.connect(_on_placement_mode_entered)
  building_placement.placement_mode_exited.connect(_on_placement_mode_exited)

  # Re-emit enemy_attacked from PlayerInputController so scenarios can connect to it on main
  player_input_controller.enemy_attacked.connect(func(): GameManager.enemy_attacked.emit())

  # Re-emit building_placed from BuildingPlacement so scenarios can connect to it on main
  building_placement.building_placed.connect(func(): GameManager.building_placed.emit())

  # Proxy wave_changed from ScenarioManager as wave_cleared
  ScenarioManager.wave_changed.connect(func(_scenario_id, _wave): GameManager.wave_cleared.emit())

  # When scenarios end, make sure to stop any current dialog.
  # This is here because there's no existing dialog/dialogic manager for this.
  ScenarioManager.scenario_ended.connect(func(_scenario_id): _stop_dialog())

  # Load the appropriate scenario dynamically
  _load_scenario()


func _process(_delta: float) -> void:
  # Check if any enemies are visible to the player for the first time
  if not GameManager.has_enemy_appeared:
    # check to see if any nodes in the enemies group are within the
    # camera's view frustum instead of just checking if they exist at all
    var enemies = get_tree().get_nodes_in_group("enemies")
    for enemy in enemies:
      if enemy is Node3D and camera.is_position_in_frustum(enemy.global_position):
        MyLogger.info("Main", "Enemy appeared in view: %s" % enemy.name)
        GameManager.enemy_appeared.emit()
        break


func _load_scenario() -> void:
  # Get the current scenario from ScenarioManager
  var scenario_id = ScenarioManager.get_current_scenario_id()

  # Check if there's already a scenario loaded (from the editor)
  # Look for any existing child that's a Stage_Scenario
  for child in get_children():
    if child is Stage_Scenario:
      MyLogger.info("Main", "Removing existing scenario: %s" % child.name)
      remove_child(child)
      child.queue_free()

  # Instantiate and add the scenario
  current_scenario = ScenarioManager.instantiate_scenario()
  if not current_scenario:
    MyLogger.error("Main", "Failed to instantiate scenario: %s" % scenario_id)
    return

  add_child(current_scenario)

  # Send the scenario's full world-space AABB to the minimap immediately.
  # This covers all geometry (terrain + spawn surfaces), unlike the nav mesh
  # AABB which only covers the walkable area.
  ui.updated_bounding_box.emit(current_scenario.get_transformed_aabb())

  # Configure the scenario with the UI reference
  current_scenario.ui = ui

  # Configure boundaries based on scenario settings
  _configure_boundaries_from_scenario()

  # Rebake navigation mesh after loading scenario
  navigation_controller.rebake_navigation_mesh()

  # Configure camera max zoom/size from scenario settings
  camera_controller.camera_max_size = current_scenario.camera_max_size

  MyLogger.info("Main", "Scenario loaded successfully: %s" % scenario_id)


func _configure_boundaries_from_scenario() -> void:
  if not current_scenario:
    MyLogger.warn("Main", "Cannot configure boundaries - no scenario loaded")
    return

  # Get boundary values from the scenario
  var min_x = current_scenario.boundary_min_x
  var max_x = current_scenario.boundary_max_x
  var min_z = current_scenario.boundary_min_z
  var max_z = current_scenario.boundary_max_z

  MyLogger.info("Main", "Configuring boundaries from scenario: X[%d, %d] Z[%d, %d]" % [int(min_x), int(max_x), int(min_z), int(max_z)])

  # Update camera boundary constraints
  if camera_controller:
    camera_controller.world_min_x = min_x
    camera_controller.world_max_x = max_x
    camera_controller.world_min_z = min_z
    camera_controller.world_max_z = max_z


func _on_building_spawn_requested(building: Resource_BuildingType) -> void:
  # Forward the signal to the building placement system
  building_placement._on_building_spawn_requested(building)


## Shows range indicators on all shooting buildings when placement mode is entered.
func _on_placement_mode_entered() -> void:
  var shooting_buildings = get_tree().get_nodes_in_group(Entity_RangedBuilding.RANGED_BUILDINGS_GROUP)
  for building in shooting_buildings:
    if building is Entity_RangedBuilding:
      building.show_range_indicator()


## Hides range indicators on all shooting buildings when placement mode is exited.
func _on_placement_mode_exited() -> void:
  var shooting_buildings = get_tree().get_nodes_in_group(Entity_RangedBuilding.RANGED_BUILDINGS_GROUP)
  for building in shooting_buildings:
    if building is Entity_RangedBuilding:
      building.hide_range_indicator(true) # Force hide even if hovered


func _stop_dialog() -> void:
  if Dialogic:
    Dialogic.clear()
