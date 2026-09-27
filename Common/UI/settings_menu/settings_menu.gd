extends Control
class_name UI_SettingsMenu

## Settings Menu UI
## Provides interface for adjusting video, audio, and input settings.
## Per-setting logic is handled by SettingBinding child nodes; this script
## only manages high-level flows (apply, cancel, video confirmation, Twitch auth).

signal closed()

@onready var tab_container: TabContainer = $Panel/MarginContainer/VBoxContainer/TabContainer

# Keybinds tab controls
@onready var keybinds_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Keybinds/ScrollContainer/KeybindsContainer

# Bottom buttons
@onready var apply_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/ApplyButton
@onready var cancel_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/CancelButton

# Twitch settings UI elements
@onready var twitch_auth_button: Button = %TwitchAuthButton
@onready var twitch_status_label: Label = %TwitchStatusLabel

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

# Keybind button scene
const KeybindButtonScene = preload("res://Common/UI/settings_menu/keybind_button.tscn")
const VideoConfirmDialogScene = preload("res://Common/UI/settings_menu/video_confirm_dialog.tscn")

# Store original keybinds to restore on cancel
var original_keybinds: Dictionary = {}

# Video confirmation dialog
var video_confirm_dialog = null

# Cached array of all SettingBinding descendants (populated in _ready)
var _bindings_cache: Array = []


func _ready() -> void:
  # Hide by default
  visible = false

  # Create video confirmation dialog
  video_confirm_dialog = VideoConfirmDialogScene.instantiate()
  add_child(video_confirm_dialog)
  video_confirm_dialog.settings_confirmed.connect(_on_video_settings_confirmed)
  video_confirm_dialog.settings_reverted.connect(_on_video_settings_reverted)

  # Build bindings cache (all SettingBinding descendants, done after child _ready() calls)
  for node in find_children("*", "", true, false):
    if node is SettingBinding:
      _bindings_cache.append(node)

  # Setup resolution options via the resolution binding's control
  _setup_resolution_options()

  # Setup UI scale options via the UI scale binding's control
  _setup_ui_scale_options()

  # Setup keybind buttons
  _setup_keybind_buttons()

  # Setup Twitch status
  await _update_twitch_status()

  # Connect bottom buttons
  apply_button.pressed.connect(_on_apply_pressed)
  cancel_button.pressed.connect(_on_cancel_pressed)

  # Connect Twitch auth button
  twitch_auth_button.pressed.connect(_on_twitch_auth_pressed)
  if SettingsManager.twitch_enabled and is_instance_valid(Twitch.api):
    Twitch.api.unauthenticated.connect(_on_twitch_unauthenticated)

  # Connect binding signals that require menu-level side effects
  _connect_binding_signals()


# ---------------------------------------------------------------------------
# SettingBinding helpers
# ---------------------------------------------------------------------------

func _get_all_bindings() -> Array:
  return _bindings_cache


func _get_bindings_by_group(group: String) -> Array:
  var result: Array = []
  for binding in _get_all_bindings():
    if (binding as SettingBinding).apply_group == group:
      result.append(binding)
  return result


func _find_binding_for_key(key: StringName) -> SettingBinding:
  for binding in _get_all_bindings():
    if (binding as SettingBinding).setting_key == key:
      return binding as SettingBinding
  return null


func _connect_binding_signals() -> void:
  for raw in _get_all_bindings():
    var binding := raw as SettingBinding
    if binding.apply_group == "audio":
      binding.value_changed.connect(_on_audio_binding_changed)
    elif binding.setting_key == &"twitch_enabled":
      binding.value_changed.connect(_on_twitch_enabled_changed)


# ---------------------------------------------------------------------------
# Setup helpers
# ---------------------------------------------------------------------------

func _setup_resolution_options() -> void:
  var resolution_binding := _find_binding_for_key(&"resolution_index")
  if not resolution_binding:
    return
  var option := resolution_binding.get_control() as OptionButton
  if not option:
    return
  option.clear()
  for i in range(SettingsManager.RESOLUTIONS.size()):
    option.add_item(SettingsManager.get_resolution_string(i), i)


