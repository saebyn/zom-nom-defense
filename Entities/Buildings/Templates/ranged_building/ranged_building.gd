extends Entity_PlaceableBuilding
class_name Entity_RangedBuilding

const RANGED_BUILDINGS_GROUP: String = "ranged_buildings"

@export var effect_range: float = 15.0:
  get:
    return effect_range
  set(value):
    effect_range = value
    if effect_range_indicator:
      effect_range_indicator.scale = _calculate_scale(effect_range)

## Whether this building is currently being hovered over by the mouse
var _is_hovered: bool = false

@onready var effect_range_indicator: MeshInstance3D = $RangePreview

func _ready():
  # Call parent _ready first
  super._ready()
  
  # Add to buildings group for range preview coordination
  add_to_group(RANGED_BUILDINGS_GROUP)

  # Scale the range indicator properly (do this once at ready)
  # CylinderMesh has a default radius of 0.5 and height of 2.0. To get a cylinder with radius = effect_range,
  # we need to scale X and Z by effect_range / 0.5 = effect_range * 2.
  # For height, we use a small value (0.1) to create a thin disc showing ground coverage.
  if effect_range_indicator:
    effect_range_indicator.scale = _calculate_scale(effect_range)

  MyLogger.info("RangedBuilding", "Ranged building initialized with effect range: %f" % effect_range)


func _calculate_scale(new_range: float) -> Vector3:
  # CylinderMesh has a default radius of 0.5 and height of 2.0. To get a cylinder with radius = effect_range,
  # we need to scale X and Z by effect_range / 0.5 = effect_range * 2.
  # For height, we use a small value to create a thin disc showing ground coverage.
  return Vector3(new_range * 2, 0.001, new_range * 2)


## Shows the effect range indicator for this ranged building.
## Used during placement mode to show all existing turret ranges, or on hover.
func show_range_indicator() -> void:
  MyLogger.debug("RangedBuilding", "Showing range indicator with range: %f" % effect_range)
  if effect_range_indicator:
    effect_range_indicator.visible = true


## Hides the effect range indicator for this ranged building.
## Used when exiting placement mode or when mouse stops hovering.
## @param force When true, hides the indicator even if currently being hovered (used for placement mode exit)
func hide_range_indicator(force: bool = false) -> void:
  # Don't hide if currently being hovered, unless forced
  if _is_hovered and not force:
    return
  if effect_range_indicator:
    effect_range_indicator.visible = false


## Called when mouse enters this building's collision shape.
func on_mouse_enter() -> void:
  _is_hovered = true
  show_range_indicator()


## Called when mouse exits this building's collision shape.
func on_mouse_exit() -> void:
  _is_hovered = false
  hide_range_indicator()

func _handle_buffs(buff_type: Entity_BuffBuilding.BuffType, amounts: Array[float]) -> void:
  match buff_type:
    Entity_BuffBuilding.BuffType.RANGE:
      effect_range = _stack_buffs(buff_type, effect_range, amounts)

## Override to add range stat
func get_tooltip_info() -> Dictionary:
  var info = super.get_tooltip_info()
  
  # Range
  var base_range = _original_values.get(Entity_BuffBuilding.BuffType.RANGE, effect_range)
  info.base_stats["range"] = base_range
  info.current_stats["range"] = effect_range
  
  return info
