extends Control
class_name UI_CurrencyDisplay

## UI component to display the player's current scrap and level

const LOSS_COLOR = Color(0.694, 0.298, 0.122, 1.0)

@onready var scrap_label: Label = $HBoxContainer/ScrapLabel
@onready var level_label: Label = $HBoxContainer/LevelLabel

var _pulse_tweens: Dictionary[Label, Tween] = {}
var _displayed_scrap: int

func _ready():
  # Connect to the currency manager signals
  if CurrencyManager:
    CurrencyManager.scrap_changed.connect(_on_scrap_changed)
    CurrencyManager.level_up.connect(_on_level_up)
    CurrencyManager.display_pulse_requested.connect(_on_display_pulse_requested)
    # Initialize the display with current resources
    _update_display()
  else:
    push_error("CurrencyManager not found! Make sure it's loaded as an autoload.")


func _update_display():
  var scrap = CurrencyManager.get_scrap()
  var level = CurrencyManager.get_level()
  scrap_label.text = "Scrap: %d" % scrap
  level_label.text = "Level: %d" % level
  _displayed_scrap = scrap


func _on_scrap_changed(new_amount: int):
  var pulse_color = LOSS_COLOR if new_amount < _displayed_scrap else Color.GOLD
  _update_display()
  _pulse_label(scrap_label, pulse_color)

func _on_level_up(_new_level: int):
  _update_display()
  _pulse_label(level_label)


func _on_display_pulse_requested(value_name: String, duration: float) -> void:
  match value_name:
    "scrap":
      _pulse_label(scrap_label, Color.GOLD, duration)
    "level":
      _pulse_label(level_label, Color.GOLD, duration)


func _pulse_label(label: Label, pulse_color: Color = Color.GOLD, duration: float = 0.5) -> void:
  var active_tween = _pulse_tweens.get(label) as Tween
  if active_tween:
    active_tween.kill()

  var tween = create_tween()
  _pulse_tweens[label] = tween
  tween.tween_method(_animate_pulse.bind(label, pulse_color, duration), 0.0, duration, duration)
  tween.tween_callback(_clear_shadow_offset.bind(label))


func _animate_pulse(elapsed: float, label: Label, pulse_color: Color, duration: float) -> void:
  var oscillation = 0.675 + 0.325 * cos(elapsed * TAU / 0.75)
  var fade_out = clampf((duration - elapsed) / 0.5, 0.0, 1.0)
  var strength = oscillation * fade_out
  label.modulate = Color.WHITE.lerp(pulse_color, strength)
  _set_shadow_offset(lerpf(1.0, 5.0, strength), label)


func _set_shadow_offset(offset: float, label: Label) -> void:
  var rounded_offset = roundi(offset)
  label.add_theme_constant_override("shadow_offset_x", rounded_offset)
  label.add_theme_constant_override("shadow_offset_y", rounded_offset)


func _clear_shadow_offset(label: Label) -> void:
  label.modulate = Color.WHITE
  label.remove_theme_constant_override("shadow_offset_x")
  label.remove_theme_constant_override("shadow_offset_y")
