class_name SettingBinding
extends Node

## SettingBinding - Data-driven binding between a UI control and a SettingsManager property
##
## Add this node as a child of any settings container to bind a UI control to a
## SettingsManager property. Configure all exported properties in the inspector.
## The menu script discovers these nodes automatically and calls load_value(),
## apply_value(), and revert_value() in bulk — no per-setting code required.
##
## For a step-by-step guide on adding new settings, see docs/adding_settings.md

## Emitted when the user changes the value (not during programmatic load/revert)
signal value_changed(new_value: Variant)

## SettingsManager property name to read/write (e.g. &"master_volume")
@export var setting_key: StringName = ""

## Path to the UI control node relative to this SettingBinding node
@export var control_path: NodePath = NodePath("")

## Property on the control to get/set (e.g. &"value", &"button_pressed", &"selected", &"text")
@export var control_property: StringName = "value"

## Logical group used to batch apply/revert operations in the menu script
@export_enum("video", "audio", "twitch", "debug", "gameplay", "none") var apply_group: String = "none"

## When true, each user change is immediately forwarded to SettingsManager (e.g. audio sliders)
@export var live_preview: bool = false

## When false, this binding is NOT reverted when the user presses Cancel (e.g. debug mode)
@export var revert_on_cancel: bool = true

## Conversion applied between the SettingsManager value and the control display value
@export_enum("none", "db_to_percentage") var conversion: String = "none"

## Optional path to a Label node that is updated whenever the value changes
@export var value_label_path: NodePath = NodePath("")

## Format string used to update the label, e.g. "Master: %d%%" (receives one integer arg)
@export var label_format: String = ""

var _control: Control = null
var _original_value: Variant = null
var _staged_value: Variant = null
# Guards against re-entrant signal handling during programmatic value updates
var _loading: bool = false


func _ready() -> void:
  if control_path != NodePath(""):
    _control = get_node_or_null(control_path)
  if is_instance_valid(_control):
    _wire_signal()


func _wire_signal() -> void:
  if not is_instance_valid(_control):
    return
  if _control is HSlider or _control is VSlider:
    _control.value_changed.connect(_on_value_changed)
  elif _control is CheckButton or _control is CheckBox:
    _control.toggled.connect(_on_toggled)
  elif _control is OptionButton:
    _control.item_selected.connect(_on_item_selected)
  elif _control is TextEdit:
    _control.text_changed.connect(_on_text_changed)


func _on_value_changed(value: float) -> void:
  if _loading:
    return
  _staged_value = _convert_from_control(value)
  _update_label()
  if live_preview:
    _apply_to_manager()
  value_changed.emit(_staged_value)


func _on_toggled(pressed: bool) -> void:
  if _loading:
    return
  _staged_value = pressed
  if live_preview:
    _apply_to_manager()
  value_changed.emit(_staged_value)


func _on_item_selected(index: int) -> void:
  if _loading:
    return
  _staged_value = index
  if live_preview:
    _apply_to_manager()
  value_changed.emit(_staged_value)


func _on_text_changed() -> void:
  if _loading:
    return
  if _control is TextEdit:
    _staged_value = (_control as TextEdit).text
  if live_preview:
    _apply_to_manager()
  value_changed.emit(_staged_value)


## Load the current value from SettingsManager and update the UI control.
## Call this when the menu is opened to populate controls with persisted settings.
func load_value() -> void:
  if not is_instance_valid(_control) or setting_key.is_empty():
    return
  _loading = true
  _original_value = SettingsManager.get(setting_key)
  _staged_value = _original_value
  _control.set(control_property, _convert_to_control(_original_value))
  _loading = false
  _update_label()


## Return the control node resolved from control_path
func get_control() -> Control:
  return _control


## Return the value staged by the most recent user interaction (or the loaded value if unchanged)
func get_staged_value() -> Variant:
  return _staged_value


## Return the value that was present in SettingsManager when load_value() was last called
func get_original_value() -> Variant:
  return _original_value


## Write the current staged value to SettingsManager (without updating the UI control)
func apply_value() -> void:
  _apply_to_manager()


## Restore the original value in SettingsManager and update the UI control.
## Called by the menu script when the user cancels or when a video-settings revert occurs.
func revert_value() -> void:
  _staged_value = _original_value
  if is_instance_valid(_control):
    _loading = true
    _control.set(control_property, _convert_to_control(_original_value))
    _loading = false
  _apply_to_manager()
  _update_label()


func _apply_to_manager() -> void:
  if setting_key.is_empty():
    return
  SettingsManager.set(setting_key, _staged_value)


func _convert_to_control(val: Variant) -> Variant:
  if conversion == "db_to_percentage":
    if float(val) <= SettingsManager.AUDIO_SILENCE_DB:
      return 0.0
    return db_to_linear(float(val)) * 100.0
  return val


func _convert_from_control(val: Variant) -> Variant:
  if conversion == "db_to_percentage":
    var percent := float(val)
    return SettingsManager.AUDIO_SILENCE_DB if percent <= 0.0 else linear_to_db(percent / 100.0)
  return val


func _update_label() -> void:
  if label_format.is_empty() or value_label_path == NodePath(""):
    return
  var label_node: Node = get_node_or_null(value_label_path)
  if is_instance_valid(label_node) and label_node is Label:
    (label_node as Label).text = label_format % [roundi(_convert_to_control(_staged_value))]
