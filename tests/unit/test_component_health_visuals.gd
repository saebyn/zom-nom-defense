extends GutTest

## Unit tests for Component_Health visual improvements:
## - Dynamic transparency based on HP ratio
## - Entity-type-based bar color selection

# Helper: create a health instance attached to a parent node
func _make_health(parent: Node = null) -> Component_Health:
  if not parent:
    parent = Node3D.new()
  var health_scene = load("res://Common/Components/health/health.tscn")
  var health: Component_Health = health_scene.instantiate()
  parent.add_child(health)
  add_child_autofree(parent)
  return health

## Helper: create a Node3D with an enemy_type property via an inline script.
## Required because plain Node3D doesn't accept dynamic property assignment via set().
func _make_enemy_parent(enemy_type_value: String) -> Node3D:
  var script = GDScript.new()
  script.source_code = "extends Node3D\nvar enemy_type: String = \"\""
  var err = script.reload()
  assert_eq(err, OK, "_make_enemy_parent: inline script failed to compile")
  var parent = Node3D.new()
  parent.set_script(script)
  parent.enemy_type = enemy_type_value
  return parent


# ────────────────────────────────────────────────────────────────
# Unit-frame visibility tests
# ────────────────────────────────────────────────────────────────

func test_unit_frame_hidden_at_full_health_by_default():
  var health := _make_health()
  await get_tree().process_frame

  # No damage taken, not hovered — sprite should be hidden
  assert_false(health.sprite.visible,
    "Unit frame should be hidden at full health with no hover")

func test_unit_frame_shown_on_hover():
  var health := _make_health()
  await get_tree().process_frame

  health.show_unit_frame()

  assert_true(health.sprite.visible,
    "Unit frame should be visible while hovered")

func test_unit_frame_hidden_after_hover_ends():
  var health := _make_health()
  await get_tree().process_frame

  health.show_unit_frame()
  health.hide_unit_frame()

  assert_false(health.sprite.visible,
    "Unit frame should hide when hover ends (no recent damage)")

func test_unit_frame_shown_after_damage():
  var health := _make_health()
  await get_tree().process_frame

  # Manually set the damage-reveal timer as take_damage would
  health._damage_reveal_timer = Component_Health.DAMAGE_REVEAL_DURATION
  health._update_display()

  assert_true(health.sprite.visible,
    "Unit frame should be visible immediately after taking damage")

func test_unit_frame_stays_visible_while_hovered_after_hover_ends_with_recent_damage():
  var health := _make_health()
  await get_tree().process_frame

  # Hover + recent damage
  health._damage_reveal_timer = Component_Health.DAMAGE_REVEAL_DURATION
  health.show_unit_frame()
  # End hover — timer still running, should stay visible
  health.hide_unit_frame()

  assert_true(health.sprite.visible,
    "Unit frame should stay visible after hover ends if damage timer is still running")

func test_survivor_unit_frame_always_visible():
  var parent := _make_survivor_parent("Carol")
  var health := _make_health(parent)
  await get_tree().process_frame

  # No hover, no recent damage — survivor unit frame should still be visible
  assert_true(health.sprite.visible,
    "Survivor unit frame should always be visible regardless of hover or damage")

func test_survivor_unit_frame_visible_after_hide():
  var parent := _make_survivor_parent("Dave")
  var health := _make_health(parent)
  await get_tree().process_frame

  health.show_unit_frame()
  health.hide_unit_frame()

  assert_true(health.sprite.visible,
    "Survivor unit frame should stay visible even after hide_unit_frame()")

func test_layout_permission_hides_requested_unit_frame():
  var parent := _make_survivor_parent("Erin")
  var health := _make_health(parent)
  await get_tree().process_frame

  health.set_unit_frame_layout_allowed(false)

  assert_true(health.is_unit_frame_requested(),
    "Layout permission should not change the component's visibility request")
  assert_false(health.sprite.visible,
    "Layout manager should be able to hide a requested unit frame")

