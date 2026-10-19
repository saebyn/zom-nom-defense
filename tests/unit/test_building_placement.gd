extends GutTest

const WALL_TYPE := preload("res://Config/Buildings/wall.tres")

class TestBuildingPlacement extends Utility_BuildingPlacement:
  func _validate_placement(_target_position: Vector3) -> BuildingPlacementStatus:
    return BuildingPlacementStatus.NONE

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


func test_placed_building_keeps_preview_position_and_rotation() -> void:
  var world := Node3D.new()
  world.position = Vector3(12.0, 0.0, -8.0)
  world.rotation.y = PI / 4.0
  add_child_autofree(world)

  var navigation_region := NavigationRegion3D.new()
  world.add_child(navigation_region)

  var placement := TestBuildingPlacement.new()
  var ground_raycast := RayCast3D.new()
  ground_raycast.name = "GroundDetectionRayCast3D"
  placement.add_child(ground_raycast)
  var building_raycast := RayCast3D.new()
  building_raycast.name = "BuildingDetectionRayCast3D2"
  placement.add_child(building_raycast)
  world.add_child(placement)
  placement.navigation_region = navigation_region
  placement.audio_player = AudioStreamPlayer.new()
  placement.add_child(placement.audio_player)

  var building_type: Resource_BuildingType = WALL_TYPE.duplicate()
  building_type.cost = 1
  CurrencyManager.current_scrap = building_type.cost
  placement._on_building_spawn_requested(building_type)
  placement._preview.global_position = Vector3(3.0, 0.0, -4.0)
  placement._preview.global_rotation = Vector3(0.0, PI / 2.0, 0.0)
  var expected_transform := placement._preview.global_transform

  placement._place_building()

  var placed_building: Entity_PlaceableBuilding
  for child in world.get_children():
    if child is Entity_PlaceableBuilding:
      placed_building = child
      break

  assert_not_null(placed_building, "Placement should add the permanent building to the world")
  if placed_building:
    assert_true(
      placed_building.global_position.is_equal_approx(expected_transform.origin),
      "Placed building should keep the preview's global position"
    )
    assert_true(
      placed_building.global_transform.basis.is_equal_approx(expected_transform.basis),
      "Placed building should keep the preview's global rotation"
    )