func _setup_ui_scale_options() -> void:
  var ui_scale_binding := _find_binding_for_key(&"ui_scale_index")
  if not ui_scale_binding:
    return
  var option := ui_scale_binding.get_control() as OptionButton
  if not option:
    return
  option.clear()
  for i in range(SettingsManager.UI_SCALES.size()):
    option.add_item(SettingsManager.get_ui_scale_string(i), i)


func _setup_keybind_buttons() -> void:
  # Get all input actions
  var actions = InputMap.get_actions()

  for action in actions:
    # Skip UI actions and built-in actions
    if action.begins_with("ui_") or action.begins_with("spatial_editor") or action == "dialogic_default_action":
      continue

    # Create keybind button for this action
    var keybind_button = KeybindButtonScene.instantiate()
    keybind_button.action_name = action
    keybinds_container.add_child(keybind_button)


# ---------------------------------------------------------------------------
# Menu lifecycle
# ---------------------------------------------------------------------------

func show_menu() -> void:
  visible = true
  _store_original_keybinds()
  for binding in _get_all_bindings():
    (binding as SettingBinding).load_value()
  if tab_container:
    tab_container.current_tab = 0


func hide_menu() -> void:
  visible = false


# ---------------------------------------------------------------------------
# Apply / Cancel
# ---------------------------------------------------------------------------

func _has_video_changes() -> bool:
  for binding in _get_bindings_by_group("video"):
    var b := binding as SettingBinding
    if b.get_staged_value() != b.get_original_value():
      return true
  return false


func _on_apply_pressed() -> void:
  # Check if video settings changed before applying anything
  var video_settings_changed := _has_video_changes()

  # Apply audio settings (live preview keeps SettingsManager in sync, but apply explicitly)
  for binding in _get_bindings_by_group("audio"):
    (binding as SettingBinding).apply_value()
  SettingsManager.apply_audio_settings()

  # Apply Twitch settings
  for binding in _get_bindings_by_group("twitch"):
    (binding as SettingBinding).apply_value()

  # Apply Gameplay settings
  for binding in _get_bindings_by_group("gameplay"):
    (binding as SettingBinding).apply_value()

  if video_settings_changed:
    # Apply video settings then show confirmation dialog
    for binding in _get_bindings_by_group("video"):
      (binding as SettingBinding).apply_value()
    SettingsManager.apply_video_settings()
    MyLogger.info("SettingsMenu", "Video settings changed, showing confirmation dialog")
    video_confirm_dialog.show_dialog()
  else:
    # No video changes — save and close
    SettingsManager.save_settings()
    MyLogger.info("SettingsMenu", "Settings applied and saved")
    hide_menu()
    closed.emit()


func _on_cancel_pressed() -> void:
  MyLogger.debug("SettingsMenu", "Settings cancelled")
  _restore_original_keybinds()
  # Revert all bindings that support cancel-revert
  for raw in _get_all_bindings():
    var binding := raw as SettingBinding
    if binding.revert_on_cancel:
      binding.revert_value()
  SettingsManager.apply_audio_settings()
  hide_menu()
  closed.emit()


func _on_video_settings_confirmed() -> void:
  # User confirmed the video settings — save everything and close
  SettingsManager.save_settings()
  MyLogger.info("SettingsMenu", "Video settings confirmed and saved")
  hide_menu()
  closed.emit()


func _on_video_settings_reverted() -> void:
  # User rejected or timer expired — revert video settings
  for binding in _get_bindings_by_group("video"):
    (binding as SettingBinding).revert_value()
  SettingsManager.apply_video_settings()
  MyLogger.info("SettingsMenu", "Video settings reverted to previous state")
  # Audio settings were already applied, so save those
  SettingsManager.save_settings()
  hide_menu()
  closed.emit()


# ---------------------------------------------------------------------------
# Binding-triggered side effects
# ---------------------------------------------------------------------------

