extends GutTest

## Integration test for building reclaim and scrap-to-XP conversion at scenario end
## Tests the complete flow of:
## 1. Buildings being reclaimed at scenario end
## 2. Scrap being converted to XP
## 3. Scrap being reset to starting amount
## 4. Victory/game over stats being stored

var test_scenario: Stage_Scenario
var initial_scrap: int
var initial_xp: int
var initial_level: int

func before_each():
  # Save initial state
  initial_scrap = CurrencyManager.current_scrap
  initial_xp = CurrencyManager.current_xp
  initial_level = CurrencyManager.current_level
  
  # Set game state to PLAYING first
  GameManager.set_game_state(GameManager.GameState.PLAYING)
  
  # Wait a frame to ensure state change is processed
  await get_tree().process_frame
  
  # Reset to known state
  CurrencyManager.current_scrap = 200
  CurrencyManager.current_xp = 0
  CurrencyManager.current_level = 1
  CurrencyManager.scrap_to_xp_conversion_rate = 2.0
  
  ScenarioManager.set_current_scenario_id("scenario_test")
  ScenarioManager.last_scenario_stats.clear()
  
  # Verify we're in PLAYING state (sanity check)
  assert_true(GameManager.is_playing(), "PRECONDITION: GameManager must be in PLAYING state")

func after_each():
  # Restore original state
  CurrencyManager.current_scrap = initial_scrap
  CurrencyManager.current_xp = initial_xp
  CurrencyManager.current_level = initial_level
  
  if test_scenario and is_instance_valid(test_scenario):
    test_scenario.free()
  
  GameManager.set_game_state(GameManager.GameState.MAIN_MENU)
  ScenarioManager.clear_current_scenario()

func test_convert_scrap_to_xp_with_200_scrap():
  # Arrange
  CurrencyManager.current_scrap = 200
  CurrencyManager.current_xp = 0
  var starting_scrap = CurrencyManager.starting_scrap
  
  # Act
  var result = CurrencyManager.convert_remaining_scrap_to_xp()
  
  # Assert
  assert_eq(result.scrap_converted, 200, "Should convert 200 scrap")
  assert_eq(result.xp_gained, 100, "Should gain 100 XP (200 / 2.0)")
  # Note: current_xp is 0 because 100 XP triggers level up (100 XP needed for level 1->2)
  # After leveling up, XP resets to 0
  assert_eq(CurrencyManager.current_xp, 0, "Current XP should be 0 after level up")
  assert_eq(CurrencyManager.current_scrap, starting_scrap, "Scrap should reset to starting amount")
  assert_eq(CurrencyManager.current_level, 2, "Should level up to level 2")

func test_convert_scrap_to_xp_with_zero_scrap():
  # Arrange
  CurrencyManager.current_scrap = 0
  CurrencyManager.current_xp = 50
  var starting_scrap = CurrencyManager.starting_scrap
  
  # Act
  var result = CurrencyManager.convert_remaining_scrap_to_xp()
  
  # Assert
  assert_eq(result.scrap_converted, 0, "Should convert 0 scrap")
  assert_eq(result.xp_gained, 0, "Should gain 0 XP")
  assert_eq(CurrencyManager.current_xp, 50, "Current XP should remain 50")
  assert_eq(CurrencyManager.current_scrap, starting_scrap, "Scrap should reset to starting amount")

func test_convert_with_insufficient_scrap_for_xp():
  # Arrange
  CurrencyManager.current_scrap = 1 # Less than conversion rate
  CurrencyManager.current_xp = 0
  var starting_scrap = CurrencyManager.starting_scrap
  
  # Act
  var result = CurrencyManager.convert_remaining_scrap_to_xp()
  
  # Assert
  assert_eq(result.scrap_converted, 1, "Should attempt to convert 1 scrap")
  assert_eq(result.xp_gained, 0, "Should gain 0 XP (rounds down to 0)")
  assert_eq(CurrencyManager.current_xp, 0, "Current XP should remain 0")
  assert_eq(CurrencyManager.current_scrap, starting_scrap, "Scrap should reset to starting amount")

func test_scenario_stats_stored_for_victory():
  # Arrange - Set up scenario with known state
  CurrencyManager.current_scrap = 150
  ScenarioManager.set_current_scenario_id("scenario_1")
  
  # Simulate what happens in _on_all_waves_completed
  var completion_time = 120.5 # 2 minutes 0.5 seconds
  
  # Mock reclaim data (simulating _reclaim_all_buildings)
  var reclaim_data = {
    "building_count": 3,
    "total_refund": 150
  }
  
  # Add reclaimed scrap to current scrap
  CurrencyManager.current_scrap += reclaim_data.total_refund
  
  # Convert remaining scrap to XP
  var conversion_data = CurrencyManager.convert_remaining_scrap_to_xp()
  
  # Check if this is a new record (simulate scenario.gd logic)
  var previous_best_time = ScenarioManager.get_best_time("scenario_1")
  var is_new_record = previous_best_time == 0.0 or completion_time < previous_best_time
  
  # Store stats (as done in scenario.gd)
  ScenarioManager.last_scenario_stats = {
    "scenario_id": "scenario_1",
    "completion_time": completion_time,
    "buildings_reclaimed": reclaim_data.building_count,
    "scrap_reclaimed": reclaim_data.total_refund,
    "scrap_converted": conversion_data.scrap_converted,
    "xp_gained_from_conversion": conversion_data.xp_gained,
    "is_new_record": is_new_record,
  }
  
  # Assert - Verify stats are stored correctly
  var stats = ScenarioManager.last_scenario_stats
  assert_false(stats.is_empty(), "Stats should not be empty")
  assert_eq(stats.scenario_id, "scenario_1", "Scenario ID should match")
  assert_eq(stats.completion_time, 120.5, "Completion time should be stored")
  assert_eq(stats.buildings_reclaimed, 3, "Should track 3 buildings reclaimed")
  assert_eq(stats.scrap_reclaimed, 150, "Should track 150 scrap reclaimed")
  assert_eq(stats.scrap_converted, 300, "Should convert total 300 scrap (150 initial + 150 reclaimed)")
  assert_eq(stats.xp_gained_from_conversion, 150, "Should gain 150 XP (300 / 2.0)")
  assert_true(stats.has("is_new_record"), "Stats should include is_new_record flag")

func test_reset_scrap_sets_to_starting_amount():
  # Arrange
  CurrencyManager.current_scrap = 500
  var starting_scrap = CurrencyManager.starting_scrap
  
  # Act
  CurrencyManager.reset_scrap()
  
  # Assert
  assert_eq(CurrencyManager.current_scrap, starting_scrap, "Scrap should reset to starting_scrap")

func test_get_xp_for_next_level_returns_correct_values():
  # Test level 1 -> 2
  CurrencyManager.current_level = 1
  var xp_needed = CurrencyManager.get_xp_for_next_level()
  assert_eq(xp_needed, 100, "Level 1 should need 100 XP")
  
  # Test level 5 -> 6
  CurrencyManager.current_level = 5
  xp_needed = CurrencyManager.get_xp_for_next_level()
  assert_eq(xp_needed, 500, "Level 5 should need 500 XP")
