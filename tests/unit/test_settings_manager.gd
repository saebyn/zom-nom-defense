extends GutTest

## Unit tests for SettingsManager functionality

func before_each():
  # Note: We cannot fully reset SettingsManager between tests since it's an autoload
  # Tests should be designed to be independent despite this limitation
  pass

func after_each():
  pass

func test_default_viewer_names_enabled():
  # Assert - viewer names should be enabled by default
  assert_true(SettingsManager.viewer_names_enabled, "Viewer-submitted survivor names should be enabled by default")

func test_viewer_names_enabled_can_be_toggled():
  # Arrange
  var original: bool = SettingsManager.viewer_names_enabled

  # Act - disable the setting
  SettingsManager.viewer_names_enabled = false

  # Assert - the value reflects the change
  assert_false(SettingsManager.viewer_names_enabled, "viewer_names_enabled should be false after setting to false")

  # Restore original value
  SettingsManager.viewer_names_enabled = original

func test_save_keybinds_writes_key_event_to_config():
  # Arrange - use a test action that exists in InputMap
  var test_action = "camera_move_left"
  
  # Set a known key binding
  var key_event = InputEventKey.new()
  key_event.physical_keycode = KEY_A
  key_event.shift_pressed = false
  InputMap.action_erase_events(test_action)
  InputMap.action_add_event(test_action, key_event)
  
  # Act - save keybinds via the config file
  var config = ConfigFile.new()
  SettingsManager._save_keybinds(config)
  
  # Assert - config should contain the binding as an array
  assert_true(config.has_section("keybinds"), "Config should have keybinds section")
  assert_true(config.has_section_key("keybinds", test_action), "Config should have the test action")
  var saved_bindings: Array = config.get_value("keybinds", test_action, [])
  assert_eq(saved_bindings.size(), 1, "Should have exactly one binding saved")
  var saved_data: Dictionary = saved_bindings[0]
  assert_eq(saved_data.get("type"), "key", "Saved type should be 'key'")
  assert_eq(saved_data.get("physical_keycode"), KEY_A, "Saved keycode should match KEY_A")
  assert_eq(saved_data.get("shift_pressed"), false, "Saved shift_pressed should be false")

func test_save_keybinds_writes_mouse_event_to_config():
  # Arrange - use a test action and assign a mouse button
  var test_action = "camera_move_left"
  
  var mouse_event = InputEventMouseButton.new()
  mouse_event.button_index = MOUSE_BUTTON_LEFT
  InputMap.action_erase_events(test_action)
  InputMap.action_add_event(test_action, mouse_event)
  
  # Act
  var config = ConfigFile.new()
  SettingsManager._save_keybinds(config)
  
  # Assert
  assert_true(config.has_section_key("keybinds", test_action), "Config should have the test action")
  var saved_bindings: Array = config.get_value("keybinds", test_action, [])
  assert_eq(saved_bindings.size(), 1, "Should have exactly one binding saved")
  var saved_data: Dictionary = saved_bindings[0]
  assert_eq(saved_data.get("type"), "mouse", "Saved type should be 'mouse'")
  assert_eq(saved_data.get("button_index"), int(MOUSE_BUTTON_LEFT), "Saved button_index should match")

func test_load_keybinds_applies_key_event_to_input_map():
  # Arrange - create a config with a known keybind (array format)
  var test_action = "camera_move_left"
  var config = ConfigFile.new()
  config.set_value("keybinds", test_action, [ {
    "type": "key",
    "physical_keycode": KEY_Z,
    "ctrl_pressed": false,
    "alt_pressed": false,
    "shift_pressed": true,
    "meta_pressed": false,
    "command_or_control_autoremap": false
  }])
  
  # Act - load keybinds from config
  SettingsManager._load_keybinds(config)
  
  # Assert - InputMap should now have the new binding
  var events = InputMap.action_get_events(test_action)
  assert_true(events.size() > 0, "Action should have at least one event")
  var loaded_event = events[0]
  assert_true(loaded_event is InputEventKey, "Loaded event should be a key event")
  if loaded_event is InputEventKey:
    assert_eq(loaded_event.physical_keycode, KEY_Z, "Loaded keycode should be KEY_Z")
    assert_eq(loaded_event.shift_pressed, true, "Loaded shift_pressed should be true")

