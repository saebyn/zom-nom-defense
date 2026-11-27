extends GutTest

const SETTINGS_MENU = preload("res://Common/UI/settings_menu/settings_menu.tscn")

var viewport: SubViewport
var menu: UI_SettingsMenu
var previous_volumes: Vector3


func before_each() -> void:
  previous_volumes = Vector3(
    SettingsManager.master_volume, SettingsManager.music_volume, SettingsManager.sfx_volume
  )
  SettingsManager.master_volume = -6.02
  SettingsManager.music_volume = -6.02
  SettingsManager.sfx_volume = -6.02
  SettingsManager.apply_audio_settings()

  viewport = SubViewport.new()
  viewport.size = Vector2i(1280, 720)
  add_child_autofree(viewport)
  menu = SETTINGS_MENU.instantiate()
  viewport.add_child(menu)


func after_each() -> void:
  SettingsManager.master_volume = previous_volumes.x
  SettingsManager.music_volume = previous_volumes.y
  SettingsManager.sfx_volume = previous_volumes.z
  SettingsManager.apply_audio_settings()


func _playing_previews() -> Array[Node]:
  return menu.find_children("*", "AudioStreamPlayer").filter(
    func(player: AudioStreamPlayer) -> bool: return player.playing
  )


func _show_audio_tab() -> void:
  menu.show_menu()
  menu.tab_container.current_tab = 1
  await wait_process_frames(2)


func _send_pointer(position: Vector2, pressed: bool) -> void:
  var event := InputEventMouseButton.new()
  event.position = position
  event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = pressed
  viewport.push_input(event, true)


func _drag_pointer(position: Vector2) -> void:
  var event := InputEventMouseMotion.new()
  event.position = position
  event.button_mask = MOUSE_BUTTON_MASK_LEFT
  viewport.push_input(event, true)


func _tap_right_arrow() -> void:
  for pressed in [true, false]:
    var event := InputEventKey.new()
    event.keycode = KEY_RIGHT
    event.pressed = pressed
    viewport.push_input(event, true)


func _send_dpad_right(pressed: bool) -> void:
  var event := InputEventJoypadButton.new()
  event.button_index = JOY_BUTTON_DPAD_RIGHT
  event.pressed = pressed
  # The slider gets repeat state from Input, not just the viewport's event.
  Input.parse_input_event(event)
  Input.flush_buffered_events()
  viewport.push_input(event, true)


func test_loading_settings_does_not_play_a_calibration_sound() -> void:
  await _show_audio_tab()
  assert_eq(_playing_previews().size(), 0, "Loading saved volumes must be quiet")

  # Refresh a visible control so hiding the audio tab cannot mask a stray preview.
  SettingsManager.music_volume = -12.04
  var music_binding := menu.find_child("MusicBinding") as SettingBinding
  music_binding.load_value()

  assert_almost_eq((music_binding.get_control() as Slider).value, 25.0, 0.01)
  assert_eq(_playing_previews().size(), 0, "Refreshing a visible slider must also be quiet")


func test_dragging_each_volume_plays_one_continuous_preview_on_its_bus() -> void:
  await _show_audio_tab()
  var buses := {&"MasterSlider": &"Master", &"MusicSlider": &"Music", &"SFXSlider": &"Sound Effects"}
  for slider_name in buses:
    var expected_bus: StringName = buses[slider_name]
    var slider := menu.find_child(slider_name) as Slider
    var point := slider.get_global_rect().get_center() - Vector2(slider.size.x * 0.2, 0)
    _send_pointer(point, true)
    var players := _playing_previews()
    assert_eq(players.size(), 1, "Changing %s must start exactly one preview" % expected_bus)
    if players.is_empty():
      _send_pointer(point, false)
      continue
    var player := players[0] as AudioStreamPlayer
    assert_eq(player.bus, expected_bus)
    assert_lt(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(expected_bus)), -6.02,
      "The adjusted volume must reach the preview's bus immediately")
    var playback := player.get_stream_playback()
    await get_tree().create_timer(0.7, true, false, true).timeout
    assert_true(player.playing, "The preview must keep playing during a sustained drag")
    _drag_pointer(point + Vector2(slider.size.x * 0.1, 0))
    assert_eq(player.get_stream_playback(), playback, "Changing the value must not restart playback")

    _send_pointer(point, false)
    assert_eq(_playing_previews().size(), 0, "Releasing the pointer must stop the preview")


