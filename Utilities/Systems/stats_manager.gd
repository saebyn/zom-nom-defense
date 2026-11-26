extends Node

## Comprehensive stats tracking system for Tower Defense game
## Tracks enemy defeats, building placements, currency metrics, and player actions
## Features persistent storage via SaveManager
## 
## Usage:
##   StatsManager.track_enemy_defeated("basic_enemy", false)
##   StatsManager.track_building_placed("turret")
##   StatsManager.get_enemies_defeated_by_type("basic_enemy")
##   StatsManager.track_click_performed()
##   StatsManager.get_clicks_performed()

# Enemy defeat tracking
var enemies_defeated_total: int = 0
var enemies_defeated_by_type: Dictionary = {} # String -> int
var enemies_defeated_by_hand: int = 0

# Player action tracking
var clicks_performed: int = 0
var enemy_clicks: int = 0 # Clicks that actually hit an enemy

# Building placement tracking
var buildings_placed_total: int = 0
var buildings_placed_by_type: Dictionary = {} # String -> int

# Resource tracking (scrap and XP)
var total_scrap_earned: int = 0
var max_scrap_held: int = 0
var total_xp_earned: int = 0

# Level tracking
var waves_completed: int = 0
var max_waves_completed: int = 0

# Signals for real-time updates
signal enemy_defeated(enemy_type: String, by_hand: bool)
signal building_placed(building_type: String)
signal max_scrap_held_updated(new_max: int)
signal stats_updated()
signal stats_loaded()
signal stats_saved()

func _ready():
  MyLogger.info("StatsManager", "Stats tracking system initialized")
  
  # Register with SaveManager
  SaveManager.register_system(self )
  
  # Connect to existing systems
  if CurrencyManager:
    CurrencyManager.scrap_earned.connect(_on_scrap_earned)
    CurrencyManager.scrap_changed.connect(_on_scrap_changed)
    CurrencyManager.xp_earned.connect(_on_xp_earned)
    # Update max scrap with current amount if it's higher
    var current_scrap = CurrencyManager.get_scrap()
    if current_scrap > max_scrap_held:
      max_scrap_held = current_scrap
  else:
    MyLogger.error("StatsManager", "CurrencyManager not found!")

  if ScenarioManager:
    ScenarioManager.wave_changed.connect(_on_wave_changed)
  else:
    MyLogger.error("StatsManager", "ScenarioManager not found!")

func reset_attempt() -> void:
  waves_completed = 0

## Track an enemy defeat
func track_enemy_defeated(enemy_type: String, defeated_by_hand: bool = false) -> void:
  enemies_defeated_total += 1
  
  # Track by type
  if enemy_type in enemies_defeated_by_type:
    enemies_defeated_by_type[enemy_type] += 1
  else:
    enemies_defeated_by_type[enemy_type] = 1
  
  # Track defeats by hand vs by buildings
  if defeated_by_hand:
    enemies_defeated_by_hand += 1
  
  MyLogger.debug("Stats", "Enemy defeated: %s (by hand: %s). Total: %d" % [enemy_type, defeated_by_hand, enemies_defeated_total])
  
  enemy_defeated.emit(enemy_type, defeated_by_hand)
  stats_updated.emit()

## Track a player click (raw click count, regardless of hit or kill)
func track_click_performed() -> void:
  clicks_performed += 1
  # Throttle logging to avoid excessive debug output on every single click
  if clicks_performed % 50 == 0:
    MyLogger.debug("Stats", "Click performed. Total clicks: %d" % clicks_performed)
  stats_updated.emit()

## Track a click that actually hit an enemy
func track_enemy_click() -> void:
  enemy_clicks += 1
  # Throttle logging to avoid excessive debug output on every enemy click
  if enemy_clicks % 50 == 0:
    MyLogger.debug("Stats", "Enemy clicked. Total enemy clicks: %d" % enemy_clicks)
  stats_updated.emit()

## Track a building placement
func track_building_placed(building_type: String) -> void:
  buildings_placed_total += 1
  
  # Track by type
  if building_type in buildings_placed_by_type:
    buildings_placed_by_type[building_type] += 1
  else:
    buildings_placed_by_type[building_type] = 1
  
  MyLogger.debug("Stats", "Building placed: %s. Total: %d" % [building_type, buildings_placed_total])
  
  building_placed.emit(building_type)
  stats_updated.emit()

## Scrap earned callback
func _on_scrap_earned(amount: int) -> void:
  total_scrap_earned += amount
  MyLogger.debug("Stats", "Scrap earned: %d. Total earned: %d" % [amount, total_scrap_earned])

## Scrap changed callback - track maximum held
func _on_scrap_changed(new_amount: int) -> void:
  if new_amount > max_scrap_held:
    max_scrap_held = new_amount
    MyLogger.debug("Stats", "New max scrap held: %d" % max_scrap_held)
    max_scrap_held_updated.emit(max_scrap_held)
    stats_updated.emit()

## XP earned callback
func _on_xp_earned(amount: int) -> void:
  total_xp_earned += amount
  MyLogger.debug("Stats", "XP earned: %d. Total earned: %d" % [amount, total_xp_earned])

