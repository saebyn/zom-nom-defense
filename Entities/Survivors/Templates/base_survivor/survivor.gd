extends Node3D

@export var skin_material: StandardMaterial3D
@export var hitpoints_override: int = -1 ## If set to a positive value, overrides the default health component's hitpoints
@export_range(0.5, 2.0) var voice_pitch: float = 1.0 ## Pitch override for this survivor's voice sounds

var health: Component_Health
var survivor_name: String = "" ## Name of this survivor (from their persistent profile)
var profile_id: String = "" ## Persistent profile id assigned by SurvivorNameManager

@onready var mesh: MeshInstance3D = $Skeleton3D/characterMedium
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

func _ready():
  # Assign (or create) a persistent survivor profile.
  # Returns the id of an alive carry-forward profile, or a freshly created one.
  profile_id = SurvivorNameManager.assign_next_profile()
  survivor_name = SurvivorNameManager.get_profile_name(profile_id)
  if survivor_name.is_empty():
    MyLogger.warn("Survivor", "Could not get name for profile id '%s'" % profile_id)
  else:
    MyLogger.info("Survivor", "Survivor '%s' (profile %s) created" % [survivor_name, profile_id])

  # Find Health component via metadata
  if has_meta("health_component"):
    health = get_meta("health_component")
  
  # Connect health signals
  if health:
    if not health.died.is_connected(_on_died):
      health.died.connect(_on_died)
    if not health.damaged.is_connected(_on_health_damaged):
      health.damaged.connect(_on_health_damaged)

    # Override health if specified
    if hitpoints_override > 0:
      health.hitpoints = hitpoints_override

  # Add texture to mesh
  if skin_material and mesh:
    mesh.set_surface_override_material(0, skin_material)

  # Refresh health display now that survivor_name is set.
  # health._ready() runs before target._ready() (children initialise first),
  # so the name label would otherwise remain blank until the first hover event.
  if health:
    health.refresh_display()


func _on_died(damage_source: String = "unknown") -> void:
  MyLogger.info("Survivor", "Survivor '%s' (profile %s) has died. Source: %s" % [survivor_name, profile_id, damage_source])
  # Mark the profile as dead (releases name for future reuse)
  SurvivorNameManager.mark_profile_dead(profile_id)
  var parent := get_parent()
  if parent and parent.has_method("on_survivor_died"):
    parent.on_survivor_died(self, damage_source)
  queue_free() # Remove the survivor from the scene when it dies.


func _on_health_damaged(amount: int, hitpoints: int, damage_source: String = "unknown") -> void:
  MyLogger.debug("Survivor.Combat", "Survivor '%s' took %d damage from %s. Remaining HP: %d" % [survivor_name, amount, damage_source, hitpoints])
