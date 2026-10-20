extends Control
class_name UI_UnitFrameLayout

@export var camera: Camera3D
@export var camera_focus: Node3D

@export_group("Selection")
@export_range(1, 100, 1) var max_visible_frames: int = 10
@export_range(0.01, 1.0, 0.01) var selection_interval: float = 0.1

@export_group("Layout")
@export_range(0.0, 32.0, 1.0) var collision_padding: float = 6.0
@export_range(1, 32, 1) var collision_iterations: int = 24
@export_range(0.0, 1.0, 0.01) var anchor_pull: float = 0.08
@export_range(0.0, 500.0, 1.0) var max_displacement: float = 160.0
@export_range(0.0, 64.0, 1.0) var viewport_margin: float = 8.0

@export_group("Leader Lines")
@export_range(0.0, 100.0, 1.0) var leader_line_threshold: float = 10.0
@export_range(0.5, 8.0, 0.5) var leader_line_width: float = 1.5
@export var leader_line_color: Color = Color(0.922, 0.843, 0.702, 0.65)

var _selection_elapsed: float = 0.0
var _selected_frames: Array[Component_Health] = []
var _current_offsets: Dictionary = {}
var _line_segments: Array[PackedVector2Array] = []


func _enter_tree() -> void:
  add_to_group(Component_Health.UNIT_FRAME_LAYOUT_MANAGER_GROUP)


func _ready() -> void:
  mouse_filter = Control.MOUSE_FILTER_IGNORE
  _refresh_selection()


func _process(delta: float) -> void:
  if not camera or not camera_focus:
    return

  _selection_elapsed += delta
  if _selection_elapsed >= selection_interval:
    _selection_elapsed = 0.0
    _refresh_selection()

  _update_layout(delta)


func _draw() -> void:
  for segment in _line_segments:
    draw_line(segment[0], segment[1], leader_line_color, leader_line_width, true)


func _exit_tree() -> void:
  var tree := get_tree()
  if not tree:
    return

  for node in tree.get_nodes_in_group(Component_Health.UNIT_FRAME_GROUP):
    if node is Component_Health:
      node.set_unit_frame_layout_allowed(true)
      node.sprite.offset = Vector2.ZERO


func register_unit_frame(frame: Component_Health) -> void:
  if not camera or not camera_focus:
    return

  frame.set_unit_frame_layout_allowed(false)
  _selection_elapsed = selection_interval


func _refresh_selection() -> void:
  if not camera or not camera_focus or not is_inside_tree():
    return

  var all_frames: Array[Component_Health] = []
  var candidates: Array[Component_Health] = []
  var live_frame_ids: Dictionary = {}
  for node in get_tree().get_nodes_in_group(Component_Health.UNIT_FRAME_GROUP):
    if not node is Component_Health or not is_instance_valid(node):
      continue

    var frame := node as Component_Health
    all_frames.append(frame)
    live_frame_ids[frame.get_instance_id()] = true
    if frame.is_unit_frame_requested() and _is_frame_on_screen(frame):
      candidates.append(frame)

  var selected := _select_candidates(candidates, camera_focus.global_position)
  var next_selected_ids: Dictionary = {}
  _selected_frames.clear()

  for frame in selected:
    _selected_frames.append(frame)
    next_selected_ids[frame.get_instance_id()] = true

  for frame in all_frames:
    var frame_id := frame.get_instance_id()
    var is_selected := next_selected_ids.has(frame_id)
    frame.set_unit_frame_layout_allowed(is_selected)
    if not is_selected:
      frame.sprite.offset = Vector2.ZERO
      _current_offsets.erase(frame_id)

  for frame_id in _current_offsets.keys():
    if not live_frame_ids.has(frame_id):
      _current_offsets.erase(frame_id)


func _select_candidates(
  candidates: Array[Component_Health],
  focus_position: Vector3
) -> Array[Component_Health]:
  var ranked := _rank_candidates(candidates, focus_position)
  ranked.resize(mini(max_visible_frames, ranked.size()))
  return ranked


func _rank_candidates(
  candidates: Array[Component_Health],
  focus_position: Vector3
) -> Array[Component_Health]:
  var ranked := candidates.duplicate()
  ranked.sort_custom(func(a: Component_Health, b: Component_Health) -> bool:
    var a_urgent := a.is_unit_frame_urgent()
    var b_urgent := b.is_unit_frame_urgent()
    if a_urgent != b_urgent:
      return a_urgent

    var a_distance := _focus_distance_squared(a, focus_position)
    var b_distance := _focus_distance_squared(b, focus_position)
    if a_distance != b_distance:
      return a_distance < b_distance
    return a.get_instance_id() < b.get_instance_id()
  )
  return ranked


