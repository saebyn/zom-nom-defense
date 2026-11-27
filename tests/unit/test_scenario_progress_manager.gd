extends GutTest

## Unit tests for ScenarioManager autoload
## Tests level completion tracking, unlock logic, and persistence

var test_save_path = "user://test_level_progression.save"

func before_each():
  # Reset the ScenarioManager state before each test
  ScenarioManager.completed_scenarios.clear()
  ScenarioManager.scenario_best_times.clear()
  
  # Clean up any test save file
  if FileAccess.file_exists(test_save_path):
    var dir = DirAccess.open("user://")
    if dir:
      dir.remove(test_save_path.replace("user://", ""))

func after_each():
  # Clean up test save file
  if FileAccess.file_exists(test_save_path):
    var dir = DirAccess.open("user://")
    if dir:
      dir.remove(test_save_path.replace("user://", ""))

func test_scenario_1_is_always_unlocked():
  # Act & Assert
  assert_true(ScenarioManager.is_scenario_unlocked("scenario_1"), "Scenario 1 should always be unlocked")

func test_scenario_2_locked_by_default():
  # Act & Assert
  assert_false(ScenarioManager.is_scenario_unlocked("scenario_2"), "Scenario 2 should be locked initially")

func test_completing_scenario_1_unlocks_scenario_2():
  # Arrange - Level 2 should be locked initially
  assert_false(ScenarioManager.is_scenario_unlocked("scenario_2"), "Scenario 2 should be locked initially")
  
  # Act - Complete scenario 1
  ScenarioManager.mark_scenario_complete("scenario_1")
  
  # Assert - Level 2 should now be unlocked
  assert_true(ScenarioManager.is_scenario_unlocked("scenario_2"), "Scenario 2 should be unlocked after completing scenario 1")

func test_mark_scenario_complete_adds_to_completed_list():
  # Arrange
  var initial_count = ScenarioManager.completed_scenarios.size()
  
  # Act
  ScenarioManager.mark_scenario_complete("scenario_1")
  
  # Assert
  assert_eq(ScenarioManager.completed_scenarios.size(), initial_count + 1, "Completed levels should increase by 1")
  assert_true(ScenarioManager.completed_scenarios.has("scenario_1"), "Scenario 1 should be in completed list")

func test_is_scenario_completed_returns_correct_status():
  # Arrange - Level not completed
  assert_false(ScenarioManager.is_scenario_completed("scenario_1"), "Scenario 1 should not be completed initially")
  
  # Act - Complete level
  ScenarioManager.mark_scenario_complete("scenario_1")
  
  # Assert - Level is completed
  assert_true(ScenarioManager.is_scenario_completed("scenario_1"), "Scenario 1 should be completed")

func test_best_time_tracking():
  # Arrange - No best time initially
  assert_eq(ScenarioManager.get_best_time("scenario_1"), 0.0, "Best time should be 0.0 initially")
  
  # Act - Complete with a time
  ScenarioManager.mark_scenario_complete("scenario_1", 120.5)
  
  # Assert - Best time is recorded
  assert_eq(ScenarioManager.get_best_time("scenario_1"), 120.5, "Best time should be recorded")

func test_best_time_only_updates_when_better():
  # Arrange - Set initial best time
  ScenarioManager.mark_scenario_complete("scenario_1", 120.5)
  
  # Act - Complete with worse time
  ScenarioManager.mark_scenario_complete("scenario_1", 150.0)
  
  # Assert - Best time should still be 120.5
  assert_eq(ScenarioManager.get_best_time("scenario_1"), 120.5, "Best time should not update with worse time")
  
  # Act - Complete with better time
  ScenarioManager.mark_scenario_complete("scenario_1", 100.0)
  
  # Assert - Best time should update to 100.0
  assert_eq(ScenarioManager.get_best_time("scenario_1"), 100.0, "Best time should update with better time")

func test_get_scenario_metadata_returns_correct_data():
  # Act
  var metadata = ScenarioManager.get_scenario_metadata("scenario_1")
  
  # Assert
  assert_true(metadata.has("name"), "Metadata should have name field")
  assert_true(metadata.has("scene_path"), "Metadata should have scene_path field")
  assert_true(metadata.has("description"), "Metadata should have description field")

func test_get_all_scenario_ids_returns_sorted_list():
  # Act
  var scenario_ids = ScenarioManager.get_all_scenario_ids()
  
  # Assert
  assert_gt(scenario_ids.size(), 0, "Should have at least one scenario")
  assert_true(scenario_ids.has("scenario_1"), "Should include scenario_1")
  assert_true(scenario_ids.has("scenario_2"), "Should include scenario_2")
  # Check if sorted
  for i in range(scenario_ids.size() - 1):
    assert_true(scenario_ids[i] <= scenario_ids[i + 1], "Scenario IDs should be sorted")

func test_get_unlock_requirement_returns_previous_scenario():
  # Act & Assert
  assert_eq(ScenarioManager.get_unlock_requirement("scenario_1"), "", "Scenario 1 has no requirement")
  assert_eq(ScenarioManager.get_unlock_requirement("scenario_2"), "scenario_1", "Scenario 2 requires scenario 1")
  assert_eq(ScenarioManager.get_unlock_requirement("scenario_4"), "scenario_2", "Scenario 4 requires scenario 2")

func test_completing_same_level_twice_doesnt_duplicate():
  # Act
  ScenarioManager.mark_scenario_complete("scenario_1")
  ScenarioManager.mark_scenario_complete("scenario_1")
  
  # Assert - Should only appear once
  var count = 0
  for scenario in ScenarioManager.completed_scenarios:
    if scenario == "scenario_1":
      count += 1
  assert_eq(count, 1, "Scenario 1 should only appear once in completed list")

func test_unlock_progression_chain():
  # Start with all scenarios locked except scenario 1
  assert_true(ScenarioManager.is_scenario_unlocked("scenario_1"), "Scenario 1 should be unlocked")
  assert_false(ScenarioManager.is_scenario_unlocked("scenario_2"), "Scenario 2 should be locked")
  assert_false(ScenarioManager.is_scenario_unlocked("scenario_4"), "Scenario 4 should be locked")
  
  # Complete scenario 1 - should unlock scenario 2
  ScenarioManager.mark_scenario_complete("scenario_1")
  assert_true(ScenarioManager.is_scenario_unlocked("scenario_2"), "Scenario 2 should be unlocked")
  assert_false(ScenarioManager.is_scenario_unlocked("scenario_4"), "Scenario 4 should still be locked")
  
  # Complete scenario 2 - should unlock scenario 4
  ScenarioManager.mark_scenario_complete("scenario_2")
  assert_true(ScenarioManager.is_scenario_unlocked("scenario_4"), "Scenario 4 should be unlocked")
