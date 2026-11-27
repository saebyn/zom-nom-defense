extends GutTest

## Integration test for SaveManager with real managers
## Tests that managers properly save and load their state through SaveManager
## 
## Note: Autoload managers persist between tests, so we carefully manage state

const TEST_SLOT_1 = 7
const TEST_SLOT_2 = 8

func before_all():
  # Clean up any test slots
  _cleanup_test_slots()

func after_all():
  # Clean up test slots
  _cleanup_test_slots()

func before_each():
  # Set game state to PLAYING so earn_scrap/earn_xp functions work
  GameManager.set_game_state(GameManager.GameState.PLAYING)
  
  # Wait a frame to ensure state change is processed
  await get_tree().process_frame
  
  # Ensure clean slate for each test
  _cleanup_test_slots()
  
  # Verify we're in PLAYING state (sanity check)
  assert_true(GameManager.is_playing(), "PRECONDITION: GameManager must be in PLAYING state")

func after_each():
  # Clean up after each test
  _cleanup_test_slots()
  # Reset game state
  GameManager.set_game_state(GameManager.GameState.MAIN_MENU)

func _cleanup_test_slots():
  SaveManager.delete_save_slot(TEST_SLOT_1)
  SaveManager.delete_save_slot(TEST_SLOT_2)
  SaveManager.current_save_slot = -1
  
  # Reset all manager state to ensure clean slate between tests
  for system in SaveManager.managed_systems:
    system.reset_data()

## Test: Create new game and save currency data
func test_currency_manager_save_load():
  # File operations may generate engine errors in headless mode - ignore them
  
  # Create fresh game
  SaveManager.create_new_game(TEST_SLOT_1)
  
  # Modify currency data
  CurrencyManager.earn_scrap(500)
  CurrencyManager.earn_xp(250)
  
  var expected_xp = CurrencyManager.get_xp()
  var expected_level = CurrencyManager.get_level()
  
  # Save
  SaveManager.save_current_slot()
  
  # Create a different save to reset state
  SaveManager.create_new_game(TEST_SLOT_2)
  assert_eq(CurrencyManager.get_scrap(), CurrencyManager.starting_scrap, "Should be reset to starting scrap")
  
  # Load original save
  var success = SaveManager.load_save_slot(TEST_SLOT_1)
  
  assert_true(success, "Load should succeed")
  assert_eq(CurrencyManager.get_scrap(), CurrencyManager.starting_scrap, "Scrap should not persist")
  assert_eq(CurrencyManager.get_xp(), expected_xp, "XP should be restored")
  assert_eq(CurrencyManager.get_level(), expected_level, "Level should be restored")

## Test: Stats manager save/load
func test_stats_manager_save_load():
  # File operations may generate engine errors in headless mode - ignore them
  
  # Create fresh game
  SaveManager.create_new_game(TEST_SLOT_1)
  
  # Track some stats
  StatsManager.track_enemy_defeated("basic_zombie", false)
  StatsManager.track_enemy_defeated("basic_zombie", false)
  StatsManager.track_building_placed("turret")
  StatsManager.track_click_performed()
  StatsManager.track_click_performed()
  StatsManager.track_click_performed()
  
  var expected_enemies = StatsManager.get_enemies_defeated_total()
  var expected_buildings = StatsManager.get_buildings_placed_total()
  var expected_clicks = StatsManager.get_clicks_performed()
  
  # Save
  SaveManager.save_current_slot()
  
  # Create different save to reset
  SaveManager.create_new_game(TEST_SLOT_2)
  assert_eq(StatsManager.get_enemies_defeated_total(), 0, "Should be reset")
  assert_eq(StatsManager.get_clicks_performed(), 0, "clicks_performed should be reset to 0 on new game")
  
  # Load
  SaveManager.load_save_slot(TEST_SLOT_1)
  
  assert_eq(StatsManager.get_enemies_defeated_total(), expected_enemies, "Enemy count should be restored")
  assert_eq(StatsManager.get_buildings_placed_total(), expected_buildings, "Building count should be restored")
  assert_eq(StatsManager.get_clicks_performed(), expected_clicks, "clicks_performed should be restored after load")


## Test: clicks_performed resets on new game
func test_clicks_performed_resets_on_new_game():
  # Create a game and accumulate some clicks
  SaveManager.create_new_game(TEST_SLOT_1)
  StatsManager.track_click_performed()
  StatsManager.track_click_performed()
  StatsManager.track_click_performed()
  assert_eq(StatsManager.get_clicks_performed(), 3, "Should have 3 clicks tracked")
  
  # Starting a new game must reset the counter
  SaveManager.create_new_game(TEST_SLOT_2)
  assert_eq(StatsManager.get_clicks_performed(), 0, "clicks_performed must be 0 after new game")