func _on_audio_binding_changed(_value: Variant) -> void:
  SettingsManager.apply_audio_settings()


func _on_twitch_enabled_changed(_value: Variant) -> void:
  await _update_twitch_status()


# ---------------------------------------------------------------------------
# Twitch
# ---------------------------------------------------------------------------

func _on_twitch_unauthenticated() -> void:
  MyLogger.warn("SettingsMenu", "Twitch token lost - re-authentication required")
  twitch_status_label.text = "Twitch: Disconnected"
  twitch_auth_button.disabled = false


func _on_twitch_auth_pressed() -> void:
  # Start Twitch authentication process
  MyLogger.info("SettingsMenu", "Starting Twitch authentication process")

  # Disable the auth button while authenticating to prevent multiple clicks
  twitch_auth_button.disabled = true
  twitch_status_label.text = "Twitch: Authenticating..."

  var setup_successful: bool = await Twitch.setup()

  if setup_successful:
    MyLogger.info("SettingsMenu", "Twitch authentication successful")
    twitch_status_label.text = "Twitch: Connected"
    twitch_auth_button.disabled = true
  else:
    MyLogger.warn("SettingsMenu", "Twitch authentication failed")
    twitch_status_label.text = "Twitch: Connection Failed"
    twitch_auth_button.disabled = false

  # if the signal wasn't connected in _ready (because Twitch.api wasn't valid at that time), connect it now
  if SettingsManager.twitch_enabled and is_instance_valid(Twitch.api) and not Twitch.api.unauthenticated.is_connected(_on_twitch_unauthenticated):
    Twitch.api.unauthenticated.connect(_on_twitch_unauthenticated)


func _update_twitch_status() -> void:
  if not SettingsManager.twitch_enabled:
    twitch_status_label.text = "Twitch: Disabled"
    twitch_auth_button.disabled = true
  elif Twitch.auth != null and Twitch.auth.is_authenticated:
    var display_name: String = await _get_twitch_display_name()
    if display_name.is_empty():
      twitch_status_label.text = "Twitch: Connected (unknown user)"
    else:
      twitch_status_label.text = "Twitch: Connected as %s" % display_name
    twitch_auth_button.disabled = false
  else:
    twitch_status_label.text = "Twitch: Not Connected"
    twitch_auth_button.disabled = false


func _get_twitch_display_name() -> String:
  var current_user: TwitchUser = await Twitch.get_current_user()
  if is_instance_valid(current_user) and not current_user.display_name.is_empty():
    return current_user.display_name
  return ""


# ---------------------------------------------------------------------------
# Keybinds
# ---------------------------------------------------------------------------

func _store_original_keybinds() -> void:
  # Store the current keybinds so we can restore them if user cancels
  original_keybinds.clear()
  var actions = InputMap.get_actions()

  for action in actions:
    # Skip UI actions and built-in actions
    if action.begins_with("ui_") or action.begins_with("spatial_editor"):
      continue

    # Store a copy of all events for this action
    var events = InputMap.action_get_events(action)
    var events_copy = []
    for event in events:
      events_copy.append(event.duplicate())
    original_keybinds[action] = events_copy


func _restore_original_keybinds() -> void:
  # Restore keybinds to their original state
  for action in original_keybinds.keys():
    # Clear current bindings
    InputMap.action_erase_events(action)

    # Restore original bindings
    for event in original_keybinds[action]:
      InputMap.action_add_event(action, event)

  # Update the display of all keybind buttons
  if keybinds_container:
    for child in keybinds_container.get_children():
      if child.has_method("_update_display"):
        child._update_display()

  MyLogger.debug("SettingsMenu", "Keybinds restored to original state")


func _on_master_slider_value_changed(_value: float) -> void:
  audio_player.bus = "Master"
  audio_player.play()

func _on_music_slider_value_changed(_value: float) -> void:
  audio_player.bus = "Music"
  audio_player.play()

func _on_sfx_slider_value_changed(_value: float) -> void:
  audio_player.bus = "Sound Effects"
  audio_player.play()

