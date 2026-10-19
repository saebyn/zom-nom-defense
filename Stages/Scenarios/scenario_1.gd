extends Stage_Scenario

@onready var car: Node3D = $MuscleCar
@onready var survivor: Node3D = $Survivor1

@export var survivor_fall_y: float = -3.278 ## Relative Y position the survivor will fall to when the car is destroyed
@export var survivor_fall_duration: float = 0.5

## Dialogic timeline path
const TIMELINE := "res://Dialogic/Timelines/scenario_1_tut_welcome.dtl"


func _ready() -> void:
  super._ready()
  # Defer so the full scene tree (including Main and BuildingPlacement) is ready
  call_deferred("_start_intro_dialog")


func _start_intro_dialog() -> void:
  if Dialogic == null:
    MyLogger.warn("Scenario1", "Dialogic autoload not found — skipping dialog")
    return

  Dialogic.process_mode = Node.PROCESS_MODE_ALWAYS
  var layout: Node = Dialogic.start(TIMELINE)
  if layout:
    layout.process_mode = Node.PROCESS_MODE_ALWAYS


func car_destroyed(damage_source: String):
  if not is_instance_valid(car) or car.is_queued_for_deletion():
    return
  MyLogger.info("Scenario1", "Car destroyed by " + damage_source)
  car.queue_free()
  # Then we need to make the survivor fall down
  var tween = get_tree().create_tween()
  tween.tween_property(
    survivor,
    "position:y",
    survivor_fall_y,
    survivor_fall_duration
  ).as_relative().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
