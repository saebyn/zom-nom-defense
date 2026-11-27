extends GutTest

const AUDIO_MANAGER_SCENE = preload("res://Utilities/Systems/audio_manager.tscn")
const ADVANCE_TRACK = &"advance_background_music_track"
const FIRST_TRACK = "Make Do Or Die"
const SECOND_TRACK = "Battle Theme A"

var viewport: SubViewport
var audio_manager
var previous_bindings: Array[InputEvent]
var previous_paused: bool
var previous_music_pause: bool


func before_each() -> void:
  previous_bindings = InputMap.action_get_events(ADVANCE_TRACK)
  InputMap.action_erase_events(ADVANCE_TRACK)
  for binding in ProjectSettings.get_setting("input/" + ADVANCE_TRACK)["events"]:
    InputMap.action_add_event(ADVANCE_TRACK, binding)
  previous_paused = get_tree().paused
  previous_music_pause = SettingsManager.music_pause
  get_tree().paused = false
  # Exercise real input routing without sending test events to the autoload.
  viewport = SubViewport.new()
  add_child_autofree(viewport)
  audio_manager = AUDIO_MANAGER_SCENE.instantiate()
  viewport.add_child(audio_manager)
  if not audio_manager.bg_music_player.playing:
    audio_manager.play_background_music()
  watch_signals(audio_manager)


func after_each() -> void:
  InputMap.action_erase_events(ADVANCE_TRACK)
  for binding in previous_bindings:
    InputMap.action_add_event(ADVANCE_TRACK, binding)
  get_tree().paused = previous_paused
  _set_music_pause(previous_music_pause)


func _set_music_pause(value: bool) -> void:
  SettingsManager.music_pause = value
  SettingsManager.apply_audio_settings()


func _send_key(key: Key, pressed: bool, ctrl: bool = false, echo: bool = false) -> void:
  var event = InputEventKey.new()
  event.keycode = key
  event.physical_keycode = key
  event.pressed = pressed
  event.ctrl_pressed = ctrl
  event.echo = echo
  viewport.push_input(event, true)


func _press_key(key: Key, ctrl: bool = false) -> void:
  _send_key(key, true, ctrl)
  _send_key(key, false, ctrl)


func test_rebound_shortcut_advances_instead_of_f2() -> void:
  var binding = InputEventKey.new()
  binding.physical_keycode = KEY_F6
  binding.ctrl_pressed = true
  InputMap.action_erase_events(ADVANCE_TRACK)
  InputMap.action_add_event(ADVANCE_TRACK, binding)

  _press_key(KEY_F2)
  _press_key(KEY_F6)
  assert_signal_not_emitted(audio_manager, "song_started")

  _press_key(KEY_F6, true)
  assert_signal_emitted_with_parameters(audio_manager, "song_started", [SECOND_TRACK])


func test_holding_shortcut_skips_only_once() -> void:
  _send_key(KEY_F2, true)
  _send_key(KEY_F2, true, false, true)
  _send_key(KEY_F2, false)

  assert_signal_emitted_with_parameters(audio_manager, "song_started", [SECOND_TRACK])
  assert_signal_emit_count(audio_manager, "song_started", 1)


func test_default_shortcut_ignores_ctrl_f2() -> void:
  _press_key(KEY_F2, true)

  assert_signal_not_emitted(audio_manager, "song_started")


func test_rapid_skips_switch_tracks_without_waiting_for_cooldown() -> void:
  var expected_tracks = [SECOND_TRACK, FIRST_TRACK, SECOND_TRACK]
  for _index in expected_tracks.size():
    _press_key(KEY_F2)
  var actual_count: int = get_signal_emit_count(audio_manager, "song_started")
  assert_eq(actual_count, expected_tracks.size())
  for index in mini(actual_count, expected_tracks.size()):
    assert_signal_emitted_with_parameters(audio_manager, "song_started", [expected_tracks[index]], index)


func test_shortcut_does_not_restart_stopped_music() -> void:
  audio_manager.stop_background_music()

  _press_key(KEY_F2)

  assert_signal_not_emitted(audio_manager, "song_started")


func test_shortcut_leaves_only_track_playing() -> void:
  var second_stream: AudioStream = audio_manager.songs[SECOND_TRACK]
  audio_manager.songs.erase(SECOND_TRACK)

  _press_key(KEY_F2)
  assert_signal_not_emitted(audio_manager, "song_started")

  audio_manager.songs[SECOND_TRACK] = second_stream
  _press_key(KEY_F2)
  assert_signal_emitted_with_parameters(audio_manager, "song_started", [SECOND_TRACK])


func test_shortcut_advances_music_that_keeps_playing_when_game_is_paused() -> void:
  _set_music_pause(false)
  get_tree().paused = true

  _press_key(KEY_F2)

  assert_signal_emitted_with_parameters(audio_manager, "song_started", [SECOND_TRACK])


func test_shortcut_does_not_change_paused_music() -> void:
  _set_music_pause(true)
  get_tree().paused = true

  _press_key(KEY_F2)
  assert_signal_not_emitted(audio_manager, "song_started")

  get_tree().paused = false
  _press_key(KEY_F2)
  assert_signal_emitted_with_parameters(audio_manager, "song_started", [SECOND_TRACK])
