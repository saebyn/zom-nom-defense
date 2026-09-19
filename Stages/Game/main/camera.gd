class_name Main_CameraController
extends Node3D

@export var camera: Camera3D
@export var yaw_pivot: Node3D

@export var camera_move_speed: float = 5.0
@export var camera_zoom_speed: float = 50.0
@export var camera_zoom_step: float = 2.0
@export var camera_zoom_fast_multiplier: float = 3.0
@export var camera_min_size: float = 5.0
@export var camera_max_size: float = 100.0
@export var camera_zoom_duration: float = 0.2

@export_group("Mouse Controls")
@export var enable_middle_mouse_drag: bool = true
@export var mouse_drag_speed: float = 0.5
@export var enable_edge_scroll: bool = true
@export var edge_scroll_margin: float = 20.0
@export var edge_scroll_speed: float = 30.0

@export_group("Camera Boundaries")
@export var enable_boundaries: bool = true
@export var world_min_x: float = -200.0
@export var world_max_x: float = 200.0
@export var world_min_z: float = -200.0
@export var world_max_z: float = 200.0

@export_group("Zoom Presets")
@export var survivor_zoom_size: float = 15.0
@export var zoom_preset_duration: float = 0.5

var zoom_tween: Tween
var move_tween: Tween
var input_enabled: bool = true

var _is_middle_mouse_pressed: bool = false
var _last_mouse_position: Vector2 = Vector2.ZERO


func _ready() -> void:
  if not camera or not yaw_pivot:
    MyLogger.error("Camera", "Camera controller requires a camera and yaw pivot")
    set_process(false)
    set_process_input(false)
    return

  if get_tree().get_nodes_in_group("main_camera").size() > 0:
    MyLogger.warn("Camera", "Another node is already in the 'main_camera' group; only one should be active at a time.")
  camera.add_to_group("main_camera")

  input_enabled = GameManager.current_state == GameManager.GameState.PLAYING
  GameManager.game_state_changed.connect(_on_game_state_changed)


func _input(event: InputEvent) -> void:
  if not input_enabled:
    return

  if enable_middle_mouse_drag and event is InputEventMouseButton:
    if event.button_index == MOUSE_BUTTON_MIDDLE:
      if event.pressed:
        _is_middle_mouse_pressed = true
        _last_mouse_position = event.position
      else:
        _is_middle_mouse_pressed = false

  if enable_middle_mouse_drag and _is_middle_mouse_pressed and event is InputEventMouseMotion:
    var mouse_delta: Vector2 = event.position - _last_mouse_position
    _last_mouse_position = event.position

    # Move opposite the mouse so dragging behaves like grabbing the battlefield.
    # Mouse delta is intentionally not normalized for a natural 1:1 drag feel.
    _move_focus(_convert_screen_to_world_movement(-mouse_delta) * mouse_drag_speed)


func _on_game_state_changed(new_state: GameManager.GameState) -> void:
  input_enabled = new_state == GameManager.GameState.PLAYING


## Convert conventional screen-space movement (right/down) to ground-plane movement.
## The camera's global basis includes all yaw and pitch inherited from its pivots.
func _convert_screen_to_world_movement(screen_movement: Vector2) -> Vector3:
  var camera_right := camera.global_basis.x
  camera_right.y = 0.0
  camera_right = camera_right.normalized()

  var camera_forward := -camera.global_basis.z
  camera_forward.y = 0.0
  camera_forward = camera_forward.normalized()

  # Screen Y increases downward, hence subtracting forward for positive Y.
  return camera_right * screen_movement.x - camera_forward * screen_movement.y


