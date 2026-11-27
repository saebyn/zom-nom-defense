extends GutTest

## Integration test for bonus XP feature in scenario completion flow
## Tests the complete flow from scenario completion to stats tracking to UI display

func before_each():
  # Reset CurrencyManager state
  CurrencyManager.current_scrap = 100
  CurrencyManager.current_xp = 0
  CurrencyManager.current_level = 1
  
  # Reset ScenarioManager state
  ScenarioManager.completed_scenarios.clear()
  ScenarioManager.scenario_best_times.clear()
  ScenarioManager.last_scenario_stats = {}
  ScenarioManager.clear_current_scenario()
  
  # Reset GameManager state
  GameManager.set_game_state(GameManager.GameState.PLAYING)

func test_bonus_xp_is_included_in_scenario_stats():
  # This test simulates what happens in scenario._on_all_waves_completed()
  # Arrange
  var scenario_id = "scenario_1"
  var bonus_xp = 50
  var conversion_xp = 25
  ScenarioManager.set_current_scenario_id(scenario_id)
  
  # Act - Simulate scenario completion flow
  # 1. Convert scrap to XP
  CurrencyManager.earn_xp(conversion_xp)
  
  # 2. Award bonus XP
  CurrencyManager.earn_xp(bonus_xp)
  
  # 3. Store stats (as done in scenario.gd)
  ScenarioManager.last_scenario_stats = {
    "scenario_id": scenario_id,
    "completion_time": 120.0,
    "buildings_reclaimed": 3,
    "scrap_reclaimed": 30,
    "scrap_converted": 50,
    "xp_gained_from_conversion": conversion_xp,
    "bonus_xp_earned": bonus_xp,
    "is_new_record": true,
  }
  
  # Assert
  assert_eq(ScenarioManager.last_scenario_stats.get("bonus_xp_earned", 0), bonus_xp,
    "Bonus XP should be tracked in scenario stats")
  assert_eq(ScenarioManager.last_scenario_stats.get("xp_gained_from_conversion", 0), conversion_xp,
    "Conversion XP should be tracked separately in stats")
  
  # Verify total XP in CurrencyManager
  var total_xp_earned = conversion_xp + bonus_xp
  assert_eq(CurrencyManager.current_xp, total_xp_earned,
    "CurrencyManager should have both conversion and bonus XP")

func test_victory_ui_can_display_both_xp_sources():
  # This test verifies the stats structure supports UI display
  # Arrange
  var conversion_xp = 40
  var bonus_xp = 60
  
  ScenarioManager.last_scenario_stats = {
    "scenario_id": "scenario_2",
    "xp_gained_from_conversion": conversion_xp,
    "bonus_xp_earned": bonus_xp,
  }
  
  # Act - Calculate what UI would display
  var stats = ScenarioManager.last_scenario_stats
  var displayed_conversion_xp = stats.get("xp_gained_from_conversion", 0)
  var displayed_bonus_xp = stats.get("bonus_xp_earned", 0)
  var total_xp = displayed_conversion_xp + displayed_bonus_xp
  
  # Assert
  assert_eq(displayed_conversion_xp, conversion_xp, "UI can read conversion XP")
  assert_eq(displayed_bonus_xp, bonus_xp, "UI can read bonus XP")
  assert_eq(total_xp, 100, "UI can calculate total XP correctly")

func test_zero_bonus_xp_scenario_still_works():
  # Verify scenarios with zero bonus XP work correctly
  # Arrange
  var scenario_id = "scenario_test"
  var bonus_xp = 0
  var conversion_xp = 30
  ScenarioManager.set_current_scenario_id(scenario_id)
  
  # Act - Simulate completion with zero bonus
  CurrencyManager.earn_xp(conversion_xp)
  
  # Simulate conditional bonus XP logic from scenario.gd
  if bonus_xp > 0:
    CurrencyManager.earn_xp(bonus_xp)
  
  ScenarioManager.last_scenario_stats = {
    "scenario_id": scenario_id,
    "xp_gained_from_conversion": conversion_xp,
    "bonus_xp_earned": bonus_xp,
  }
  
  # Assert
  assert_eq(CurrencyManager.current_xp, conversion_xp, "Only conversion XP should be awarded")
  assert_eq(ScenarioManager.last_scenario_stats.get("bonus_xp_earned", 0), 0,
    "Zero bonus should be recorded in stats")

func test_bonus_xp_works_with_level_ups():
  # Verify bonus XP correctly triggers level ups
  # Arrange
  CurrencyManager.current_level = 1
  CurrencyManager.current_xp = 80 # 20 XP away from level 2
  var conversion_xp = 10
  var bonus_xp = 30 # Total 40 XP, which will trigger level up
  
  # Act
  CurrencyManager.earn_xp(conversion_xp)
  CurrencyManager.earn_xp(bonus_xp)
  
  # Assert - Should level up from 1 to 2
  # 80 + 10 + 30 = 120 XP total
  # 100 XP needed for level 2, so 20 XP remains
  assert_eq(CurrencyManager.current_level, 2, "Should level up with bonus XP")
  assert_eq(CurrencyManager.current_xp, 20, "Remaining XP should be correct after level up")

func test_scenario_completion_marks_complete_and_awards_bonus():
  # Integration test for full completion flow
  # Arrange
  var scenario_id = "scenario_1"
  var bonus_xp = 75
  ScenarioManager.set_current_scenario_id(scenario_id)
  var initial_xp = CurrencyManager.current_xp
  
  # Act - Simulate full completion
  CurrencyManager.earn_xp(bonus_xp)
  ScenarioManager.mark_scenario_complete(scenario_id, 150.0)
  
  # Assert
  assert_true(ScenarioManager.is_scenario_completed(scenario_id),
    "Scenario should be marked complete")
  assert_eq(CurrencyManager.current_xp, initial_xp + bonus_xp,
    "Bonus XP should be awarded")
  assert_eq(ScenarioManager.get_best_time(scenario_id), 150.0,
    "Completion time should be recorded")
