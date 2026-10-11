extends GutTest

## Unit tests for Component_Attack AoE splash logic.
## Covers:
##   - AoE hits enemies within radius, misses those outside
##   - Falloff curve scales damage correctly by distance
##   - Primary target is not double-hit by splash
##   - Crit applies to splash when crit_applies_to_splash = true
##   - Damage multiplier stacking (e.g. Hydraulic Mouse) works on splash
##   - Crit uses "critical" damage_source; non-crit uses component's damage_source
##   - Crit + Hydraulic Mouse stacking: 1.25 × 2.0 = 2.5×

# ─────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────

func _make_attack() -> Component_Attack:
  var scene = load("res://Common/Components/attack/attack.tscn")
  var attack: Component_Attack = scene.instantiate()
  attack.damage_amount = 100.0
  attack.damage_source = "test"
  # No audio_player so sound is silently skipped
  
  # Hook up signals so that the attack component will work
  attack.attack_accepted.connect(func(_target):
    attack.release_attack()
    attack.finish_attack()
  )

  return attack


## Creates a Node3D with a Component_Health child registered in its metadata.
## The node is added to the given group and positioned at `pos`.
## `hp` sets the starting hitpoints (also used as max_hitpoints via _ready()).
func _make_enemy(pos: Vector3, group: String = "enemies", hp: int = 100) -> Node3D:
  var parent := Node3D.new()
  parent.position = pos
  if group != "":
    parent.add_to_group(group)
  var health_scene = load("res://Common/Components/health/health.tscn")
  var health: Component_Health = health_scene.instantiate()
  health.hitpoints = hp
  parent.add_child(health)
  add_child_autofree(parent)
  return parent


func _get_health(enemy: Node3D) -> Component_Health:
  return enemy.get_meta("health_component") as Component_Health


# ─────────────────────────────────────────────────────────────────────
# calculate_damage_amount
# ─────────────────────────────────────────────────────────────────────

func test_calculate_damage_no_crit():
  var attack := _make_attack()
  add_child_autofree(attack)
  await get_tree().process_frame

  attack.attack_effect.damage_multiplier = 2.0
  assert_eq(attack.calculate_damage_amount(), 200.0,
    "Damage without crit should be damage_amount * damage_multiplier")


func test_calculate_damage_with_crit():
  var attack := _make_attack()
  add_child_autofree(attack)
  await get_tree().process_frame

  attack.attack_effect.damage_multiplier = 1.0
  attack.attack_effect.crit_multiplier = 2.0
  assert_eq(attack.calculate_damage_amount(true), 200.0,
    "Crit damage should apply crit_multiplier on top of normal damage")


func test_calculate_damage_crit_false_ignores_multiplier():
  var attack := _make_attack()
  add_child_autofree(attack)
  await get_tree().process_frame

  attack.attack_effect.crit_multiplier = 3.0
  assert_eq(attack.calculate_damage_amount(false), 100.0,
    "Non-crit should not apply crit_multiplier")


# ─────────────────────────────────────────────────────────────────────
# AoE splash — hitting within radius
# ─────────────────────────────────────────────────────────────────────

func test_aoe_splash_hits_enemy_within_radius():
  var attack := _make_attack()
  add_child_autofree(attack)
  await get_tree().process_frame

  attack.attack_effect.aoe_radius = 5.0

  var primary := _make_enemy(Vector3.ZERO)
  var nearby := _make_enemy(Vector3(3.0, 0, 0))

  await get_tree().process_frame

  var nearby_health := _get_health(nearby)
  var hp_before := nearby_health.hitpoints

  attack.perform_attack(primary)

  assert_lt(nearby_health.hitpoints, hp_before,
    "Enemy within AoE radius should take splash damage")


func test_aoe_splash_misses_enemy_outside_radius():
  var attack := _make_attack()
  add_child_autofree(attack)
  await get_tree().process_frame

  attack.attack_effect.aoe_radius = 2.0

  var primary := _make_enemy(Vector3.ZERO)
  var far_away := _make_enemy(Vector3(10.0, 0, 0))

  await get_tree().process_frame

  var far_health := _get_health(far_away)
  var hp_before := far_health.hitpoints

  attack.perform_attack(primary)

  assert_eq(far_health.hitpoints, hp_before,
    "Enemy outside AoE radius should not take splash damage")


# ─────────────────────────────────────────────────────────────────────
# AoE splash — primary target not double-hit
# ─────────────────────────────────────────────────────────────────────

func test_aoe_splash_does_not_double_hit_primary_target():
  var attack := _make_attack()
  add_child_autofree(attack)
  await get_tree().process_frame

  attack.attack_effect.aoe_radius = 10.0

  var primary := _make_enemy(Vector3.ZERO)

  await get_tree().process_frame

  var primary_health := _get_health(primary)
  var hp_before := primary_health.hitpoints

  attack.perform_attack(primary)

  # Only one hit's worth of damage should be subtracted
  assert_eq(primary_health.hitpoints, hp_before - int(attack.calculate_damage_amount()),
    "Primary target should only be hit once, not by splash as well")


