extends GutTest

const TIMELINE := "res://Dialogic/Timelines/scenario_1_tut_welcome.dtl"

var initial_tutorial_enabled: bool
var initial_unlocked_techs: Array[String]
var settings_file_existed: bool
var initial_settings_file: PackedByteArray
var runner_gui: CanvasItem
var runner_gui_was_visible: bool


func before_each() -> void:
  process_mode = Node.PROCESS_MODE_ALWAYS
  # GUT draws above the game UI; hide its overlay so real GUI clicks reach Dialogic.
  runner_gui = get_tree().root.find_child("GutScene", true, false)
  if runner_gui:
    runner_gui_was_visible = runner_gui.visible
    runner_gui.hide()
  initial_tutorial_enabled = SettingsManager.tutorial_enabled
  settings_file_existed = FileAccess.file_exists(SettingsManager.SETTINGS_FILE)
  if settings_file_existed:
    initial_settings_file = FileAccess.get_file_as_bytes(SettingsManager.SETTINGS_FILE)
  initial_unlocked_techs = TechTreeManager.unlocked_tech_ids.duplicate()
  SettingsManager.tutorial_enabled = true
  TechTreeManager.unlocked_tech_ids.clear()
  GameManager.reset_tutorial_flags()
  GameManager.set_game_state(GameManager.GameState.PLAYING)
  GameManager.resume_game()
  Dialogic.process_mode = Node.PROCESS_MODE_ALWAYS
  Dialogic.paused = false
  await Dialogic.clear()


func after_each() -> void:
  await Dialogic.end_timeline(true)
  await _settle()
  SettingsManager.tutorial_enabled = initial_tutorial_enabled
  # The opt-out branch saves settings; restore the user's exact original file.
  if settings_file_existed:
    var settings_file := FileAccess.open(SettingsManager.SETTINGS_FILE, FileAccess.WRITE)
    settings_file.store_buffer(initial_settings_file)
    settings_file.close()
  else:
    DirAccess.remove_absolute(SettingsManager.SETTINGS_FILE)
  TechTreeManager.unlocked_tech_ids = initial_unlocked_techs
  GameManager.reset_tutorial_flags()
  GameManager.resume_game()
  GameManager.set_game_state(GameManager.GameState.MAIN_MENU)
  if runner_gui:
    runner_gui.visible = runner_gui_was_visible


func _settle() -> void:
  for frame in range(4):
    await get_tree().process_frame


func _start(timeline: Variant = TIMELINE) -> void:
  var layout: Node = Dialogic.start(timeline)
  layout.process_mode = Node.PROCESS_MODE_ALWAYS
  await _settle()


func _textbox() -> Control:
  return Dialogic.Styles.get_layout_node().get_node("TextboxWithSpeakerPortrait")


func _event() -> DialogicEvent:
  if Dialogic.current_event_idx < 0:
    return null
  return Dialogic.current_timeline_events[Dialogic.current_event_idx]


func _main_wait(signal_name: String) -> bool:
  var event := _event()
  return event is ZomNomWaitForMainSceneSignalEvent and event.signal_name == signal_name


func _advance() -> void:
  Dialogic.Text.skip_text_reveal()
  await _settle()
  Dialogic.Inputs.input_block_timer.stop()
  if Dialogic.Styles.get_current_style() == "Tutorial":
    _textbox().continue_button.pressed.emit()
  else:
    Dialogic.Inputs.handle_input()
  await _settle()


func _advance_until(condition: Callable) -> bool:
  for step in range(80):
    if condition.call():
      return true
    if _event() is DialogicTextEvent:
      await _advance()
    else:
      await wait_seconds(0.05)
  fail_test("Tutorial did not reach the expected event; stopped at %s" % Dialogic.current_event_idx)
  return false


func _choose_tutorial(choice: int = 1) -> void:
  await _start()
  if not await _advance_until(func(): return Dialogic.current_state == Dialogic.States.AWAITING_CHOICE):
    return
  assert_eq(Dialogic.Styles.get_current_style(), "Style", "Opt-in stays in the conversation layout")
  assert_true(GameManager.is_paused())
  assert_false(_textbox().continue_button.visible, "Choices hide Continue")
  await wait_seconds(0.25)
  var button: DialogicNode_ChoiceButton = Dialogic.Choices.get_choice_button(choice)
  assert_true(button.is_visible_in_tree())
  assert_false(button.disabled)
  button.choice_selected.emit()
  await _settle()


