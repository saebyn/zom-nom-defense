extends GutTest

const HUD_SCENE = preload("res://Stages/UI/main_ui/ui.tscn")

var viewport: SubViewport
var hud: MainUI
var hotbar: UI_Hotbar
var buildings: Array[Resource_BuildingType] = []
var previous_buildings: Array[Resource_BuildingType]
var previous_state: GameManager.GameState
var previous_paused: bool
var previous_speed: float
var played_sounds: Array[int] = []

func before_each() -> void:
  previous_buildings = BuildingRegistry.available_building_types.duplicate()
  previous_state = GameManager.current_state
  previous_paused = get_tree().paused
  previous_speed = GameManager.get_game_speed()
  GameManager.resume_game()
  GameManager.set_game_state(GameManager.GameState.PLAYING)
  GameManager.set_game_speed(1.0)

  buildings.clear()
  for i in range(6):
    var building = Resource_BuildingType.new()
    building.id = "hotbar_test_%d" % i
    building.name = "Test building %d" % i
    buildings.append(building)
  BuildingRegistry.available_building_types = buildings.duplicate()

  # Exercise the real HUD's layout/process modes and Godot's GUI input routing.
  viewport = SubViewport.new()
  viewport.size = Vector2i(1280, 720)
  viewport.gui_embed_subwindows = true
  add_child_autofree(viewport)
  hud = HUD_SCENE.instantiate()
  viewport.add_child(hud)
  hotbar = hud.hotbar
  watch_signals(hotbar)
  played_sounds.clear()
  AudioManager.sound_played.connect(_on_sound_played)
  await wait_process_frames(2)

func after_each() -> void:
  AudioManager.sound_played.disconnect(_on_sound_played)
  BuildingRegistry.available_building_types = previous_buildings
  GameManager.set_game_speed(previous_speed)
  GameManager.set_game_state(previous_state)
  get_tree().paused = previous_paused

func _on_sound_played(effect: Resource_SoundEffect.SoundEffect) -> void:
  played_sounds.append(effect)

func click_slot(slot: int, button_index: MouseButton = MOUSE_BUTTON_LEFT) -> void:
  var point = hotbar.slot_buttons[slot].get_global_rect().get_center()
  var motion = InputEventMouseMotion.new()
  motion.position = point
  viewport.push_input(motion, true)
  for pressed in [true, false]:
    var event = InputEventMouseButton.new()
    event.position = point
    event.button_index = button_index
    event.pressed = pressed
    viewport.push_input(event, true)

func press_slot_key(slot: int, echo: bool = false) -> void:
  var event: InputEventKey = InputMap.action_get_events("hotbar_slot_%d" % (slot + 1))[0].duplicate()
  event.pressed = true
  event.echo = echo
  viewport.push_input(event, true)
  event = event.duplicate()
  event.pressed = false
  viewport.push_input(event, true)

func test_paused_mouse_click_shows_feedback_without_selecting() -> void:
  GameManager.pause_game()
  click_slot(0)
  assert_true(hotbar.pause_feedback.visible)
  assert_signal_not_emitted(hotbar, "building_selected")
  assert_true(GameManager.is_paused(), "Feedback must not resume gameplay")
  assert_eq(hotbar.get_slot_building(0), buildings[0], "Selection must not reconfigure the slot")
  assert_eq(played_sounds.count(Resource_SoundEffect.SoundEffect.ERROR), 1)
  assert_does_not_have(played_sounds, Resource_SoundEffect.SoundEffect.UI_CONFIRM,
    "The automatic button sound must not overwrite rejection with a success cue")
  assert_true(hotbar.rejection_audio.can_process(), "Error audio must run while paused")
  assert_true(hotbar.rejection_audio.playing)
  assert_false(hotbar.rejection_audio.stream_paused)
  assert_eq(hotbar.rejection_audio.bus, &"Sound Effects")
  assert_false(hotbar.slot_buttons[0]._tooltip_panel.visible,
    "The hovered building tooltip must not cover the explanation")