# ─────────────────────────────────────────────────────────────────────
# AoE splash — falloff curve scales damage
# ─────────────────────────────────────────────────────────────────────

func test_aoe_falloff_scales_damage_by_distance():
  var attack := _make_attack()
  add_child_autofree(attack)
  await get_tree().process_frame

  attack.attack_effect.aoe_radius = 4.0

  # Build a linear falloff curve: (0, 1.0) → (1, 0.0)
  var falloff := Curve.new()
  falloff.add_point(Vector2(0.0, 1.0))
  falloff.add_point(Vector2(1.0, 0.0))
  attack.attack_effect.aoe_falloff = falloff

  var primary := _make_enemy(Vector3.ZERO)
  # Enemy at half the radius → normalized distance = 0.5 → multiplier ≈ 0.5
  var half_radius := _make_enemy(Vector3(2.0, 0, 0))

  await get_tree().process_frame

  var half_health := _get_health(half_radius)
  var hp_before := half_health.hitpoints

  attack.perform_attack(primary)

  var damage_dealt := hp_before - half_health.hitpoints
  # Full base damage is 100; at distance 2.0 / 4.0 = 0.5, falloff ≈ 0.5 → ~50
  assert_almost_eq(damage_dealt, 50.0, 1.0,
    "Splash damage at half radius should be approximately 50%% of base (falloff=0.5)")


func test_aoe_no_falloff_applies_full_base_damage():
  var attack := _make_attack()
  add_child_autofree(attack)
  await get_tree().process_frame

  attack.attack_effect.aoe_radius = 5.0
  attack.attack_effect.aoe_falloff = null # No falloff → full damage

  var primary := _make_enemy(Vector3.ZERO)
  var nearby := _make_enemy(Vector3(3.0, 0, 0))

  await get_tree().process_frame

  var nearby_health := _get_health(nearby)
  var hp_before := nearby_health.hitpoints

  attack.perform_attack(primary)

  var damage_dealt := hp_before - nearby_health.hitpoints
  assert_almost_eq(damage_dealt, attack.calculate_damage_amount(), 0.01,
    "Splash damage with no falloff curve should equal base calculate_damage_amount()")


# ─────────────────────────────────────────────────────────────────────
# AoE splash — crit_applies_to_splash
# ─────────────────────────────────────────────────────────────────────

func test_aoe_crit_applies_to_splash_when_flag_true():
  var attack := _make_attack()
  add_child_autofree(attack)
  await get_tree().process_frame

  attack.attack_effect.aoe_radius = 5.0
  attack.attack_effect.aoe_falloff = null
  attack.attack_effect.crit_chance = 1.0 # Always crit
  attack.attack_effect.crit_multiplier = 2.0
  attack.attack_effect.crit_applies_to_splash = true

  var primary := _make_enemy(Vector3.ZERO)
  # Use 1000 HP so the enemy can absorb the full crit splash damage (200) without clamping
  var nearby := _make_enemy(Vector3(2.0, 0, 0), "enemies", 1000)

  await get_tree().process_frame

  var nearby_health := _get_health(nearby)
  var hp_before := nearby_health.hitpoints

  attack.perform_attack(primary)

  var damage_dealt := hp_before - nearby_health.hitpoints
  var expected := attack.calculate_damage_amount(true) # crit_multiplier = 2 → 200
  assert_almost_eq(damage_dealt, expected, 0.01,
    "Splash should receive crit multiplier when crit_applies_to_splash is true")


func test_aoe_crit_not_applied_to_splash_when_flag_false():
  var attack := _make_attack()
  add_child_autofree(attack)
  await get_tree().process_frame

  attack.attack_effect.aoe_radius = 5.0
  attack.attack_effect.aoe_falloff = null
  attack.attack_effect.crit_chance = 1.0 # Always crit
  attack.attack_effect.crit_multiplier = 2.0
  attack.attack_effect.crit_applies_to_splash = false # Do NOT crit splash

  var primary := _make_enemy(Vector3.ZERO)
  var nearby := _make_enemy(Vector3(2.0, 0, 0))

  await get_tree().process_frame

  var nearby_health := _get_health(nearby)
  var hp_before := nearby_health.hitpoints

  attack.perform_attack(primary)

  var damage_dealt := hp_before - nearby_health.hitpoints
  var base_damage := attack.calculate_damage_amount() # No crit
  assert_almost_eq(damage_dealt, base_damage, 0.01,
    "Splash should NOT receive crit multiplier when crit_applies_to_splash is false")


# ─────────────────────────────────────────────────────────────────────
# AoE splash — stacking with damage multiplier (e.g. Hydraulic Mouse)
# ─────────────────────────────────────────────────────────────────────

