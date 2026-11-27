extends GutTest

const WALL_TYPE := preload("res://Config/Buildings/wall.tres")
const PLACEMENT_SCENE := preload("res://Utilities/Placement/building_placement/building_placement.tscn")

var _initial_scrap: int
var _initial_buildings_placed_total: int
var _initial_buildings_placed_by_type: Dictionary


func before_each() -> void:
  _initial_scrap = CurrencyManager.current_scrap
  _initial_buildings_placed_total = StatsManager.buildings_placed_total
  _initial_buildings_placed_by_type = StatsManager.buildings_placed_by_type.duplicate()


func after_each() -> void:
  CurrencyManager.current_scrap = _initial_scrap
  StatsManager.buildings_placed_total = _initial_buildings_placed_total
  StatsManager.buildings_placed_by_type = _initial_buildings_placed_by_type


func test_first_rebake_reopens_the_building_footprint(
  action = use_parameters(["right-click", "lethal damage"])
) -> void:
  var viewport := SubViewport.new()
  viewport.size = Vector2i(640, 480)
  viewport.own_world_3d = true
  add_child_autofree(viewport)
  var world := Node3D.new()
  viewport.add_child(world)

  var camera := Camera3D.new()
  camera.position.y = 10.0
  camera.rotation.x = -PI / 2.0
  world.add_child(camera)
  camera.make_current()
  _add_floor(world)

  var region := NavigationRegion3D.new()
  region.navigation_mesh = NavigationMesh.new()
  region.navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
  region.navigation_mesh.geometry_collision_mask = 48 # Terrain and Building bake layers.
  region.navigation_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
  world.add_child(region)
  NavigationServer3D.map_set_use_async_iterations(region.get_navigation_map(), false)

  var navigation := Main_NavigationController.new()
  navigation.navigation_region = region
  navigation.navigation_rebake_interval = 60.0
  world.add_child(navigation)

  var placement: Utility_BuildingPlacement = PLACEMENT_SCENE.instantiate()
  placement.navigation_region = region
  placement.camera = camera
  placement.audio_player = AudioStreamPlayer.new()
  placement.add_child(placement.audio_player)
  world.add_child(placement)
  placement.rebake_navigation_mesh.connect(navigation.rebake_navigation_mesh)

  var player_input := Main_PlayerInputController.new()
  player_input.building_placement = placement
  player_input.camera = camera
  world.add_child(player_input)

  var footprint := Vector3(0.5, 0.0, 0.0)
  var click_position := camera.unproject_position(footprint)
  CurrencyManager.current_scrap = WALL_TYPE.cost
  placement._on_building_spawn_requested(WALL_TYPE)
  var motion := InputEventMouseMotion.new()
  motion.position = click_position
  viewport.push_input(motion, true)
  await wait_physics_frames(3)
  placement._place_building()
  var placement_baked: bool = await wait_for_signal(region.bake_finished, 2.0)
  assert_true(placement_baked, "Placement should trigger a bake")
  if not placement_baked:
    return
  await wait_physics_frames(3)
  assert_gt(_horizontal_gap(region, footprint), 0.5, "The placed Building should block its footprint")

  var building: Entity_PlaceableBuilding
  for child in world.get_children():
    if child is Entity_PlaceableBuilding:
      building = child
      break
  assert_not_null(building, "Placement should create a Building")
  if not building:
    return

  if action == "right-click":
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_RIGHT
    click.position = click_position
    click.pressed = true
    viewport.push_input(click, true)
  else:
    building.health.take_damage(building.health.hitpoints)

  var removal_baked: bool = await wait_for_signal(region.bake_finished, 2.0)
  assert_false(is_instance_valid(building), "The Building should leave the scene")
  assert_true(removal_baked, "Removal should trigger a bake without waiting for the periodic timer")
  if not removal_baked:
    return
  await wait_physics_frames(3)
  assert_lt(_horizontal_gap(region, footprint), 0.1, "The first bake should reopen the Building's footprint")


func _add_floor(world: Node3D) -> void:
  var floor_body := StaticBody3D.new()
  floor_body.collision_layer = 16
  floor_body.position.y = -0.05
  floor_body.add_to_group("navigation_mesh_source_group")
  var floor_collision := CollisionShape3D.new()
  var floor_shape := BoxShape3D.new()
  floor_shape.size = Vector3(20.0, 0.1, 20.0)
  floor_collision.shape = floor_shape
  floor_body.add_child(floor_collision)
  world.add_child(floor_body)


func _horizontal_gap(region: NavigationRegion3D, position: Vector3) -> float:
  var closest := NavigationServer3D.map_get_closest_point(region.get_navigation_map(), position)
  return Vector2(closest.x - position.x, closest.z - position.z).length()