func test_all_paused_shortcuts_show_feedback_without_selecting() -> void:
  GameManager.pause_game()
  hotbar.slot_buttons[5]._on_mouse_entered()
  for slot in range(6):
    hotbar._hide_pause_feedback()
    press_slot_key(slot)
    assert_true(hotbar.pause_feedback.visible, "Shortcut %d must work while paused" % (slot + 1))
    assert_false(hotbar.slot_buttons[5]._tooltip_panel.visible)
  assert_signal_not_emitted(hotbar, "building_selected")

func test_unpaused_mouse_and_shortcuts_select_the_requested_building() -> void:
  click_slot(0)
  assert_signal_emitted_with_parameters(hotbar, "building_selected", [buildings[0]])
  for slot in range(6):
    press_slot_key(slot)
    assert_signal_emitted_with_parameters(hotbar, "building_selected", [buildings[slot]], slot + 1)
  assert_signal_emit_count(hotbar, "building_selected", 7)
  assert_false(hotbar.pause_feedback.visible)
  assert_eq(played_sounds.count(Resource_SoundEffect.SoundEffect.UI_CONFIRM), 7)
  assert_does_not_have(played_sounds, Resource_SoundEffect.SoundEffect.ERROR)

func test_successful_mouse_and_keyboard_selection_press_the_whole_slot_and_return() -> void:
  GameManager.set_game_speed(4.0)
  var original_position = hotbar.slot_buttons[0].position
  click_slot(0)
  press_slot_key(1)
  await get_tree().create_timer(0.06, true, false, true).timeout
  for slot in [0, 1]:
    assert_lt(hotbar.slot_buttons[slot].scale.x, 1.0,
      "Both input paths must press the frame, icon and labels inward even at 4x speed")
    assert_eq(hotbar.slot_buttons[slot].rotation, 0.0, "Successful selection must not shake")
  assert_eq(hotbar.slot_buttons[2].scale, Vector2.ONE, "Other slots must stay still")
  assert_eq(hotbar.slot_buttons[0].position, original_position, "Do not shift the container layout")
  await get_tree().create_timer(0.2, true, false, true).timeout
  for slot in [0, 1]:
    assert_eq(hotbar.slot_buttons[slot].scale, Vector2.ONE)

func test_empty_mouse_and_keyboard_selection_shake_without_selecting_or_pause_notice() -> void:
  hotbar.clear_slot(0)
  hotbar.clear_slot(1)
  for paused in [false, true]:
    get_tree().paused = paused
    click_slot(0)
    press_slot_key(1)
    await get_tree().create_timer(0.07, true, false, true).timeout
    for slot in [0, 1]:
      assert_ne(hotbar.slot_buttons[slot].rotation, 0.0,
        "Empty slots must shake for clicks and shortcuts, paused or unpaused")
      assert_eq(hotbar.slot_buttons[slot].scale, Vector2.ONE)
      assert_null(hotbar.get_slot_building(slot))
    assert_eq(hotbar.slot_buttons[2].rotation, 0.0)
    assert_false(hotbar.pause_feedback.visible, "An empty slot must not show the pause explanation")
    await get_tree().create_timer(0.35, true, false, true).timeout
    for slot in [0, 1]:
      assert_eq(hotbar.slot_buttons[slot].rotation, 0.0)
  assert_signal_not_emitted(hotbar, "building_selected")
  assert_eq(played_sounds.count(Resource_SoundEffect.SoundEffect.ERROR), 2,
    "Empty attempts share the rejection sound cooldown")
  assert_does_not_have(played_sounds, Resource_SoundEffect.SoundEffect.UI_CONFIRM)

func test_empty_right_click_configures_without_shake_or_press() -> void:
  hotbar.clear_slot(0)
  for paused in [false, true]:
    get_tree().paused = paused
    click_slot(0, MOUSE_BUTTON_RIGHT)
    await get_tree().create_timer(0.07, true, false, true).timeout
    assert_true(hotbar.building_selection_menu.visible)
    assert_eq(hotbar.current_configuring_slot, 0)
    assert_eq(hotbar.slot_buttons[0].rotation, 0.0)
    assert_eq(hotbar.slot_buttons[0].scale, Vector2.ONE)
    assert_false(hotbar.pause_feedback.visible)
    hotbar.building_selection_menu.hide()
    await wait_process_frames(2)
  assert_signal_not_emitted(hotbar, "building_selected")
  assert_does_not_have(played_sounds, Resource_SoundEffect.SoundEffect.ERROR)
  assert_does_not_have(played_sounds, Resource_SoundEffect.SoundEffect.UI_CONFIRM)

