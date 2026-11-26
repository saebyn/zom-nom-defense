extends GutTest

const TEST_SLOT := 6
const SCENARIO_ID := "scenario_2" # No tutorial to pause the fresh attempt.
const BYPASS_TECH := "zom_nom_defense/debug/bypass_tech_requirements"

func test_restart_discards_attempt_changes_but_saves_lifetime_activity() -> void:
  var tree := get_tree()
  var previous_scene := tree.current_scene
  tree.current_scene = null # Do not replace the test runner's scene.
  var original_bypass: bool = ProjectSettings.get_setting(BYPASS_TECH, false)
  ProjectSettings.set_setting(BYPASS_TECH, false)
  SaveManager.delete_save_slot(TEST_SLOT)
  SaveManager.create_new_game(TEST_SLOT)
  ScenarioManager.set_current_scenario_id(SCENARIO_ID)
  GameManager.set_game_state(GameManager.GameState.PLAYING)
  GameManager.begin_scenario_attempt()
  CurrencyManager.earn_scrap(100)
  assert_true(TechTreeManager.unlock_tech("tur_scrap_shooter", true))
  StatsManager.track_enemy_defeated("basic_enemy", true)
  ScenarioManager.set_current_wave(1)
  ScenarioManager.set_current_wave(2)
  GameManager.toggle_in_game_menu()

  GameManager.restart_scenario()
  await wait_process_frames(2)

  assert_not_null(tree.current_scene, "Restart loads a fresh gameplay scene")
  assert_eq(ScenarioManager.get_current_scenario_id(), SCENARIO_ID)
  assert_eq(ScenarioManager.get_current_wave(), 0)
  assert_true(GameManager.is_playing())
  assert_false(GameManager.is_paused())
  assert_eq(CurrencyManager.get_scrap(), CurrencyManager.starting_scrap)
  assert_false(TechTreeManager.is_tech_unlocked("tur_scrap_shooter"))
  assert_eq(StatsManager.get_enemies_defeated_total(), 1)
  ScenarioManager.set_current_wave(1)
  assert_eq(StatsManager.get_max_waves_completed(), 2)

  StatsManager.track_enemy_defeated("basic_enemy", true)
  GameManager.toggle_in_game_menu()
  GameManager.return_to_main_menu()
  await wait_process_frames(2)

  assert_eq(GameManager.current_state, GameManager.GameState.MAIN_MENU)
  assert_eq(ScenarioManager.get_current_scenario_id(), "")
  assert_true(SaveManager.load_save_slot(TEST_SLOT))
  assert_eq(StatsManager.get_enemies_defeated_total(), 2)
  assert_true(AchievementManager.is_achievement_unlocked("first_blood"))
  assert_false(TechTreeManager.is_tech_unlocked("tur_scrap_shooter"))
  if tree.current_scene and tree.current_scene != previous_scene:
    tree.current_scene.queue_free()
  tree.current_scene = previous_scene
  SaveManager.delete_save_slot(TEST_SLOT)
  for system in SaveManager.managed_systems:
    system.reset_data()
  ProjectSettings.set_setting(BYPASS_TECH, original_bypass)
