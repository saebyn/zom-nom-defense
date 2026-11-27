extends GutTest

const MainMenuScene := preload("res://Stages/UI/main_menu/main_menu.tscn")
const VERSION_SETTING := "application/config/version"

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

func _open_menu(tips = null) -> UI_MainMenu:
  var menu := MainMenuScene.instantiate() as UI_MainMenu
  if tips != null:
    menu.tips.assign(tips)
  add_child_autofree(menu)
  return menu

func test_shows_the_release_version_when_the_main_menu_opens() -> void:
  var original_version = ProjectSettings.get_setting(VERSION_SETTING)
  ProjectSettings.set_setting(VERSION_SETTING, "0.5.4")

  var version_label := _open_menu().get_node("Version") as Label

  ProjectSettings.set_setting(VERSION_SETTING, original_version)
  assert_eq(version_label.text, "v0.5.4")

func test_shows_dev_build_in_an_unstamped_checkout() -> void:
  var version_label := _open_menu().get_node("Version") as Label

  assert_eq(version_label.text, "Dev build")

func test_shows_the_loaded_save_slot_and_enables_play() -> void:
  SaveManager.current_save_slot = 2

  var menu := _open_menu()
  var save_slot_button := menu.get_node("CurrentSave") as Button
  var play_button := menu.get_node("LeftMenu/ButtonInset/Actions/Play") as Button

  assert_eq(save_slot_button.text, "Save Slot 2")
  assert_eq(save_slot_button.tooltip_text, "Change Save Slot")
  assert_false(play_button.disabled)

func test_offers_slot_selection_instead_of_play_when_the_remembered_slot_is_unavailable() -> void:
  var path := SaveManager.LAST_SAVE_SLOT_PATH
  var selection_existed := FileAccess.file_exists(path)
  var previous_selection := FileAccess.get_file_as_bytes(path) if selection_existed else PackedByteArray()
  var selection := ConfigFile.new()
  selection.set_value("selection", "slot", SaveManager.MAX_SAVE_SLOTS + 1)
  assert_eq(selection.save(path), OK)
  SaveManager.current_save_slot = -1

  var menu := _open_menu()
  var save_slot_button := menu.get_node("CurrentSave") as Button
  var play_button := menu.get_node("LeftMenu/ButtonInset/Actions/Play") as Button

  if selection_existed:
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_buffer(previous_selection)
    file.close()
  else:
    DirAccess.remove_absolute(path)

  assert_eq(save_slot_button.text, "Select Save Slot")
  assert_false(save_slot_button.disabled)
  assert_true(play_button.disabled)
  save_slot_button.pressed.emit()
  await wait_process_frames(2)
  assert_true(get_tree().current_scene is UI_SaveSlotSelection)
  if get_tree().current_scene is UI_SaveSlotSelection:
    get_tree().unload_current_scene()

func test_default_menu_has_a_tip_to_show() -> void:
  var tip_label := _open_menu().get_node("Tip") as Label

  assert_ne(tip_label.text.strip_edges(), "")

func test_shows_a_prefixed_tip_when_the_main_menu_opens() -> void:
  var tip_label := _open_menu(["Protect Survivors."]).get_node("Tip") as Label

  assert_eq(tip_label.text, "Tip: Protect Survivors.")

func test_leaves_the_tip_label_empty_when_there_are_no_tips() -> void:
  var tip_label := _open_menu([]).get_node("Tip") as Label

  assert_eq(tip_label.text, "")

func test_skips_blank_entries() -> void:
  var tip_label := _open_menu([" \t", "Protect Survivors."]).get_node("Tip") as Label

  assert_eq(tip_label.text, "Tip: Protect Survivors.")

func test_rotates_at_two_real_seconds_per_word_and_wraps() -> void:
  Engine.time_scale = 2.0
  var tip_label := _open_menu(["Click!", "Protect \t Survivors."]).get_node("Tip") as Label

  await get_tree().create_timer(1.75, true, false, true).timeout
  assert_eq(tip_label.text, "Tip: Click!", "The one-word tip should still be visible")
  await get_tree().create_timer(0.5, true, false, true).timeout
  assert_eq(tip_label.text, "Tip: Protect \t Survivors.", "The next tip should show after two seconds")
  await get_tree().create_timer(3.5, true, false, true).timeout
  assert_eq(tip_label.text, "Tip: Protect \t Survivors.", "The two-word tip should last longer")
  await get_tree().create_timer(0.5, true, false, true).timeout
  assert_eq(tip_label.text, "Tip: Click!", "The list should wrap after four more seconds")