func test_aoe_splash_respects_stacked_damage_multiplier():
  var attack := _make_attack()
  add_child_autofree(attack)
  await get_tree().process_frame

  # Simulate Hydraulic Mouse (+25% damage) stacked on top
  var hydraulic_mouse := Resource_AttackEffect.new()
  hydraulic_mouse.damage_multiplier = 1.25
  attack.attack_effect.stack_effect(hydraulic_mouse)

  attack.attack_effect.aoe_radius = 5.0
  attack.attack_effect.aoe_falloff = null

  var primary := _make_enemy(Vector3.ZERO)
  # Use 1000 HP so the enemy can absorb the full stacked damage (125) without clamping
  var nearby := _make_enemy(Vector3(2.0, 0, 0), "enemies", 1000)

  await get_tree().process_frame

  var nearby_health := _get_health(nearby)
  var hp_before := nearby_health.hitpoints

  attack.perform_attack(primary)

  var damage_dealt := hp_before - nearby_health.hitpoints
  # 100 * 1.25 = 125 expected splash damage
  assert_almost_eq(damage_dealt, 125.0, 0.01,
    "Splash damage should reflect stacked damage multiplier (Hydraulic Mouse)")


# ─────────────────────────────────────────────────────────────────────
# No AoE when radius is zero
# ─────────────────────────────────────────────────────────────────────

func test_no_aoe_when_radius_is_zero():
  var attack := _make_attack()
  add_child_autofree(attack)
  await get_tree().process_frame

  attack.attack_effect.aoe_radius = 0.0

  var primary := _make_enemy(Vector3.ZERO)
  var nearby := _make_enemy(Vector3(0.5, 0, 0))

  await get_tree().process_frame

  var nearby_health := _get_health(nearby)
  var hp_before := nearby_health.hitpoints

  attack.perform_attack(primary)

  assert_eq(nearby_health.hitpoints, hp_before,
    "No splash should occur when aoe_radius is 0")


# ─────────────────────────────────────────────────────────────────────
# Crit damage_source — "critical" on crit, normal on non-crit
# ─────────────────────────────────────────────────────────────────────

func test_crit_uses_critical_damage_source():
  var attack := _make_attack()
  add_child_autofree(attack)
  await get_tree().process_frame

  attack.attack_effect.crit_chance = 1.0 # Always crit
  attack.attack_effect.crit_multiplier = 2.0
  attack.damage_source = "player"

  var primary := _make_enemy(Vector3.ZERO, "enemies", 1000) # High HP so it doesn't die
  await get_tree().process_frame

  var primary_health := _get_health(primary)
  watch_signals(primary_health)

  attack.perform_attack(primary)

  assert_signal_emitted_with_parameters(primary_health.damaged,
    [200, 800, Component_Attack.CRITICAL_DAMAGE_SOURCE])


func test_non_crit_uses_normal_damage_source():
  var attack := _make_attack()
  add_child_autofree(attack)
  await get_tree().process_frame

  attack.attack_effect.crit_chance = 0.0 # Never crit
  attack.damage_source = "player"

  var primary := _make_enemy(Vector3.ZERO, "enemies", 1000) # High HP so it doesn't die
  await get_tree().process_frame

  var primary_health := _get_health(primary)
  watch_signals(primary_health)

  attack.perform_attack(primary)

  assert_signal_emitted_with_parameters(primary_health.damaged,
    [100, 900, "player"])


func test_crit_applies_correct_multiplier():
  var attack := _make_attack()
  add_child_autofree(attack)
  await get_tree().process_frame

  attack.attack_effect.crit_chance = 1.0 # Always crit
  attack.attack_effect.crit_multiplier = 2.0
  # damage_amount = 100, damage_multiplier = 1.0 → crit damage = 200

  var primary := _make_enemy(Vector3.ZERO, "enemies", 1000)
  await get_tree().process_frame

  var primary_health := _get_health(primary)
  var hp_before := primary_health.hitpoints

  attack.perform_attack(primary)

  var damage_dealt := hp_before - primary_health.hitpoints
  assert_almost_eq(damage_dealt, 200.0, 0.01,
    "Crit should apply crit_multiplier (100 * 2.0 = 200)")


# ─────────────────────────────────────────────────────────────────────
# Stacking: Hydraulic Mouse (1.25×) + Double Tap (crit 2.0×) = 2.5×
# ─────────────────────────────────────────────────────────────────────

func test_crit_stacks_with_hydraulic_mouse_damage_multiplier():
  var attack := _make_attack()
  add_child_autofree(attack)
  await get_tree().process_frame

  # Simulate Hydraulic Mouse stacked first (damage_multiplier += 0.25 → 1.25)
  var hydraulic_mouse := Resource_AttackEffect.new()
  hydraulic_mouse.damage_multiplier = 1.25
  attack.attack_effect.stack_effect(hydraulic_mouse)

  # Simulate Double Tap stacked (crit_chance += 0.1 → 0.1; forced to 1.0 here for determinism, crit_multiplier += 1.0 → 2.0)
  var double_tap := Resource_AttackEffect.new()
  double_tap.crit_chance = 1.0 # Real Double Tap adds 0.1; overridden to 1.0 to guarantee crit in test
  double_tap.crit_multiplier = 2.0
  attack.attack_effect.stack_effect(double_tap)

  # Expected: 100 * 1.25 * 2.0 = 250
  assert_almost_eq(attack.calculate_damage_amount(true), 250.0, 0.01,
    "Crit + Hydraulic Mouse should multiply: 100 * 1.25 * 2.0 = 250")
