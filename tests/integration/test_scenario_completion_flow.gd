extends GutTest

## Integration test for the complete scenario victory and progression flow
## Tests the interaction between GameManager, ScenarioManager, and victory conditions
##
## Architecture note: 
## - Scenario class calls ScenarioManager.mark_scenario_complete() when victory occurs
## - GameManager tracks current scenario ID and game state
## - VictoryMenu UI responds to VICTORY state for display only (no game logic)

var initial_completed_scenarios: Array[String] = []

func before_each():
  # Save the initial state
  initial_completed_scenarios = ScenarioManager.completed_scenarios.duplicate()
  
  # Reset to a known state
  ScenarioManager.completed_scenarios.clear()
  ScenarioManager.scenario_best_times.clear()
  
  # Reset state
  GameManager.set_game_state(GameManager.GameState.MAIN_MENU)
  ScenarioManager.clear_current_scenario()

func after_each():
  # Restore original state
  ScenarioManager.completed_scenarios = initial_completed_scenarios.duplicate()
  ScenarioManager.clear_current_scenario()
  GameManager.set_game_state(GameManager.GameState.MAIN_MENU)

func test_scenario_id_is_set_when_starting_scenario():
  # Arrange
  var scenario_id = "scenario_1"
  
  # Act
  ScenarioManager.set_current_scenario_id(scenario_id)
  
  # Assert
  assert_eq(ScenarioManager.get_current_scenario_id(), scenario_id, "Scenario ID should be set correctly")

func test_victory_marks_scenario_complete():
  # This test verifies the complete flow:
  # 1. Set current scenario ID (simulates scenario selection)
  # 2. Trigger victory state
  # 3. Verify scenario is marked as complete
  # Arrange
  var scenario_id = "scenario_1"
  ScenarioManager.set_current_scenario_id(scenario_id)
  assert_false(ScenarioManager.is_scenario_completed(scenario_id), "Scenario should not be completed initially")
  
  # Act
  ScenarioManager.mark_scenario_complete(scenario_id)
  
  # Assert
  assert_true(ScenarioManager.is_scenario_completed(scenario_id), "Scenario should be marked as complete")
  assert_has(ScenarioManager.completed_scenarios, scenario_id, "Scenario ID should be in completed_scenarios array")

func test_completing_scenario_1_unlocks_scenario_2():
  # Arrange
  assert_true(ScenarioManager.is_scenario_unlocked("scenario_1"), "Scenario 1 should always be unlocked")
  assert_false(ScenarioManager.is_scenario_unlocked("scenario_2"), "Scenario 2 should be locked initially")
  
  # Act
  ScenarioManager.set_current_scenario_id("scenario_1")
  ScenarioManager.mark_scenario_complete("scenario_1")
  
  # Assert
  assert_true(ScenarioManager.is_scenario_unlocked("scenario_2"), "Scenario 2 should be unlocked after completing scenario 1")

func test_scenario_completion_records_time():
  # Arrange
  var scenario_id = "scenario_1"
  var completion_time = 120.5
  ScenarioManager.set_current_scenario_id(scenario_id)
  
  # Act
  ScenarioManager.mark_scenario_complete(scenario_id, completion_time)
  
  # Assert
  assert_true(ScenarioManager.is_scenario_completed(scenario_id), "Scenario should be completed")
  assert_eq(ScenarioManager.get_best_time(scenario_id), completion_time, "Best time should be recorded")

func test_better_time_updates_best_time():
  # Arrange
  var scenario_id = "scenario_1"
  ScenarioManager.set_current_scenario_id(scenario_id)
  ScenarioManager.mark_scenario_complete(scenario_id, 150.0)
  
  # Act - complete with better time
  ScenarioManager.mark_scenario_complete(scenario_id, 100.0)
  
  # Assert
  assert_eq(ScenarioManager.get_best_time(scenario_id), 100.0, "Best time should be updated to faster time")

func test_worse_time_does_not_update_best_time():
  # Arrange
  var scenario_id = "scenario_1"
  ScenarioManager.set_current_scenario_id(scenario_id)
  ScenarioManager.mark_scenario_complete(scenario_id, 100.0)
  
  # Act - complete with worse time
  ScenarioManager.mark_scenario_complete(scenario_id, 150.0)
  
  # Assert
  assert_eq(ScenarioManager.get_best_time(scenario_id), 100.0, "Best time should remain the faster time")

func test_scenario_id_persists_across_state_changes():
  # Arrange
  var scenario_id = "scenario_1"
  
  # Act
  ScenarioManager.set_current_scenario_id(scenario_id)
  GameManager.set_game_state(GameManager.GameState.PLAYING)
  GameManager.set_game_state(GameManager.GameState.VICTORY)
  
  # Assert
  assert_eq(ScenarioManager.get_current_scenario_id(), scenario_id, "Scenario ID should persist across state changes")

func test_sequential_scenario_unlocking():
  # Test that scenarios unlock sequentially as previous scenarios are completed
  # Initially only scenario 1 should be unlocked
  assert_true(ScenarioManager.is_scenario_unlocked("scenario_1"), "Scenario 1 should be unlocked")
  assert_false(ScenarioManager.is_scenario_unlocked("scenario_2"), "Scenario 2 should be locked")
  assert_false(ScenarioManager.is_scenario_unlocked("scenario_4"), "Scenario 4 should be locked")
  
  # Complete scenario 1
  ScenarioManager.set_current_scenario_id("scenario_1")
  ScenarioManager.mark_scenario_complete("scenario_1")
  
  # Now scenario 2 should be unlocked
  assert_true(ScenarioManager.is_scenario_unlocked("scenario_2"), "Scenario 2 should be unlocked after completing scenario 1")
  assert_false(ScenarioManager.is_scenario_unlocked("scenario_4"), "Scenario 4 should still be locked")
  
  # Complete scenario 2
  ScenarioManager.set_current_scenario_id("scenario_2")
  ScenarioManager.mark_scenario_complete("scenario_2")
  
  # Now scenario 4 should be unlocked
  assert_true(ScenarioManager.is_scenario_unlocked("scenario_4"), "Scenario 4 should be unlocked after completing scenario 2")

func test_game_manager_returns_empty_string_when_no_scenario_set():
  # Arrange - no scenario ID set
  # Assert
  assert_eq(ScenarioManager.get_current_scenario_id(), "", "Should return empty string when no scenario is set")

func test_scenario_completion_signal_is_emitted():
  # Arrange
  var scenario_id := "scenario_1"
  watch_signals(ScenarioManager)
  
  # Act
  ScenarioManager.mark_scenario_complete(scenario_id)
  
  # Assert
  assert_signal_emitted(ScenarioManager, "scenario_completed", "scenario_completed signal should be emitted")
  assert_signal_emitted_with_parameters(ScenarioManager, "scenario_completed", [scenario_id])

func test_scenario_unlocked_signal_is_emitted():
  # Arrange
  watch_signals(ScenarioManager)
  
  # Act - Complete scenario 1 which should unlock scenario 2
  ScenarioManager.mark_scenario_complete("scenario_1")
  
  # Assert
  assert_signal_emitted(ScenarioManager, "scenario_unlocked", "scenario_unlocked signal should be emitted")
  assert_signal_emitted_with_parameters(ScenarioManager, "scenario_unlocked", ["scenario_2"])
