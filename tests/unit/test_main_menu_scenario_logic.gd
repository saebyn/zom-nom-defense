extends GutTest

## Unit tests for main menu scenario logic
## Tests that the main menu properly clears scenario state and handles scenario selection
## 
## BUG FIX: Main menu now calls initialize_default_slot() BEFORE checking unlocked scenarios
## to prevent the save load from modifying state after the check.
## 
## NOTE: We test the logic directly without instantiating the UI scene
## to avoid dependencies on asset imports (audio files, etc.)

const ENABLE_TOOLS := "zom_nom_defense/debug/enable_tools"
const UNLOCK_ALL_SCENARIOS := "zom_nom_defense/debug/unlock_all_scenarios"

var initial_completed_scenarios: Array[String] = []
var initial_current_scenario: String = ""
var initial_enable_tools: bool
var initial_unlock_all_scenarios: bool

func before_each():
  # Save the initial state
  initial_completed_scenarios = ScenarioManager.completed_scenarios.duplicate()
  initial_current_scenario = ScenarioManager.get_current_scenario_id()
  initial_enable_tools = ProjectSettings.get_setting(ENABLE_TOOLS, false)
  initial_unlock_all_scenarios = ProjectSettings.get_setting(UNLOCK_ALL_SCENARIOS, false)
  ProjectSettings.set_setting(ENABLE_TOOLS, false)
  ProjectSettings.set_setting(UNLOCK_ALL_SCENARIOS, false)

func after_each():
  # Restore original state
  ProjectSettings.set_setting(ENABLE_TOOLS, initial_enable_tools)
  ProjectSettings.set_setting(UNLOCK_ALL_SCENARIOS, initial_unlock_all_scenarios)
  ScenarioManager.completed_scenarios = initial_completed_scenarios.duplicate()
  if initial_current_scenario.is_empty():
    ScenarioManager.clear_current_scenario()
  else:
    ScenarioManager.set_current_scenario_id(initial_current_scenario)

## Test that scenario manager clear_current_scenario works correctly
func test_scenario_manager_clears_current_scenario():
  # Arrange - Set a scenario (as would happen when loading a save)
  ScenarioManager.set_current_scenario_id("scenario_1")
  assert_eq(ScenarioManager.get_current_scenario_id(), "scenario_1", "Scenario should be set before test")
  
  # Act - Clear the scenario (as main menu _ready() does)
  ScenarioManager.clear_current_scenario()
  
  # Assert - Scenario should be cleared
  assert_eq(ScenarioManager.get_current_scenario_id(), "", "clear_current_scenario() should clear current scenario")

## Test that clearing scenario works even after loading from save
func test_clear_scenario_after_simulated_save_load():
  # Arrange - Simulate loading a save that sets a scenario (like SaveManager does)
  ScenarioManager.set_current_scenario_id("scenario_2")
  assert_eq(ScenarioManager.get_current_scenario_id(), "scenario_2", "Scenario should be set to simulate save load")
  
  # Act - Clear scenario (simulating what main menu _ready() does)
  ScenarioManager.clear_current_scenario()
  
  # Assert - Scenario should be cleared
  assert_eq(ScenarioManager.get_current_scenario_id(), "", "Should clear scenario even after simulated save load")

## Test that unlocked scenarios logic works with cleared current scenario
func test_unlocked_scenarios_with_cleared_current_scenario():
  # Arrange - Set up a state where multiple scenarios are unlocked
  ScenarioManager.completed_scenarios.clear()
  ScenarioManager.mark_scenario_complete("scenario_1")
  
  # Verify scenario 2 is now unlocked
  assert_true(ScenarioManager.is_scenario_unlocked("scenario_1"), "Scenario 1 should be unlocked")
  assert_true(ScenarioManager.is_scenario_unlocked("scenario_2"), "Scenario 2 should be unlocked after completing scenario 1")
  
  # Set a current scenario (simulating save load)
  ScenarioManager.set_current_scenario_id("scenario_1")
  assert_eq(ScenarioManager.get_current_scenario_id(), "scenario_1", "Current scenario should be set")
  
  # Act - Clear the scenario (simulating main menu _ready())
  ScenarioManager.clear_current_scenario()
  
  # Assert - Current scenario should be empty
  assert_eq(ScenarioManager.get_current_scenario_id(), "", "Current scenario should be cleared")
  
  # Verify the unlocked scenarios check still works correctly with empty current scenario
  var unlocked_scenarios: Array[String] = []
  var scenario_ids = ScenarioManager.get_all_scenario_ids()
  for scenario_id in scenario_ids:
    if ScenarioManager.is_scenario_unlocked(scenario_id):
      unlocked_scenarios.append(scenario_id)
  
  assert_gt(unlocked_scenarios.size(), 1, "Should have multiple unlocked scenarios")
  assert_true(unlocked_scenarios.has("scenario_1"), "Should include scenario_1")
  assert_true(unlocked_scenarios.has("scenario_2"), "Should include scenario_2")

