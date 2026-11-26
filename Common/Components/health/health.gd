extends Node3D
class_name Component_Health

const UNIT_FRAME_GROUP: StringName = &"unit_frames"
const UNIT_FRAME_LAYOUT_MANAGER_GROUP: StringName = &"unit_frame_layout_managers"

## Opacity applied when HP is at or above the high-health threshold (nearly invisible)
const HIGH_HP_OPACITY: float = 0.10
## Maximum opacity, applied at or below the low-health threshold
const FULL_OPACITY: float = 1.0
## HP ratio above which the bar fades to low opacity (becomes more transparent)
const HIGH_HP_THRESHOLD: float = 0.8
## HP ratio at or below which the bar is always fully opaque
const LOW_HP_THRESHOLD: float = 0.3

## Seconds the unit frame remains visible after taking damage
const DAMAGE_REVEAL_DURATION: float = 3.0

## Health bar fill colors keyed to zombie/entity type themes (Visual Style Guide)
const COLOR_ZOMBIE_STANDARD: Color = Color(0.478, 0.608, 0.463, 1.0) # desaturated green #7A9B76
const COLOR_ZOMBIE_FAST: Color = Color(0.788, 0.365, 0.310, 1.0) # warm red/orange #C95D4F
const COLOR_ZOMBIE_TANK: Color = Color(0.420, 0.447, 0.502, 1.0) # cool gray #6B7280
const COLOR_SURVIVOR: Color = Color(0.949, 0.655, 0.353, 1.0) # orange accent #F2A75A
const COLOR_DEFAULT: Color = Color(0.349, 0.431, 0.286, 1.0) # zombie_flesh from palette
## Lerp weight toward white when tinting the name label (0 = bar color, 1 = pure white)
const NAME_LABEL_LIGHTEN_WEIGHT: float = 0.55

@export_group("Health Settings")
@export var hitpoints: int = 1000
@export var max_damage_per_hit: float = INF
@export var disabled: bool:  ## Prevents the entity from taking damage or dying. When true, the unit frame is hidden and hitpoints are not tracked.
  get:
    return disabled
  set(value):
    disabled = value
    _update_display()

@export_group("Visual Settings")
## When false the unit frame sprite is hidden entirely (health is still tracked).
@export var unit_frame_enabled: bool = true
## Override the health bar fill color. Requires use_custom_bar_color = true.
@export var bar_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## When true, bar_color is used instead of automatic type-based color detection.
@export var use_custom_bar_color: bool = false

@export_group("SFX Settings")
@export var hit_sound: Resource_SoundEffect.SoundEffect = Resource_SoundEffect.SoundEffect.DEFAULT
@export var death_sound: Resource_SoundEffect.SoundEffect = Resource_SoundEffect.SoundEffect.DEFAULT
@export var audio_player: AudioStreamPlayer3D


@onready var health_bar: ProgressBar = $SubViewportContainer/SubViewport/VBoxContainer/BarOverlay/HealthBar
@onready var health_label: Label = $SubViewportContainer/SubViewport/VBoxContainer/BarOverlay/HealthLabel
@onready var name_label: Label = $SubViewportContainer/SubViewport/VBoxContainer/NameLabel
@onready var background: NinePatchRect = $SubViewportContainer/SubViewport/Background
@onready var subviewport: SubViewport = $SubViewportContainer/SubViewport
@onready var sprite: Sprite3D = $Sprite3D

var max_hitpoints: int
var dead: bool = false

## Whether the player is currently hovering over the parent entity
var _hovered: bool = false
## Seconds remaining before the unit frame auto-hides after damage
var _damage_reveal_timer: float = 0.0
## Whether pausing the game is temporarily revealing this frame.
var _paused_reveal: bool = false
## Whether the shared layout manager has allocated a visible slot to this frame.
## Defaults to true so the component keeps working in scenes without a manager.
var _layout_allowed: bool = true

var damage_numbers: Component_DamageNumbers

## StyleBoxFlat used to apply fill color to the health bar (created once in _ready)
var _bar_fill_style: StyleBoxFlat

signal died(damage_source: String)
signal damaged(amount: float, hitpoints: int, damage_source: String)