func _process(delta: float) -> void:
  if not input_enabled:
    return

  if enable_edge_scroll:
    var viewport := get_viewport()
    if viewport:
      var viewport_size := viewport.get_visible_rect().size
      var mouse_pos := viewport.get_mouse_position()
      var edge_movement := Vector2.ZERO

      if mouse_pos.x < edge_scroll_margin:
        edge_movement.x = -1.0
      elif mouse_pos.x > viewport_size.x - edge_scroll_margin:
        edge_movement.x = 1.0

      if mouse_pos.y < edge_scroll_margin:
        edge_movement.y = -1.0
      elif mouse_pos.y > viewport_size.y - edge_scroll_margin:
        edge_movement.y = 1.0

      if edge_movement != Vector2.ZERO:
        _move_focus(
          _convert_screen_to_world_movement(edge_movement.normalized())
          * edge_scroll_speed
          * delta
        )

  var input_vector := Input.get_vector(
    "camera_move_left",
    "camera_move_right",
    "camera_move_up",
    "camera_move_down"
  )

  if input_vector != Vector2.ZERO:
    _move_focus(
      _convert_screen_to_world_movement(input_vector.normalized())
      * camera_move_speed
      * delta
    )

  if Input.is_action_just_pressed("camera_rotate_left"):
    yaw_pivot.rotate_y(-PI / 2)

  if Input.is_action_just_pressed("camera_rotate_right"):
    yaw_pivot.rotate_y(PI / 2)

  if Input.is_action_just_pressed("camera_zoom_to_survivors"):
    zoom_to_survivors()

  if Input.is_action_just_pressed("camera_zoom_out_max"):
    zoom_out_max()

  var zoom_in_pressed := Input.is_action_just_pressed("camera_zoom_in") or Input.is_action_just_pressed("camera_zoom_in_key")
  var zoom_out_pressed := Input.is_action_just_pressed("camera_zoom_out") or Input.is_action_just_pressed("camera_zoom_out_key")

  if zoom_in_pressed or zoom_out_pressed:
    var zoom_multiplier := camera_zoom_fast_multiplier if not Input.is_action_pressed("zoom_slow") else 1.0
    var actual_zoom_step := camera_zoom_step * zoom_multiplier
    var target_size := camera.size

    if zoom_in_pressed:
      target_size = max(camera.size - actual_zoom_step, camera_min_size)
    elif zoom_out_pressed:
      target_size = min(camera.size + actual_zoom_step, camera_max_size)

    if target_size != camera.size:
      _animate_zoom(target_size, camera_zoom_duration)


func _move_focus(movement: Vector3) -> void:
  global_position += movement
  if enable_boundaries:
    _apply_boundary_constraints()


func _apply_boundary_constraints() -> void:
  global_position.x = clamp(global_position.x, world_min_x, world_max_x)
  global_position.z = clamp(global_position.z, world_min_z, world_max_z)


func zoom_to_survivors() -> void:
  var survivors := get_tree().get_nodes_in_group("survivors")
  if survivors.is_empty():
    MyLogger.warn("Camera", "No survivors found to zoom to")
    return

  var center := Vector3.ZERO
  var count := 0
  for survivor in survivors:
    if survivor is Node3D:
      center += survivor.global_position
      count += 1

  if count == 0:
    MyLogger.warn("Camera", "No valid Node3D survivors found to zoom to")
    return

  center /= count
  center.y = 0.0

  _animate_to_ground_position(center, survivor_zoom_size)
  MyLogger.info("Camera", "Zooming to survivors at position: %s" % str(center))


func zoom_out_max() -> void:
  _animate_zoom(camera_max_size, zoom_preset_duration)
  MyLogger.info("Camera", "Zooming out to max size: %s" % str(camera_max_size))


func _animate_to_ground_position(ground_target: Vector3, target_zoom: float) -> void:
  if enable_boundaries:
    ground_target.x = clamp(ground_target.x, world_min_x, world_max_x)
    ground_target.z = clamp(ground_target.z, world_min_z, world_max_z)

  if move_tween:
    move_tween.kill()

  move_tween = create_tween()
  move_tween.set_ease(Tween.EASE_IN_OUT)
  move_tween.set_trans(Tween.TRANS_QUAD)
  move_tween.tween_property(self, "global_position", ground_target, zoom_preset_duration)

  _animate_zoom(target_zoom, zoom_preset_duration)


func _animate_zoom(target_zoom: float, duration: float) -> void:
  target_zoom = clamp(target_zoom, camera_min_size, camera_max_size)

  if zoom_tween:
    zoom_tween.kill()

  zoom_tween = create_tween()
  zoom_tween.set_ease(Tween.EASE_IN_OUT)
  zoom_tween.set_trans(Tween.TRANS_QUAD)
  zoom_tween.tween_property(camera, "size", target_zoom, duration)