func test_switching_between_selection_and_rejection_leaves_no_transform_behind() -> void:
  press_slot_key(0)
  await get_tree().create_timer(0.05, true, false, true).timeout
  GameManager.pause_game()
  press_slot_key(0)
  assert_eq(hotbar.slot_buttons[0].scale, Vector2.ONE, "Rejection cancels an active press")
  await get_tree().create_timer(0.06, true, false, true).timeout
  GameManager.resume_game()
  press_slot_key(0)
  assert_eq(hotbar.slot_buttons[0].rotation, 0.0, "Selection cancels an active shake")
  await get_tree().create_timer(0.05, true, false, true).timeout
  assert_lt(hotbar.slot_buttons[0].scale.x, 1.0)
  press_slot_key(0)
  await get_tree().create_timer(0.25, true, false, true).timeout
  assert_eq(hotbar.slot_buttons[0].scale, Vector2.ONE, "Repeated presses must not accumulate scaling")
  assert_eq(hotbar.slot_buttons[0].rotation, 0.0)
  assert_signal_emit_count(hotbar, "building_selected", 3)

func test_repeated_attempts_reuse_notice_and_ignore_key_echo() -> void:
  GameManager.pause_game()
  hotbar.clear_slot(2)
  var child_count = hotbar.get_child_count()
  click_slot(0)
  press_slot_key(1)
  click_slot(2)
  assert_eq(hotbar.get_child_count(), child_count, "Feedback must not create queued notices")
  assert_true(hotbar.pause_feedback.visible)
  assert_eq(played_sounds.count(Resource_SoundEffect.SoundEffect.ERROR), 1,
    "Rapid attempts must not spam error sounds")
  hotbar._hide_pause_feedback()
  press_slot_key(0, true)
  assert_false(hotbar.pause_feedback.visible, "Holding a shortcut must not keep reopening feedback")
  assert_eq(played_sounds.count(Resource_SoundEffect.SoundEffect.ERROR), 1)
  assert_signal_not_emitted(hotbar, "building_selected")

func test_only_rejected_slot_shakes_and_returns_to_rest_while_paused() -> void:
  GameManager.set_game_speed(4.0)
  GameManager.pause_game()
  press_slot_key(2)
  await get_tree().create_timer(0.07, true, false, true).timeout
  assert_ne(hotbar.slot_buttons[2].rotation, 0.0)
  assert_eq(hotbar.slot_buttons[1].rotation, 0.0)
  await get_tree().create_timer(0.2, true, false, true).timeout
  assert_eq(hotbar.slot_buttons[2].rotation, 0.0)

func test_error_sound_can_repeat_after_cooldown() -> void:
  GameManager.pause_game()
  press_slot_key(0)
  await get_tree().create_timer(0.4, true, false, true).timeout
  press_slot_key(1)
  assert_eq(played_sounds.count(Resource_SoundEffect.SoundEffect.ERROR), 2)

func test_feedback_expires_while_paused_at_four_times_speed() -> void:
  GameManager.set_game_speed(4.0)
  GameManager.pause_game()
  hotbar.pause_feedback_timer.wait_time = 0.3
  press_slot_key(0)
  await get_tree().create_timer(0.12, true, false, true).timeout
  assert_true(hotbar.pause_feedback.visible, "Game speed must not shorten the notice")
  await get_tree().create_timer(0.25, true, false, true).timeout
  assert_false(hotbar.pause_feedback.visible, "Notice must expire even while paused")

func test_resume_clears_feedback_and_allows_selection() -> void:
  GameManager.pause_game()
  press_slot_key(0)
  GameManager.resume_game()
  await wait_process_frames(2)
  assert_false(hotbar.pause_feedback.visible)
  assert_true(hotbar.pause_feedback_timer.is_stopped())
  assert_false(hotbar.rejection_audio.playing)
  assert_eq(hotbar.slot_buttons[0].rotation, 0.0)
  press_slot_key(0)
  assert_signal_emitted_with_parameters(hotbar, "building_selected", [buildings[0]])