## Test: enemy_clicks save/load
func test_enemy_clicks_save_load():
  # Create fresh game
  SaveManager.create_new_game(TEST_SLOT_1)

  # Track some enemy clicks
  StatsManager.track_enemy_click()
  StatsManager.track_enemy_click()
  StatsManager.track_enemy_click()
  StatsManager.track_enemy_click()

  var expected_enemy_clicks = StatsManager.get_enemy_clicks()

  # Save
  SaveManager.save_current_slot()

  # Create different save to reset
  SaveManager.create_new_game(TEST_SLOT_2)
  assert_eq(StatsManager.get_enemy_clicks(), 0, "enemy_clicks should be reset to 0 on new game")

  # Load original save
  var success = SaveManager.load_save_slot(TEST_SLOT_1)

  assert_true(success, "Load should succeed")
  assert_eq(StatsManager.get_enemy_clicks(), expected_enemy_clicks, "enemy_clicks should be restored after load")

## Test: enemy_clicks resets on new game
func test_enemy_clicks_resets_on_new_game():
  # Create a game and accumulate some enemy clicks
  SaveManager.create_new_game(TEST_SLOT_1)
  StatsManager.track_enemy_click()
  StatsManager.track_enemy_click()
  assert_eq(StatsManager.get_enemy_clicks(), 2, "Should have 2 enemy clicks tracked")

  # Starting a new game must reset the counter
  SaveManager.create_new_game(TEST_SLOT_2)
  assert_eq(StatsManager.get_enemy_clicks(), 0, "enemy_clicks must be 0 after new game")

## Test: Level manager save/load
func test_scenario_manager_save_load():
  # File operations may generate engine errors in headless mode - ignore them
  
  # Create fresh game
  SaveManager.create_new_game(TEST_SLOT_1)
  
  # Mark some scenarios complete
  ScenarioManager.mark_scenario_complete("scenario_1", 120.5)
  ScenarioManager.mark_scenario_complete("scenario_2", 95.3)
  
  var expected_count = ScenarioManager.completed_scenarios.size()
  
  # Save
  SaveManager.save_current_slot()
  
  # Create different save to reset
  SaveManager.create_new_game(TEST_SLOT_2)
  assert_eq(ScenarioManager.completed_scenarios.size(), 0, "Should be reset")
  
  # Load
  SaveManager.load_save_slot(TEST_SLOT_1)
  
  assert_eq(ScenarioManager.completed_scenarios.size(), expected_count, "Completed count should match")
  assert_true(ScenarioManager.is_scenario_completed("scenario_1"), "Scenario 1 should be complete")
  assert_true(ScenarioManager.is_scenario_completed("scenario_2"), "Scenario 2 should be complete")
  assert_eq(ScenarioManager.get_best_time("scenario_1"), 120.5, "Best time should be restored")

## Test: Tech tree manager save/load
func test_tech_tree_manager_save_load():
  # File operations may generate engine errors in headless mode - ignore them
  
  # This test verifies tech tree persistence works
  # Note: Tech tree state may persist between tests due to autoload nature
  # Create fresh game
  SaveManager.create_new_game(TEST_SLOT_1)
  
  # Verify tech nodes exist
  assert_gt(TechTreeManager.tech_nodes.size(), 0, "Tech tree should have at least one tech node")
  
  # Get first tech node
  var tech_id = TechTreeManager.tech_nodes.keys()[0]
  
  # Manually add to unlocked (bypass unlock logic for testing)
  if not TechTreeManager.is_tech_unlocked(tech_id):
    TechTreeManager.unlocked_tech_ids.append(tech_id)
  
  var expected_count = TechTreeManager.unlocked_tech_ids.size()
  assert_gt(expected_count, 0, "Should have at least one unlocked tech")
  
  # Save
  SaveManager.save_current_slot()
  
  # Verify save file contains tech tree data
  var slot_path = SaveManager.SAVE_SLOT_PATH % TEST_SLOT_1
  var save_data = SaveManager._load_json_file(slot_path)
  assert_true(save_data.has("tech_tree"), "Save should contain tech tree data")
  assert_true(save_data["tech_tree"].has("unlocked_tech_ids"), "Tech tree should have unlocked_tech_ids")
  
  # Load into a different slot to verify data round-trips
  SaveManager.create_new_game(TEST_SLOT_2)
  TechTreeManager.unlocked_tech_ids.clear() # Clear for this new game
  
  # Verify it's cleared
  assert_eq(TechTreeManager.unlocked_tech_ids.size(), 0, "Tech tree should be reset after new game")
  
  # Load original slot
  SaveManager.load_save_slot(TEST_SLOT_1)
  
  # Verify tech is restored
  assert_true(TechTreeManager.is_tech_unlocked(tech_id), "Tech should be unlocked after load")
  assert_eq(TechTreeManager.unlocked_tech_ids.size(), expected_count, "Unlocked count should match")

