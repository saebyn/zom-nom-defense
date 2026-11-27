class_name UI_VolumeSliderPreview
extends Node

const VOLUME_BUSES := {
  &"master_volume": &"Master",
  &"music_volume": &"Music",
  &"sfx_volume": &"Sound Effects",
}

# Godot's slider waits half a second before the first held controller repeat.
const IDLE_SECONDS := 0.6

@onready var _player: AudioStreamPlayer = $AudioStreamPlayer
@onready var _idle_timer: Timer = $IdleTimer

var _active_slider: Slider
var _dragging_slider: Slider


func _ready() -> void:
  _idle_timer.timeout.connect(_stop_preview)


## Connect after the screen's live-apply handler so the preview uses the new bus volume.
func bind_volume_slider(binding: SettingBinding) -> void:
  if not VOLUME_BUSES.has(binding.setting_key):
    return
  var slider := binding.get_control() as Slider
  if slider == null:
    return

  var bus: StringName = VOLUME_BUSES[binding.setting_key]
  binding.value_changed.connect(_on_volume_changed.bind(slider, bus))
  slider.drag_started.connect(_on_drag_started.bind(slider))
  slider.drag_ended.connect(_on_drag_ended.bind(slider))
  slider.visibility_changed.connect(_on_slider_visibility_changed.bind(slider))


func _on_volume_changed(_value: float, slider: Slider, bus: StringName) -> void:
  _active_slider = slider
  if _dragging_slider == slider:
    _idle_timer.stop()
  else:
    _idle_timer.start(IDLE_SECONDS)
  if _player.playing and _player.bus == bus:
    return
  _player.stop()
  _player.bus = bus
  _player.play()


func _on_drag_started(slider: Slider) -> void:
  _dragging_slider = slider


func _on_drag_ended(_value_changed: bool, slider: Slider) -> void:
  _end_adjustment(slider)


func _on_slider_visibility_changed(slider: Slider) -> void:
  if not slider.is_visible_in_tree():
    _end_adjustment(slider)


func _end_adjustment(slider: Slider) -> void:
  if _dragging_slider == slider:
    _dragging_slider = null
  if _active_slider == slider:
    _stop_preview()


func _stop_preview() -> void:
  _idle_timer.stop()
  _player.stop()
  _active_slider = null