func take_damage(amount: float, damage_source: String = "unknown"):
  if disabled:
    return

  assert(amount >= 0, "Damage amount cannot be negative.")

  var damage = floori(min(amount, max_damage_per_hit))
  hitpoints = max(hitpoints - damage, 0)
  damaged.emit(damage, hitpoints, damage_source)
  _damage_reveal_timer = DAMAGE_REVEAL_DURATION
  _update_display()
  
  # Show damage number via damage numbers component if available
  if damage_numbers:
      damage_numbers.show_damage(damage, damage_source)

  # Play hit sound if audio player is assigned
  if audio_player:
    var pitch_override = _get_voice_pitch()
    AudioManager.play_sound(audio_player, hit_sound, pitch_override)
  
  assert(hitpoints >= 0, "Hitpoints should never be negative.")

  if hitpoints <= 0:
    _die(damage_source)


func _ready():
  visible = true
  add_to_group(UNIT_FRAME_GROUP)

  # Store the initial hitpoints as max_hitpoints
  max_hitpoints = hitpoints

  # Register this component in parent's metadata for discovery
  # Must happen in _ready so that sibling/parent scripts can find it during their own _ready
  var parent = get_parent()

  if not audio_player:
    MyLogger.warn("Health", "No AudioStreamPlayer assigned for Health effect sounds.")

  if parent:
    parent.set_meta("health_component", self)

    # Try to get damage numbers component if it exists
    if parent.has_meta("damage_numbers_component"):
      damage_numbers = parent.get_meta("damage_numbers_component")

  # One-time display initialisation
  _bar_fill_style = StyleBoxFlat.new()
  health_bar.add_theme_stylebox_override("fill", _bar_fill_style)
  subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
  _paused_reveal = GameManager.is_paused()
  _update_display()

  var layout_manager := get_tree().get_first_node_in_group(UNIT_FRAME_LAYOUT_MANAGER_GROUP)
  if layout_manager and layout_manager.has_method("register_unit_frame"):
    layout_manager.register_unit_frame(self)

  GameManager.speed_changed.connect(_on_game_speed_changed)

func _on_game_speed_changed(new_speed: float):
  _paused_reveal = new_speed <= 0
  _update_display()

func _process(delta: float) -> void:
  if _damage_reveal_timer > 0.0:
    _damage_reveal_timer -= delta
    if _damage_reveal_timer <= 0.0 and not _hovered:
      _damage_reveal_timer = 0.0
      _update_display()

func _update_display():
  if not is_node_ready():
    return
  
  sprite.visible = _layout_allowed and is_unit_frame_requested()

  # Set up health display UI
  health_bar.max_value = max_hitpoints
  health_bar.value = hitpoints
  health_label.text = str(hitpoints) + " / " + str(max_hitpoints)

  # Set entity name / type label
  name_label.text = _get_entity_display_name()

  _update_unit_frame_visuals()

## Refresh the unit-frame display without changing hover state.
## Call this after updating data on the parent node (e.g. assigning survivor_name)
## so the label reflects the latest values immediately.
func refresh_display() -> void:
  _update_display()

## Return whether the component's own rules currently request a unit frame.
func is_unit_frame_requested() -> bool:
  var parent = get_parent()
  var is_survivor: bool = parent != null and parent.is_in_group("survivors")
  return (not disabled) and unit_frame_enabled and (is_survivor or _hovered or _damage_reveal_timer > 0.0 or _paused_reveal)

## Hovered and recently damaged frames can displace a distance-ranked frame.
func is_unit_frame_urgent() -> bool:
  return _hovered or _damage_reveal_timer > 0.0

## Apply the shared layout manager's visibility quota without changing local rules.
func set_unit_frame_layout_allowed(allowed: bool) -> void:
  if _layout_allowed == allowed:
    return

  _layout_allowed = allowed
  _update_display()

func is_unit_frame_layout_allowed() -> bool:
  return _layout_allowed

## Called by external hover detection to make the unit frame visible.
func show_unit_frame() -> void:
  _hovered = true
  _update_display()

## Called by external hover detection to hide the unit frame (unless recently damaged).
func hide_unit_frame() -> void:
  _hovered = false
  _update_display()