func test_scenario_one_styles_pauses_and_all_gameplay_waits() -> void:
  await _choose_tutorial()
  assert_eq(Dialogic.Styles.get_current_style(), "Tutorial")
  assert_true(_textbox().continue_button.is_visible_in_tree())
  assert_true(GameManager.is_paused(), "Instructions still pause gameplay")
  assert_eq(Dialogic.Styles.get_layout_node().process_mode, Node.PROCESS_MODE_ALWAYS)
  var portrait: Control = _textbox().get_node("Anchor/Panel/HBox/PortraitPanel/PortraitBackgroundColor/DialogicNode_PortraitContainer")
  assert_gt(portrait.get_child_count(), 0, "The existing speaker portrait is reused")

  for signal_name in ["enemy_appeared", "enemy_attacked", "wave_cleared"]:
    if not await _advance_until(func(): return _main_wait(signal_name)):
      return
    assert_false(GameManager.is_paused(), "Gameplay runs during %s" % signal_name)
    assert_false(Dialogic.Text.is_textbox_visible(), "Waits keep their existing hide/show behavior")
    var waiting_index: int = Dialogic.current_event_idx
    Dialogic.Inputs.input_block_timer.stop()
    Dialogic.Inputs.handle_input()
    assert_eq(Dialogic.current_event_idx, waiting_index, "Continue cannot bypass a gameplay wait")
    GameManager.emit_signal(signal_name)
    await _settle()

  if not await _advance_until(func(): return _event() is ZomNomWaitForTechUnlockedEvent):
    return
  assert_eq(Dialogic.Styles.get_current_style(), "Tutorial", "System speaker must not override the tutorial style")
  assert_false(GameManager.is_paused())
  var tech_wait_index: int = Dialogic.current_event_idx
  TechTreeManager.tech_unlocked.emit("unrelated_tech")
  await _settle()
  assert_eq(Dialogic.current_event_idx, tech_wait_index)
  TechTreeManager.tech_unlocked.emit("tur_scrap_shooter")
  await _settle()

  if not await _advance_until(func(): return _main_wait("building_placed")):
    return
  assert_false(GameManager.is_paused())
  assert_false(Dialogic.Text.is_textbox_visible())
  GameManager.building_placed.emit()
  await _settle()
  assert_true(GameManager.is_paused())
  if not await _advance_until(func(): return Dialogic.Styles.get_current_style() == "Style"):
    return
  assert_false(_textbox().tutorial_side_panel, "Closing conversation restores the bottom textbox")
  assert_false(_textbox().is_in_group("dialogic_input"))
  assert_false(_textbox().get_node("Anchor/Panel/HBox").vertical)
  assert_eq(_textbox().box_size, Vector2(600, 160))
  await _advance_until(func(): return Dialogic.current_timeline == null)
  assert_true(GameManager.is_paused(), "The existing final manual unpause is preserved")


func test_declining_keeps_conversation_style_and_resumes_gameplay() -> void:
  await _choose_tutorial(2)
  assert_false(SettingsManager.tutorial_enabled)
  assert_false(GameManager.is_paused())
  assert_eq(Dialogic.Styles.get_current_style(), "Style")
  await _advance()
  assert_null(Dialogic.current_timeline)


func test_disabled_tutorial_only_plays_the_existing_intro() -> void:
  SettingsManager.tutorial_enabled = false
  await _start()
  for line in range(3):
    assert_eq(Dialogic.Styles.get_current_style(), "Style")
    await _advance()
  assert_null(Dialogic.current_timeline)


func _click(position: Vector2) -> void:
  var motion := InputEventMouseMotion.new()
  motion.position = position
  motion.global_position = position
  Input.parse_input_event(motion)
  Input.flush_buffered_events()
  await _settle()
  for pressed in [true, false]:
    var event := InputEventMouseButton.new()
    event.position = position
    event.global_position = position
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = pressed
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    await _settle()


func _key(keycode: Key) -> void:
  for pressed in [true, false]:
    var event := InputEventKey.new()
    event.physical_keycode = keycode
    event.keycode = keycode
    event.pressed = pressed
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    await _settle()


