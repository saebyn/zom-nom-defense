extends GutTest


func _make_frame(position: Vector3, survivor: bool = true) -> Component_Health:
  var parent := Node3D.new()
  parent.position = position
  if survivor:
    parent.add_to_group("survivors")

  var health_scene = load("res://Common/Components/health/health.tscn")
  var health: Component_Health = health_scene.instantiate()
  parent.add_child(health)
  add_child_autofree(parent)
  return health


func _make_manager() -> UI_UnitFrameLayout:
  var manager := UI_UnitFrameLayout.new()
  add_child_autofree(manager)
  return manager


func test_selects_nearest_frames_to_ground_focus():
  var manager := _make_manager()
  manager.max_visible_frames = 2
  var far := _make_frame(Vector3(30.0, 0.0, 0.0))
  var near := _make_frame(Vector3(5.0, 0.0, 0.0))
  var middle := _make_frame(Vector3(15.0, 0.0, 0.0))
  await get_tree().process_frame

  var candidates: Array[Component_Health] = [far, near, middle]
  var selected := manager._select_candidates(candidates, Vector3.ZERO)

  assert_eq(selected.size(), 2, "Selection should respect the visible-frame cap")
  assert_eq(selected[0], near, "Nearest frame should rank first")
  assert_eq(selected[1], middle, "Second-nearest frame should rank second")


func test_distance_ranking_ignores_entity_height():
  var manager := _make_manager()
  var high := _make_frame(Vector3(5.0, 100.0, 0.0))
  var ground := _make_frame(Vector3(10.0, 0.0, 0.0))
  await get_tree().process_frame

  var candidates: Array[Component_Health] = [ground, high]
  var ranked := manager._rank_candidates(candidates, Vector3.ZERO)

  assert_eq(ranked[0], high, "Ranking should use X/Z ground-plane distance")


func test_urgent_frame_overrides_distance_cutoff():
  var manager := _make_manager()
  manager.max_visible_frames = 2
  var near := _make_frame(Vector3(5.0, 0.0, 0.0))
  var middle := _make_frame(Vector3(10.0, 0.0, 0.0))
  var urgent_far := _make_frame(Vector3(100.0, 0.0, 0.0), false)
  await get_tree().process_frame
  urgent_far.show_unit_frame()

  var candidates: Array[Component_Health] = [near, middle, urgent_far]
  var selected := manager._select_candidates(candidates, Vector3.ZERO)

  assert_eq(selected[0], urgent_far, "Hovered frame should override distance ranking")
  assert_has(selected, near, "Nearest regular frame should keep the remaining slot")
  assert_does_not_have(selected, middle, "Farther regular frame should lose the slot")


func test_slightly_nearer_frame_wins_strict_distance_ranking():
  var manager := _make_manager()
  manager.max_visible_frames = 1
  var incumbent := _make_frame(Vector3(10.0, 0.0, 0.0))
  var nearer := _make_frame(Vector3(9.9, 0.0, 0.0))
  await get_tree().process_frame

  var candidates: Array[Component_Health] = [incumbent, nearer]
  var selected := manager._select_candidates(candidates, Vector3.ZERO)

  assert_eq(selected[0], nearer,
    "Strict distance ranking should replace a farther incumbent")


func test_non_overlapping_cards_stay_at_their_anchors():
  var manager := _make_manager()
  var desired: Array[Vector2] = [Vector2(100, 100), Vector2(300, 100)]
  var sizes: Array[Vector2] = [Vector2(80, 30), Vector2(80, 30)]

  var resolved := manager._resolve_card_positions(
    desired, sizes, Rect2(0, 0, 500, 300)
  )

  assert_eq(resolved, desired, "Separated cards should not be displaced")


func test_overlapping_cards_are_separated():
  var manager := _make_manager()
  var desired: Array[Vector2] = [Vector2(200, 150), Vector2(210, 150)]
  var sizes: Array[Vector2] = [Vector2(80, 30), Vector2(80, 30)]

  var resolved := manager._resolve_card_positions(
    desired, sizes, Rect2(0, 0, 500, 300)
  )
  var first_rect := Rect2(resolved[0] - sizes[0] * 0.5, sizes[0]).grow(
    manager.collision_padding * 0.5
  )
  var second_rect := Rect2(resolved[1] - sizes[1] * 0.5, sizes[1]).grow(
    manager.collision_padding * 0.5
  )

  assert_false(first_rect.intersects(second_rect),
    "Resolved card rectangles should not overlap")


func test_overlapping_cards_receive_horizontal_stagger():
  var manager := _make_manager()
  var desired: Array[Vector2] = [Vector2(250, 150), Vector2(250, 150), Vector2(250, 150)]
  var sizes: Array[Vector2] = [Vector2(160, 42), Vector2(160, 42), Vector2(160, 42)]

  var resolved := manager._resolve_card_positions(
    desired, sizes, Rect2(0, 0, 500, 300)
  )
  var minimum_x := minf(resolved[0].x, minf(resolved[1].x, resolved[2].x))
  var maximum_x := maxf(resolved[0].x, maxf(resolved[1].x, resolved[2].x))

  assert_gte(maximum_x - minimum_x, manager.horizontal_stagger,
    "Nearby cards should form staggered columns instead of a vertical stack")


