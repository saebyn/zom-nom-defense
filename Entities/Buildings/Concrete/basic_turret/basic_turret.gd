class_name Entity_BasicTurret
extends Entity_ShootingBuilding

## A turret that rotates to track and attack enemies.
## The turret smoothly rotates its top mesh towards the nearest enemy target
## and only attacks when properly aligned within the aim_margin threshold.

@onready var animation_tree: AnimationTree = $AnimationTree

@export var rotation_speed: float = 360 # Degrees per second
@export var aim_margin: float = 0.1 # Radians within which we consider ourselves "aimed" at the target
@onready var turret_yaw: Node3D = $turret/TurretYaw
@export var attack_particle_system: GPUParticles3D

const BASE_BLEND_PATH := "parameters/BaseBlend/blend_amount"
const FIRE_REQUEST_PATH := "parameters/FireOneShot/request"

func _process(delta: float) -> void:
  if current_target:
    # Blend to the reset pose so TurretYaw can own target tracking without
    # competing with the idle animation.
    animation_tree.set(BASE_BLEND_PATH, 0.0)

    # Calculate target direction for yaw rotation
    var target_direction: Vector3 = (current_target.global_position - turret_yaw.global_position).normalized()
    var aim_yaw_angle: float = atan2(-target_direction.x, -target_direction.z) + PI / 2
    var turret_yaw_angle: float = turret_yaw.rotation.y

    var rotation_delta: float = deg_to_rad(rotation_speed) * delta

    var rotation_amount: float = get_angle_difference(turret_yaw_angle, aim_yaw_angle)
    var rotation_amount_delta = clampf(rotation_amount, -rotation_delta, rotation_delta)

    if abs(rotation_amount) > aim_margin:
      MyLogger.trace("BasicTurret", "Rotating turret by %f radians towards target (clamped from %f)" % [rotation_amount_delta, rotation_amount])
      ready_to_attack = false
      turret_yaw.rotate_y(rotation_amount_delta)
    else:
      MyLogger.trace("BasicTurret", "Turret aligned with target.")
      ready_to_attack = true
  else:
    MyLogger.trace("BasicTurret", "No target detected.")
    ready_to_attack = false
    animation_tree.set(BASE_BLEND_PATH, 1.0)


func get_angle_difference(angle1: float, angle2: float) -> float:
  var diff: float = fmod(angle2 - angle1 + PI, TAU) - PI
  return diff


func _on_attack() -> void:
  animation_tree.set(FIRE_REQUEST_PATH, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
  attack_particle_system.restart()
