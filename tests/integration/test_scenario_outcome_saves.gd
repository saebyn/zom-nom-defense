extends GutTest

const TEST_SLOT := 9
const SCENARIO_ID := "scenario_1"
const BYPASS_TECH := "zom_nom_defense/debug/bypass_tech_requirements"
var _original_bypass_tech: bool

func before_each() -> void:
  _original_bypass_tech = ProjectSettings.get_setting(BYPASS_TECH, false)
  ProjectSettings.set_setting(BYPASS_TECH, false)
  GameManager.set_game_state(GameManager.GameState.MAIN_MENU)
  ScenarioManager.clear_current_scenario()
  SaveManager.delete_save_slot(TEST_SLOT)
  SaveManager.create_new_game(TEST_SLOT)

func after_each() -> void:
  ProjectSettings.set_setting(BYPASS_TECH, _original_bypass_tech)
  GameManager.resume_game()
  GameManager.set_game_state(GameManager.GameState.MAIN_MENU)
  ScenarioManager.clear_current_scenario()
  SaveManager.delete_save_slot(TEST_SLOT)
  for system in SaveManager.managed_systems:
    system.reset_data()

func _start_attempt() -> Stage_Scenario:
  ScenarioManager.set_current_scenario_id(SCENARIO_ID)
  GameManager.set_game_state(GameManager.GameState.PLAYING)
  GameManager.begin_scenario_attempt()
  var scenario := Stage_Scenario.new()
  scenario.enemy_spawner = System_EnemySpawner.new()
  scenario.add_child(scenario.enemy_spawner)
  var survivor := Node3D.new()
  survivor.add_to_group("survivors")
  scenario.add_child(survivor)
  add_child_autofree(scenario)
  return scenario

func test_game_over_saves_activity_without_awarding_xp_or_a_clear() -> void:
  var scenario := _start_attempt()
  StatsManager.track_enemy_defeated("basic_enemy", true)
  CurrencyManager.earn_scrap(100)

  scenario.on_survivor_died(null, "test")

  assert_eq(GameManager.current_state, GameManager.GameState.GAME_OVER)
  assert_eq(CurrencyManager.get_xp(), 0, "Game Over must not award XP")
  assert_true(SaveManager.load_save_slot(TEST_SLOT))
  assert_eq(StatsManager.get_enemies_defeated_total(), 1)
  assert_true(AchievementManager.is_achievement_unlocked("first_blood"))
  assert_eq(CurrencyManager.get_xp(), 0)
  assert_false(ScenarioManager.is_scenario_completed(SCENARIO_ID))
  assert_eq(SaveManager.get_slot_metadata(TEST_SLOT).get("last_scenario"), "",
    "An activity-only save must not replace progression metadata")

func test_game_over_restores_previous_tech_and_survivors() -> void:
  var profile := SurvivorNameManager.assign_next_profile()
  assert_true(SaveManager.save_current_slot(false))
  var scenario := _start_attempt()
  CurrencyManager.earn_scrap(100)
  assert_true(TechTreeManager.unlock_tech("tur_scrap_shooter", true))
  SurvivorNameManager.mark_profile_dead(profile)

  scenario.on_survivor_died(null, "test")

  assert_false(TechTreeManager.is_tech_unlocked("tur_scrap_shooter"))
  assert_false(BuildingRegistry.is_building_available("turret"))
  assert_eq(SurvivorNameManager.get_profile(profile).get("status"), "alive")
  assert_eq(CurrencyManager.get_scrap(), CurrencyManager.starting_scrap)

func test_victory_commits_once_and_a_replay_can_save_again() -> void:
  var scenario := _start_attempt()
  CurrencyManager.earn_scrap(100)
  assert_true(TechTreeManager.unlock_tech("tur_scrap_shooter", true))
  watch_signals(SaveManager)

  scenario.enemy_spawner.all_waves_completed.emit()
  scenario.enemy_spawner.all_waves_completed.emit()
  scenario.on_survivor_died(null, "late death")

  assert_eq(GameManager.current_state, GameManager.GameState.VICTORY)
  assert_signal_emit_count(SaveManager, "save_completed", 1)
  assert_true(SaveManager.load_save_slot(TEST_SLOT))
  assert_eq(CurrencyManager.get_xp(), 62, "25 scrap left converts to 12 XP, plus 50 bonus XP")
  assert_true(ScenarioManager.is_scenario_completed(SCENARIO_ID))
  assert_true(ScenarioManager.is_scenario_unlocked("scenario_2"))
  assert_true(TechTreeManager.is_tech_unlocked("tur_scrap_shooter"))

  scenario.free()
  GameManager.resume_game()
  var replay := _start_attempt()
  replay.enemy_spawner.all_waves_completed.emit()
  assert_signal_emit_count(SaveManager, "save_completed", 2)
  assert_true(SaveManager.load_save_slot(TEST_SLOT))
  assert_eq(StatsManager.get_total_xp_earned(), 112)

func test_abandoned_attempt_saves_activity_without_carrying_state_into_replay() -> void:
  var scenario := _start_attempt()
  CurrencyManager.earn_scrap(100)
  assert_true(TechTreeManager.unlock_tech("tur_scrap_shooter", true))
  StatsManager.track_enemy_defeated("basic_enemy", true)
  ScenarioManager.set_current_wave(1)
  ScenarioManager.set_current_wave(2)
  watch_signals(SaveManager)

  GameManager.abandon_scenario_attempt()
  GameManager.abandon_scenario_attempt()

  assert_signal_emit_count(SaveManager, "save_completed", 1)
  assert_true(SaveManager.load_save_slot(TEST_SLOT))
  assert_eq(StatsManager.get_enemies_defeated_total(), 1)
  assert_true(AchievementManager.is_achievement_unlocked("first_blood"))
  assert_false(TechTreeManager.is_tech_unlocked("tur_scrap_shooter"))
  scenario.free()
  _start_attempt()
  assert_eq(CurrencyManager.get_scrap(), CurrencyManager.starting_scrap)
  assert_eq(ScenarioManager.get_current_wave(), 0)
  ScenarioManager.set_current_wave(1)
  assert_eq(StatsManager.get_max_waves_completed(), 2, "New attempt must not extend the previous attempt's record")
  GameManager.abandon_scenario_attempt()

func test_game_over_can_save_activity_after_loading_a_backup() -> void:
  # Make a valid backup, then corrupt the primary like an interrupted or damaged save.
  assert_true(SaveManager.save_current_slot(false))
  var primary := FileAccess.open(SaveManager.SAVE_SLOT_PATH % TEST_SLOT, FileAccess.WRITE)
  primary.store_string("not JSON")
  primary.close()
  assert_true(SaveManager.load_save_slot(TEST_SLOT))

  var scenario := _start_attempt()
  StatsManager.track_enemy_defeated("basic_enemy", true)
  scenario.on_survivor_died(null, "test")

  assert_true(SaveManager.load_save_slot(TEST_SLOT))
  assert_eq(StatsManager.get_enemies_defeated_total(), 1)
  # The update must not replace the valid backup with the corrupt primary.
  primary = FileAccess.open(SaveManager.SAVE_SLOT_PATH % TEST_SLOT, FileAccess.WRITE)
  primary.store_string("not JSON")
  primary.close()
  assert_true(SaveManager.load_save_slot(TEST_SLOT), "Backup is still usable")