func test_keyboard_adjustment_plays_until_input_goes_idle() -> void:
  await _show_audio_tab()
  var slider := menu.find_child("MusicSlider") as Slider
  slider.grab_focus()

  _tap_right_arrow()
  assert_eq(slider.value, 51.0)
  var players := _playing_previews()
  assert_eq(players.size(), 1)
  if players.is_empty():
    return
  var player := players[0] as AudioStreamPlayer
  assert_eq(player.bus, &"Music")
  var playback := player.get_stream_playback()

  await get_tree().create_timer(0.3, true, false, true).timeout
  assert_true(player.playing, "A single key press must be audible long enough to judge")
  _tap_right_arrow()
  assert_eq(player.get_stream_playback(), playback, "Repeat input must extend, not restart, the preview")
  await get_tree().create_timer(0.4, true, false, true).timeout
  assert_true(player.playing, "The timeout must be measured from the last adjustment")
  await get_tree().create_timer(0.35, true, false, true).timeout
  assert_eq(_playing_previews().size(), 0, "The preview must stop when adjustments stop")


func test_held_controller_adjustment_keeps_the_preview_playing() -> void:
  await _show_audio_tab()
  var slider := menu.find_child("SFXSlider") as Slider
  slider.grab_focus()

  _send_dpad_right(true)
  assert_eq(slider.value, 51.0)
  var players := _playing_previews()
  assert_eq(players.size(), 1)
  if players.is_empty():
    _send_dpad_right(false)
    return
  var player := players[0] as AudioStreamPlayer
  var playback := player.get_stream_playback()

  await get_tree().create_timer(0.75, true, false, true).timeout
  assert_gt(slider.value, 51.0, "Holding right must repeat the adjustment")
  assert_true(player.playing)
  assert_eq(player.get_stream_playback(), playback)

  _send_dpad_right(false)
  await get_tree().create_timer(0.75, true, false, true).timeout
  assert_eq(_playing_previews().size(), 0)


func test_leaving_the_audio_tab_stops_playback() -> void:
  await _show_audio_tab()
  (menu.find_child("MusicSlider") as Slider).grab_focus()
  _tap_right_arrow()
  assert_eq(_playing_previews().size(), 1)

  menu.tab_container.current_tab = 0

  assert_eq(_playing_previews().size(), 0, "Leaving the audio controls must stop the preview")


func test_adjusting_another_bus_replaces_the_active_preview() -> void:
  await _show_audio_tab()
  (menu.find_child("MasterSlider") as Slider).grab_focus()
  _tap_right_arrow()
  var players := _playing_previews()
  assert_eq(players.size(), 1)
  if players.is_empty():
    return
  var player := players[0] as AudioStreamPlayer
  assert_eq(player.bus, &"Master")
  var stream := player.stream

  (menu.find_child("SFXSlider") as Slider).grab_focus()
  _tap_right_arrow()

  players = _playing_previews()
  assert_eq(players.size(), 1, "Previews on different buses must not overlap")
  if not players.is_empty():
    var replacement := players[0] as AudioStreamPlayer
    assert_eq(replacement.bus, &"Sound Effects")
    assert_eq(replacement.stream, stream, "Every bus must use the same calibration sound")


func test_cancel_restores_the_previous_volume_without_playing_a_preview() -> void:
  await _show_audio_tab()
  (menu.find_child("MusicSlider") as Slider).grab_focus()
  _tap_right_arrow()
  var music_bus := AudioServer.get_bus_index(&"Music")
  assert_gt(AudioServer.get_bus_volume_db(music_bus), -6.02, "Changes must be applied before saving")

  var point := menu.cancel_button.get_global_rect().get_center()
  _send_pointer(point, true)
  _send_pointer(point, false)

  assert_false(menu.visible)
  assert_almost_eq(SettingsManager.music_volume, -6.02, 0.001)
  assert_almost_eq(AudioServer.get_bus_volume_db(music_bus), -6.02, 0.001)
  assert_eq(_playing_previews().size(), 0, "Resetting volumes must be quiet")
