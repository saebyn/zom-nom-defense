extends GutTest

const ENEMY_SCRIPT = preload("res://Entities/Enemies/Templates/base_enemy/enemy.gd")


func before_each() -> void:
  GameManager.set_game_state(GameManager.GameState.PLAYING)
  await get_tree().process_frame
  CurrencyManager.current_scrap = 0
  CurrencyManager.current_xp = 95
  CurrencyManager.current_level = 1
  StatsManager.reset_stats()
  AchievementManager.reset_data()


func after_each() -> void:
  StatsManager.reset_stats()
  AchievementManager.reset_data()
  GameManager.set_game_state(GameManager.GameState.MAIN_MENU)


func test_enemy_death_awards_scrap_without_xp_or_level_change() -> void:
  var enemy = ENEMY_SCRIPT.new()
  enemy.scrap_reward = 15
  enemy.enemy_type = "test_enemy"

  enemy._on_died("player")
  await get_tree().process_frame

  assert_eq(CurrencyManager.current_scrap, 15, "Enemy death should award configured scrap")
  assert_eq(CurrencyManager.current_xp, 95, "Enemy death should not award XP")
  assert_eq(CurrencyManager.current_level, 1, "Enemy death should not change player level")
  assert_eq(StatsManager.enemies_defeated_total, 1, "Enemy death should still be tracked")
  assert_eq(StatsManager.enemies_defeated_by_hand, 1, "Player defeats should still be tracked")