func _focus_distance_squared(frame: Component_Health, focus_position: Vector3) -> float:
  var entity := frame.get_parent() as Node3D
  if not entity:
    return INF

  var delta := Vector2(
    entity.global_position.x - focus_position.x,
    entity.global_position.z - focus_position.z
  )
  return delta.length_squared()


func _is_frame_on_screen(frame: Component_Health) -> bool:
  var anchor: Vector3 = frame.sprite.global_position
  if camera.is_position_behind(anchor):
    return false

  var card_size: Vector2 = _get_card_screen_size(frame)
  var card_rect := Rect2(camera.unproject_position(anchor) - card_size * 0.5, card_size)
  return card_rect.intersects(get_viewport().get_visible_rect(), true)


func _update_layout(_delta: float) -> void:
  var frames: Array[Component_Health] = []
  var desired_centers: Array[Vector2] = []
  var card_sizes: Array[Vector2] = []
  var current_centers: Array[Vector2] = []

  for frame in _selected_frames:
    if not is_instance_valid(frame) or not frame.sprite.visible:
      continue
    frames.append(frame)
    var desired_center := camera.unproject_position(frame.sprite.global_position)
    desired_centers.append(desired_center)
    card_sizes.append(_get_card_screen_size(frame))
    var current_offset: Vector2 = _current_offsets.get(frame.get_instance_id(), Vector2.ZERO)
    current_centers.append(desired_center + current_offset)

  _line_segments.clear()
  if frames.is_empty():
    queue_redraw()
    return

  var resolved_centers := _resolve_card_positions(
    desired_centers,
    card_sizes,
    get_viewport().get_visible_rect(),
    current_centers
  )

  for index in range(frames.size()):
    var frame := frames[index]
    var frame_id := frame.get_instance_id()
    var target_offset: Vector2 = resolved_centers[index] - desired_centers[index]
    _current_offsets[frame_id] = target_offset
    _set_frame_screen_offset(frame, target_offset)

    if target_offset.length() < leader_line_threshold:
      continue

    var card_rect := Rect2(
      desired_centers[index] + target_offset - card_sizes[index] * 0.5,
      card_sizes[index]
    )
    var line_start := _get_leader_line_start(frame)
    if not card_rect.has_point(line_start):
      _line_segments.append(PackedVector2Array([
        line_start,
        _closest_point_on_rect(card_rect, line_start),
      ]))

  queue_redraw()


func _resolve_card_positions(
  desired_centers: Array[Vector2],
  card_sizes: Array[Vector2],
  viewport_rect: Rect2,
  initial_centers: Array[Vector2] = []
) -> Array[Vector2]:
  var positions: Array[Vector2] = desired_centers.duplicate()
  var overlap_clusters := _find_overlap_clusters(desired_centers, card_sizes)
  if initial_centers.size() == desired_centers.size():
    positions = initial_centers.duplicate()
  if positions.size() < 2:
    if positions.size() == 1:
      positions[0] = _constrain_card_position(
        positions[0], desired_centers[0], card_sizes[0], viewport_rect
      )
    return positions

  for index in range(positions.size()):
    positions[index] = positions[index].lerp(desired_centers[index], anchor_pull)

  for _iteration in range(collision_iterations):
    _resolve_overlaps_once(positions, desired_centers, card_sizes, viewport_rect)

  for cluster in overlap_clusters:
    if _cluster_has_overlap(positions, card_sizes, cluster):
      _arrange_cluster_grid(
        positions, desired_centers, card_sizes, cluster, viewport_rect
      )

  # A fallback grid can reach into a neighboring cluster, so finish with a
  # global pass rather than assuming the original clusters remain independent.
  for _iteration in range(collision_iterations):
    _resolve_overlaps_once(positions, desired_centers, card_sizes, viewport_rect)

  var all_indices: Array[int] = []
  all_indices.assign(range(positions.size()))
  if _cluster_has_overlap(positions, card_sizes, all_indices):
    _arrange_cluster_grid(
      positions, desired_centers, card_sizes, all_indices, viewport_rect
    )

  return positions


