extends Node
class_name Main_PlayerInputController

## PlayerInputController
##
## Manages player mouse input in the game world:
## - Enemy attack on left-click
## - Building removal on right-click
## - Hover state delegation to HoverController
## - Attack cooldown cursor management

signal enemy_attacked ## Emitted when the player clicks to attack an enemy

@export var camera: Camera3D
@export var attack: Component_Attack
@export var building_placement: Utility_BuildingPlacement
@export var hover_controller: Main_HoverController
@export var navigation_controller: Main_NavigationController
@export var ui: MainUI
@export var attack_waiting_cursor_image: Texture2D
@export var raycast_length: float = 1000.0

var _enemy_raycast: RayCast3D
var _building_raycast: RayCast3D


func _ready() -> void:
  # Ensure player attacks are attributed correctly
  if attack:
    attack.damage_source = "player"

  # Create enemy detection raycast
  _enemy_raycast = RayCast3D.new()
  _enemy_raycast.enabled = false
  _enemy_raycast.collision_mask = 4 # Only detect enemies (layer 3: attackable)
  add_child(_enemy_raycast)

  # Create building detection raycast
  _building_raycast = RayCast3D.new()
  _building_raycast.enabled = false
  _building_raycast.collision_mask = 2 # Only detect buildings (layer 2)
  add_child(_building_raycast)

  # Sync tech tree unlocks with attack effects
  for tech_id in TechTreeManager.list_unlocked_techs():
    _on_tech_unlocked(tech_id)

  TechTreeManager.tech_unlocked.connect(_on_tech_unlocked)


func _input(event: InputEvent) -> void:
  if event is InputEventMouseButton and not building_placement.busy and event.pressed:
    if event.button_index == MOUSE_BUTTON_LEFT:
      _handle_enemy_click(event.position)
    elif event.button_index == MOUSE_BUTTON_RIGHT:
      _handle_building_remove_click(event.position)
  elif event is InputEventMouseMotion and not building_placement.busy:
    if hover_controller:
      hover_controller.handle_hover(event.position)


func _handle_enemy_click(click_position: Vector2) -> void:
  # Track every left-click for achievement purposes, regardless of what was hit
  StatsManager.track_click_performed()

  # Create a raycast from the camera to detect what was clicked
  var ray_origin := camera.project_ray_origin(click_position)
  var ray_direction := camera.project_ray_normal(click_position)

  # Use the dedicated enemy raycast
  _enemy_raycast.enabled = true
  _enemy_raycast.position = ray_origin
  _enemy_raycast.target_position = ray_direction * raycast_length

  # Force the raycast to update
  _enemy_raycast.force_raycast_update()

  if _enemy_raycast.is_colliding():
    var collider = _enemy_raycast.get_collider()
    MyLogger.debug("PlayerInput", "Clicked on: %s" % collider.name)

    var result = attack.perform_attack(collider)
    # Only count as an enemy click if the collider is actually an enemy,
    # not other attackable things like scrap pickups.
    # We check the collider's group instead of class to allow for more flexible enemy implementations.
    if collider.is_in_group("enemies"):
      StatsManager.track_enemy_click()
      if result == Component_Attack.AttackResult.SUCCESS:
        enemy_attacked.emit()

  # Disable the enemy raycast after use
  _enemy_raycast.enabled = false


func _handle_building_remove_click(click_position: Vector2) -> void:
  # Create a raycast from the camera to detect what was clicked
  var ray_origin := camera.project_ray_origin(click_position)
  var ray_direction := camera.project_ray_normal(click_position)

  # Use the dedicated building raycast (layer 2 for buildings)
  _building_raycast.enabled = true
  _building_raycast.collision_mask = 2 # Only detect buildings
  _building_raycast.position = ray_origin
  _building_raycast.target_position = ray_direction * raycast_length

  # Force the raycast to update
  _building_raycast.force_raycast_update()

  if _building_raycast.is_colliding():
    var collider = _building_raycast.get_collider()
    MyLogger.info("PlayerInput", "Right-clicked on: %s (type: %s)" % [collider.name, collider.get_class()])

    # Check if the collider is a Entity_PlaceableBuilding
    if collider is Entity_PlaceableBuilding:
      var building := collider as Entity_PlaceableBuilding
      MyLogger.info("PlayerInput", "Confirmed Entity_PlaceableBuilding, calling remove()")

      # Clear hover state before removing to prevent dangling references
      if hover_controller and building is Entity_RangedBuilding:
        hover_controller.clear_hover_for_building(building as Entity_RangedBuilding)
        hover_controller.clear_tooltip_for_building(building as Entity_RangedBuilding)
      if hover_controller:
        hover_controller.clear_hover_for_entity(building)

      var refund := building.remove()
      MyLogger.info("PlayerInput", "Removed building and recovered %d scrap" % refund)

      # Show UI feedback
      if ui and ui.has_method("show_building_removed"):
        ui.show_building_removed(refund)

      # Rebake navigation mesh after removal
      if navigation_controller:
        navigation_controller.rebake_navigation_mesh()
    else:
      MyLogger.info("PlayerInput", "Clicked object is not a removable building")
  else:
    MyLogger.info("PlayerInput", "Right-click raycast did not hit anything")

  # Disable the building raycast after use
  _building_raycast.enabled = false


func _on_attack_cooldown_started(_target: Node) -> void:
  if attack_waiting_cursor_image:
    Input.set_custom_mouse_cursor(attack_waiting_cursor_image)


func _on_attack_cooldown_ended() -> void:
  Input.set_custom_mouse_cursor(null)


func _on_tech_unlocked(tech_id: String) -> void:
  MyLogger.info("PlayerInput", "Tech unlocked: %s - Checking for attack effect" % tech_id)
  var tech_node = TechTreeManager.get_tech_node(tech_id)
  if tech_node == null:
    MyLogger.warning("PlayerInput", "Tech unlocked with unknown tech_id: %s" % tech_id)
    return
  if tech_node.player_attack_effect:
    attack.attack_effect.stack_effect(tech_node.player_attack_effect)