func test_restoring_layout_permission_shows_requested_unit_frame():
  var parent := _make_survivor_parent("Frank")
  var health := _make_health(parent)
  await get_tree().process_frame

  health.set_unit_frame_layout_allowed(false)
  health.set_unit_frame_layout_allowed(true)

  assert_true(health.sprite.visible,
    "Requested unit frame should return when layout permission is restored")

func test_layout_permission_does_not_reveal_unrequested_unit_frame():
  var health := _make_health()
  await get_tree().process_frame

  health.set_unit_frame_layout_allowed(false)
  health.set_unit_frame_layout_allowed(true)

  assert_false(health.sprite.visible,
    "Layout permission should not bypass the component's local visibility rules")

func test_pause_reveal_is_not_urgent():
  var health := _make_health()
  await get_tree().process_frame

  health._on_game_speed_changed(0.0)

  assert_true(health.is_unit_frame_requested(),
    "Pausing should request the unit frame")
  assert_false(health.is_unit_frame_urgent(),
    "Pause reveal should not outrank hovered or damaged frames")

func test_pause_cycle_preserves_hover_state():
  var health := _make_health()
  await get_tree().process_frame
  health.show_unit_frame()

  health._on_game_speed_changed(0.0)
  health._on_game_speed_changed(1.0)

  assert_true(health.is_unit_frame_urgent(),
    "Resuming should not clear a frame that remains hovered")
  assert_true(health.sprite.visible,
    "Hovered frame should remain visible after a pause cycle")


# ────────────────────────────────────────────────────────────────
# Transparency tests (unit frame must be revealed first)
# ────────────────────────────────────────────────────────────────

func test_full_health_fades_to_high_opacity():
  var health := _make_health()
  await get_tree().process_frame

  health.show_unit_frame() # reveal so bar alpha is meaningful
  # At 100% HP the bar should be nearly invisible (HIGH_HP_OPACITY)
  assert_almost_eq(health.health_bar.modulate.a, Component_Health.HIGH_HP_OPACITY, 0.01,
    "Full HP should use HIGH_HP_OPACITY")

func test_low_health_shows_full_opacity():
  var health := _make_health()
  await get_tree().process_frame

  health.show_unit_frame()
  # Drop HP to or below LOW_HP_THRESHOLD — bar must be fully opaque
  health.hitpoints = int(health.max_hitpoints * Component_Health.LOW_HP_THRESHOLD)
  health._update_display()

  assert_almost_eq(health.health_bar.modulate.a, Component_Health.FULL_OPACITY, 0.01,
    "HP at LOW_HP_THRESHOLD should use FULL_OPACITY")

func test_zero_health_shows_full_opacity():
  var health := _make_health()
  await get_tree().process_frame

  health.show_unit_frame()
  health.hitpoints = 0
  health._update_display()

  assert_almost_eq(health.health_bar.modulate.a, Component_Health.FULL_OPACITY, 0.01,
    "Zero HP should use FULL_OPACITY")

func test_opacity_at_high_hp_threshold_boundary():
  var health := _make_health()
  await get_tree().process_frame

  health.show_unit_frame()
  # Exactly at HIGH_HP_THRESHOLD (80%)
  health.hitpoints = int(health.max_hitpoints * Component_Health.HIGH_HP_THRESHOLD)
  health._update_display()

  # Should be at HIGH_HP_OPACITY (at or above threshold)
  assert_almost_eq(health.health_bar.modulate.a, Component_Health.HIGH_HP_OPACITY, 0.05,
    "HP at HIGH_HP_THRESHOLD should be near HIGH_HP_OPACITY")