func test_overlapping_cards_are_separated_near_viewport_edge():
  var manager := _make_manager()
  var desired: Array[Vector2] = [Vector2(20, 20), Vector2(20, 20)]
  var sizes: Array[Vector2] = [Vector2(80, 30), Vector2(80, 30)]

  var resolved := manager._resolve_card_positions(
    desired, sizes, Rect2(0, 0, 500, 300)
  )
  var first_rect := Rect2(resolved[0] - sizes[0] * 0.5, sizes[0]).grow(
    manager.collision_padding * 0.5
  )
  var second_rect := Rect2(resolved[1] - sizes[1] * 0.5, sizes[1]).grow(
    manager.collision_padding * 0.5
  )

  assert_false(first_rect.intersects(second_rect),
    "Viewport clamping should not reintroduce an avoidable overlap")


func test_ten_coincident_cards_form_non_overlapping_cluster():
  var manager := _make_manager()
  var desired: Array[Vector2] = []
  var sizes: Array[Vector2] = []
  for _index in range(10):
    desired.append(Vector2(400, 300))
    sizes.append(Vector2(160, 42))

  var resolved := manager._resolve_card_positions(
    desired, sizes, Rect2(0, 0, 800, 600)
  )

  for first in range(resolved.size() - 1):
    for second in range(first + 1, resolved.size()):
      var first_rect := Rect2(
        resolved[first] - sizes[first] * 0.5, sizes[first]
      ).grow(manager.collision_padding * 0.5)
      var second_rect := Rect2(
        resolved[second] - sizes[second] * 0.5, sizes[second]
      ).grow(manager.collision_padding * 0.5)
      assert_false(first_rect.intersects(second_rect),
        "Every selected card should have a non-overlapping position")


func test_static_dense_cluster_keeps_the_same_layout_between_frames():
  var manager := _make_manager()
  var desired: Array[Vector2] = []
  var sizes: Array[Vector2] = []
  for index in range(10):
    desired.append(Vector2(370 + (index % 3) * 15, 270 + (index / 3) * 12))
    sizes.append(Vector2(160, 42))

  var first_layout := manager._resolve_card_positions(
    desired, sizes, Rect2(0, 0, 800, 600)
  )
  var next_layout := manager._resolve_card_positions(
    desired, sizes, Rect2(0, 0, 800, 600)
  )

  for index in range(first_layout.size()):
    assert_true(next_layout[index].is_equal_approx(first_layout[index]),
      "An unchanged dense cluster should not oscillate between layouts")


func test_dense_fallback_avoids_neighboring_cluster():
  var manager := _make_manager()
  var desired: Array[Vector2] = []
  var sizes: Array[Vector2] = []
  for _index in range(9):
    desired.append(Vector2(400, 300))
    sizes.append(Vector2(160, 42))
  desired.append(Vector2(570, 300))
  sizes.append(Vector2(160, 42))

  var resolved := manager._resolve_card_positions(
    desired, sizes, Rect2(0, 0, 900, 600)
  )

  for first in range(resolved.size() - 1):
    for second in range(first + 1, resolved.size()):
      assert_false(manager._cards_overlap(
        resolved[first], sizes[first], resolved[second], sizes[second]
      ), "Fallback cluster should not overlap a neighboring card")


func test_card_displacement_is_capped():
  var manager := _make_manager()
  manager.max_displacement = 25.0
  var desired := Vector2(200, 150)

  var constrained := manager._constrain_card_position(
    Vector2(400, 150),
    desired,
    Vector2(80, 30),
    Rect2(0, 0, 500, 300)
  )

  assert_almost_eq(constrained.distance_to(desired), 25.0, 0.01,
    "Card should not move beyond max_displacement")


func test_fixed_orthographic_scale_matches_rendering_shader():
  var manager := _make_manager()
  var camera := Camera3D.new()
  camera.projection = Camera3D.PROJECTION_ORTHOGONAL
  manager.add_child(camera)
  manager.camera = camera
  var frame := _make_frame(Vector3.ZERO)
  await get_tree().process_frame

  var scale := manager._get_texture_pixel_screen_scale(frame)
  var expected := frame.sprite.pixel_size * get_viewport().get_visible_rect().size.y * 0.5

  assert_almost_eq(scale.x, expected, 0.0001,
    "Fixed orthographic scale should match Godot's viewport-height shader scaling")
  assert_almost_eq(scale.y, expected, 0.0001,
    "Fixed orthographic scale should be uniform")


func test_leader_line_leaves_clearance_around_target():
  var manager := _make_manager()
  manager.leader_target_clearance = 20.0

  var cleared_start := manager._clear_leader_target(Vector2.ZERO, Vector2(100, 0))

  assert_eq(cleared_start, Vector2(20, 0),
    "Leader line should start beyond the target clearance gap")


func test_short_leader_line_is_suppressed_inside_target_clearance():
  var manager := _make_manager()
  manager.leader_target_clearance = 20.0
  var card_edge := Vector2(10, 0)

  var cleared_start := manager._clear_leader_target(Vector2.ZERO, card_edge)

  assert_eq(cleared_start, card_edge,
    "Leader line inside the target clearance should collapse to zero length")