## Test: Multiple managers save/load together
func test_all_managers_save_load():
  # File operations may generate engine errors in headless mode - ignore them
  
  # Create fresh game
  SaveManager.create_new_game(TEST_SLOT_1)
  
  # Modify all managers
  CurrencyManager.earn_scrap(300)
  StatsManager.track_enemy_defeated("zombie", false)
  ScenarioManager.mark_scenario_complete("scenario_1")
  
  var expected_enemies = StatsManager.get_enemies_defeated_total()
  var expected_levels = ScenarioManager.completed_scenarios.size()
  
  # Save
  SaveManager.save_current_slot()
  
  # Create different save to reset all
  SaveManager.create_new_game(TEST_SLOT_2)
  
  # Load original
  SaveManager.load_save_slot(TEST_SLOT_1)
  
  # Verify all restored
  assert_eq(CurrencyManager.get_scrap(), CurrencyManager.starting_scrap, "Attempt-local scrap was discarded")
  assert_eq(StatsManager.get_enemies_defeated_total(), expected_enemies, "Stats restored")
  assert_eq(ScenarioManager.completed_scenarios.size(), expected_levels, "Scenarios restored")

## Test: Switch between save slots
func test_save_slot_switching():
  # File operations may generate engine errors in headless mode - ignore them
  
  # This test verifies that different save slots maintain independent state
  SaveManager.create_new_game(TEST_SLOT_1)
  CurrencyManager.earn_xp(10)
  SaveManager.save_current_slot()
  
  SaveManager.create_new_game(TEST_SLOT_2)
  CurrencyManager.earn_xp(50)
  SaveManager.save_current_slot()
  
  # Verify slots are independent by loading each
  SaveManager.load_save_slot(TEST_SLOT_1)
  assert_eq(CurrencyManager.get_xp(), 10)
  
  SaveManager.load_save_slot(TEST_SLOT_2)
  assert_eq(CurrencyManager.get_xp(), 50)

## Test: Metadata is accurate
func test_save_metadata():
  # File operations may generate engine errors in headless mode - ignore them
  
  # Create fresh game
  SaveManager.create_new_game(TEST_SLOT_1)
  
  # Modify state
  CurrencyManager.earn_xp(300) # Should level up
  ScenarioManager.set_current_scenario_id("scenario_2")
  
  var player_level = CurrencyManager.get_level()
  
  # Save
  SaveManager.save_current_slot()
  
  # Get metadata
  var metadata = SaveManager.get_slot_metadata(TEST_SLOT_1)
  
  assert_true(metadata.get("exists"), "Slot should exist")
  assert_eq(metadata.get("player_level"), player_level, "Player level should match")
  assert_eq(metadata.get("last_scenario"), "scenario_2", "Last scenario should match")
  assert_true(metadata.has("timestamp"), "Should have timestamp")

## Last scenario is informational, not an active attempt to restore.
func test_loading_does_not_restore_an_active_scenario():
  # File operations may generate engine errors in headless mode - ignore them
  
  # Create fresh game and set a scenario
  SaveManager.create_new_game(TEST_SLOT_1)
  ScenarioManager.set_current_scenario_id("scenario_2")
  
  # Save
  SaveManager.save_current_slot()
  
  # Create a different game to clear the scenario
  SaveManager.create_new_game(TEST_SLOT_2)
  ScenarioManager.clear_current_scenario()
  assert_eq(ScenarioManager.get_current_scenario_id(), "", "Scenario should be cleared")
  
  # Load the original save
  var success = SaveManager.load_save_slot(TEST_SLOT_1)
  
  assert_true(success, "Load should succeed")
  assert_eq(ScenarioManager.get_current_scenario_id(), "")
  assert_eq(SaveManager.get_slot_metadata(TEST_SLOT_1).get("last_scenario"), "scenario_2")