func test_menus_clear_and_suppress_feedback() -> void:
  GameManager.pause_game()
  hotbar.clear_slot(5)
  for state in [GameManager.GameState.IN_GAME_MENU, GameManager.GameState.IN_TECH_TREE]:
    GameManager.set_game_state(GameManager.GameState.PLAYING)
    press_slot_key(0)
    assert_true(hotbar.pause_feedback.visible)
    GameManager.set_game_state(state)
    await wait_process_frames(2)
    assert_false(hotbar.pause_feedback.visible)
    var sound_count = played_sounds.count(Resource_SoundEffect.SoundEffect.ERROR)
    press_slot_key(0)
    press_slot_key(5)
    assert_false(hotbar.pause_feedback.visible)
    assert_eq(played_sounds.count(Resource_SoundEffect.SoundEffect.ERROR), sound_count,
      "Menu shortcuts must stay silent")
  assert_signal_not_emitted(hotbar, "building_selected")

func test_dialogue_clears_feedback_but_hidden_gameplay_wait_allows_it() -> void:
  var textbox = DialogicNode_DialogText.new()
  hud.add_child(textbox)
  GameManager.pause_game()
  hotbar.clear_slot(5)
  press_slot_key(0)
  assert_true(hotbar.pause_feedback.visible)
  textbox.show()
  await wait_process_frames(2)
  assert_false(hotbar.pause_feedback.visible)
  press_slot_key(0)
  press_slot_key(5)
  assert_false(hotbar.pause_feedback.visible, "Do not compete with tutorial text or choices")
  assert_true(textbox.visible, "Feedback must not dismiss dialogue")
  assert_eq(played_sounds.count(Resource_SoundEffect.SoundEffect.ERROR), 1,
    "Tutorial text must not trigger error sounds")
  textbox.hide()
  press_slot_key(0)
  assert_true(hotbar.pause_feedback.visible, "A hidden tutorial gameplay wait must not suppress feedback")
  assert_signal_not_emitted(hotbar, "building_selected")

func test_configuration_remains_available_while_paused() -> void:
  GameManager.pause_game()
  press_slot_key(0)
  click_slot(0, MOUSE_BUTTON_RIGHT)
  await wait_process_frames(2)
  assert_true(hotbar.building_selection_menu.visible)
  assert_false(hotbar.pause_feedback.visible)
  hotbar.building_selection_menu.id_pressed.emit(2)
  assert_eq(hotbar.get_slot_building(0), buildings[1])
  hotbar.building_selection_menu.hide()

func test_in_game_menu_still_blocks_configuration() -> void:
  GameManager.pause_game()
  GameManager.set_game_state(GameManager.GameState.IN_GAME_MENU)
  # Exercise the hotbar guard even if an event gets past the menu overlay.
  var event = InputEventMouseButton.new()
  event.button_index = MOUSE_BUTTON_RIGHT
  event.pressed = true
  hotbar._on_slot_gui_input(event, 0)
  assert_false(hotbar.building_selection_menu.visible)
  assert_eq(hotbar.current_configuring_slot, -1)

func test_hidden_hotbar_does_not_show_feedback() -> void:
  GameManager.pause_game()
  hotbar.clear_slot(0)
  press_slot_key(1)
  hotbar.hide()
  await wait_process_frames(2)
  assert_false(hotbar.pause_feedback.visible)
  press_slot_key(0)
  press_slot_key(1)
  assert_false(hotbar.pause_feedback.visible)
  assert_eq(played_sounds.count(Resource_SoundEffect.SoundEffect.ERROR), 1)
  assert_signal_not_emitted(hotbar, "building_selected")

func test_notice_stays_above_slots_and_does_not_capture_mouse_input() -> void:
  GameManager.pause_game()
  press_slot_key(0)
  await wait_process_frames(2)
  var notice_rect = hotbar.pause_feedback.get_global_rect()
  assert_true(Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(notice_rect))
  assert_lte(notice_rect.end.y, hotbar.slots_container.global_position.y)
  assert_eq(hotbar.pause_feedback.mouse_filter, Control.MOUSE_FILTER_IGNORE)
  for control in hotbar.pause_feedback.find_children("*", "Control"):
    assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE)