func _resolve_overlaps_once(
  positions: Array[Vector2],
  desired_centers: Array[Vector2],
  card_sizes: Array[Vector2],
  viewport_rect: Rect2
) -> void:
  for first in range(positions.size() - 1):
    for second in range(first + 1, positions.size()):
      var half_extent: Vector2 = (card_sizes[first] + card_sizes[second]) * 0.5
      half_extent += Vector2.ONE * collision_padding
      var delta: Vector2 = positions[second] - positions[first]
      var overlap: Vector2 = half_extent - delta.abs()
      if overlap.x <= 0.0 or overlap.y <= 0.0:
        continue

      var separate_horizontally := overlap.x < overlap.y
      _separate_pair(positions, first, second, overlap, delta, separate_horizontally)
      positions[first] = _constrain_card_position(
        positions[first], desired_centers[first], card_sizes[first], viewport_rect
      )
      positions[second] = _constrain_card_position(
        positions[second], desired_centers[second], card_sizes[second], viewport_rect
      )

      # If the preferred axis was blocked by a boundary or displacement cap,
      # retry the remaining overlap on the other axis.
      delta = positions[second] - positions[first]
      overlap = half_extent - delta.abs()
      if overlap.x > 0.0 and overlap.y > 0.0:
        _separate_pair(positions, first, second, overlap, delta, not separate_horizontally)
        positions[first] = _constrain_card_position(
          positions[first], desired_centers[first], card_sizes[first], viewport_rect
        )
        positions[second] = _constrain_card_position(
          positions[second], desired_centers[second], card_sizes[second], viewport_rect
        )

  for index in range(positions.size()):
    positions[index] = _constrain_card_position(
      positions[index], desired_centers[index], card_sizes[index], viewport_rect
    )


func _find_overlap_clusters(
  positions: Array[Vector2],
  card_sizes: Array[Vector2]
) -> Array:
  var clusters: Array = []
  var visited: Dictionary = {}
  for start in range(positions.size()):
    if visited.has(start):
      continue

    var cluster: Array[int] = []
    var pending: Array[int] = [start]
    visited[start] = true
    while not pending.is_empty():
      var current: int = pending.pop_back()
      cluster.append(current)
      for other in range(positions.size()):
        if visited.has(other):
          continue
        if _cards_overlap(
          positions[current], card_sizes[current], positions[other], card_sizes[other]
        ):
          visited[other] = true
          pending.append(other)
    clusters.append(cluster)
  return clusters


func _cluster_has_overlap(
  positions: Array[Vector2],
  card_sizes: Array[Vector2],
  cluster: Array[int]
) -> bool:
  for first_offset in range(cluster.size() - 1):
    for second_offset in range(first_offset + 1, cluster.size()):
      var first := cluster[first_offset]
      var second := cluster[second_offset]
      if _cards_overlap(
        positions[first], card_sizes[first], positions[second], card_sizes[second]
      ):
        return true
  return false


func _cards_overlap(
  first_position: Vector2,
  first_size: Vector2,
  second_position: Vector2,
  second_size: Vector2
) -> bool:
  var required_separation := (first_size + second_size) * 0.5
  required_separation += Vector2.ONE * collision_padding
  var separation := (second_position - first_position).abs()
  return separation.x < required_separation.x and separation.y < required_separation.y


func _arrange_cluster_grid(
  positions: Array[Vector2],
  desired_centers: Array[Vector2],
  card_sizes: Array[Vector2],
  cluster: Array[int],
  viewport_rect: Rect2
) -> void:
  if cluster.size() < 2:
    return

  var ordered := cluster.duplicate()
  ordered.sort_custom(func(a: int, b: int) -> bool:
    if desired_centers[a].x != desired_centers[b].x:
      return desired_centers[a].x < desired_centers[b].x
    if desired_centers[a].y != desired_centers[b].y:
      return desired_centers[a].y < desired_centers[b].y
    return a < b
  )

  var maximum_card_size := Vector2.ZERO
  var cluster_center := Vector2.ZERO
  for index in ordered:
    maximum_card_size = maximum_card_size.max(card_sizes[index])
    cluster_center += desired_centers[index]
  cluster_center /= float(ordered.size())

  var cell_size := maximum_card_size + Vector2.ONE * collision_padding
  var card_aspect := maxf(cell_size.x / maxf(cell_size.y, 1.0), 1.0)
  var columns := clampi(ceili(sqrt(float(ordered.size()) / card_aspect)), 1, ordered.size())
  var rows := ceili(float(ordered.size()) / float(columns))
  var grid_size := Vector2(
    maximum_card_size.x + float(columns - 1) * cell_size.x,
    maximum_card_size.y + float(rows - 1) * cell_size.y
  )
  var minimum_center := viewport_rect.position + grid_size * 0.5 + Vector2.ONE * viewport_margin
  var maximum_center := viewport_rect.end - grid_size * 0.5 - Vector2.ONE * viewport_margin
  if minimum_center.x <= maximum_center.x:
    cluster_center.x = clampf(cluster_center.x, minimum_center.x, maximum_center.x)
  if minimum_center.y <= maximum_center.y:
    cluster_center.y = clampf(cluster_center.y, minimum_center.y, maximum_center.y)

  for order_index in range(ordered.size()):
    var column: int = order_index % columns
    var row := floori(float(order_index) / float(columns))
    positions[ordered[order_index]] = cluster_center + Vector2(
      (float(column) - float(columns - 1) * 0.5) * cell_size.x,
      (float(row) - float(rows - 1) * 0.5) * cell_size.y
    )