func test_side_panel_input_and_menu_blocking() -> void:
  await _choose_tutorial()
  Dialogic.Text.skip_text_reveal()
  Dialogic.Inputs.input_block_timer.stop()
  var current_index: int = Dialogic.current_event_idx
  await _click(Vector2(10, 10))
  assert_eq(Dialogic.current_event_idx, current_index, "World clicks do not advance tutorial text")
  await _click(_textbox().continue_button.get_global_rect().get_center())
  assert_gt(Dialogic.current_event_idx, current_index, "Continue advances while gameplay is paused")

  for keycode in [KEY_ENTER, KEY_SPACE]:
    Dialogic.Text.skip_text_reveal()
    Dialogic.Inputs.input_block_timer.stop()
    current_index = Dialogic.current_event_idx
    await _key(keycode)
    assert_gt(Dialogic.current_event_idx, current_index, "Keyboard advance is preserved")

  for state in [GameManager.GameState.IN_GAME_MENU, GameManager.GameState.IN_TECH_TREE]:
    GameManager.set_game_state(state)
    assert_true(Dialogic.paused)
    current_index = Dialogic.current_event_idx
    _textbox().continue_button.pressed.emit()
    await _key(KEY_ENTER)
    assert_eq(Dialogic.current_event_idx, current_index, "Menus block dialogue input")
    GameManager.set_game_state(GameManager.GameState.PLAYING)
    assert_false(Dialogic.paused)


func test_style_round_trip_keeps_choices_and_resets_geometry() -> void:
  var timeline := DialogicTimeline.new()
  timeline.events = [
    '[style name="Tutorial"]',
    'survivor: Tutorial question?',
    '- Continue the test',
    '\t[style name="Style"]',
    '\tsystem: Back to conversation.',
  ]
  await _start(timeline)
  await _advance()
  assert_eq(Dialogic.current_state, Dialogic.States.AWAITING_CHOICE)
  assert_false(_textbox().continue_button.visible)
  await wait_seconds(0.25)
  Dialogic.Choices.select_choice(1)
  await _settle()
  assert_eq(Dialogic.Styles.get_current_style(), "Style")
  assert_eq(_textbox().box_size, Vector2(600, 160))
  assert_false(_textbox().get_node("Anchor/Panel/HBox").vertical)
  assert_true(_textbox().continue_button.visible)


func test_side_panel_fits_small_viewports_and_ui_scaling() -> void:
  await _choose_tutorial()
  var window := get_tree().root
  var initial_size := window.size
  var initial_scale := window.content_scale_factor
  for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
    for ui_scale in [1.0, 2.0]:
      window.size = resolution
      window.content_scale_factor = ui_scale
      await _settle()
      var panel: PanelContainer = _textbox().get_node("Anchor/Panel")
      var panel_rect := panel.get_global_rect()
      var viewport_rect := window.get_visible_rect()
      assert_true(viewport_rect.encloses(panel_rect), "%s at %s UI scale: %s inside %s" % [resolution, ui_scale, panel_rect, viewport_rect])
      assert_gt(panel_rect.position.x, viewport_rect.size.x / 2.0 - 50.0, "Panel leaves the left and central play area clear")
      assert_true(panel_rect.encloses(_textbox().continue_button.get_global_rect()), "Continue stays inside the panel")
  window.size = initial_size
  window.content_scale_factor = initial_scale
  await _settle()


func test_mouse_continue_then_keyboard_after_style_switch() -> void:
  var timeline := DialogicTimeline.new()
  timeline.events = [
    '[style name="Tutorial"]',
    'survivor: Last tutorial instruction.',
    '[style name="Style"]',
    'survivor: Back to conversation.',
    'survivor: Next conversation line.',
  ]
  await _start(timeline)
  Dialogic.Text.skip_text_reveal()
  Dialogic.Inputs.input_block_timer.stop()
  await _click(_textbox().continue_button.get_global_rect().get_center())
  assert_eq(Dialogic.Styles.get_current_style(), "Style")
  Dialogic.Text.skip_text_reveal()
  Dialogic.Inputs.input_block_timer.stop()
  var current_index: int = Dialogic.current_event_idx
  await _key(KEY_ENTER)
  assert_gt(Dialogic.current_event_idx, current_index, "Tutorial button focus must not swallow conversation keyboard input")