## Test that only scenario_1 is unlocked for new game
func test_only_scenario_1_unlocked_for_new_game():
  # Arrange - Clear all completion data (simulating new game)
  ScenarioManager.completed_scenarios.clear()
  ScenarioManager.clear_current_scenario()
  
  # Assert - Current scenario should be empty
  assert_eq(ScenarioManager.get_current_scenario_id(), "", "Current scenario should be empty")
  
  # Verify only scenario_1 is unlocked
  var unlocked_scenarios: Array[String] = []
  var scenario_ids = ScenarioManager.get_all_scenario_ids()
  for scenario_id in scenario_ids:
    if ScenarioManager.is_scenario_unlocked(scenario_id):
      unlocked_scenarios.append(scenario_id)
  
  assert_eq(unlocked_scenarios, ["scenario_1"], "Car Defense should be the only unlocked scenario on a fresh save")

func test_unlock_all_does_not_expose_test_scenario_without_dev_tools():
  ProjectSettings.set_setting(UNLOCK_ALL_SCENARIOS, true)

  assert_does_not_have(ScenarioManager.get_all_scenario_ids(), "scenario_test",
    "Test Scenario should be hidden when dev tools are off")
  assert_false(ScenarioManager.is_scenario_unlocked("scenario_test"),
    "Unlock all should not bypass the dev tools gate")
  assert_true(ScenarioManager.is_scenario_unlocked("scenario_2"),
    "Unlock all should still bypass ordinary progression")

func test_dev_tools_expose_test_scenario_without_unlocking_story_scenarios():
  ScenarioManager.completed_scenarios.clear()
  ProjectSettings.set_setting(ENABLE_TOOLS, true)

  var scenario_ids = ScenarioManager.get_all_scenario_ids()
  assert_has(scenario_ids, "scenario_test", "Dev tools should list Test Scenario")
  assert_true(ScenarioManager.is_scenario_unlocked("scenario_test"),
    "Dev tools alone should unlock Test Scenario")
  assert_has(scenario_ids, "scenario_2", "Scenario Select should still list locked story scenarios")
  assert_false(ScenarioManager.is_scenario_unlocked("scenario_2"),
    "Dev tools should not bypass ordinary progression")

## Test that is_scenario_unlocked doesn't depend on current_scenario_id
func test_is_scenario_unlocked_independent_of_current_scenario():
  # Arrange - Complete scenario 1 to unlock scenario 2
  ScenarioManager.completed_scenarios.clear()
  ScenarioManager.mark_scenario_complete("scenario_1")
  
  # Set current scenario to something
  ScenarioManager.set_current_scenario_id("scenario_1")
  assert_eq(ScenarioManager.get_current_scenario_id(), "scenario_1", "Current scenario should be set")
  
  # Act - Check unlocked status before clearing
  var unlocked_before_clear = ScenarioManager.is_scenario_unlocked("scenario_2")
  
  # Clear current scenario
  ScenarioManager.clear_current_scenario()
  
  # Check unlocked status after clearing
  var unlocked_after_clear = ScenarioManager.is_scenario_unlocked("scenario_2")
  
  # Assert - Unlock status should be the same regardless of current_scenario_id
  assert_true(unlocked_before_clear, "Scenario 2 should be unlocked before clearing current scenario")
  assert_true(unlocked_after_clear, "Scenario 2 should still be unlocked after clearing current scenario")
  assert_eq(unlocked_before_clear, unlocked_after_clear, "Unlock status should not depend on current_scenario_id")