func _separate_pair(
  positions: Array[Vector2],
  first: int,
  second: int,
  overlap: Vector2,
  delta: Vector2,
  horizontally: bool
) -> void:
  if horizontally:
    var direction_x := signf(delta.x)
    if is_zero_approx(direction_x):
      direction_x = 1.0
    var shift_x := Vector2(direction_x * overlap.x * 0.5, 0.0)
    positions[first] -= shift_x
    positions[second] += shift_x
  else:
    var direction_y := signf(delta.y)
    if is_zero_approx(direction_y):
      direction_y = 1.0
    var shift_y := Vector2(0.0, direction_y * overlap.y * 0.5)
    positions[first] -= shift_y
    positions[second] += shift_y


func _constrain_card_position(
  position: Vector2,
  desired_position: Vector2,
  card_size: Vector2,
  viewport_rect: Rect2
) -> Vector2:
  var displacement := position - desired_position
  if max_displacement > 0.0 and displacement.length() > max_displacement:
    position = desired_position + displacement.normalized() * max_displacement

  # Keeping the whole card onscreen wins if custom settings make the viewport
  # and displacement constraints impossible to satisfy simultaneously.
  var half_size := card_size * 0.5
  var minimum := viewport_rect.position + half_size + Vector2.ONE * viewport_margin
  var maximum := viewport_rect.end - half_size - Vector2.ONE * viewport_margin
  if minimum.x <= maximum.x:
    position.x = clampf(position.x, minimum.x, maximum.x)
  if minimum.y <= maximum.y:
    position.y = clampf(position.y, minimum.y, maximum.y)
  return position


func _get_card_screen_size(frame: Component_Health) -> Vector2:
  return frame.sprite.get_item_rect().size * _get_texture_pixel_screen_scale(frame)


func _get_texture_pixel_screen_scale(frame: Component_Health) -> Vector2:
  var anchor: Vector3 = frame.sprite.global_position
  var sample_anchor: Vector3 = anchor
  var pixel_size: float = frame.sprite.pixel_size
  if frame.sprite.fixed_size and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
    var viewport_height := get_viewport().get_visible_rect().size.y
    return Vector2.ONE * pixel_size * viewport_height * 0.5

  if frame.sprite.fixed_size:
    sample_anchor = camera.global_position - camera.global_basis.z.normalized()

  var screen_anchor: Vector2 = camera.unproject_position(sample_anchor)
  var screen_right: Vector2 = camera.unproject_position(
    sample_anchor + camera.global_basis.x.normalized() * pixel_size
  )
  var screen_up: Vector2 = camera.unproject_position(
    sample_anchor + camera.global_basis.y.normalized() * pixel_size
  )
  return Vector2(
    maxf(screen_anchor.distance_to(screen_right), 0.0001),
    maxf(screen_anchor.distance_to(screen_up), 0.0001)
  )


func _set_frame_screen_offset(frame: Component_Health, screen_offset: Vector2) -> void:
  var screen_scale := _get_texture_pixel_screen_scale(frame)
  frame.sprite.offset = Vector2(
    screen_offset.x / screen_scale.x,
    -screen_offset.y / screen_scale.y
  )


func _get_leader_line_start(frame: Component_Health) -> Vector2:
  var anchor: Vector3 = frame.sprite.global_position
  var entity := frame.get_parent() as Node3D
  if entity:
    anchor = entity.global_position.lerp(anchor, 0.5)
  return camera.unproject_position(anchor)


func _closest_point_on_rect(rect: Rect2, point: Vector2) -> Vector2:
  return Vector2(
    clampf(point.x, rect.position.x, rect.end.x),
    clampf(point.y, rect.position.y, rect.end.y)
  )
