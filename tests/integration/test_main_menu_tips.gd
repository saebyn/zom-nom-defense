extends GutTest

const MainMenuScene := preload("res://Stages/UI/main_menu/main_menu.tscn")

var _original_slot: int
var _original_playtime: float
var _original_game_state: GameManager.GameState
var _original_scenario_id: String
var _original_wave: int
var _original_paused: bool
var _original_time_scale: float

func before_each() -> void:
  _original_slot = SaveManager.current_save_slot
  _original_playtime = SaveManager.slot_playtime
  _original_game_state = GameManager.current_state
  _original_scenario_id = ScenarioManager.get_current_scenario_id()
  _original_wave = ScenarioManager.get_current_wave()
  _original_paused = get_tree().paused
  _original_time_scale = Engine.time_scale
  # Simulate an already-loaded Save Slot so opening the menu never writes a save.
  SaveManager.current_save_slot = SaveManager.DEFAULT_SLOT

func after_each() -> void:
  SaveManager.current_save_slot = _original_slot
  SaveManager.slot_playtime = _original_playtime
  GameManager.set_game_state(_original_game_state)
  ScenarioManager.set_current_scenario_id(_original_scenario_id)
  ScenarioManager.set_current_wave(_original_wave)
  get_tree().paused = _original_paused
  Engine.time_scale = _original_time_scale

func _open_menu(tips = null) -> Label:
  var menu := MainMenuScene.instantiate() as UI_MainMenu
  if tips != null:
    menu.tips.assign(tips)
  add_child_autofree(menu)
  return menu.get_node("Tip") as Label

func test_default_menu_has_a_tip_to_show() -> void:
  var tip_label := _open_menu()

  assert_ne(tip_label.text.strip_edges(), "")

func test_shows_a_prefixed_tip_when_the_main_menu_opens() -> void:
  var tip_label := _open_menu(["Protect Survivors."])

  assert_eq(tip_label.text, "Tip: Protect Survivors.")

func test_leaves_the_tip_label_empty_when_there_are_no_tips() -> void:
  var tip_label := _open_menu([])

  assert_eq(tip_label.text, "")

func test_skips_blank_entries() -> void:
  var tip_label := _open_menu([" \t", "Protect Survivors."])

  assert_eq(tip_label.text, "Tip: Protect Survivors.")

func test_rotates_at_two_real_seconds_per_word_and_wraps() -> void:
  Engine.time_scale = 2.0
  var tip_label := _open_menu(["Click!", "Protect \t Survivors."])

  await get_tree().create_timer(1.75, true, false, true).timeout
  assert_eq(tip_label.text, "Tip: Click!", "The one-word tip should still be visible")
  await get_tree().create_timer(0.5, true, false, true).timeout
  assert_eq(tip_label.text, "Tip: Protect \t Survivors.", "The next tip should show after two seconds")
  await get_tree().create_timer(3.5, true, false, true).timeout
  assert_eq(tip_label.text, "Tip: Protect \t Survivors.", "The two-word tip should last longer")
  await get_tree().create_timer(0.5, true, false, true).timeout
  assert_eq(tip_label.text, "Tip: Click!", "The list should wrap after four more seconds")
