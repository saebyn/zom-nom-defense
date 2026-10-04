extends Node
class_name Main_Debug

@export var enemy_type: Resource_EnemyType
@export var camera: Camera3D
@export var raycast_length: float = 1000.0

var raycast: RayCast3D

func _ready() -> void:
  raycast = RayCast3D.new()
  raycast.enabled = ProjectSettings.get_setting("zom_nom_defense/debug/enable_tools")
  raycast.set_collision_mask_value(5, true)
  add_child(raycast)

func _input(event: InputEvent) -> void:
  if not ProjectSettings.get_setting("zom_nom_defense/debug/enable_tools"):
    return

  if event is InputEventKey and event.pressed:
    match event.keycode:
      Key.KEY_Z:
        # get cursor position in world
        var placement_position = _project_to_ground(get_viewport().get_mouse_position())

        # get node of current scenario
        var scenario_node = get_parent().current_scenario

        var enemy = enemy_type.scene.instantiate()
        enemy.load_resource(enemy_type)
        scenario_node.add_child(enemy)
        enemy.global_position = placement_position


func _project_to_ground(mouse_position: Vector2):
  var ray_origin = camera.project_ray_origin(mouse_position)
  var ray_direction = camera.project_ray_normal(mouse_position)
  raycast.target_position = ray_direction * raycast_length
  raycast.position = ray_origin
  raycast.force_raycast_update()
  if raycast.is_colliding():
    var collision_point = raycast.get_collision_point()
    MyLogger.info("Main_Debug", "Projected point on ground: %s" % collision_point)
    return collision_point
  else:
    MyLogger.warning("Main_Debug", "Raycast did not hit anything")
    return null
