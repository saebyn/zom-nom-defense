extends GutTest

const EFFECT := preload("res://Common/Effects/destruction_effect/destruction_effect.tscn")

func test_effect_survives_generic_entity_and_preserves_authored_transform() -> void:
  var world := Node3D.new()
  world.position = Vector3(12, 3, -8)
  world.rotation.y = 0.4
  add_child_autofree(world)
  var entity := Node3D.new()
  entity.position = Vector3(-4, 2, 6)
  entity.rotation.y = -0.7
  entity.scale = Vector3(1.5, 2, 0.8)
  world.add_child(entity)
  var effect: Node3D = EFFECT.instantiate()
  effect.position = Vector3(0.2, 0.6, -0.3)
  entity.add_child(effect)
  var expected_transform := effect.global_transform
  await wait_process_frames(2)
  assert_false(effect.get_node("Debris").emitting, "Adding the scene does not trigger it")

  # Also works when entity removal is requested before the effect's signal handler.
  entity.queue_free()
  effect.destroyed("test")
  assert_eq(effect.get_parent(), world)
  assert_true(effect.global_transform.is_equal_approx(expected_transform))
  assert_true(effect.get_node("Debris").emitting)
  assert_true(effect.get_node("Flash").visible)
  effect.destroyed("duplicate")
  assert_eq(effect.get_parent(), world, "Repeated triggers do not reparent again")
  await wait_process_frames(2)
  assert_false(is_instance_valid(entity))
  assert_true(is_instance_valid(effect))
  await wait_seconds(1.1)
  assert_false(is_instance_valid(effect))
