## Add beneath an entity and connect Health.died to destroyed in the scene.
## Detaches before playback so the entity can be removed immediately.
class_name Effect_Destruction
extends Node3D

@export_range(0.05, 0.5, 0.01) var flash_duration: float = 0.16

var _triggered: bool = false

func destroyed(_damage_source: String) -> void:
  if _triggered:
    return
  _triggered = true
  # Keep the effect in the entity's world, with its authored offset and scale.
  reparent(get_parent().get_parent(), true)
  var debris: CPUParticles3D = $Debris
  debris.emitting = true
  var flash: MeshInstance3D = $Flash
  flash.show()
  var tween := create_tween()
  tween.tween_property(flash, "scale", flash.scale * 0.01, flash_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
  tween.tween_callback(flash.hide)
  # Bound cleanup to the scene, including when particles are offscreen.
  tween.tween_interval(maxf(0.0, debris.lifetime - flash_duration) + 0.1)
  tween.tween_callback(queue_free)