## Max waves completed callback
func _on_wave_changed(_scenario_id: String, _wave: int) -> void:
  waves_completed += 1
  if waves_completed > max_waves_completed:
    max_waves_completed = waves_completed
    MyLogger.debug("Stats", "New max waves completed: %d" % max_waves_completed)
    stats_updated.emit()

## Get stats data

func get_enemies_defeated_total() -> int:
  return enemies_defeated_total

func get_enemies_defeated_by_type(enemy_type: String) -> int:
  return enemies_defeated_by_type.get(enemy_type, 0)

func get_enemies_defeated_by_hand() -> int:
  return enemies_defeated_by_hand

func get_clicks_performed() -> int:
  return clicks_performed

func get_enemy_clicks() -> int:
  return enemy_clicks

func get_buildings_placed_total() -> int:
  return buildings_placed_total

func get_buildings_placed_by_type(building_type: String) -> int:
  return buildings_placed_by_type.get(building_type, 0)

func get_total_scrap_earned() -> int:
  return total_scrap_earned

func get_max_scrap_held() -> int:
  return max_scrap_held

func get_total_xp_earned() -> int:
  return total_xp_earned

func get_all_enemy_types() -> Array[String]:
  return enemies_defeated_by_type.keys()

func get_all_building_types() -> Array[String]:
  return buildings_placed_by_type.keys()

func get_max_waves_completed() -> int:
  return max_waves_completed

## Get comprehensive stats summary
func get_stats_summary() -> Dictionary:
  return {
    "enemies_defeated_total": enemies_defeated_total,
    "enemies_defeated_by_type": enemies_defeated_by_type.duplicate(),
    "enemies_defeated_by_hand": enemies_defeated_by_hand,
    "clicks_performed": clicks_performed,
    "enemy_clicks": enemy_clicks,
    "buildings_placed_total": buildings_placed_total,
    "buildings_placed_by_type": buildings_placed_by_type.duplicate(),
    "total_scrap_earned": total_scrap_earned,
    "max_scrap_held": max_scrap_held,
    "total_xp_earned": total_xp_earned,
    "max_waves_completed": max_waves_completed
  }

## Reset all stats (for new game, testing, etc.)
func reset_stats() -> void:
  reset_attempt()
  enemies_defeated_total = 0
  enemies_defeated_by_type.clear()
  enemies_defeated_by_hand = 0
  clicks_performed = 0
  enemy_clicks = 0
  buildings_placed_total = 0
  buildings_placed_by_type.clear()
  total_scrap_earned = 0
  max_scrap_held = CurrencyManager.get_scrap() if CurrencyManager else 0
  total_xp_earned = 0
  max_waves_completed = 0
  
  MyLogger.info("StatsManager", "All stats reset")
  stats_updated.emit()

## SaveableSystem Interface Implementation

## Get unique save key for this system
func get_save_key() -> String:
  return "stats"

## Get saveable state as dictionary
func get_save_data() -> Dictionary:
  return {
    "enemies_defeated_total": enemies_defeated_total,
    "enemies_defeated_by_type": enemies_defeated_by_type,
    "enemies_defeated_by_hand": enemies_defeated_by_hand,
    "clicks_performed": clicks_performed,
    "enemy_clicks": enemy_clicks,
    "buildings_placed_total": buildings_placed_total,
    "buildings_placed_by_type": buildings_placed_by_type,
    "total_scrap_earned": total_scrap_earned,
    "max_scrap_held": max_scrap_held,
    "total_xp_earned": total_xp_earned,
    "max_waves_completed": max_waves_completed
  }

## Load data from saved state
func load_data(data: Dictionary) -> void:
  enemies_defeated_total = data.get("enemies_defeated_total", 0)
  enemies_defeated_by_type = data.get("enemies_defeated_by_type", {})
  enemies_defeated_by_hand = data.get("enemies_defeated_by_hand", 0)
  clicks_performed = data.get("clicks_performed", 0)
  enemy_clicks = data.get("enemy_clicks", 0)
  buildings_placed_total = data.get("buildings_placed_total", 0)
  buildings_placed_by_type = data.get("buildings_placed_by_type", {})
  total_scrap_earned = data.get("total_scrap_earned", 0)
  max_scrap_held = data.get("max_scrap_held", 0)
  total_xp_earned = data.get("total_xp_earned", 0)
  max_waves_completed = data.get("max_waves_completed", 0)
  
  MyLogger.info("StatsManager", "Stats loaded - Enemies defeated: %d, Buildings placed: %d, Scrap earned: %d, XP earned: %d" % [enemies_defeated_total, buildings_placed_total, total_scrap_earned, total_xp_earned])
  stats_loaded.emit()

## Reset to default state (for new game)
func reset_data() -> void:
  reset_stats()

## Legacy Methods (deprecated, kept for backward compatibility)

## Check if save file exists (checks SaveManager instead)
func has_saved_stats() -> bool:
  return SaveManager.current_save_slot > 0

## Delete save file (delegates to SaveManager)
func delete_saved_stats() -> bool:
  if SaveManager.current_save_slot > 0:
    return SaveManager.delete_save_slot(SaveManager.current_save_slot)
  return true