## Determine the fill color for the health bar based on the entity type.
## Returns bar_color if use_custom_bar_color is true, otherwise infers from parent entity type.
func _get_effective_bar_color() -> Color:
  if use_custom_bar_color:
    return bar_color

  var parent = get_parent()
  if not parent:
    return COLOR_DEFAULT

  # Survivors use the orange accent color
  if parent.is_in_group("survivors"):
    return COLOR_SURVIVOR

  # Use enemy_type string to identify zombie sub-types
  if "enemy_type" in parent:
    var type: String = str(parent.enemy_type).to_lower()
    if "fast" in type:
      return COLOR_ZOMBIE_FAST
    if "tank" in type:
      return COLOR_ZOMBIE_TANK
    # Any other enemy is treated as standard zombie
    return COLOR_ZOMBIE_STANDARD

  return COLOR_DEFAULT

## Return a human-readable display name for the parent entity.
## Survivors yield their assigned survivor_name; enemies yield their enemy_type
## formatted as title-case words (e.g. "sprinter_zombie" → "Sprinter Zombie").
## Returns an empty string when the entity has neither property.
func _get_entity_display_name() -> String:
  var parent = get_parent()
  if not parent:
    return ""

  # Survivors: use the assigned survivor name
  if parent.is_in_group("survivors") and "survivor_name" in parent:
    var sname: String = str(parent.survivor_name)
    if not sname.is_empty():
      return sname

  # Enemies: format the enemy_type identifier as title-case words
  if "enemy_type" in parent:
    var type: String = str(parent.enemy_type)
    if not type.is_empty():
      var words := type.split("_")
      var parts: PackedStringArray = []
      for word in words:
        parts.append(word.to_lower().capitalize())
      return " ".join(parts)

  return ""

## Update health bar fill color and sprite transparency based on current HP ratio.
func _update_unit_frame_visuals():
  if not is_node_ready():
    return

  var hp_ratio: float = float(hitpoints) / float(max_hitpoints) if max_hitpoints > 0 else 0.0

  # Apply fill color, lerping toward saturated red as HP drops
  var base_color := _get_effective_bar_color()
  var danger_color := Color(0.85, 0.10, 0.10, 1.0) # vivid red
  # Color starts shifting at 60% HP and is fully red at 0%
  var color_lerp_weight: float = clampf(1.0 - (hp_ratio / 0.6), 0.0, 1.0)
  # Increase saturation as well: convert to HSV, boost saturation, convert back
  var lerped := base_color.lerp(danger_color, color_lerp_weight)
  if _bar_fill_style:
    _bar_fill_style.bg_color = lerped

  # Apply a lightened version of the bar color to the name label so it is
  # visually distinct from the white HP numbers but still entity-type-coded.
  name_label.add_theme_color_override("font_color", base_color.lerp(Color.WHITE, NAME_LABEL_LIGHTEN_WEIGHT))

  # Compute transparency using three zones:
  #   hp >= HIGH_HP_THRESHOLD : faded (HIGH_HP_OPACITY)
  #   hp <= LOW_HP_THRESHOLD  : fully opaque (FULL_OPACITY)
  #   between thresholds      : linear interpolation
  var target_alpha: float
  if hp_ratio >= HIGH_HP_THRESHOLD:
    target_alpha = HIGH_HP_OPACITY
  elif hp_ratio <= LOW_HP_THRESHOLD:
    target_alpha = FULL_OPACITY
  else:
    var lerp_weight: float = (hp_ratio - LOW_HP_THRESHOLD) / (HIGH_HP_THRESHOLD - LOW_HP_THRESHOLD)
    target_alpha = lerp(FULL_OPACITY, HIGH_HP_OPACITY, lerp_weight)

  # Modulate the bar and background individually inside the SubViewport.
  # Sprite3D.modulate is left at full opacity so the label (baked into the
  # same SubViewport texture) is never dimmed — it stays fully readable.
  health_bar.modulate.a = target_alpha
  background.modulate.a = target_alpha

func _die(damage_source: String = "unknown"):
  if dead:
    return

  # Play death sound if audio player is assigned
  if audio_player:
    var pitch_override = _get_voice_pitch()
    AudioManager.play_sound(audio_player, death_sound, pitch_override)

  dead = true
  hitpoints = 0
  died.emit(damage_source)

## Get the voice pitch from parent if available (for survivors)
func _get_voice_pitch() -> Variant:
  var parent := get_parent()
  if parent and "voice_pitch" in parent and parent.voice_pitch != null:
    return parent.voice_pitch
  return null # No override
