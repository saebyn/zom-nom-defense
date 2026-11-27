class_name UI_FirstRunAudioSetup
extends Control

const MAIN_MENU := "res://Stages/UI/main_menu/main_menu.tscn"

@onready var _master_slider: HSlider = %MasterSlider
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SFXSlider
@onready var _continue_button: Button = %ContinueButton
@onready var _preview: UI_VolumeSliderPreview = $VolumeSliderPreview


func _ready() -> void:
  if not SettingsManager.needs_first_run_audio_setup():
    hide()
    _open_main_menu.call_deferred()
    return

  for binding: SettingBinding in [%MasterBinding, %MusicBinding, %SFXBinding]:
    binding.load_value()
    binding.value_changed.connect(_on_volume_changed)
    _preview.bind_volume_slider(binding)
  _continue_button.pressed.connect(_on_continue_pressed)
  # Godot's default ui_accept has no controller binding.
  _continue_button.shortcut_context = _continue_button
  _update_slider_availability()
  _master_slider.grab_focus()


func _on_volume_changed(_value: float) -> void:
  SettingsManager.apply_audio_settings()
  _update_slider_availability()


func _update_slider_availability() -> void:
  var unlocked := _master_slider.value > 0.0
  for slider in [_music_slider, _sfx_slider]:
    slider.editable = unlocked
    slider.focus_mode = Control.FOCUS_ALL if unlocked else Control.FOCUS_NONE

  # Skip locked sliders for both keyboard and controller navigation.
  var controls: Array[Control] = [_master_slider]
  if unlocked:
    controls.append_array([_music_slider, _sfx_slider])
  controls.append(_continue_button)
  for i in range(controls.size()):
    var control := controls[i]
    control.focus_neighbor_top = control.get_path_to(controls[posmod(i - 1, controls.size())])
    control.focus_neighbor_bottom = control.get_path_to(controls[(i + 1) % controls.size()])


func _on_continue_pressed() -> void:
  if SettingsManager.save_settings() != OK:
    %SaveError.show()
    return
  if _open_main_menu() == OK:
    AudioManager.play_background_music()


func _open_main_menu() -> Error:
  var error := get_tree().change_scene_to_file(MAIN_MENU)
  if error != OK:
    MyLogger.error("FirstRunAudioSetup", "Could not open the main menu: %d" % error)
  return error
