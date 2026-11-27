extends GutTest

## Unit tests for ScenarioManager runtime state management
## Tests scenario ID tracking, wave tracking, and their integration with persistent progression

var initial_completed_scenarios: Array[String] = []

func before_each():
  # Save the initial state
  initial_completed_scenarios = ScenarioManager.completed_scenarios.duplicate()
  
  # Reset to a known state
  ScenarioManager.clear_current_scenario()
  ScenarioManager.completed_scenarios.clear()
  ScenarioManager.scenario_best_times.clear()

func after_each():
  # Restore original state
  ScenarioManager.completed_scenarios = initial_completed_scenarios.duplicate()
  ScenarioManager.clear_current_scenario()

## Runtime State Tests

func test_set_and_get_current_scenario_id():
  # Arrange
  var scenario_id = "scenario_1"
  
  # Act
  ScenarioManager.set_current_scenario_id(scenario_id)
  
  # Assert
  assert_eq(ScenarioManager.get_current_scenario_id(), scenario_id, "Should return the scenario ID that was set")

func test_scenario_id_starts_empty():
  # Assert
  assert_eq(ScenarioManager.get_current_scenario_id(), "", "Scenario ID should start empty")

func test_clear_current_scenario():
  # Arrange
  ScenarioManager.set_current_scenario_id("scenario_3")
  assert_eq(ScenarioManager.get_current_scenario_id(), "scenario_3", "Scenario should be set")
  watch_signals(ScenarioManager)
  
  # Act
  ScenarioManager.clear_current_scenario()
  
  # Assert
  assert_eq(ScenarioManager.get_current_scenario_id(), "", "Scenario ID should be cleared")
  assert_signal_emitted(ScenarioManager, "scenario_ended", "scenario_ended signal should be emitted")

func test_wave_tracking():
  # Arrange
  ScenarioManager.set_current_scenario_id("scenario_1")
  
  # Act
  ScenarioManager.set_current_wave(5)
  
  # Assert
  assert_eq(ScenarioManager.get_current_wave(), 5, "Should track current wave")

func test_wave_changed_signal():
  # Arrange
  ScenarioManager.set_current_scenario_id("scenario_1")
  watch_signals(ScenarioManager)
  
  # Act
  ScenarioManager.set_current_wave(3)
  
  # Assert
  assert_signal_emitted(ScenarioManager, "wave_changed", "wave_changed signal should be emitted")
  assert_signal_emitted_with_parameters(ScenarioManager, "wave_changed", ["scenario_1", 3])

func test_changing_scenario_resets_wave():
  # Arrange
  ScenarioManager.set_current_scenario_id("scenario_1")
  ScenarioManager.set_current_wave(5)
  assert_eq(ScenarioManager.get_current_wave(), 5, "Wave should be 5")
  
  # Act - Change to different scenario
  ScenarioManager.set_current_scenario_id("scenario_2")
  
  # Assert
  assert_eq(ScenarioManager.get_current_wave(), 0, "Wave should reset to 0 when changing scenarios")

func test_clearing_scenario_resets_wave():
  # Arrange
  ScenarioManager.set_current_scenario_id("scenario_1")
  ScenarioManager.set_current_wave(7)
  
  # Act
  ScenarioManager.clear_current_scenario()
  
  # Assert
  assert_eq(ScenarioManager.get_current_wave(), 0, "Wave should reset to 0 when clearing scenario")

## Integration Tests - Runtime + Persistent State

func test_completing_current_scenario():
  # Test that you can complete the currently active scenario
  # Arrange
  var scenario_id = "scenario_1"
  ScenarioManager.set_current_scenario_id(scenario_id)
  
  # Act
  ScenarioManager.mark_scenario_complete(scenario_id)
  
  # Assert
  assert_true(ScenarioManager.is_scenario_completed(scenario_id), "Scenario should be marked complete")
  assert_eq(ScenarioManager.get_current_scenario_id(), scenario_id, "Current scenario ID should remain set")

func test_runtime_state_independent_of_completion():
  # Verify that completion status doesn't affect current scenario tracking
  # Arrange
  ScenarioManager.set_current_scenario_id("scenario_1")
  ScenarioManager.mark_scenario_complete("scenario_1")
  
  # Act - Play the same scenario again
  ScenarioManager.clear_current_scenario()
  ScenarioManager.set_current_scenario_id("scenario_1")
  
  # Assert
  assert_eq(ScenarioManager.get_current_scenario_id(), "scenario_1", "Can replay completed scenario")
  assert_true(ScenarioManager.is_scenario_completed("scenario_1"), "Completion status persists")

func test_wave_progress_during_scenario_replay():
  # Verify wave tracking works correctly when replaying scenarios
  # Arrange
  ScenarioManager.mark_scenario_complete("scenario_1") # Complete it once
  
  # Act - Play it again
  ScenarioManager.set_current_scenario_id("scenario_1")
  ScenarioManager.set_current_wave(3)
  
  # Assert
  assert_eq(ScenarioManager.get_current_wave(), 3, "Wave tracking should work in replay")
