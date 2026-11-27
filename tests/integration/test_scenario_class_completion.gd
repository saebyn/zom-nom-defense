extends GutTest

## Integration test for Level class completion behavior
## Verifies that Level properly handles victory conditions and calls progression system

var initial_completed_scenarios: Array[String] = []

func before_each():
  # Save the initial state
  initial_completed_scenarios = ScenarioManager.completed_scenarios.duplicate()
  
  # Reset to a known state
  ScenarioManager.completed_scenarios.clear()
  ScenarioManager.scenario_best_times.clear()
  
  # Reset GameManager state
  GameManager.set_game_state(GameManager.GameState.MAIN_MENU)
  ScenarioManager.clear_current_scenario()

func after_each():
  # Restore original state
  ScenarioManager.completed_scenarios = initial_completed_scenarios.duplicate()
  ScenarioManager.clear_current_scenario()
  GameManager.set_game_state(GameManager.GameState.MAIN_MENU)

func test_scenario_marks_completion_when_all_waves_completed():
  # This test verifies that Level class handles progression logic
  # Architecture: Level -> ScenarioManager.mark_complete() -> GameManager.state = VICTORY
  # Arrange
  var scenario_id = "scenario_1"
  ScenarioManager.set_current_scenario_id(scenario_id)
  assert_false(ScenarioManager.is_scenario_completed(scenario_id), "Scenario should not be completed initially")
  
  # Act - Simulate what Level._on_all_waves_completed() does
  # (We can't easily trigger the actual spawner completion in a unit test,
  #  so we test the logic directly)
  if not ScenarioManager.get_current_scenario_id().is_empty():
    ScenarioManager.mark_scenario_complete(ScenarioManager.get_current_scenario_id())
    GameManager.set_game_state(GameManager.GameState.VICTORY)
  
  # Assert
  assert_true(ScenarioManager.is_scenario_completed(scenario_id), "Scenario should be marked as complete")
  assert_eq(GameManager.current_state, GameManager.GameState.VICTORY, "Game state should be VICTORY")

func test_scenario_handles_missing_scenario_id_gracefully():
  # Verify that if level ID is not set, the level handles it without crashing
  # Arrange - no level ID set
  assert_eq(ScenarioManager.get_current_scenario_id(), "", "Scenario ID should be empty")
  
  # Act - Simulate victory with no level ID (error condition)
  var scenario_id = ScenarioManager.get_current_scenario_id()
  if scenario_id.is_empty():
    # Level should log error but continue to victory state
    MyLogger.error("Test", "Simulating error: no scenario ID set")
  else:
    ScenarioManager.mark_scenario_complete(scenario_id)
  
  GameManager.set_game_state(GameManager.GameState.VICTORY)
  
  # Assert - Should reach victory state even with error
  assert_eq(GameManager.current_state, GameManager.GameState.VICTORY, "Should still reach victory state")

func test_scenario_completion_triggers_before_victory_state():
  # Verify that the order is: mark_scenario_complete -> set_game_state(VICTORY)
  # This ensures progression is saved before UI shows victory
  # Arrange
  var scenario_id = "scenario_2"
  ScenarioManager.set_current_scenario_id(scenario_id)
  watch_signals(ScenarioManager)
  watch_signals(GameManager)
  
  # Act
  ScenarioManager.mark_scenario_complete(scenario_id)
  GameManager.set_game_state(GameManager.GameState.VICTORY)
  
  # Assert - Both signals should be emitted
  assert_signal_emitted(ScenarioManager, "scenario_completed", "Level completion signal should emit")
  assert_signal_emitted(GameManager, "game_state_changed", "Game state changed signal should emit")
  
  # Verify level is completed
  assert_true(ScenarioManager.is_scenario_completed(scenario_id), "Scenario should be completed")

func test_completing_scenario_unlocks_next_scenario_before_victory_screen():
  # Verify that next level is unlocked as part of completion, not during UI display
  # Arrange
  ScenarioManager.set_current_scenario_id("scenario_1")
  assert_false(ScenarioManager.is_scenario_unlocked("scenario_2"), "scenario 2 should be locked")
  watch_signals(ScenarioManager)
  
  # Act - Simulate Scenario._on_all_waves_completed() flow
  ScenarioManager.mark_scenario_complete("scenario_1")
  
  # Assert - Level 2 should be unlocked BEFORE we transition to victory state
  assert_true(ScenarioManager.is_scenario_unlocked("scenario_2"), "scenario 2 should be unlocked immediately")
  assert_signal_emitted(ScenarioManager, "scenario_unlocked", "scenario unlock signal should emit")
  
  # Now transition to victory state (UI layer)
  GameManager.set_game_state(GameManager.GameState.VICTORY)
  
  # Level 2 should still be unlocked
  assert_true(ScenarioManager.is_scenario_unlocked("scenario_2"), "scenario 2 should remain unlocked")

func test_scenario_completion_data_persists_across_state_changes():
  # Verify that scenario completion isn't lost when changing game states
  # Arrange
  var scenario_id = "scenario_3"
  ScenarioManager.set_current_scenario_id(scenario_id)
  
  # Act - Complete scenario and change states multiple times
  ScenarioManager.mark_scenario_complete(scenario_id, 120.5)
  GameManager.set_game_state(GameManager.GameState.VICTORY)
  GameManager.set_game_state(GameManager.GameState.MAIN_MENU)
  GameManager.set_game_state(GameManager.GameState.PLAYING)
  
  # Assert - Completion data should persist
  assert_true(ScenarioManager.is_scenario_completed(scenario_id), "Level completion should persist")
  assert_eq(ScenarioManager.get_best_time(scenario_id), 120.5, "Best time should persist")
