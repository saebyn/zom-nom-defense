extends Node3D
## Scenario 1 only. Tune the flash here and debris in the companion scene.

@export_range(0.05, 0.5, 0.01) var flash_duration: float = 0.16

func _ready() -> void:
  var flash: MeshInstance3D = $Flash
  var tween := create_tween()
  tween.tween_property(flash, "scale", flash.scale * 0.01, flash_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
  tween.tween_callback(flash.hide)
  # Bound cleanup to the scene, including when particles are offscreen.
  var debris: CPUParticles3D = $Debris
  tween.tween_interval(maxf(0.0, debris.lifetime - flash_duration) + 0.1)
  tween.tween_callback(queue_free)
