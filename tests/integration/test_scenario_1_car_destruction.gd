extends GutTest

# Exercise the real scene and health wiring without starting its tutorial/waves.
class TestScenario extends "res://Stages/Scenarios/scenario_1.gd":
  func _enter_tree() -> void:
    pass

  func _ready() -> void:
    pass

var scenario: Node3D
var saved_audio_configs: Dictionary

func before_each() -> void:
  scenario = load("res://Stages/Scenarios/scenario_1.tscn").instantiate()
  scenario.set_script(TestScenario)
  # Keep the real car/health/signal wiring, isolate unrelated survivor AI and waves.
  scenario.get_node("System_EnemySpawner").free()
  var original_survivor: Node3D = scenario.get_node("Survivor1")
  var survivor_position := original_survivor.position
  original_survivor.free()
  var survivor := Node3D.new()
  survivor.name = "Survivor1"
  survivor.position = survivor_position
  scenario.add_child(survivor)
  saved_audio_configs = AudioManager.sound_effect_configs.duplicate()
  # BUILDING_DESTROYED currently has no configured sample. Supply a silent test
  # stream to verify that playback, when configured, outlives the car.
  var config := Resource_SoundEffect.new()
  var stream := AudioStreamWAV.new()
  var silence := PackedByteArray()
  silence.resize(44100)
  stream.data = silence
  config.samples = [stream]
  AudioManager.sound_effect_configs[Resource_SoundEffect.SoundEffect.BUILDING_DESTROYED] = config
  add_child_autofree(scenario)

func after_each() -> void:
  AudioManager.sound_effect_configs.assign(saved_audio_configs)

func test_lethal_damage_removes_car_but_preserves_fall_and_audio() -> void:
  var car: Node3D = scenario.car
  var car_transform := car.global_transform
  var survivor: Node3D = scenario.survivor
  var start_y := survivor.position.y
  var health: Component_Health = car.get_node("Health")
  var audio: AudioStreamPlayer3D = health.audio_player
  watch_signals(AudioManager)

  var effect: Node3D = car.get_node("DestructionEffect")
  assert_false(effect.get_node("Debris").emitting, "Effect waits for death")
  assert_false(effect.get_node("Flash").visible)
  health.take_damage(1, "test")
  assert_eq(effect.get_parent(), car, "Ordinary hits do not detach the effect")
  assert_false(effect.get_node("Debris").emitting)
  health.take_damage(health.hitpoints, "test")
  assert_true(health.dead)
  assert_true(car.is_queued_for_deletion(), "Gameplay geometry is removed immediately")
  assert_eq(effect.get_parent(), scenario)
  assert_eq(effect.global_transform, car_transform)
  assert_eq(effect.find_children("*", "CollisionObject3D").size(), 0)
  assert_signal_emitted_with_parameters(AudioManager, "sound_played", [health.death_sound])
  assert_eq(audio.get_parent(), scenario, "Death audio survives car removal")
  effect.destroyed("duplicate")
  scenario.car_destroyed("duplicate")
  assert_eq(scenario.find_children("DestructionEffect*", "Node3D", false, false).size(), 1)

  await wait_process_frames(2)
  assert_false(is_instance_valid(car))
  assert_true(is_instance_valid(audio))
  assert_true(audio.playing, "Existing death sound continues after the car is freed")
  await wait_seconds(scenario.survivor_fall_duration + 0.1)
  assert_almost_eq(survivor.position.y, start_y + scenario.survivor_fall_y, 0.01)
  assert_false(effect.get_node("Flash").visible)
  await wait_seconds(1.5)
  assert_false(is_instance_valid(effect), "One-shot debris cleans up the entire effect")

func test_scenario_removal_cleans_up_active_effect() -> void:
  var effect: Node3D = scenario.car.get_node("DestructionEffect")
  scenario.car.get_node("Health").take_damage(5000, "test")
  assert_eq(effect.get_parent(), scenario)
  scenario.queue_free()
  await wait_process_frames(2)
  assert_false(is_instance_valid(effect))
