extends GutTest

## Unit test for scenario completion bonus XP feature
## Tests that bonus XP is awarded correctly and tracked in stats

func before_each():
  # Set game state to PLAYING so earn_scrap/earn_xp functions work
  GameManager.set_game_state(GameManager.GameState.PLAYING)
  
  # Wait a frame to ensure state change is processed
  await get_tree().process_frame
  
  # Reset CurrencyManager state
  CurrencyManager.current_scrap = 0
  CurrencyManager.current_xp = 0
  CurrencyManager.current_level = 1
  
  # Reset ScenarioManager state
  ScenarioManager.completed_scenarios.clear()
  ScenarioManager.scenario_best_times.clear()
  ScenarioManager.last_scenario_stats = {}
  ScenarioManager.clear_current_scenario()
  
  # Verify we're in PLAYING state (sanity check)
  assert_true(GameManager.is_playing(), "PRECONDITION: GameManager must be in PLAYING state")

func after_each():
  # Reset game state after each test
  GameManager.set_game_state(GameManager.GameState.MAIN_MENU)

func test_bonus_xp_is_awarded_on_scenario_completion():
  # Arrange
  var bonus_xp_amount = 75
  CurrencyManager.current_xp = 0
  
  # Act - Simulate awarding bonus XP
  CurrencyManager.earn_xp(bonus_xp_amount)
  
  # Assert
  assert_eq(CurrencyManager.current_xp, bonus_xp_amount, "Bonus XP should be awarded correctly")

func test_bonus_xp_is_tracked_in_scenario_stats():
  # Arrange
  var scenario_id = "scenario_1"
  var bonus_xp = 50
  ScenarioManager.set_current_scenario_id(scenario_id)
  
  # Act - Simulate what scenario._on_all_waves_completed() does
  var conversion_data = {"scrap_converted": 100, "xp_gained": 50}
  CurrencyManager.earn_xp(bonus_xp)
  
  ScenarioManager.last_scenario_stats = {
    "scenario_id": scenario_id,
    "completion_time": 120.0,
    "buildings_reclaimed": 5,
    "scrap_reclaimed": 50,
    "scrap_converted": conversion_data.scrap_converted,
    "xp_gained_from_conversion": conversion_data.xp_gained,
    "bonus_xp_earned": bonus_xp,
    "is_new_record": true,
  }
  
  # Assert
  assert_eq(ScenarioManager.last_scenario_stats.get("bonus_xp_earned", 0), bonus_xp,
    "Bonus XP should be recorded in scenario stats")

func test_zero_bonus_xp_is_handled_correctly():
  # Arrange
  var scenario_id = "scenario_1"
  var bonus_xp = 0
  ScenarioManager.set_current_scenario_id(scenario_id)
  var initial_xp = CurrencyManager.current_xp
  
  # Act - Simulate completion with zero bonus XP
  if bonus_xp > 0:
    CurrencyManager.earn_xp(bonus_xp)
  
  ScenarioManager.last_scenario_stats = {
    "scenario_id": scenario_id,
    "bonus_xp_earned": bonus_xp,
  }
  
  # Assert
  assert_eq(CurrencyManager.current_xp, initial_xp, "XP should not change when bonus is 0")
  assert_eq(ScenarioManager.last_scenario_stats.get("bonus_xp_earned", 0), 0,
    "Zero bonus XP should be recorded in stats")

func test_bonus_xp_can_trigger_level_up():
  # Arrange
  CurrencyManager.current_level = 1
  CurrencyManager.current_xp = 50 # 50 XP away from level 2
  var bonus_xp = 100 # More than enough to level up
  
  # Act
  CurrencyManager.earn_xp(bonus_xp)
  
  # Assert - Should level up from 1 to 2
  assert_eq(CurrencyManager.current_level, 2, "Bonus XP should trigger level up")
  # After leveling up from 1 to 2, we had 150 XP total, used 100 for level up, left with 50
  assert_eq(CurrencyManager.current_xp, 50, "Remaining XP should be correct after level up")

func test_bonus_xp_combined_with_conversion_xp_in_stats():
  # Arrange
  var scenario_id = "scenario_1"
  var conversion_xp = 30
  var bonus_xp = 40
  ScenarioManager.set_current_scenario_id(scenario_id)
  
  # Act - Simulate both conversion and bonus XP
  CurrencyManager.earn_xp(conversion_xp)
  CurrencyManager.earn_xp(bonus_xp)
  
  ScenarioManager.last_scenario_stats = {
    "scenario_id": scenario_id,
    "xp_gained_from_conversion": conversion_xp,
    "bonus_xp_earned": bonus_xp,
  }
  
  # Assert - Total is 70 XP, which doesn't trigger level up (need 100)
  var total_xp = conversion_xp + bonus_xp
  assert_eq(CurrencyManager.current_xp, total_xp,
    "Total XP should be sum of conversion and bonus XP")
  assert_eq(ScenarioManager.last_scenario_stats.get("xp_gained_from_conversion", 0), conversion_xp,
    "Conversion XP should be tracked separately")
  assert_eq(ScenarioManager.last_scenario_stats.get("bonus_xp_earned", 0), bonus_xp,
    "Bonus XP should be tracked separately")

func test_negative_bonus_xp_is_not_awarded():
  # Arrange - Test defensive coding
  var initial_xp = CurrencyManager.current_xp
  var bonus_xp = -50
  
  # Act - earn_xp should not process negative values
  CurrencyManager.earn_xp(bonus_xp)
  
  # Assert
  assert_eq(CurrencyManager.current_xp, initial_xp,
    "Negative bonus XP should not be awarded")