func test_opacity_interpolates_between_thresholds():
  var health := _make_health()
  await get_tree().process_frame

  health.show_unit_frame()
  # Set HP midway between LOW_HP_THRESHOLD and HIGH_HP_THRESHOLD
  var mid_hp_ratio: float = (Component_Health.LOW_HP_THRESHOLD + Component_Health.HIGH_HP_THRESHOLD) / 2.0
  health.hitpoints = int(health.max_hitpoints * mid_hp_ratio)
  health._update_display()

  # Should be between HIGH_HP_OPACITY and FULL_OPACITY, not at either extreme
  assert_gt(health.health_bar.modulate.a, Component_Health.HIGH_HP_OPACITY,
    "Mid-health should be more opaque than HIGH_HP_OPACITY")
  assert_lt(health.health_bar.modulate.a, Component_Health.FULL_OPACITY,
    "Mid-health should be less opaque than FULL_OPACITY")

func test_label_opacity_never_below_minimum():
  var health := _make_health()
  await get_tree().process_frame

  # Label modulate is never touched by the health system, so it stays at 1.0
  assert_almost_eq(health.health_label.modulate.a, 1.0, 0.01,
    "Label opacity should be 1.0 (untouched)")

func test_label_opacity_at_low_health():
  var health := _make_health()
  await get_tree().process_frame

  health.hitpoints = 1
  health._update_display()

  assert_almost_eq(health.health_label.modulate.a, 1.0, 0.01,
    "Label opacity should be 1.0 (untouched) even at low HP")


# ────────────────────────────────────────────────────────────────
# Bar color tests
# ────────────────────────────────────────────────────────────────

func test_default_color_when_no_parent_type():
  var health := _make_health()
  await get_tree().process_frame

  # Plain Node3D parent has no enemy_type — should use DEFAULT color
  var color := health._get_effective_bar_color()
  assert_eq(color, Component_Health.COLOR_DEFAULT,
    "No-type parent should yield COLOR_DEFAULT")

func test_fast_enemy_type_yields_fast_color():
  # enemy_type strings are runtime identifiers set via Resource_EnemyType.enemy_type
  # (Config/Enemies/enemy_type_resource.gd). "fast" substring triggers fast-zombie coloring.
  var parent := _make_enemy_parent("zombie_fast")
  var health := _make_health(parent)
  await get_tree().process_frame

  var color := health._get_effective_bar_color()
  assert_eq(color, Component_Health.COLOR_ZOMBIE_FAST,
    "fast enemy_type should yield COLOR_ZOMBIE_FAST")

func test_tank_enemy_type_yields_tank_color():
  # "tank" substring triggers tank-zombie coloring.
  var parent := _make_enemy_parent("zombie_tank")
  var health := _make_health(parent)
  await get_tree().process_frame

  var color := health._get_effective_bar_color()
  assert_eq(color, Component_Health.COLOR_ZOMBIE_TANK,
    "tank enemy_type should yield COLOR_ZOMBIE_TANK")

func test_standard_enemy_type_yields_standard_color():
  # Any enemy_type without "fast"/"tank" falls through to standard zombie coloring.
  var parent := _make_enemy_parent("base_enemy")
  var health := _make_health(parent)
  await get_tree().process_frame

  var color := health._get_effective_bar_color()
  assert_eq(color, Component_Health.COLOR_ZOMBIE_STANDARD,
    "base enemy_type should yield COLOR_ZOMBIE_STANDARD")

func test_survivor_group_yields_survivor_color():
  var parent = Node3D.new()
  add_child_autofree(parent)
  parent.add_to_group("survivors")
  var health_scene = load("res://Common/Components/health/health.tscn")
  var health: Component_Health = health_scene.instantiate()
  parent.add_child(health)
  await get_tree().process_frame

  var color := health._get_effective_bar_color()
  assert_eq(color, Component_Health.COLOR_SURVIVOR,
    "survivor group should yield COLOR_SURVIVOR")

func test_explicit_bar_color_overrides_auto():
  var health := _make_health()
  health.use_custom_bar_color = true
  health.bar_color = Color(1.0, 0.0, 0.0, 1.0) # bright red override
  await get_tree().process_frame

  var color := health._get_effective_bar_color()
  assert_eq(color, Color(1.0, 0.0, 0.0, 1.0),
    "Explicit bar_color should override auto-detection")


# ────────────────────────────────────────────────────────────────
# Name label tests
# ────────────────────────────────────────────────────────────────