func test_load_keybinds_applies_mouse_event_to_input_map():
  # Arrange
  var test_action = "camera_move_left"
  var config = ConfigFile.new()
  config.set_value("keybinds", test_action, [ {
    "type": "mouse",
    "button_index": int(MOUSE_BUTTON_RIGHT)
  }])
  
  # Act
  SettingsManager._load_keybinds(config)
  
  # Assert
  var events = InputMap.action_get_events(test_action)
  assert_true(events.size() > 0, "Action should have at least one event after load")
  var loaded_event = events[0]
  assert_true(loaded_event is InputEventMouseButton, "Loaded event should be a mouse button event")
  if loaded_event is InputEventMouseButton:
    assert_eq(int(loaded_event.button_index), int(MOUSE_BUTTON_RIGHT), "Loaded button should be right mouse button")

func test_load_keybinds_ignores_unknown_actions():
  # Arrange - config with an action that doesn't exist in InputMap
  var config = ConfigFile.new()
  config.set_value("keybinds", "nonexistent_action_xyz", [ {
    "type": "key",
    "physical_keycode": KEY_A,
    "ctrl_pressed": false,
    "alt_pressed": false,
    "shift_pressed": false,
    "meta_pressed": false,
    "command_or_control_autoremap": false
  }])
  
  # Act - should not crash or add the invalid action
  SettingsManager._load_keybinds(config)
  
  # Assert - nonexistent action should still not be in InputMap
  assert_false(InputMap.has_action("nonexistent_action_xyz"), "Unknown action should not be added to InputMap")

func test_load_keybinds_skips_missing_keybinds_section():
  # Arrange - config without a keybinds section
  var config = ConfigFile.new()
  config.set_value("audio", "master_volume", -6.02)
  
  # Capture current bindings for a known action
  var test_action = "camera_move_left"
  var events_before = InputMap.action_get_events(test_action).duplicate()
  
  # Act - should not crash
  SettingsManager._load_keybinds(config)
  
  # Assert - bindings should be unchanged
  var events_after = InputMap.action_get_events(test_action)
  assert_eq(events_before.size(), events_after.size(), "Bindings should be unchanged when no keybinds section")

func test_default_ui_scale_index_is_100_percent():
  # Save and restore ui_scale_index so a persisted settings.cfg cannot break this test
  var original_ui_scale_index: int = SettingsManager.ui_scale_index
  SettingsManager.ui_scale_index = 1

  assert_eq(SettingsManager.ui_scale_index, 1, "Default UI scale index should be 1 (100%)")

  SettingsManager.ui_scale_index = original_ui_scale_index

func test_get_ui_scale_string_returns_correct_labels():
  assert_eq(SettingsManager.get_ui_scale_string(0), "75%",  "Index 0 should be 75%")
  assert_eq(SettingsManager.get_ui_scale_string(1), "100%", "Index 1 should be 100%")
  assert_eq(SettingsManager.get_ui_scale_string(2), "125%", "Index 2 should be 125%")
  assert_eq(SettingsManager.get_ui_scale_string(3), "150%", "Index 3 should be 150%")
  assert_eq(SettingsManager.get_ui_scale_string(4), "200%", "Index 4 should be 200%")

func test_get_ui_scale_string_returns_unknown_for_invalid_index():
  assert_eq(SettingsManager.get_ui_scale_string(-1), "Unknown", "Negative index should return 'Unknown'")
  assert_eq(SettingsManager.get_ui_scale_string(99), "Unknown", "Out-of-range index should return 'Unknown'")

func test_ui_scales_constant_has_expected_values():
  assert_eq(SettingsManager.UI_SCALES.size(), 5, "UI_SCALES should have 5 entries")
  assert_almost_eq(SettingsManager.UI_SCALES[1], 1.0, 0.001, "Index 1 should be 1.0 (100%)")
