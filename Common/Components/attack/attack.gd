# Attack.gd
# This script handles the attack logic for an enemy character.
# It checks if the target is valid and applies damage if possible.
# The attack has a cooldown to prevent continuous damage application.
extends Node
class_name Component_Attack

# Emitted immediately after a successful attack when cooldown begins.
signal cooldown_started
# Emitted when the attack cooldown completes or is canceled early.
signal cooldown_ended

enum AttackResult {
  SUCCESS,
  ON_COOLDOWN,
  INVALID_TARGET
}

@onready var attack_timer: Timer = $AttackTimer

@export_group("Damage Settings")
@export var damage_amount: float = 100.0 ## Amount of damage per attack
@export var attack_speed: float = 1.0 ## How many attacks per second
@export var damage_source: String = "unknown" ## Source identifier for damage tracking
@export var attack_effect: Resource_AttackEffect = null ## Attack effect resource for additional properties

@export_group("Sound Effects")
@export var hit_sound: Resource_SoundEffect.SoundEffect = Resource_SoundEffect.SoundEffect.DEFAULT
@export var crit_sound: Resource_SoundEffect.SoundEffect = Resource_SoundEffect.SoundEffect.PLAYER_ATTACK_CRIT
@export var audio_player: AudioStreamPlayer3D


var is_on_cooldown: bool = false

const CRITICAL_DAMAGE_SOURCE: String = "critical"

func _ready():
  # Register this component in parent's metadata for discovery
  if get_parent():
    get_parent().set_meta("attack_component", self )

  if not audio_player:
    MyLogger.warn("Attack", "No AudioStreamPlayer assigned for Attack effect sounds.")

  if not attack_effect:
    # No attack effect assigned; create a fresh instance with default values.
    attack_effect = Resource_AttackEffect.new()
  else:
    # Duplicate inspector-assigned resource so each component has its own mutable instance.
    attack_effect = attack_effect.duplicate(true)


func perform_attack(target: Node) -> AttackResult:
  if not is_on_cooldown:
    MyLogger.debug("Attack", "Attempting to perform attack on target: %s" % target)
    # Find Health component via metadata
    var health = null
    if target.has_meta("health_component"):
      health = target.get_meta("health_component")
    
    if health and health is Component_Health:
      var did_crit = _roll_crit()
      var effective_damage_source = CRITICAL_DAMAGE_SOURCE if did_crit else damage_source
      health.take_damage(calculate_damage_amount(did_crit), effective_damage_source)
      if audio_player:
        AudioManager.play_sound(audio_player, crit_sound if did_crit else hit_sound)
      # Apply AoE splash to nearby enemies if radius is configured
      if attack_effect.aoe_radius > 0.0:
        _apply_aoe_splash(target, did_crit)
      # Start cooldown
      is_on_cooldown = true
      # if attack_speed is 10 attacks/second,
      # then the attack cooldown is 0.1 seconds/attack
      attack_timer.start(1.0 / attack_speed)
      cooldown_started.emit()
      return AttackResult.SUCCESS
    else:
      return AttackResult.INVALID_TARGET
   
  MyLogger.debug("Attack", "Attack is on cooldown. Cannot perform attack on target: %s" % target)
  return AttackResult.ON_COOLDOWN

func cancel():
  MyLogger.debug("Attack", "Attack cooldown canceled.")
  attack_timer.stop()
  _on_AttackTimer_timeout()

func _on_AttackTimer_timeout():
  is_on_cooldown = false
  cooldown_ended.emit()

## Returns true if a critical hit should occur based on attack_effect.crit_chance.
func _roll_crit() -> bool:
  assert(attack_effect != null, "Attack effect resource must be assigned to roll for critical hits.")
  return randf() < attack_effect.crit_chance

## Applies splash damage to all enemies within aoe_radius of the primary target,
## excluding the primary target itself. Damage is scaled by the aoe_falloff curve
## (sampled at normalized distance 0–1) and optionally by the crit multiplier.
func _apply_aoe_splash(primary_target: Node, is_crit: bool) -> void:
  assert(attack_effect != null, "Attack effect resource must be assigned to apply AoE splash damage.")

  if primary_target is not Node3D:
    return
  var target_pos: Vector3 = (primary_target as Node3D).global_position
  var apply_crit_to_splash := is_crit and attack_effect.crit_applies_to_splash
  var base_splash_damage := calculate_damage_amount(apply_crit_to_splash)

  for group in attack_effect.aoe_target_groups:
    for target in get_tree().get_nodes_in_group(group):
      if target == primary_target:
        continue
      if target is not Node3D:
        continue
      var dist: float = (target as Node3D).global_position.distance_to(target_pos)
      if dist > attack_effect.aoe_radius:
        continue
      var falloff_mult := 1.0
      if attack_effect.aoe_falloff:
        var normalized_dist: float = clamp(dist / attack_effect.aoe_radius, 0.0, 1.0)
        falloff_mult = max(0.0, attack_effect.aoe_falloff.sample(normalized_dist))
      var splash_damage := base_splash_damage * falloff_mult
      if splash_damage <= 0.0:
        continue
      if target.has_meta("health_component"):
        var health = target.get_meta("health_component")
        if health is Component_Health:
          MyLogger.debug("Attack", "AoE splash hit %s for %.1f damage (falloff=%.2f)" % [target, splash_damage, falloff_mult])
          health.take_damage(splash_damage, damage_source)

func calculate_damage_amount(is_crit: bool = false) -> float:
  assert(attack_effect != null, "Attack effect resource must be assigned to calculate damage.")

  var final_damage = damage_amount
  final_damage *= attack_effect.damage_multiplier
  if is_crit:
    final_damage *= attack_effect.crit_multiplier
  return final_damage