## Helper: create a Node3D in the "survivors" group with a survivor_name property.
func _make_survivor_parent(survivor_name_value: String) -> Node3D:
  var script = GDScript.new()
  script.source_code = "extends Node3D\nvar survivor_name: String = \"\""
  var err = script.reload()
  assert_eq(err, OK, "_make_survivor_parent: inline script failed to compile")
  var parent = Node3D.new()
  parent.set_script(script)
  parent.survivor_name = survivor_name_value
  parent.add_to_group("survivors")
  return parent

func test_get_entity_display_name_empty_when_no_type():
  var health := _make_health()
  await get_tree().process_frame

  assert_eq(health._get_entity_display_name(), "",
    "Entity with no type should return empty display name")

func test_get_entity_display_name_formats_basic_enemy_type():
  var parent := _make_enemy_parent("basic_zombie")
  var health := _make_health(parent)
  await get_tree().process_frame

  assert_eq(health._get_entity_display_name(), "Basic Zombie",
    "basic_zombie enemy_type should format to 'Basic Zombie'")

func test_get_entity_display_name_formats_sprinter_enemy_type():
  var parent := _make_enemy_parent("sprinter_zombie")
  var health := _make_health(parent)
  await get_tree().process_frame

  assert_eq(health._get_entity_display_name(), "Sprinter Zombie",
    "sprinter_zombie enemy_type should format to 'Sprinter Zombie'")

func test_get_entity_display_name_returns_survivor_name():
  var parent := _make_survivor_parent("Alice")
  var health := _make_health(parent)
  await get_tree().process_frame

  assert_eq(health._get_entity_display_name(), "Alice",
    "Survivor should return their assigned name")

func test_name_label_text_set_for_enemy():
  var parent := _make_enemy_parent("tank_zombie")
  var health := _make_health(parent)
  await get_tree().process_frame

  health._update_display()

  assert_eq(health.name_label.text, "Tank Zombie",
    "Name label should show formatted enemy type")

func test_name_label_text_set_for_survivor():
  var parent := _make_survivor_parent("Bob")
  var health := _make_health(parent)
  await get_tree().process_frame

  health._update_display()

  assert_eq(health.name_label.text, "Bob",
    "Name label should show survivor name")

func test_name_label_populated_after_late_name_assignment():
  # Simulate the Godot _ready() ordering issue:
  # health._ready() runs before target._ready(), so survivor_name is "" when
  # the health component first calls _update_display(). target._ready() must
  # call health.refresh_display() again after assigning the name.
  var script = GDScript.new()
  script.source_code = "extends Node3D\nvar survivor_name: String = \"\""
  var err = script.reload()
  assert_eq(err, OK, "inline script failed to compile")
  var parent = Node3D.new()
  parent.set_script(script)
  parent.add_to_group("survivors")
  # survivor_name is empty here (mimics target._ready() not yet having run)
  var health := _make_health(parent)
  await wait_process_frames(1) # Let health._ready() run with survivor_name == ""

  # At this point health._ready() has run with survivor_name == "", so label is blank
  assert_eq(health.name_label.text, "",
    "Name label should be blank before survivor name is assigned")

  # Now simulate target._ready() assigning the name and refreshing the display
  parent.survivor_name = "Eve"
  health.refresh_display()

  assert_eq(health.name_label.text, "Eve",
    "Name label should show survivor name after refresh_display() is called post-assignment")

func test_name_label_empty_for_plain_node():
  var health := _make_health()
  await get_tree().process_frame

  health._update_display()

  assert_eq(health.name_label.text, "",
    "Name label should be empty for entity with no type or survivor_name")

func test_name_label_font_color_override_applied():
  var parent := _make_enemy_parent("basic_zombie")
  var health := _make_health(parent)
  await get_tree().process_frame

  # _update_display → _update_unit_frame_visuals applies the color override
  health._update_display()

  assert_true(health.name_label.has_theme_color_override("font_color"),
    "Name label should have a font_color theme override after display update")
